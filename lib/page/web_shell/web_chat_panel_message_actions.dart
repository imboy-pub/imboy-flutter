part of 'web_shell_bootstrap.dart';

extension _WebChatPanelMessageActions on WebChatPanelState {
  void _previewImage(ImageMessage message) {
    if (!mounted ||
        !_active ||
        message.metadata?['_e2ee_failed'] == true ||
        message.source.trim().isEmpty) {
      return;
    }
    final owner = _owner;
    final resourceOwner = _resourceOwner;
    final selection = widget.selection;
    bool current() =>
        mounted &&
        _active &&
        owner == _owner &&
        selection == widget.selection &&
        resourceOwner != null &&
        AccountLocalTaskOwner.capture(uid: widget.currentUserId) ==
            resourceOwner;
    if (!current()) return;
    final preview = widget.imagePreview;
    if (preview != null) {
      unawaited(preview(context, message.source));
    } else {
      unawaited(zoomInPhotoView(context, message.source, isCurrent: current));
    }
  }

  /// Phase 2.1.b-5a/c + FL-06 — 长按消息：弹底部菜单
  ///
  /// 菜单项可见性统一由 [resolveWebLongPressMenuPlan] 决策（最低 UX 合同
  /// 决策点，chrome 测试钉矩阵）：复制 / 引用 / 编辑 / 撤回 / 删除 / 多选。
  /// 动作全部接既有模型：
  /// - 引用 → WebComposerIntentController.beginQuote（发送走 mobile
  ///   `_sendQuoteMessage` 同 metadata 合同，快照/撤回隐藏由共享模型管）；
  /// - 编辑 → beginEdit（ChatPageUtils.canEditMessage 过滤，发送走
  ///   MessagingFacade.sendEditMessage 权威模型）；
  /// - 撤回 → _revokeMessage（既有）；
  /// - 删除 → _deleteMessageForMe（mobile deleteMessageForMe 同合同）；
  /// - 多选 → _enterMultiSelect（messageSelectionProvider 既有模型）。
  void _handleLongPress(Message message) {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final copyable = resolveCopyableText(message);
    final plan = resolveWebLongPressMenuPlan(
      message: message,
      currentUserId: widget.currentUserId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      multiSelectFlagEnabled: webMultiSelectEnabled(),
      conversationAvailable: _conversationKey.isNotEmpty,
    );

    // 没有任何可操作项时不弹菜单（避免空白菜单困惑用户）
    if (plan.isEmpty) return;

    final ctx = context;
    final t = Translations.of(ctx);
    showCupertinoModalPopup<void>(
      context: ctx,
      builder: (sheetCtx) {
        return CupertinoModalSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (plan.canCopy && copyable != null)
                ListTile(
                  key: const ValueKey('web-msg-action-copy'),
                  leading: const Icon(CupertinoIcons.doc_on_doc),
                  title: Text(t.common.buttonCopy),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    await Clipboard.setData(ClipboardData(text: copyable));
                    if (!_current(request, selection, owner)) return;
                    AppLoading.showToast(
                      t.main.copied,
                      duration: const Duration(seconds: 1),
                    );
                  },
                ),
              if (plan.canQuote)
                ListTile(
                  key: const ValueKey('web-msg-action-quote'),
                  leading: const Icon(CupertinoIcons.reply),
                  title: Text(t.chat.reply),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    _composerIntents?.beginQuote(message);
                  },
                ),
              if (plan.canEdit)
                ListTile(
                  key: const ValueKey('web-msg-action-edit'),
                  leading: const Icon(CupertinoIcons.pencil),
                  title: Text(t.common.edit),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    _composerIntents?.beginEdit(message, widget.currentUserId);
                  },
                ),
              if (plan.canRecall)
                ListTile(
                  key: const ValueKey('web-msg-action-recall'),
                  leading: const Icon(CupertinoIcons.arrow_counterclockwise),
                  title: Text(t.chat.revoke),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    unawaited(_revokeMessage(message));
                  },
                ),
              if (plan.canDelete)
                ListTile(
                  key: const ValueKey('web-msg-action-delete'),
                  leading: const Icon(CupertinoIcons.delete),
                  title: Text(t.common.buttonDelete),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    unawaited(_deleteMessageForMe(message));
                  },
                ),
              if (plan.canMultiSelect)
                ListTile(
                  key: const ValueKey('web-msg-action-multiselect'),
                  leading: const Icon(CupertinoIcons.checkmark_circle),
                  title: Text(t.chat.multiSelect),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    unawaited(_enterMultiSelect(message));
                  },
                ),
              ListTile(
                key: const ValueKey('web-msg-action-cancel'),
                leading: const Icon(CupertinoIcons.xmark),
                title: Text(t.common.cancel),
                onTap: () => Navigator.of(sheetCtx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// FL-06：多选进入 —— 先 await 草稿落盘（mobile flushDraft 契约；落盘
  /// 失败不卸载输入框避免丢草稿），再走既有 messageSelectionProvider.enter。
  Future<void> _enterMultiSelect(Message message) async {
    final controller = _composerIntents;
    if (controller == null || !mounted) return;
    final flusher = controller.draftFlusher;
    if (flusher != null) {
      final flushed = await flusher();
      if (!flushed || !mounted) return;
    }
    webEnterMultiSelect(ref, _conversationKey, message);
  }

  /// FL-06：删除（仅自己）—— 接 mobile MessageActionHandler.deleteMessageForMe
  /// 同合同：C2G 先发 S2C DEL_FOR_ME，随后 removeMessage（DB/会话联动）+
  /// chatService.removeMessageById（UI 移除）。会话行缺失时失败提示，
  /// 不做静默成功（刷新后结果一致）。
  Future<void> _deleteMessageForMe(Message message) async {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final notifier = ref.read(chatProvider.notifier);
    if (widget.selection.chatType == 'C2G') {
      await notifier.sendMessage(
        webDeleteForMePayload(
          message: message,
          chatType: widget.selection.chatType,
          currentUserId: widget.currentUserId,
        ),
      );
    }
    final conversation = _conversation;
    if (conversation == null) {
      AppLoading.showToast(t.common.operationFailedAgainLater);
      return;
    }
    final removed = await notifier.removeMessage(conversation, message);
    if (!_current(request, selection, owner)) return;
    if (!removed) {
      AppLoading.showToast(t.common.operationFailedAgainLater);
      return;
    }
    await notifier.chatService?.removeMessageById(message.id);
  }

  /// FL-06：编辑意图失权守卫（撤回先到/消息离列表 → 隐藏摘要，无权限旁路）。
  /// 无法判定（服务消息列表为空）时不猜，避免瞬态镜像误伤编辑态。
  void _guardEditingIntent() {
    final controller = _composerIntents;
    if (controller == null || !controller.intent.isEditing) return;
    final live = ref.read(chatProvider.notifier).chatService?.messages;
    if (live == null || live.isEmpty) return;
    if (webEditIntentInvalidated(controller.intent, live)) {
      controller.invalidateEditing();
    }
  }

  /// Phase 2.1.b-5d — 撤回消息（接 MessagingFacade.sendRevokeMessage）
  ///
  /// 决策已由 [canShowRecallAction] 在菜单显示前过滤；本方法假设入参可撤回。
  /// 失败时仅 SnackBar 提示，不抛异常给上层（避免 widget tree unhandled future）。
  Future<void> _revokeMessage(Message message) async {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final ctx = context;
    final t = Translations.of(ctx);
    try {
      final ok = await MessagingFacade.instance.sendRevokeMessage(
        message.id,
        selection.chatType,
      );
      if (!_current(request, selection, owner)) return;
      AppLoading.showToast(
        ok ? t.common.revokeSuccess : t.common.revokeFailed,
        duration: const Duration(seconds: 2),
      );
    } on Object {
      if (!_current(request, selection, owner)) return;
      AppLoading.showToast(
        t.common.revokeFailed,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
