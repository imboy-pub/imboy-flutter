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

part 'web_chat_input_send.dart';
part 'web_chat_input_intent.dart';
part 'web_chat_input_multi_select.dart';

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
