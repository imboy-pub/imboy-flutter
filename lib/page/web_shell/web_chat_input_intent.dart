part of 'web_chat_input.dart';

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
