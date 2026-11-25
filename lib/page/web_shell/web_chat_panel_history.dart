part of 'web_shell_bootstrap.dart';

extension _WebChatPanelPersonalHistory on WebChatPanelState {
  Future<bool> _showRestoredHistory(
    PersonalHistorySyncOutcome outcome,
    bool Function() isCurrent,
  ) async {
    final t = Translations.of(context);
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final continued = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: _sessions,
        builder: (context, _) => CupertinoAlertDialog(
          title: Text(isChinese ? '个人云端历史副本' : 'Personal cloud history copy'),
          content: !isCurrent()
              ? const SizedBox.shrink()
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      key: const ValueKey('web-personal-history-restored-text'),
                      children: [
                        for (final text in outcome.recoveredText)
                          Padding(
                            padding: AppSpacing.allSmall,
                            child: Text(text),
                          ),
                      ],
                    ),
                  ),
                ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.buttonClose),
            ),
            if (outcome.canContinueSnapshot && isCurrent())
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isChinese ? '继续' : 'Continue'),
              ),
          ],
        ),
      ),
    );
    return continued == true;
  }

  Future<String?> _requestHistoryPassphrase({required bool enable}) {
    final t = Translations.of(context);
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final enableLabel = isChinese
        ? '开启个人云端历史'
        : 'Enable personal cloud history';
    final startNote = isChinese
        ? '开启后同步新消息。请保存恢复口令，换设备时需要用它解密。'
        : 'New messages sync after you enable this. Keep your passphrase to restore them on another device.';
    var passphrase = '';
    var confirmation = '';
    return showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => CupertinoAlertDialog(
          title: Text(
            enable ? enableLabel : t.common.e2eeBackupCloudRestoreTitle,
          ),
          content: Padding(
            padding: AppSpacing.allSmall,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (enable) ...[Text(startNote), AppSpacing.verticalSmall],
                CupertinoTextField(
                  key: const ValueKey('web-personal-history-passphrase'),
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  placeholder: t.common.e2eeBackupCloudPwdHint,
                  onChanged: (value) => update(() => passphrase = value),
                ),
                if (enable) ...[
                  AppSpacing.verticalSmall,
                  CupertinoTextField(
                    key: const ValueKey(
                      'web-personal-history-confirm-passphrase',
                    ),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    placeholder: t.common.e2eeBackupConfirmPwdHint,
                    onChanged: (value) => update(() => confirmation = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.buttonCancel),
            ),
            CupertinoDialogAction(
              key: const ValueKey('web-personal-history-confirm-action'),
              onPressed:
                  passphrase.trim().isNotEmpty &&
                      (!enable || passphrase == confirmation)
                  ? () => Navigator.of(dialogContext).pop(passphrase)
                  : null,
              child: Text(
                enable ? enableLabel : t.common.e2eeBackupCloudRestoreBtn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _personalHistoryBanner(ChatState state) {
    final text = switch (state.personalHistoryVisibility) {
      PersonalHistoryVisibility.deletionProgress => '云端历史清理中，暂不可读',
      PersonalHistoryVisibility.waitingKey => '云端历史需要恢复密钥',
      PersonalHistoryVisibility.syncFailed => '云端历史同步失败，展示本地记录',
      PersonalHistoryVisibility.cloudOff => '云端历史未开启（仅本设备）',
      PersonalHistoryVisibility.localEmpty => '云端历史已开启，本设备暂无投影',
      PersonalHistoryVisibility.none => null,
    };
    final status = text == null
        ? null
        : Tooltip(
            message: 'personal-history-status',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                text,
                key: const ValueKey('web-personal-history-banner'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ref
                    .read(themeProvider.notifier)
                    .getTextStyle(
                      FontSizeType.small,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
              ),
            ),
          );
    if (!kIsWeb || !identical(_sessions, authSessionReader) || !_readingOwned) {
      return status;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status != null) Flexible(child: status),
        Tooltip(
          message: Translations.of(context).common.e2eeBackupCloudRestoreBtn,
          excludeFromSemantics: true,
          child: CupertinoButton(
            key: const ValueKey('web-personal-history-restore'),
            minimumSize: const Size.square(AppSizes.touchTarget),
            padding: AppSpacing.allSmall,
            onPressed: _personalHistoryBusy ? null : _restorePersonalHistory,
            child: Icon(
              CupertinoIcons.cloud_download,
              semanticLabel: Translations.of(context)
                  .common
                  .e2eeBackupCloudRestoreBtn,
            ),
          ),
        ),
      ],
    );
  }
}
