import 'dart:async';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, Message, TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/policy/quote_author_rules.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart'
    show
        MessageSelectionTraits,
        evaluateMessageSelectability,
        MessageSelectionReason;
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:imboy/modules/messaging/public.dart' show MessagingFacade;
import 'package:imboy/store/model/message_model.dart' show IMBoyMessageStatus;
import 'package:imboy/store/model/model_parse_utils.dart' show parseModelInt;
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/page/chat/chat/bundle_forward_dispatcher.dart'
    show
        BundleForwardDispatcher,
        bundleActionAllowedFor,
        exportActionAllowedFor;
import 'package:imboy/page/chat/chat/chat_multi_select_wiring.dart'
    show
        canDispatchSelectedMessages,
        forwardEachActionAllowedFor,
        sortMultiSelectMessages;
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/services/message_selection_traits.dart'
    show messageSelectionTraitsOf;
import 'package:imboy/page/chat/chat/utils/chat_page_utils.dart'
    show ChatPageUtils;
import 'package:imboy/page/chat/send_to/send_to_page.dart' show SendToPage;
import 'package:imboy/modules/messaging/presentation/export/chat_export_flow.dart'
    show runChatExportFlow;
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/common_events.dart'
    show ReEditMessageEvent;
import 'package:imboy/service/plaintext_text_limit.dart';
import 'package:imboy/service/pending_text_send.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart' show UserRepoLocal;
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:xid/xid.dart';

import 'web_shell_state.dart';
import 'web_chat_selection_guard.dart';
import 'web_attachment_input.dart';
import 'web_group_composer_gate.dart';
import 'web_ime_composition_guard.dart';
import 'web_message_actions.dart';

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
  // FL-06：编辑/引用意图（WebComposerIntentScope 由 WebChatPanel 提供）。
  WebComposerIntentController? _intentController;
  WebComposerIntent _seenIntent = const WebComposerIntent();
  int _seenGeneration = -1;
  (String, int)? _intentDraftStash;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = WebComposerIntentScope.maybeOf(context);
    if (!identical(controller, _intentController)) {
      _intentController?.removeListener(_onIntentChanged);
      _intentController = controller;
      _seenGeneration = -1;
      _seenIntent = const WebComposerIntent();
      _intentDraftStash = null;
      controller?.addListener(_onIntentChanged);
      _applyIntentDelta();
    }
    // FL-06：多选进入前由 panel 经此钩子 await 草稿落盘（镜像 mobile
    // ChatInputState.flushDraft 契约；输入框卸载前草稿必须已持久化）。
    controller?.draftFlusher = () => _flushDraft();
  }

  /// FL-06：意图控制器代次变化（编辑/引用/取消/失权）→ 推进 composer。
  void _onIntentChanged() {
    if (!mounted) return;
    setState(_applyIntentDelta);
  }

  /// FL-06：编辑/引用意图按代次（generation）推进。任何代次变化只应用一次：
  /// - 新编辑意图 → 暂存当前草稿并把快照文本填入 composer（快照语境）；
  /// - 意图清空且带恢复标记 → 还原编辑前草稿；
  /// - 其余（发送成功收敛/失权失效）→ 只清理本地暂存。
  void _applyIntentDelta() {
    final controller = _intentController;
    if (controller == null || controller.generation == _seenGeneration) {
      return;
    }
    final intent = controller.intent;
    final previous = _seenIntent;
    _seenGeneration = controller.generation;
    _seenIntent = intent;
    if (intent.isEditing &&
        (intent.editingMessageId != previous.editingMessageId ||
            intent.editSnapshotText != previous.editSnapshotText)) {
      _intentDraftStash = (_controller.text, _controller.selection.baseOffset);
      final snapshot = intent.editSnapshotText ?? '';
      _controller.value = TextEditingValue(
        text: snapshot,
        selection: TextSelection.collapsed(offset: snapshot.length),
      );
      _inputFocus.requestFocus();
      return;
    }
    if (!intent.isEditing && !intent.isQuote) {
      if (controller.consumePendingRestore()) {
        final stash = _intentDraftStash;
        _intentDraftStash = null;
        if (stash != null) {
          _controller.value = TextEditingValue(
            text: stash.$1,
            selection: TextSelection.collapsed(
              offset: stash.$2.clamp(0, stash.$1.length),
            ),
          );
        }
      } else {
        _intentDraftStash = null;
      }
    }
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
    _intentController?.removeListener(_onIntentChanged);
    if (_intentController?.draftFlusher != null) {
      _intentController?.draftFlusher = null;
    }
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
    // FL-06：发送模式决策接既有 send_mode_rules 优先级（edit > quote > new）。
    // 编辑/引用不走 pending-send 重试队列（无新消息身份），失败反馈与
    // 普通发送一致（sendError + 保留 composer 文本）。
    final intents = _intentController;
    final intent = intents?.intent ?? const WebComposerIntent();
    if (intents != null && intent.isEditing) {
      await _sendEdit(intents, intent, text, currentComposer, current);
      return;
    }
    if (intents != null && intent.isQuote) {
      await _sendQuote(
        intents,
        intent,
        text,
        currentComposer,
        current,
        revision,
        animateInsert,
      );
      return;
    }
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

  /// FL-06：编辑提交 —— 接既有权威模型 `MessagingFacade.sendEditMessage`
  /// （模型层 canEdit/status==sent/15min 重检 + FL-03 edited_at 权威合并）。
  ///
  /// UI 层无静默覆盖合同：
  /// - 提交时捕获意图代次；仅当代次未变且 composer 文本仍等于提交文本时
  ///   才收敛编辑态并清空 composer；
  /// - 期间再次 beginEdit（反序/并发）→ 代次变化，旧 ACK 不触碰新编辑态；
  /// - 用户已继续输入 → 同样不清空（mobile late-success 同语义）；
  /// - 失败 → sendError + 文本保留可重试。
  Future<void> _sendEdit(
    WebComposerIntentController intents,
    WebComposerIntent intent,
    String text,
    bool Function() currentComposer,
    bool Function() current,
  ) async {
    final messageId = intent.editingMessageId!;
    final generation = intents.generation;
    setState(() {
      _sending = true;
      _sendError = false;
    });
    try {
      final ok =
          await intents.editDispatcher?.call(
            messageId,
            widget.selection.chatType,
            text,
          ) ??
          await MessagingFacade.instance.sendEditMessage(
            messageId,
            widget.selection.chatType,
            text,
          );
      if (!currentComposer()) return;
      if (!ok) {
        setState(() => _sendError = true);
        return;
      }
      if (intents.generation != generation || _controller.text.trim() != text) {
        return;
      }
      _intentDraftStash = null;
      if (_controller.text.isNotEmpty) _controller.clear();
      intents.completeIntent();
      await _flushDraft();
    } catch (error) {
      debugPrint('[web-chat-input] edit send: ${error.runtimeType}');
      if (currentComposer()) setState(() => _sendError = true);
    } finally {
      if (currentComposer()) setState(() => _sending = false);
    }
  }

  /// FL-06：引用发送 —— 复用 mobile `_sendQuoteMessage` 的 metadata 合同
  ///（msg_type=quote + quote_msg 快照 + quote_msg_author_name + quote_text），
  /// 快照语境由共享模型负责（SqliteChatService.hideQuoteSnapshot 撤回隐藏）。
  Future<void> _sendQuote(
    WebComposerIntentController intents,
    WebComposerIntent intent,
    String text,
    bool Function() currentComposer,
    bool Function() current,
    int revision,
    bool animateInsert,
  ) async {
    final generation = intents.generation;
    final message = _quoteMessageFor(intent, text);
    setState(() {
      _sending = true;
      _sendError = false;
    });
    try {
      if (!await _flushDraft() || !current()) return;
      final notifier = ref.read(chatProvider.notifier);
      final sent = await notifier.addMessage(
        widget.currentUserId,
        widget.selection.peerId,
        _peerAvatar,
        widget.selection.peerId,
        widget.selection.chatType,
        message,
      );
      if (!current()) return;
      if (!sent) {
        setState(() => _sendError = true);
        return;
      }
      final service = notifier.chatService;
      if (identical(service, notifier.chatService)) {
        await service?.insertMessage(
          message,
          index: 0,
          animated: animateInsert,
        );
      }
      if (!current()) return;
      if (intents.generation != generation || _controller.text.trim() != text) {
        return;
      }
      if (_textRevision == revision) _controller.clear();
      intents.completeIntent();
      await _flushDraft();
    } catch (error) {
      debugPrint('[web-chat-input] quote send: ${error.runtimeType}');
      if (currentComposer()) setState(() => _sendError = true);
    } finally {
      if (currentComposer()) setState(() => _sending = false);
    }
  }

  /// FL-06：引用消息构建（与 mobile chat_page._sendQuoteMessage 同合同）。
  CustomMessage _quoteMessageFor(WebComposerIntent intent, String text) {
    final quoted = intent.quoteMessage!;
    return CustomMessage(
      authorId: widget.currentUserId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: {
        'msg_type': 'quote',
        'peer_id': widget.selection.peerId,
        'quote_msg': quoted.toJson(),
        'quote_msg_author_name': resolveQuoteAuthorName(
          quoteAuthorId: quoted.authorId,
          currentUid: widget.currentUserId,
          myNickname: UserRepoLocal.to.current.nickname,
          peerTitle: widget.selection.peerId,
        ),
        'quote_text': text,
      },
    );
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

  /// FL-06：编辑/引用意图条（composer 上方；撤回失权后由控制器失效隐藏）。
  List<Widget> _intentBars(ColorScheme colors) {
    final intent = _intentController?.intent ?? const WebComposerIntent();
    final bars = <Widget>[];
    if (intent.isEditing) {
      bars.add(
        Container(
          key: const ValueKey('web-composer-edit-bar'),
          margin: const EdgeInsets.only(bottom: AppSpacing.small),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: AppSpacing.tiny,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.pencil, size: AppSizes.iconSizeSmall),
              AppSpacing.horizontalSmall,
              Expanded(
                child: Text(
                  t.common.editing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: const ValueKey('web-composer-edit-cancel'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(CupertinoIcons.xmark),
                tooltip: t.common.cancel,
                onPressed: () =>
                    _intentController?.cancelIntent(restoreDraft: true),
              ),
            ],
          ),
        ),
      );
    } else if (intent.isQuote) {
      final quoted = intent.quoteMessage;
      final preview = quoted is TextMessage
          ? quoted.text
          : (quoted?.metadata?['quote_text']?.toString() ?? '');
      bars.add(
        Container(
          key: const ValueKey('web-composer-quote-bar'),
          margin: const EdgeInsets.only(bottom: AppSpacing.small),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: AppSpacing.tiny,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.reply, size: AppSizes.iconSizeSmall),
              AppSpacing.horizontalSmall,
              Expanded(
                child: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: const ValueKey('web-composer-quote-cancel'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(CupertinoIcons.xmark),
                tooltip: t.common.cancel,
                onPressed: () => _intentController?.cancelIntent(),
              ),
            ],
          ),
        ),
      );
    }
    return bars;
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
          ..._intentBars(colors),
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

// ===== FL-06：Web 编辑/引用/删除/多选接既有模型 =====
//
// 设计边界（imboy/.plans/…/tasks/FL-06.md + uiux-matrix「消息操作」行）：
// - Web 与 Mobile 共用权威模型，不复制业务逻辑：
//   编辑 → MessagingFacade.sendEditMessage（canEdit/status/15min + FL-03
//   edited_at 权威合并，UI 只做代次围栏防静默覆盖）；
//   引用 → mobile `_sendQuoteMessage` 同 metadata 合同（quote_msg 快照、
//   撤回隐藏摘要走 SqliteChatService.hideQuoteSnapshot 共享路径）；
//   删除 → mobile deleteMessageForMe 同合同（C2G S2C DEL_FOR_ME + 本地移除）；
//   多选 → messageSelectionProvider + 既有策略函数 + BundleForwardDispatcher/
//   SendToPage.batch/runChatExportFlow 共享编排。
// - 本文件是 web_chat_panel.dart（part of web_shell_bootstrap）可用的唯一
//   独立注入面：bootstrap 对本文件 import 无 show 限制，panel 直接调用这里
//   的公开 API，不新增 bootstrap import。

/// 编辑/引用意图快照（不可变）。
///
/// 优先级接 send_mode_rules：`isEditing`（有目标 id）压过 `isQuote`。
class WebComposerIntent {
  const WebComposerIntent({
    this.editingMessageId,
    this.editSnapshotText,
    this.quoteMessage,
  });

  /// 正在编辑的消息 id（空/非空判断见 [isEditing]）。
  final String? editingMessageId;

  /// 编辑快照语境（beginEdit 时刻的权威正文，:02 断言）。
  final String? editSnapshotText;

  /// 引用目标消息（原消息快照，发送时序列化进 quote_msg）。
  final Message? quoteMessage;

  bool get isEditing =>
      editingMessageId != null && editingMessageId!.isNotEmpty;
  bool get isQuote => !isEditing && quoteMessage != null;
}

/// 编辑/引用意图控制器（WebChatPanel 持有，经 [WebComposerIntentScope] 注入）。
///
/// 代次（generation）围栏：任何意图跃迁（begin*/cancel/complete/invalidate）
/// 都自增；composer 只在「代次未变且文本未变」时收敛编辑态 —— 两次编辑反序、
/// 并发编辑、迟到的旧 ACK 都不会静默覆盖（:01 断言）。
class WebComposerIntentController extends ChangeNotifier {
  WebComposerIntentController({this.editDispatcher, this.canEditNow});

  /// 测试/平台注入的编辑派发面；null → 真实 MessagingFacade.sendEditMessage。
  final Future<bool> Function(
    String messageId,
    String chatType,
    String content,
  )?
  editDispatcher;

  /// 编辑入口的附加权限闸（如禁言）；null → 仅 ChatPageUtils.canEditMessage。
  final bool Function()? canEditNow;

  /// 多选进入前的草稿落盘钩子（WebChatInput 注册；panel await）。
  Future<bool> Function()? draftFlusher;

  WebComposerIntent _intent = const WebComposerIntent();
  int _generation = 0;
  bool _pendingRestore = false;

  WebComposerIntent get intent => _intent;
  int get generation => _generation;

  void _bump() {
    _generation++;
    notifyListeners();
  }

  /// 长按菜单「编辑」：接既有 ChatPageUtils.canEditMessage（本人+文本+15min）。
  /// 失败返回 false 且不进入编辑态（无权限旁路）。
  bool beginEdit(Message message, String currentUserId) {
    if (!ChatPageUtils.canEditMessage(message, currentUserId)) return false;
    if (canEditNow != null && !canEditNow!()) return false;
    _pendingRestore = false;
    _intent = WebComposerIntent(
      editingMessageId: message.id,
      editSnapshotText: message is TextMessage ? message.text : '',
      quoteMessage: null,
    );
    _bump();
    return true;
  }

  /// 共享事件路径（ReEditMessageEvent / editingMessageIdSetter）设置编辑目标；
  /// [snapshotText] 由事件文本填充（幂等：同 id 只更新快照）。
  void beginReEdit(String messageId, {String? snapshotText}) {
    if (messageId.isEmpty) return;
    if (_intent.isEditing && _intent.editingMessageId == messageId) {
      if (snapshotText != null && snapshotText != _intent.editSnapshotText) {
        _intent = WebComposerIntent(
          editingMessageId: messageId,
          editSnapshotText: snapshotText,
          quoteMessage: null,
        );
        _bump();
      }
      return;
    }
    _pendingRestore = false;
    _intent = WebComposerIntent(
      editingMessageId: messageId,
      editSnapshotText: snapshotText ?? '',
      quoteMessage: null,
    );
    _bump();
  }

  /// 长按菜单「引用」：任意非占位消息可引用（快照发送时才序列化）。
  void beginQuote(Message message) {
    _pendingRestore = false;
    _intent = WebComposerIntent(quoteMessage: message);
    _bump();
  }

  /// 用户取消：[restoreDraft] 时 composer 还原编辑前草稿。
  void cancelIntent({bool restoreDraft = false}) {
    if (!_intent.isEditing && !_intent.isQuote) return;
    _pendingRestore = restoreDraft && _intent.isEditing;
    _intent = const WebComposerIntent();
    _bump();
  }

  /// 发送成功收敛（清意图，不恢复草稿 —— composer 已清空并落盘）。
  void completeIntent() {
    _pendingRestore = false;
    if (!_intent.isEditing && !_intent.isQuote) return;
    _intent = const WebComposerIntent();
    _bump();
  }

  /// 失权失效（撤回先到/消息离列表）：隐藏摘要且不恢复草稿（快照已过期）。
  void invalidateEditing() {
    if (!_intent.isEditing) return;
    _pendingRestore = false;
    _intent = const WebComposerIntent();
    _bump();
  }

  /// composer 消费一次「取消并恢复草稿」标记。
  bool consumePendingRestore() {
    final value = _pendingRestore;
    _pendingRestore = false;
    return value;
  }
}

/// 编辑/引用意图注入面（WebChatPanel 在 build 中包住 ChatPanel）。
class WebComposerIntentScope extends InheritedWidget {
  const WebComposerIntentScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final WebComposerIntentController controller;

  static WebComposerIntentController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WebComposerIntentScope>()
      ?.controller;

  @override
  bool updateShouldNotify(WebComposerIntentScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

/// 长按菜单可见性矩阵（纯函数；:04 最低 UX 合同决策点）。
///
/// 与 mobile `showMessageActionMenu` 语义对齐：
/// - E2EE 解密失败占位行：只保留删除（防占位串被复制/引用/编辑为真实文本）；
/// - 编辑：ChatPageUtils.canEditMessage（本人+TextMessage+15min）；
/// - 引用：非占位即可（快照语境由模型层管）；
/// - 撤回：canShowRecallAction（本人+2min 窗）；
/// - 多选：flag 开启 + 会话键可用 + evaluateMessageSelectability 通过。
class WebLongPressMenuPlan {
  const WebLongPressMenuPlan({
    required this.canCopy,
    required this.canQuote,
    required this.canEdit,
    required this.canRecall,
    required this.canDelete,
    required this.canMultiSelect,
  });

  final bool canCopy, canQuote, canEdit, canRecall, canDelete, canMultiSelect;

  bool get isEmpty =>
      !canCopy &&
      !canQuote &&
      !canEdit &&
      !canRecall &&
      !canDelete &&
      !canMultiSelect;
}

WebLongPressMenuPlan resolveWebLongPressMenuPlan({
  required Message message,
  required String currentUserId,
  required int nowMs,
  required bool multiSelectFlagEnabled,
  required bool conversationAvailable,
}) {
  final e2eeFailed = message.metadata?['_e2ee_failed'] == true;
  final copyable = resolveCopyableText(message);
  return WebLongPressMenuPlan(
    canCopy: !e2eeFailed && copyable != null,
    canQuote: !e2eeFailed,
    canEdit:
        !e2eeFailed && ChatPageUtils.canEditMessage(message, currentUserId),
    canRecall:
        !e2eeFailed &&
        canShowRecallAction(
          message: message,
          currentUserId: currentUserId,
          nowMs: nowMs,
        ),
    canDelete: true,
    canMultiSelect:
        !e2eeFailed &&
        multiSelectFlagEnabled &&
        conversationAvailable &&
        evaluateMessageSelectability(messageSelectionTraitsOf(message))
            .selectable,
  );
}

/// 「删除（仅自己）」C2G S2C 消息构建 —— 与 mobile
/// MessageActionHandler._sendDeleteForMeMessage 同合同。
Map<String, dynamic> webDeleteForMePayload({
  required Message message,
  required String chatType,
  required String currentUserId,
}) {
  final peerId = message.metadata?['peer_id']?.toString();
  return {
    'id': Xid().toString(),
    'from': currentUserId,
    'to': peerId,
    'type': 'S2C',
    'payload': {
      'old_msg_id': message.id,
      'to': peerId,
      'msg_type': '${chatType}_DEL_FOR_ME',
    },
    'created_at': DateTimeHelper.millisecond(),
  };
}

/// 多选灰度开关（rollout flag，默认关闭 → 零 UI 变化）。
bool webMultiSelectEnabled() =>
    AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatMultiSelectV1);

/// 多选激活态（panel/watch 共用；空 key 恒 false）。
bool webMultiSelectActiveOf(WidgetRef ref, String conversationUk3) =>
    conversationUk3.isEmpty
    ? false
    : ref.watch(messageSelectionProvider(conversationUk3)).active;

/// 长按菜单「多选」→ 进入并选中首条（接 enterMultiSelectWithFeedback 契约）。
String? webEnterMultiSelect(
  WidgetRef ref,
  String conversationUk3,
  Message message,
) {
  if (conversationUk3.isEmpty) return MessageSelectionReason.inactive;
  final reason = ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .enter(message.id, messageSelectionTraitsOf(message));
  if (reason == MessageSelectionReason.limitExceeded) {
    AppLoading.showToast(
      t.chat.multiSelectLimit(
        count: MessageSelectionNotifier.maxSelectionCount,
      ),
    );
  } else if (reason != null) {
    AppLoading.showToast(t.chat.multiSelectUnavailable);
  }
  return reason;
}

/// 勾选切换（取消已选恒成功；第 101 条 toast 上限）。
String? webToggleMessageSelection(
  WidgetRef ref,
  String conversationUk3,
  Message message,
) {
  if (conversationUk3.isEmpty) return MessageSelectionReason.inactive;
  final reason = ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .toggle(message.id, messageSelectionTraitsOf(message));
  if (reason == MessageSelectionReason.limitExceeded) {
    AppLoading.showToast(
      t.chat.multiSelectLimit(
        count: MessageSelectionNotifier.maxSelectionCount,
      ),
    );
  }
  return reason;
}

/// 退出多选并清空。
void webExitMultiSelect(WidgetRef ref, String conversationUk3) {
  if (conversationUk3.isEmpty) return;
  ref.read(messageSelectionProvider(conversationUk3).notifier).exit();
}

/// 选中集合对账（镜像路径 + post-frame 兜底，复用 reconcile 脏检查）。
void webReconcileMultiSelection(WidgetRef ref, String conversationUk3) {
  if (conversationUk3.isEmpty) return;
  final selection = ref.read(messageSelectionProvider(conversationUk3));
  if (!selection.active) return;
  final liveIds = ref
      .read(chatProvider.notifier)
      .chatService
      ?.messages
      .map((m) => m.id)
      .toList(growable: false);
  ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .reconcile(liveIds ?? const <String>[]);
}

/// 编辑意图失权判定（撤回先到/消息离当前列表 → 隐藏摘要，无权限旁路）。
/// 撤回标记取 UI 消息 metadata 的本地状态键（30/39 区间为撤回终态）。
bool webEditIntentInvalidated(
  WebComposerIntent intent,
  List<Message> messages,
) {
  if (!intent.isEditing) return false;
  final id = intent.editingMessageId!;
  for (final message in messages) {
    if (message.id != id) continue;
    final localStatus = parseModelInt(
      message.metadata?[IMBoyMessageStatus.localStatusMetadataKey],
    );
    return IMBoyMessageStatus.isRevokedStatus(localStatus);
  }
  return true;
}

/// 订阅撤回后「重新编辑」事件：Web 无 mobile ChatInputState（manager 的
/// setText 对 dummy key 是 no-op），文本与意图由本订阅注入控制器。
StreamSubscription<ReEditMessageEvent> webBindReEditEvents({
  required WebComposerIntentController controller,
}) => AppEventBus.on<ReEditMessageEvent>().listen((event) {
  if (event.messageId == null || event.messageId!.isEmpty) return;
  controller.beginReEdit(event.messageId!, snapshotText: event.text);
});

/// 多选消息行包装：勾选框 + 不可选置灰（镜像 mobile chat_message_item 语义）。
Widget webMultiSelectRowWrapper(
  BuildContext context, {
  required WidgetRef ref,
  required String conversationUk3,
  required Message message,
  required Widget child,
}) {
  final selection = conversationUk3.isEmpty
      ? MessageSelectionState()
      : ref.watch(messageSelectionProvider(conversationUk3));
  if (!selection.active) return child;
  final checked = selection.contains(message.id);
  final selectable =
      checked ||
      evaluateMessageSelectability(messageSelectionTraitsOf(message))
          .selectable;
  final colors = Theme.of(context).colorScheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      IconButton(
        key: ValueKey('web-msg-select-checkbox-${message.id}'),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          checked
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.circle,
          size: AppSizes.iconSizeSmall,
          color: selectable ? colors.primary : colors.outlineVariant,
        ),
        tooltip: t.chat.multiSelect,
        onPressed: selectable
            ? () => webToggleMessageSelection(ref, conversationUk3, message)
            : null,
      ),
      Expanded(
        child: selectable ? child : Opacity(opacity: 0.45, child: child),
      ),
    ],
  );
}

/// Web 多选动作栏：接既有策略（forwardEach/bundle/export）与共享编排，
/// 布局语义与 mobile MessageMultiSelectActionBar 一致（取消/计数/转发/导出）。
class WebMultiSelectActionBar extends ConsumerWidget {
  const WebMultiSelectActionBar({
    super.key,
    required this.conversationUk3,
    required this.sourceChatType,
    required this.conversationTitle,
    required this.peerId,
  });

  final String conversationUk3;
  final String sourceChatType;
  final String conversationTitle;
  final String peerId;

  List<Message> _sorted(WidgetRef ref) {
    final selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.watch(messageSelectionProvider(conversationUk3));
    final messages =
        ref.read(chatProvider.notifier).chatService?.messages ??
        const <Message>[];
    return sortMultiSelectMessages(selection, messages);
  }

  void _runCurrent(
    BuildContext context,
    WidgetRef ref,
    List<Message> initial,
    bool Function(Iterable<MessageSelectionTraits> traits) allowed,
    void Function(BuildContext, List<Message>) action,
  ) {
    final selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.read(messageSelectionProvider(conversationUk3));
    final messages =
        ref.read(chatProvider.notifier).chatService?.messages ??
        const <Message>[];
    final fresh = sortMultiSelectMessages(selection, messages);
    if (!canDispatchSelectedMessages(
      active: selection.active,
      current: fresh,
      initial: initial,
      allowed: allowed,
    )) {
      AppLoading.showToast(t.chat.multiSelectUnavailable);
      return;
    }
    action(context, fresh);
  }

  void _showForwardOptions(
    BuildContext context,
    WidgetRef ref,
    List<Message> selected,
    bool forwardEachAllowed,
    bool forwardBundleAllowed,
  ) {
    // 策略不允许 → CupertinoButton 禁用占位（与 mobile
    // MessageMultiSelectActionBar._forwardOption 同形态：ActionSheetAction
    // 的 onPressed 为非空 VoidCallback，禁用项用 Button 表达）。
    Widget option({
      required Key key,
      required String label,
      required bool allowed,
      required VoidCallback onAllowed,
    }) => allowed
        ? CupertinoActionSheetAction(
            key: key,
            onPressed: onAllowed,
            child: Text(label),
          )
        : CupertinoButton(
            key: key,
            minimumSize: const Size(44, 44),
            onPressed: null,
            child: Text(label),
          );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          option(
            key: const ValueKey('web-multi-select-forward-each'),
            label: t.chat.multiSelectForwardEach,
            allowed: forwardEachAllowed,
            onAllowed: () {
              Navigator.of(sheetContext).pop();
              _runCurrent(
                context,
                ref,
                selected,
                forwardEachActionAllowedFor,
                (ctx, fresh) => _forwardEach(ctx, fresh),
              );
            },
          ),
          option(
            key: const ValueKey('web-multi-select-forward-bundle'),
            label: t.chat.multiSelectForwardBundle,
            allowed: forwardBundleAllowed,
            onAllowed: () {
              Navigator.of(sheetContext).pop();
              _runCurrent(
                context,
                ref,
                selected,
                bundleActionAllowedFor,
                (ctx, fresh) => _forwardBundle(ctx, fresh),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          key: const ValueKey('web-multi-select-forward-cancel'),
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  void _forwardEach(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xLarge),
        child: SendToPage.batch(messages: messages),
      ),
    );
  }

  void _forwardBundle(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    unawaited(
      BundleForwardDispatcher.forwardAsHistoryBundle(
        context,
        messages: messages,
        sourceChatType: sourceChatType,
        title: conversationTitle,
      ),
    );
  }

  void _export(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) return;
    unawaited(
      runChatExportFlow(
        context,
        conversationUk3: conversationUk3,
        conversationTitle: conversationTitle,
        messages: messages,
        chatType: sourceChatType,
        toId: peerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = conversationUk3.isEmpty
        ? MessageSelectionState()
        : ref.watch(messageSelectionProvider(conversationUk3));
    // 镜像 + post-frame 对账（复用 reconcile 脏检查，幂等收敛）。
    webReconcileMultiSelection(ref, conversationUk3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      webReconcileMultiSelection(ref, conversationUk3);
    });
    final sorted = _sorted(ref);
    final traits = sorted.map(messageSelectionTraitsOf);
    final forwardEachAllowed = forwardEachActionAllowedFor(traits);
    final forwardBundleAllowed = bundleActionAllowedFor(traits);
    final exportAllowed = exportActionAllowedFor(traits);
    final colors = Theme.of(context).colorScheme;
    final countText = t.chat.multiSelectCount(count: selection.count);
    return Container(
      key: const ValueKey('web-multi-select-action-bar'),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.all(AppSpacing.small),
      child: Row(
        children: [
          TextButton(
            key: const ValueKey('web-multi-select-cancel'),
            onPressed: () => webExitMultiSelect(ref, conversationUk3),
            child: Text(t.chat.multiSelectCancel),
          ),
          Expanded(
            child: Text(
              countText,
              key: const ValueKey('web-multi-select-count'),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            key: const ValueKey('web-multi-select-forward'),
            onPressed:
                sorted.isEmpty || (!forwardEachAllowed && !forwardBundleAllowed)
                ? null
                : () => _showForwardOptions(
                    context,
                    ref,
                    sorted,
                    forwardEachAllowed,
                    forwardBundleAllowed,
                  ),
            child: Text(t.chat.forward),
          ),
          TextButton(
            key: const ValueKey('web-multi-select-export'),
            onPressed: exportAllowed
                ? () => _runCurrent(
                    context,
                    ref,
                    sorted,
                    exportActionAllowedFor,
                    _export,
                  )
                : null,
            child: Text(t.chat.multiSelectExport),
          ),
        ],
      ),
    );
  }
}
