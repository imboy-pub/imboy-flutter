import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/native_personal_history_sync.dart';
import 'package:imboy/theme/default/app_spacing.dart';

typedef NativeHistoryRestorer = Future<NativeHistoryRestoreResult> Function(
  String? passphrase,
  NativeHistoryPageCursor? page,
  bool enable,
  bool Function() isCurrent,
);

/// Native settings entry for the personal history recovery key scope.
class NativePersonalHistoryPage extends StatefulWidget {
  const NativePersonalHistoryPage({
    super.key,
    required this.authentication,
    required this.isCurrent,
    required this.restore,
  });

  final Listenable authentication;
  final bool Function() isCurrent;
  final NativeHistoryRestorer restore;

  @override
  State<NativePersonalHistoryPage> createState() =>
      _NativePersonalHistoryPageState();
}

class _NativePersonalHistoryPageState extends State<NativePersonalHistoryPage> {
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  ModalRoute<dynamic>? _route;
  NativeHistoryRestoreResult? _result;
  NativeHistoryPageCursor? _nextPage;
  bool _moreToSync = false;
  bool _rescanRequired = false;
  bool _busy = false;
  bool _enable = false;

  @override
  void initState() {
    super.initState();
    widget.authentication.addListener(_onAuthentication);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    widget.authentication.removeListener(_onAuthentication);
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool _isCurrent() =>
      mounted && (_route?.isCurrent ?? true) && widget.isCurrent();

  void _onAuthentication() {
    if (!mounted || widget.isCurrent()) return;
    _passphrase.clear();
    _confirmation.clear();
    setState(() {
      _enable = false;
      _result = null;
      _nextPage = null;
      _moreToSync = false;
      _rescanRequired = false;
    });
  }

  bool get _canSubmit =>
      !_busy &&
      _passphrase.text.trim().isNotEmpty &&
      (!_enable || _passphrase.text == _confirmation.text);

  void _toggleEnable() {
    _passphrase.clear();
    _confirmation.clear();
    setState(() {
      _enable = !_enable;
      _result = null;
      _nextPage = null;
      _moreToSync = false;
      _rescanRequired = false;
    });
  }

  Future<void> _restore() async {
    if (!_canSubmit || !_isCurrent()) return;
    final passphrase = _passphrase.text;
    final enable = _enable;
    _passphrase.clear();
    _confirmation.clear();
    _nextPage = null;
    _moreToSync = false;
    _rescanRequired = false;
    await _load(passphrase, null, enable: enable);
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextPage;
    if (cursor == null || _busy || !_isCurrent()) return;
    await _load(null, cursor);
  }

  Future<void> _load(
    String? passphrase,
    NativeHistoryPageCursor? cursor, {
    bool enable = false,
  }) async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final outcome = await widget.restore(
        passphrase,
        cursor,
        enable,
        _isCurrent,
      );
      if (!_isCurrent()) return;
      setState(() {
        _result = outcome;
        if (outcome.kind == NativeHistoryRestoreKind.enabled) _enable = false;
        if (outcome.kind == NativeHistoryRestoreKind.restored ||
            outcome.kind == NativeHistoryRestoreKind.rescanRequired) {
          _nextPage = outcome.nextPage;
          if (cursor == null) {
            _moreToSync = outcome.moreToSync;
            _rescanRequired =
                outcome.kind == NativeHistoryRestoreKind.rescanRequired;
          }
        }
      });
    } on Object {
      if (_isCurrent()) {
        setState(() {
          _result = const NativeHistoryRestoreResult(
            NativeHistoryRestoreKind.failed,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _rescanMessage(bool zh) => zh
      ? '服务端要求重新扫描。仍可查看已验证的历史副本。'
      : 'The server requires a history rescan. Previously verified copies are still available.';

  String _status(bool zh) => switch (_result?.kind) {
    NativeHistoryRestoreKind.enabled =>
      zh ? '个人云端历史已开启。' : 'Personal cloud history is enabled.',
    NativeHistoryRestoreKind.rescanRequired => _rescanMessage(zh),
    NativeHistoryRestoreKind.restored when _rescanRequired => _rescanMessage(
      zh,
    ),
    NativeHistoryRestoreKind.restored when _moreToSync =>
      zh
          ? '还有云端记录待同步。输入恢复口令继续。'
          : 'More cloud history remains. Enter your passphrase to continue.',
    NativeHistoryRestoreKind.restored when _result!.texts.isEmpty =>
      zh ? '这一页没有可显示的已验证历史。' : 'No verified history is available on this page.',
    NativeHistoryRestoreKind.restored =>
      zh ? '已显示本页的个人云端历史。' : 'Showing personal cloud history for this page.',
    NativeHistoryRestoreKind.wrongPassphrase =>
      zh ? '恢复口令错误，请重试。' : 'The recovery passphrase is incorrect.',
    NativeHistoryRestoreKind.cloudOff =>
      zh ? '此账号未开启个人云端历史。' : 'Personal cloud history is off for this account.',
    NativeHistoryRestoreKind.purgePending =>
      zh ? '个人云端历史正在清理。' : 'Personal cloud history is being deleted.',
    NativeHistoryRestoreKind.missingPackage =>
      zh ? '未找到此账号的恢复密钥包。' : 'This account has no recovery key package.',
    NativeHistoryRestoreKind.cancelled =>
      zh
          ? '会话或云端授权已变化，请重试。'
          : 'Session or cloud authorization changed. Try again.',
    NativeHistoryRestoreKind.failed =>
      zh ? '暂时无法恢复个人云端历史。' : 'Could not restore personal cloud history.',
    null => '',
  };

  @override
  Widget build(BuildContext context) {
    final labels = Translations.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final active = widget.isCurrent();
    final message = active
        ? _status(zh)
        : (zh ? '账号已切换，请重新打开本页。' : 'Account changed. Reopen this page.');
    return IosPageTemplate(
      title: zh ? '个人云端历史' : 'Personal cloud history',
      contentMaxWidth: ResourcePageLayout.maxWidth,
      body: ListView(
        padding: AppSpacing.allRegular,
        children: [
          if (active) ...[
            Text(
              zh ? '输入开启个人云端历史时设置的口令，恢复此账号的消息副本。' : 'Enter the passphrase you set for personal cloud history to restore a copy of this account’s messages.',
            ),
            AppSpacing.verticalRegular,
            if (_enable)
              Padding(
                padding: AppSpacing.allSmall,
                child: Text(
                  zh ? '开启后，此账号的新消息可加密同步。请保存恢复口令。' : 'New messages on this account can sync encrypted. Keep your recovery passphrase.',
                ),
              ),
            CupertinoTextField(
              key: const ValueKey('native-personal-history-passphrase'),
              controller: _passphrase,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              placeholder: labels.common.e2eeBackupCloudPwdHint,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _restore(),
            ),
            AppSpacing.verticalRegular,
            if (_enable) ...[
              CupertinoTextField(
                key: const ValueKey(
                  'native-personal-history-confirm-passphrase',
                ),
                controller: _confirmation,
                enabled: !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                placeholder: labels.common.e2eeBackupConfirmPwdHint,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _restore(),
              ),
              AppSpacing.verticalRegular,
            ],
            CupertinoButton.filled(
              key: const ValueKey('native-personal-history-restore'),
              onPressed: _canSubmit ? _restore : null,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : Text(
                      _enable
                          ? (zh ? '开启个人云端历史' : 'Enable personal cloud history')
                          : labels.common.e2eeBackupCloudRestoreBtn,
                    ),
            ),
            CupertinoButton(
              key: const ValueKey('native-personal-history-enable-mode'),
              onPressed: _busy ? null : _toggleEnable,
              child: Text(
                _enable
                    ? labels.common.buttonCancel
                    : (zh ? '开启个人云端历史' : 'Enable personal cloud history'),
              ),
            ),
          ],
          if (message.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                key: const ValueKey('native-personal-history-status'),
              ),
            ),
          if (active &&
              (_result?.kind == NativeHistoryRestoreKind.restored ||
                  _result?.kind == NativeHistoryRestoreKind.rescanRequired))
            Column(
              key: const ValueKey('native-personal-history-restored-text'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final text in _result!.texts)
                  Padding(padding: AppSpacing.allSmall, child: Text(text)),
              ],
            ),
          if (active && _nextPage != null)
            CupertinoButton(
              key: const ValueKey('native-personal-history-next-page'),
              onPressed: _busy ? null : _loadNextPage,
              child: Text(zh ? '查看下一页' : 'View next page'),
            ),
        ],
      ),
    );
  }
}
