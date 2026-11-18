import 'dart:async';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/service/plaintext_text_limit.dart';
import 'package:imboy/service/pending_text_send.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:xid/xid.dart';

import 'web_shell_state.dart';
import 'web_chat_selection_guard.dart';
import 'web_attachment_input.dart';
import 'web_group_composer_gate.dart';
import 'web_ime_composition_guard.dart';

/// Web text composer using the native account drafts and message send/retry path.
class WebChatInput extends ConsumerStatefulWidget {
  const WebChatInput({
    super.key,
    required this.selection,
    required this.currentUserId,
    this.messageRepository,
  });

  final ChatSelection selection;
  final String currentUserId;
  final MessageRepository? messageRepository;

  @override
  ConsumerState<WebChatInput> createState() => _WebChatInputState();
}

class _WebChatInputState extends ConsumerState<WebChatInput> {
  final _controller = TextEditingController();
  final _composerRegion = GlobalKey();
  final _inputFocus = FocusNode();
  final _imeGuard = WebImeCompositionGuard();
  AccountDraftStore? _drafts;
  Timer? _draftTimer;
  bool _sending = false;
  bool _sendError = false;
  bool _textLimitError = false;
  bool _draftError = false;
  String _peerAvatar = '';
  String _lastText = '';
  int _textRevision = 0;
  TextMessage? _pendingMessage;
  bool _pendingError = false;

  bool get _active =>
      isValidWebChatSelection(widget.selection) &&
      _drafts?.isCurrent == true &&
      authSessionReader.current.uid == widget.currentUserId;

  /// MSG-01：组合态统一判定。引擎 `TextEditingValue.composing` 在真实
  /// 浏览器 IME 下恒空（runs/msg01-live-20261116 F1/F2），补 DOM 组合
  /// 事件流守卫；合成控制器路径（测试/原生）仍由引擎 composing 兜住。
  bool get _imeComposing {
    if (_imeGuard.composing) return true;
    final composing = _controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  @override
  void initState() {
    super.initState();
    _bindDraft();
    _controller.addListener(_onInputChanged);
    authSessionReader.addListener(_onAuthChanged);
  }

  @override
  void didUpdateWidget(covariant WebChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.currentUserId != widget.currentUserId) {
      unawaited(_flushDraft());
      _controller.removeListener(_onInputChanged);
      _bindDraft();
      _controller.addListener(_onInputChanged);
    }
  }

  void _bindDraft() {
    _draftTimer?.cancel();
    _drafts = isValidWebChatSelection(widget.selection)
        ? AccountDraftStore.capture(
            widget.selection.chatType,
            widget.selection.peerId,
          )
        : null;
    final draft = _active ? _drafts!.read() : (text: '', cursor: null);
    _controller.value = TextEditingValue(
      text: draft.text,
      selection: TextSelection.collapsed(
        offset: (draft.cursor ?? draft.text.length).clamp(0, draft.text.length),
      ),
    );
    _lastText = _controller.text;
    _textRevision = 0;
    _sending = _sendError = _draftError = _textLimitError = false;
    _pendingMessage = null;
    _pendingError = false;
    _restorePending();
    _peerAvatar = '';
    unawaited(_loadPeerAvatar());
  }

  void _restorePending() {
    final value = _drafts?.readPendingSend() ?? '';
    if (value.isEmpty) return;
    try {
      final message = readPendingTextSend(
        value,
        uid: widget.currentUserId,
        peerId: widget.selection.peerId,
      );
      _pendingMessage = message;
    } on Object {
      _pendingError = true;
    }
  }

  Future<void> _loadPeerAvatar() async {
    if (!_active || widget.selection.chatType != 'C2C') return;
    final drafts = _drafts;
    try {
      final contact = await ContactRepo().findByUid(widget.selection.peerId);
      if (!mounted || !identical(drafts, _drafts) || !_active) return;
      setState(() => _peerAvatar = contact?.avatar ?? '');
    } catch (error) {
      // Avatar metadata is optional; retain the normal fallback on lookup failure.
      debugPrint('[web-chat-input] avatar lookup: ${error.runtimeType}');
    }
  }

  void _onAuthChanged() {
    if (!mounted || _active) return;
    _draftTimer?.cancel();
    _controller.clear();
    setState(() {});
  }

  void _onInputChanged() {
    if (_lastText != _controller.text) {
      _lastText = _controller.text;
      _textRevision++;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_flushDraft());
    });
    setState(() {});
  }

  Future<bool> _flushDraft() async {
    _draftTimer?.cancel();
    final drafts = _drafts;
    if (drafts == null) return true;
    try {
      await drafts.save(
        _controller.text,
        cursor: _controller.selection.baseOffset,
      );
      if (mounted && identical(drafts, _drafts) && _draftError) {
        setState(() => _draftError = false);
      }
      return true;
    } catch (error) {
      debugPrint('[web-chat-input] draft save: ${error.runtimeType}');
      if (mounted && identical(drafts, _drafts) && drafts.isCurrent) {
        setState(() => _draftError = true);
      }
      return false;
    }
  }

  @override
  void dispose() {
    authSessionReader.removeListener(_onAuthChanged);
    _controller.removeListener(_onInputChanged);
    unawaited(_flushDraft());
    _controller.dispose();
    _inputFocus.dispose();
    _imeGuard.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final permission = WebGroupSendScope.leaseOf(context);
    final revision = _textRevision;
    final text = _controller.text.trim();
    // DEF-A11YNEW-05：prefers-reduced-motion 下消息插入动画取消（引擎把
    // Web 的 prefers-reduced-motion 映射进 MediaQuery.disableAnimations，
    // media_query_manager.dart REDUCED_MOTION；此前本插入点恒为 animated:true）。
    final animateInsert = !MediaQuery.disableAnimationsOf(context);
    if (text.isEmpty ||
        _sending ||
        !_active ||
        !permission() ||
        _pendingError ||
        _imeComposing) {
      return;
    }
    if (PlaintextTextLimit.exceeded(text)) {
      setState(() => _textLimitError = true);
      await _flushDraft();
      return;
    }
    _textLimitError = false;
    final drafts = _drafts;
    if (drafts == null) return;
    bool currentComposer() => mounted && identical(drafts, _drafts) && _active;
    bool current() => currentComposer() && permission();
    setState(() {
      _sending = true;
      _sendError = false;
    });
    final message = _messageFor(text);
    final pending = jsonEncode(message.toJson());
    try {
      if (!await _flushDraft() || !current()) return;
      await drafts.savePendingSend(pending);
      if (!current()) return;
      if (!await _dispatch(message, current, animateInsert)) {
        if (current()) setState(() => _sendError = true);
        return;
      }
      if (!current()) return;
      // Commit draft removal before its identity, so interrupted cleanup can retry safely.
      if (_textRevision == revision) _controller.clear();
      if (await _flushDraft() && current()) {
        await drafts.clearPendingSend(pending);
        if (current()) _pendingMessage = null;
      }
    } catch (error) {
      debugPrint('[web-chat-input] send: ${error.runtimeType}');
      if (current()) setState(() => _sendError = true);
    } finally {
      if (currentComposer()) setState(() => _sending = false);
    }
  }

  TextMessage _messageFor(String text) {
    _pendingMessage = _pendingMessage?.text == text
        ? _pendingMessage
        : TextMessage(
            authorId: widget.currentUserId,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              DateTimeHelper.millisecond(),
              isUtc: true,
            ),
            id: Xid().toString(),
            text: text,
            metadata: {'peer_id': widget.selection.peerId},
          );
    return _pendingMessage!;
  }

  Future<bool> _dispatch(
    TextMessage message,
    bool Function() current,
    bool animateInsert,
  ) async {
    final notifier = ref.read(chatProvider.notifier);
    final service = notifier.chatService;
    final type = widget.selection.chatType;
    final peer = widget.selection.peerId;
    return dispatchPendingTextSend(
      message: message,
      type: type,
      peerId: peer,
      repository:
          widget.messageRepository ??
          MessageRepo(tableName: MessageRepo.getTableName(type)),
      isCurrent: current,
      retry: notifier.retryMessage,
      sendNew: (message) async {
        final sent = await notifier.addMessage(
          message.authorId,
          peer,
          _peerAvatar,
          peer,
          type,
          message,
        );
        if (!current()) return false;
        if (identical(service, notifier.chatService)) {
          await service?.insertMessage(
            message,
            index: 0,
            animated: animateInsert,
          );
        }
        return current() && sent;
      },
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        HardwareKeyboard.instance.isShiftPressed ||
        _imeComposing) {
      return KeyEventResult.ignored;
    }
    unawaited(_send());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!isValidWebChatSelection(widget.selection)) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final t = Translations.of(context);
    final canSend =
        !_sending &&
        _active &&
        WebGroupSendScope.allowedOf(context) &&
        !_pendingError &&
        !_imeComposing &&
        _controller.text.trim().isNotEmpty;
    // DEF-A11YNEW-05：forced-colors=active 时引擎把 highContrast 置位
    // （media_query_manager.dart FORCED_COLORS → AccessibilityFeatures），
    // 加粗 composer 顶边保住结构边界可见性；canvas 绘制不受浏览器
    // forced-colors 重绘，主题文字对比度维持既有 token 不塌。
    final highContrast = MediaQuery.highContrastOf(context);
    return Container(
      key: _composerRegion,
      padding: AppSpacing.allMedium,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: highContrast ? colors.outline : colors.outlineVariant,
            width: highContrast ? 1.0 : 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebAttachmentInput(
            selection: widget.selection,
            currentUserId: widget.currentUserId,
            isCurrent: () => _active,
            inputFocus: _inputFocus,
            regionKey: _composerRegion,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: ComposerField(
                    key: const ValueKey('web-chat-input-field'),
                    controller: _controller,
                    focusNode: _inputFocus,
                    enabled: _active && WebGroupSendScope.allowedOf(context),
                    minLines: 1,
                    maxLines: 5,
                    maxLength: null,
                    showCounter: false,
                    showEmojiButton: false,
                    hintText: t.chat.sendMessage,
                    onSubmitted: _send,
                  ),
                ),
              ),
              AppSpacing.horizontalSmall,
              IconButton(
                key: const ValueKey('web-chat-input-send-btn'),
                constraints: const BoxConstraints(
                  minWidth: AppSizes.touchTarget,
                  minHeight: AppSizes.touchTarget,
                ),
                icon: Semantics(
                  value: _sending ? t.chat.sending : null,
                  liveRegion: _sending,
                  child: _sending
                      ? const CupertinoActivityIndicator()
                      : const Icon(CupertinoIcons.arrow_up_circle),
                ),
                tooltip: t.chat.sendMessage,
                onPressed: canSend
                    ? () {
                        _inputFocus.requestFocus();
                        unawaited(_send());
                      }
                    : null,
              ),
            ],
          ),
          if (_textLimitError || _sendError || _draftError || _pendingError)
            Semantics(
              liveRegion: true,
              child: Text(
                _textLimitError
                    ? t.common.textTooLarge
                    : (_sendError || _pendingError)
                    ? t.common.sendFailed
                    : t.common.saveFailed,
                style: TextStyle(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}
