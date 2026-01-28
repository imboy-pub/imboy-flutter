import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/page/chat/chat/message_action_handler.dart';

// Barrel exports - 导入所需的所有依赖
import '../barrel/ui_packages.dart';
import '../barrel/imboy_packages.dart';
import '../barrel/page_packages.dart';
import '../barrel/store_packages.dart';
import '../barrel/chat_widgets.dart';

/// ChatPage 初始化逻辑 Mixin
///
/// 将初始化相关方法从主页面类中抽取出来，提高代码可维护性
///
/// 使用方式：
/// ```dart
/// class ChatPageState extends ConsumerState<ChatPage> with ChatPageInit {
///   // mixin 提供的方法可直接使用
/// }
/// ```
mixin ChatPageInit {
  // ===== 需要由主类提供的属性 =====

  /// 获取当前 widget 的 type 属性
  String get widgetType;

  /// 获取当前 widget 的 peerId 属性
  String get widgetPeerId;

  /// 获取当前 widget 的 peerAvatar 属性
  String get widgetPeerAvatar;

  /// 获取当前 widget 的 peerTitle 属性
  String get widgetPeerTitle;

  /// 获取当前 widget 的 options 属性
  Map<String, dynamic>? get widgetOptions;

  /// 获取 conversationUk3
  String get conversationUk3;

  /// 获取/设置会话对象
  ConversationModel get conversation;
  set conversation(ConversationModel value);

  /// 获取/设置阅后即焚相关状态
  bool get burnEnabled;
  set burnEnabled(bool value);
  int get burnAfterMs;
  set burnAfterMs(int value);

  /// 获取 chatInputKey
  GlobalKey<ChatInputState> get chatInputKey;

  /// 获取/设置编辑中的消息ID
  String? get editingMessageId;
  set editingMessageId(String? value);

  /// 获取 ref
  WidgetRef get ref;

  /// 添加消息到聊天（由主类实现）
  Future<bool> addMessage(dynamic message);

  // ===== 私有属性 =====

  static const MethodChannel _secureChannel = MethodChannel('imboy/secure');

  ChatAttachmentHandler? _attachmentHandler;
  MessageActionHandler? _messageActionHandler;

  // ===== 公共方法 =====

  /// 初始化控制器
  ///
  /// 在 build 方法第一次调用前完成，避免 LateInitializationError
  void initializeControllers(ValueNotifier<double> composerHeightNotifier) {
    // 在 build 方法中通过 ref.watch 获取 state
    final chatState = ref.read(chatProvider);
    composerHeightNotifier.value = chatState.composerHeight;

    // 注意：ref.listen 必须在 build 方法中调用，不能在 initState 中调用
    // 状态监听已移至 build 方法中的 ref.watch
  }

  /// 设置会话
  ///
  /// 创建或获取会话对象，并触发相应的事件
  Future<void> setupConversation() async {
    bool showConversation = widgetOptions?['showConversation'] ?? true;

    final conversationResult = await ref
        .read(conversationProvider.notifier)
        .createConversation(
          type: widgetType,
          peerId: widgetPeerId,
          avatar: widgetPeerAvatar,
          title: widgetPeerTitle,
          subtitle: "",
          lastTime: showConversation ? DateTimeHelper.millisecond() : 0,
        );

    conversation = conversationResult;

    if (showConversation) {
      AppEventBus.fireData(conversation);
    }
    // 重置 nextAutoId
    ref.read(chatProvider.notifier).updateNextAutoId(0);
  }

  /// 重新加载会话设置
  ///
  /// 从数据库重新加载会话配置，包括阅后即焚设置
  Future<void> reloadConversationSettings() async {
    try {
      final c = await ConversationRepo().findByPeerId(widgetType, widgetPeerId);
      if (c != null) {
        conversation = c;
      }
      final payload = conversation.payload;
      burnEnabled = payload?['burn_enabled'] == true;
      final raw = payload?['burn_after_ms'];
      if (raw is int && raw > 0) {
        burnAfterMs = raw;
      } else if (raw is String) {
        final v = int.tryParse(raw);
        if (v != null && v > 0) burnAfterMs = v;
      }
      await applySecureFlag();

      // 初始化附件处理器（在 burnEnabled 和 burnAfterMs 设置后）
      _attachmentHandler = ChatAttachmentHandler(
        peerId: widgetPeerId,
        conversationUk3: conversationUk3,
        burnEnabled: burnEnabled,
        burnAfterMs: burnAfterMs,
        onMessageCreated: addMessage,
      );

      // 初始化消息操作处理器
      _messageActionHandler = MessageActionHandler(
        type: widgetType,
        peerId: widgetPeerId,
        conversation: conversation,
        ref: ref,
        chatInputKey: chatInputKey,
        onEditingMessageIdChanged: (id) {
          editingMessageId = id;
        },
      );
    } catch (_) {}
  }

  /// 应用安全标志
  ///
  /// 通过原生通道启用/禁用屏幕捕获等安全特性
  Future<void> applySecureFlag() async {
    try {
      await _secureChannel.invokeMethod(burnEnabled ? 'enable' : 'disable');
    } catch (_) {}
  }

  /// 禁用安全标志
  ///
  /// 在页面销毁时调用，确保安全标志被禁用
  Future<void> disableSecureFlag() async {
    try {
      await _secureChannel.invokeMethod('disable');
    } catch (_) {}
  }

  /// 同步禁用安全标志
  ///
  /// 用于 dispose 等不能使用 async 的场景
  void disableSecureFlagSync() {
    // ignore: discarded_futures
    disableSecureFlag();
  }

  /// 初始化群组信息
  ///
  /// 仅在群组聊天时调用，更新群组标题和成员数量
  Future<String?> initGroupInfo() async {
    if (widgetType == 'C2G') {
      final memberCount = widgetOptions?['memberCount'] ?? 0;
      ref.read(chatProvider.notifier).updateMemberCount(memberCount);
      return await ref
          .read(chatProvider.notifier)
          .groupTitle(widgetPeerId, widgetPeerTitle, memberCount);
    }
    return null;
  }

  /// 获取附件处理器
  ///
  /// 如果未初始化会抛出异常
  ChatAttachmentHandler get attachmentHandler {
    if (_attachmentHandler == null) {
      throw StateError(
        'ChatAttachmentHandler 未初始化，请先调用 reloadConversationSettings()',
      );
    }
    return _attachmentHandler!;
  }

  /// 获取消息操作处理器
  ///
  /// 如果未初始化会抛出异常
  MessageActionHandler get messageActionHandler {
    if (_messageActionHandler == null) {
      throw StateError(
        'MessageActionHandler 未初始化，请先调用 reloadConversationSettings()',
      );
    }
    return _messageActionHandler!;
  }
}
