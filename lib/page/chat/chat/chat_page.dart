import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/modules/messaging/public.dart';

// Barrel exports - 减少导入语句
import 'barrel/ui_packages.dart';
import 'barrel/imboy_packages.dart';
import 'barrel/page_packages.dart';
import 'barrel/store_packages.dart';
import 'barrel/chat_widgets.dart';

import 'package:imboy/service/events/events.dart';

// 附件处理器
import 'attachment_handler.dart';

// 消息操作处理器
import 'message_action_handler.dart';

// 事件订阅管理器
import 'mixin/chat_event_subscription_manager.dart';

// 消息事件处理器
import 'mixin/message_event_handler.dart';

// 选择器处理器
import 'mixin/selection_handler.dart';

// UI 组件
import '../widget/burn_badge.dart';
import '../widget/message_quick_action_menu.dart';
import '../widget/typing_indicator.dart';

// 显式导入需要特殊处理的
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as flutter_chat_ui;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/service/message_type_constants.dart';

// CustomMessageBuilder 需要显式导入（与 flutter_chat_core 冲突）
import 'package:imboy/component/chat/message.dart' show CustomMessageBuilder;

// 显式导入 StorageService（解决编译错误）
import 'package:imboy/service/storage.dart';

// 性能优化开关：设置为 true 使用优化的 ChatMessageList，false 使用原 ChatAnimatedList
const bool _useOptimizedMessageList = false;

// 聊天页面主Widget
// ignore: must_be_immutable
class ChatPage extends ConsumerStatefulWidget {
  final String type; // 聊天类型 [C2C | C2G | C2S]
  final String peerId; // 对方ID (用户ID/群组ID/服务ID)
  final String peerAvatar; // 对方头像
  final String peerTitle; // 对方标题/名称
  final String peerSign; // 对方签名
  final String msgId; // 消息ID (用于定位特定消息)
  // 可选配置参数
  final Map<String, dynamic>? options;
  /*
    options可能包含的字段:
    {
      'memberCount':1, // 成员数量，C2G 群聊消息用的
      'popTime':1, // 通过设置 popTime 控制回退几次
      'computeTitle':'', // 计算标题
      'showConversation': true // 面对面建群的时候为false
    }
  */
  const ChatPage({
    super.key,
    this.type = 'C2C',
    required this.peerId,
    required this.peerTitle,
    required this.peerAvatar,
    required this.peerSign,
    this.msgId = '',
    this.options,
  });
  @override
  ConsumerState<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends ConsumerState<ChatPage>
    with MessageEventHandler, SelectionHandler {
  // 使用 Riverpod Provider 替代 GetX
  // state 已移除 - 在 build 方法中通过 ref.watch(chatProvider) 获取

  // ===== MessageEventHandler Mixin 所需的实现 =====

  @override
  String get currentUserId => UserRepoLocal.to.currentUid;

  @override
  dynamic get messageActionHandler => _messageActionHandler;

  // 消息重试回调
  @override
  Future<void> onMessageRetry(String messageId) => _onMessageRetry(messageId);

  // 更新引用消息的回调
  @override
  Future<void> updateQuoteMessage(Message? msg) async {
    setState(() => quoteMessage = msg);
  }

  // ===== SelectionHandler Mixin 所需的实现 =====

  @override
  String get conversationUk3 => _conversationUk3;

  @override
  Map<String, dynamic> get peer => {
    'id': widget.peerId,
    'avatar': widget.peerAvatar,
    'title': widget.peerTitle,
    'sign': widget.peerSign,
  };

  @override
  GlobalKey get chatInputKey => _chatInputKey;

  @override
  bool get burnEnabled => _burnEnabled;

  @override
  int get burnAfterMs => _burnAfterMs;

  @override
  Future<bool> Function(Message message)? get onMessageCreated => _addMessage;

  @override
  dynamic get attachmentHandler => _attachmentHandler;

  static const MethodChannel _secureChannel = MethodChannel('imboy/secure');
  static final Stream<int> _burnTicker = Stream<int>.periodic(
    const Duration(seconds: 1),
    (i) => i,
  ).asBroadcastStream();
  bool _showAppBar = true; // 控制顶部导航栏显示/隐藏
  String newGroupName = ""; // 新群组名称
  int get maxAssetsCount => 9; // 最大可选资源数量
  List<AssetEntity> assets = <AssetEntity>[]; // 选择的资源列表
  Message? quoteMessage; // 引用的消息
  final GlobalKey<ChatInputState> _chatInputKey = GlobalKey<ChatInputState>();
  final performanceMonitor = ChatPerformanceMonitor();

  // @提及相关状态
  List<String> _currentMentionIds = [];

  // 消息发送防抖
  DateTime? _lastSendTime;
  // 输入状态发送防抖
  DateTime? _lastTypingSendTime;
  Timer? _typingTimer;

  static const Duration _sendDebounceDuration = Duration(milliseconds: 500);
  late final ValueNotifier<double> composerHeightNotifier;
  Timer? _cleanupTimer;
  // 可视阈值已读：延迟计时与去重集合
  final Map<String, Timer> _readDelayTimers = {};
  final Set<String> _readCommitted = {};
  // 防止重复滚动到底部（避免在每次 build 时都创建回调）
  bool _hasScrolledToBottom = false;
  // 消息ID集合，用于防止 eventBus 重复渲染消息
  final Set<String> msgIds = {};
  final User currentUser = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );
  late ConversationModel conversation; // 当前会话
  late User _peerUser; // 对方用户信息
  String? _editingMessageId; // 当前正在编辑的消息ID
  bool _burnEnabled = false;
  int _burnAfterMs = 30000;
  StreamSubscription? _connectivitySubscription; // 网络状态监听

  // 附件处理器（延迟初始化，依赖 conversationUk3）
  late final ChatAttachmentHandler _attachmentHandler;

  // 消息操作处理器
  late final MessageActionHandler _messageActionHandler;

  // 用于定位目标消息的 GlobalKey
  final GlobalKey _targetMessageKey = GlobalKey();

  // 保存 ChatNotifier 引用，用于在 dispose 中安全访问
  late final ChatNotifier _chatNotifier;

  // ===== 便利访问器（替代 UIEventHandlerMixinState 接口） =====

  // 获取消息滚动管理器
  MessageScrollManager get messageScrollNotifier =>
      ref.read(messageScrollManagerProvider.notifier);

  // 安全获取 conversationUk3
  // 避免 LateInitializationError：优先使用路由参数/已初始化会话，否则通过标准生成器生成
  String get _conversationUk3 {
    final fromOptions = widget.options?['conversationUk3'];
    if (fromOptions is String && fromOptions.isNotEmpty) {
      return fromOptions;
    }

    if (_isConversationInitialized) {
      return conversation.uk3;
    }

    return ConversationUk3Generator.generateSmart(
      type: _chatType,
      currentUserId: UserRepoLocal.to.currentUid,
      peerId: widget.peerId,
    );
  }

  /// 统一归一化聊天类型，避免历史脏值（如 'null'）继续向下游扩散
  String get _chatType => MessageFlowType.normalize(widget.type);

  // 检查 conversation 是否已初始化
  bool get _isConversationInitialized {
    try {
      final _ = conversation.uk3;
      return true;
    } catch (e) {
      return false;
    }
  }

  // 页面初始化
  @override
  void initState() {
    super.initState();

    // 保存 ChatNotifier 引用，用于在 dispose 中安全访问
    _chatNotifier = ref.read(chatProvider.notifier);

    // 立即初始化控制器（必须在 build 方法第一次调用前完成）
    _initializeControllers();

    // 初始化 Riverpod Provider 的 logic 和 state
    // 这些会在 build 方法中通过 ref.read 初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 其他初始化操作
    });

    try {
      msgIds.clear();
      _initChat();
      _initData();

      // 初始化网络状态监听器（在 build 方法之外）
      _chatNotifier.initConnectivityListener();

      // 延迟发送活动会话事件，避免在 widget 树构建期间修改 provider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifyChatActive(true);
        }
      });

      // 启动内存清理定时器
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        performanceMonitor.cleanupInvisibleMessages();
        if (kDebugMode) {
          final stats = performanceMonitor.getMemoryStats();
          debugPrint('内存使用统计: $stats');
        }
      });
    } catch (e, stack) {
      debugPrint('Error in initState: $e\n$stack');
    }
  }

  // 延迟初始化控制器（需要 ref 访问）
  void _initializeControllers() {
    // 在 build 方法中通过 ref.watch 获取 state
    final chatState = ref.read(chatProvider);
    composerHeightNotifier = ValueNotifier<double>(chatState.composerHeight);

    // 监听高度变化并同步到 Provider 状态
    composerHeightNotifier.addListener(() {
      if (mounted) {
        // 避免循环更新：只有当 notifier 的值与 state 中的值不同时才更新
        if (ref.read(chatProvider).composerHeight !=
            composerHeightNotifier.value) {
          ref
              .read(chatProvider.notifier)
              .updateComposerHeight(composerHeightNotifier.value);
        }
      }
    });

    // 注意：ref.listen 必须在 build 方法中调用，不能在 initState 中调用
    // 状态监听已移至 build 方法中的 ref.watch
  }

  // 检查消息是否可以编辑（使用工具类）
  bool canEditMessage(Message message) {
    return ChatPageUtils.canEditMessage(message, UserRepoLocal.to.currentUid);
  }

  /// 初始化聊天相关数据
  Future<void> _initChat() async {
    try {
      // 获取 ChatLogic 实例
      // logic 已移除 - 使用 Riverpod Provider

      ref.read(chatProvider.notifier).initChatService(_chatType);
      // 创建或获取会话
      await _setupConversation();
      await _reloadConversationSettings();
      await ref
          .read(chatProvider.notifier)
          .cleanupExpiredBurnMessagesForConversation(conversation);

      if (widget.msgId.isNotEmpty) {
        await ref
            .read(chatProvider.notifier)
            .loadMessagesAround(conversation, widget.msgId);
        // 延迟滚动，确保 ListView 已构建且消息已渲染
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToTargetMessage();
        });
      } else {
        await ref
            .read(chatProvider.notifier)
            .loadMoreMessages(conversation, isInitial: true);
      }

      _setupEventListeners();
    } catch (e, stack) {
      debugPrint('_initChat error: $e\n$stack');
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t.chatInitFailed}: $e')));
      }
    }
  }

  // 初始化数据
  Future<void> _initData() async {
    // 检查 widget 是否仍然 mounted
    if (!mounted) return;

    _peerUser = User(
      id: widget.peerId,
      name: widget.peerTitle,
      imageSource: widget.peerAvatar,
    );
    // 监听网络状态
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> r,
    ) {
      // 安全地更新 Provider 状态（仅在 widget 仍然 mounted 时）
      if (mounted) {
        if (r.contains(ConnectivityResult.none)) {
          // 更新 Riverpod Provider 中的 connected 状态
          ref.read(chatProvider.notifier).updateConnected(false);
        } else {
          ref.read(chatProvider.notifier).updateConnected(true);
        }
      }
    });
    if (availableMaps.isEmpty) {
      try {
        availableMaps = await MapLauncher.installedMaps;
      } catch (e) {
        //
      }
    }
    // 初始化群组信息
    await _initGroupInfo();
    // 设置消息监听
    _setupEventListeners();
    // 预加载E2EE设备密钥（优化加密性能）
    await _preloadE2EEDeviceKeys();
  }

  /// 预加载E2EE设备密钥
  ///
  /// 在聊天页面初始化时预先获取对方设备的公钥，避免发送消息时等待
  Future<void> _preloadE2EEDeviceKeys() async {
    // 只在E2EE启用时预加载
    if (!E2EESettings.isEnabled()) {
      return;
    }

    try {
      if (_chatType == MessageFlowType.c2g) {
        // 群组：预加载群组成员设备密钥
        await E2EEService.getGroupDevicePublicKeys(widget.peerId);
        debugPrint('E2EE: 已预加载群组设备密钥 ${widget.peerId}');
      } else {
        // 单聊：预加载对方设备密钥
        await E2EEService.getUserDevicePublicKeys(widget.peerId);
        debugPrint('E2EE: 已预加载用户设备密钥 ${widget.peerId}');
      }
    } catch (e) {
      // 预加载失败不影响聊天，发送时会重试
      debugPrint('E2EE: 预加载设备密钥失败（将在发送时重试）: $e');
    }
  }

  /// 设置会话
  Future<void> _setupConversation() async {
    bool showConversation = widget.options?['showConversation'] ?? true;

    final conversationResult = await ref
        .read(conversationProvider.notifier)
        .createConversation(
          type: _chatType,
          peerId: widget.peerId,
          avatar: widget.peerAvatar,
          title: widget.peerTitle,
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

  Future<void> _reloadConversationSettings() async {
    try {
      final c = await ConversationRepo().findByPeerId(_chatType, widget.peerId);
      if (c != null) {
        conversation = c;
      }
      final payload = conversation.payload;
      _burnEnabled = payload?['burn_enabled'] == true;
      final raw = payload?['burn_after_ms'];
      if (raw is int && raw > 0) {
        _burnAfterMs = raw;
      } else if (raw is String) {
        final v = int.tryParse(raw);
        if (v != null && v > 0) _burnAfterMs = v;
      }
      await _applySecureFlag();

      // 初始化附件处理器（在 _burnEnabled 和 _burnAfterMs 设置后）
      _attachmentHandler = ChatAttachmentHandler(
        peerId: widget.peerId,
        conversationUk3: _conversationUk3,
        burnEnabled: _burnEnabled,
        burnAfterMs: _burnAfterMs,
        onMessageCreated: _addMessage,
      );

      // 初始化消息操作处理器
      _messageActionHandler = MessageActionHandler(
        type: _chatType,
        peerId: widget.peerId,
        conversation: conversation,
        ref: ref,
        chatInputKey: _chatInputKey,
        onEditingMessageIdChanged: (id) {
          _editingMessageId = id;
        },
      );
    } catch (_) {}
  }

  Future<void> _applySecureFlag() async {
    try {
      await _secureChannel.invokeMethod(_burnEnabled ? 'enable' : 'disable');
    } catch (_) {}
  }

  // 检查消息是否为阅后即焚（使用工具类）
  bool _isBurnMessage(Message message) {
    return ChatPageUtils.isBurnMessage(message);
  }

  // 获取消息的阅后即焚时长（使用工具类）
  int _burnAfterMsFromMessage(Message message) {
    return ChatPageUtils.getBurnAfterMs(message);
  }

  // 为消息添加阅后即焚元数据（使用工具类）
  Map<String, dynamic> _withBurnMetadata(Map<String, dynamic> base) {
    return ChatPageUtils.withBurnMetadata(
      base: base,
      burnEnabled: _burnEnabled,
      burnAfterMs: _burnAfterMs,
    );
  }

  // 初始化群组信息
  Future<void> _initGroupInfo() async {
    if (_chatType == MessageFlowType.c2g) {
      final memberCount = widget.options?['memberCount'] ?? 0;
      ref.read(chatProvider.notifier).updateMemberCount(memberCount);
      newGroupName = await ref
          .read(chatProvider.notifier)
          .groupTitle(widget.peerId, widget.peerTitle, memberCount);
    }
  }

  // 事件订阅管理器
  ChatEventSubscriptionManager? _eventSubscriptionManager;

  // AppErrorEvent 监听器订阅（需要单独处理以显示 SnackBar）
  StreamSubscription<AppErrorEvent>? _ssAppErrorLocal;
  StreamSubscription<E2EEKeyMismatchEvent>? _ssE2EEKeyMismatch;

  void _setupEventListeners() {
    try {
      // 初始化事件订阅管理器
      _eventSubscriptionManager = ChatEventSubscriptionManager(
        widgetRef: ref,
        peerId: widget.peerId,
        peerTitle: widget.peerTitle,
        chatType: _chatType,
        conversationUk3: _conversationUk3,
        msgIds: msgIds,
        editingMessageIdSetter: (id) {
          _editingMessageId = id;
        },
        chatInputKey: _chatInputKey,
        isBurnMessageChecker: _isBurnMessage,
        conversationGetter: () => conversation,
        newGroupNameSetter: (name) {
          newGroupName = name;
          if (mounted) setState(() {});
        },
      );

      // 设置事件监听器（传入 mounted 状态检查函数）
      _eventSubscriptionManager!.setupEventListeners(
        onMountedStateChanged: () => mounted ? null : null,
      );

      // 单独处理 AppErrorEvent 的 SnackBar 显示（需要 context）
      _ssAppErrorLocal = AppEventBus.on<AppErrorEvent>().listen(
        (error) {
          if (!mounted) return;
          // 处理非好友和黑名单错误
          if (error.errorType == 'not_a_friend' ||
              error.errorType == 'in_denylist' ||
              error.message.contains('非好友') ||
              error.message.contains('黑名单')) {
            // 使用 EasyLoading 显示提示（更简单直接）
            EasyLoading.showToast(error.message);
          }
        },
        onError: (error) {
          debugPrint('AppErrorEvent listener error: $error');
        },
      );

      // 监听E2EE密钥不匹配事件，引导用户重新登录
      _ssE2EEKeyMismatch = AppEventBus.on<E2EEKeyMismatchEvent>().listen(
        (event) {
          if (!mounted) return;
          _showE2EEKeyMismatchDialog();
        },
        onError: (error) {
          debugPrint('E2EEKeyMismatchEvent listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('_setupEventListeners error: $e');
    }
  }

  @override
  void dispose() {
    // 注意：不在 dispose 中调用 _notifyChatActive(false)
    // 原因：此时 ref 已不安全，且 widget 销毁后会自然失效
    // 下一个活跃的聊天页面会调用 _notifyChatActive(true) 设置自己

    // 取消事件订阅管理器的所有订阅
    _eventSubscriptionManager?.dispose();

    // 取消 AppErrorEvent 本地监听器
    _ssAppErrorLocal?.cancel();

    // 取消 E2EE密钥不匹配事件监听器
    _ssE2EEKeyMismatch?.cancel();

    // 取消网络状态监听
    _connectivitySubscription?.cancel();

    // 注意：不要在页面 dispose 时清空消息列表
    // ChatNotifier 是全局单例 Provider，退出页面不应销毁
    // 这样重新进入会话时，消息列表仍然存在

    // 清理 composerHeightNotifier
    composerHeightNotifier.dispose();

    // 清理消息ID集合
    msgIds.clear();

    // 停止内存清理定时器
    _cleanupTimer?.cancel();
    // 取消所有"可视阈值已读"的定时
    for (final t in _readDelayTimers.values) {
      t.cancel();
    }
    _readDelayTimers.clear();
    _readCommitted.clear();

    // 清理性能监控内存
    performanceMonitor.cleanupInvisibleMessages();

    // Riverpod Provider 会自动处理资源释放
    try {
      _secureChannel.invokeMethod('disable');
    } catch (_) {}

    super.dispose();
  }

  /// 发送活动会话事件（用于未读数管理）
  void _notifyChatActive(bool isActive) {
    // 检查 widget 是否仍然 mounted（在 dispose 中调用时可能已 unmounted）
    if (!mounted) {
      debugPrint('_notifyChatActive: widget 已 unmounted，跳过更新');
      return;
    }

    try {
      final conversationUk3 = _conversationUk3;
      if (conversationUk3.isEmpty) {
        debugPrint('_notifyChatActive: 会话UK3为空，跳过更新');
        return;
      }

      // 使用 Riverpod Provider 管理活跃会话状态
      if (isActive) {
        ref
            .read(activeConversationProvider.notifier)
            .setActiveConversation(conversationUk3);

        // 修复：进入聊天页面时，自动推进已读水位到最新消息，清空未读数
        // 这样用户不需要滚动到消息可见区域，小红点就会消失
        _clearUnreadOnEnter();
      } else {
        ref.read(activeConversationProvider.notifier).clearActiveConversation();
      }
    } catch (e) {
      debugPrint('Error updating active conversation: $e');
    }
  }

  /// 进入聊天页面时清空未读数
  ///
  /// 通过推进已读水位到最新消息来实现未读数的清空
  /// 这样用户进入聊天页面后，小红点会立即消失，而不需要滚动到消息可见区域
  Future<void> _clearUnreadOnEnter() async {
    try {
      final conversationNotifier = ref.read(conversationProvider.notifier);

      // 不直接使用 conversation 字段（可能尚未初始化）
      // 而是通过 peerId 和 type 从数据库或 provider 中获取会话对象
      final ConversationRepo repo = ConversationRepo();
      final conv = await repo.findByPeerId(_chatType, widget.peerId);

      if (conv == null) {
        debugPrint('_clearUnreadOnEnter: 会话未找到，跳过清空未读数');
        return;
      }

      // 调用 advanceWatermarkToLatest 来推进已读水位到最新消息
      // 这会自动重算未读数，通常会将未读数设置为 0
      await conversationNotifier.advanceWatermarkToLatest(conv);

      debugPrint('_clearUnreadOnEnter: 已清空会话未读数: ${conv.uk3}');
    } catch (e) {
      debugPrint('_clearUnreadOnEnter: 清空未读数失败: $e');
    }
  }

  // 滚动到目标消息
  Future<void> _scrollToTargetMessage() async {
    try {
      // 确保消息列表已加载
      if (ref.read(chatProvider.notifier).chatService?.messages.isEmpty ??
          true) {
        debugPrint("消息列表为空，无法滚动");
        return;
      }

      // 查找目标消息在列表中的索引
      final messages = ref.read(chatProvider.notifier).chatService!.messages;
      final targetIndex = messages.indexWhere((m) => m.id == widget.msgId);

      if (targetIndex == -1) {
        debugPrint("未找到目标消息: ${widget.msgId}");
        return;
      }

      debugPrint(
        "找到目标消息: ${widget.msgId}, 索引: $targetIndex, 总消息数: ${messages.length}",
      );

      // 增加重试次数和间隔，确保在复杂布局或低端机上也能成功定位
      for (var attempt = 0; attempt < 12; attempt++) {
        // 检查 widget 是否仍然 mounted（防止页面销毁后继续执行）
        if (!mounted) {
          debugPrint("页面已销毁，停止滚动尝试");
          return;
        }

        await WidgetsBinding.instance.endOfFrame;
        // 渐进式等待：前几次快一点，后面慢一点
        await Future.delayed(Duration(milliseconds: attempt < 3 ? 100 : 200));

        // 再次检查 mounted（防止异步操作期间页面被销毁）
        if (!mounted) {
          debugPrint("页面已销毁，停止滚动尝试");
          return;
        }

        await ref
            .read(chatProvider.notifier)
            .chatService
            ?.scrollToMessage(
              widget.msgId,
              duration: const Duration(milliseconds: 500),
              offset: 100.0,
            );

        // 检查目标消息是否在可视区域内
        if (_targetMessageKey.currentContext != null) {
          final renderObject = _targetMessageKey.currentContext!
              .findRenderObject();
          if (renderObject is RenderBox) {
            // 简单的可见性检查：只要 context 存在且 renderObject attached，说明已经 build 并进入了树
            // 配合 scrollToMessage 的执行，通常意味着已经滚到了位置
            debugPrint("滚动定位成功，目标消息已进入视图树，尝试次数: ${attempt + 1}");
            break;
          }
        }
      }

      // 高亮消息（检查 mounted）
      if (mounted) {
        ref
            .read(messageScrollManagerProvider.notifier)
            .highlightMessage(widget.msgId);
      }
    } catch (e) {
      debugPrint("滚动到目标消息失败: $e");
      // 降级处理：使用简单的索引滚动
      _fallbackScrollToMessage();
    }
  }

  // 降级滚动方法
  void _fallbackScrollToMessage() {
    try {
      // 检查 widget 是否仍然 mounted
      if (!mounted) return;

      final messages =
          ref.read(chatProvider.notifier).chatService?.messages ?? [];
      final targetIndex = messages.indexWhere((m) => m.id == widget.msgId);

      if (targetIndex == -1) return;

      // 估算滚动位置 (reverse: true, index 0 is bottom)
      // 假设平均消息高度为80像素
      double estimatedOffset = targetIndex * 80.0;

      if (ref
          .read(messageScrollManagerProvider.notifier)
          .scrollController
          .hasClients) {
        final maxScroll = ref
            .read(messageScrollManagerProvider.notifier)
            .scrollController
            .position
            .maxScrollExtent;
        if (estimatedOffset > maxScroll) {
          estimatedOffset = maxScroll;
        }

        ref
            .read(messageScrollManagerProvider.notifier)
            .scrollController
            .jumpTo(estimatedOffset);

        // 延迟高亮（检查 mounted）
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            ref
                .read(messageScrollManagerProvider.notifier)
                .highlightMessage(widget.msgId);
          }
        });

        debugPrint("使用降级方法滚动到消息: ${widget.msgId}, 位置: $estimatedOffset");
      }
    } catch (e) {
      debugPrint("降级滚动也失败: $e");
    }
  }

  // 标记消息为已读
  // 添加消息
  Future<bool> _addMessage(Message message) async {
    try {
      await ref
          .read(chatProvider.notifier)
          .addMessage(
            UserRepoLocal.to.currentUid,
            widget.peerId,
            widget.peerAvatar,
            widget.peerTitle,
            _chatType,
            message,
          );
      await ref
          .read(chatProvider.notifier)
          .chatService
          ?.insertMessage(
            message,
            index:
                ref.read(chatProvider.notifier).chatService?.messages.length ??
                0,
            animated: true, // 新消息使用动画
          );
      return true;
    } catch (e, stack) {
      debugPrint("_addMessage error: $e : $stack");
      return false;
    }
  }

  /// 消息重试回调
  /// Message retry callback.
  Future<void> _onMessageRetry(String messageId) async {
    try {
      debugPrint('开始重试消息: $messageId');

      // 显示加载状态
      EasyLoading.show(status: t.retryingSend);

      final success = await ref
          .read(chatProvider.notifier)
          .retryMessage(messageId, _chatType);

      EasyLoading.dismiss();

      if (success) {
        EasyLoading.showSuccess(t.retrySuccess);
      } else {
        EasyLoading.showError(t.retryFailedPleaseCheckNetwork);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('${t.retryAbnormal}: $e');
      debugPrint('消息重试异常: $e');
    }
  }

  // ===== 附件处理回调方法 =====

  /// 处理语音录制完成
  void _handleVoiceSelection(dynamic obj) {
    handleVoiceSelection(obj);
  }

  /// 处理图片选择（从相册）
  void _handleImageSelection() {
    // 调用 attachmentHandler 的 handleImageSelection
    // 使用默认的图片选择器
    _attachmentHandler.handleImageSelection(
      context,
      () => AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 9,
          requestType: RequestType.image,
        ),
      ),
    );
  }

  /// 处理文件选择
  void _handleFileSelection() {
    handleFileSelection();
  }

  /// 处理相机选择
  void _handlePickerSelection(BuildContext ctx) {
    handlePickerSelection(ctx);
  }

  /// 处理位置选择（由ExtraItems内部处理，这里提供空实现）
  void _handleLocationSelection(
    String id,
    Uint8List? imageBytes,
    String address,
    String title,
    String latitude,
    String longitude,
  ) {
    handleLocationSelection(
      id,
      imageBytes,
      address,
      title,
      latitude,
      longitude,
    );
  }

  /// 处理名片选择
  Future<void> _handleVisitCardSelection() async {
    // 构建当前用户信息（用于名片显示）
    final peer = {
      'uid': _attachmentHandler.peerId,
      'nickname': widget.peerTitle,
      'avatar': widget.peerAvatar,
    };

    // 打开选择好友页面
    final result = await context.push<ContactModel>(
      '/contact/select_friend',
      extra: {'peer': peer, 'peerIsReceiver': true},
    );

    // 如果用户选择了好友，发送名片消息
    if (result != null && mounted) {
      debugPrint('发送名片消息: uid=${result.peerId}, title=${result.title}');
      await _attachmentHandler.sendVisitCardMessage(
        context,
        result.peerId,
        result.title,
        result.avatar,
      );
    }
  }

  /// 处理收藏选择
  Future<void> _handleCollectSelection() async {
    // 构建当前聊天对象信息（用于收藏页面显示）
    final peer = {
      'id': _attachmentHandler.peerId,
      'title': widget.peerTitle,
      'avatar': widget.peerAvatar,
      'sign': widget.peerSign,
    };

    debugPrint('打开收藏选择页面，peer: $peer');

    // 打开收藏页面（选择模式）
    final result = await Navigator.push<UserCollectModel>(
      context,
      CupertinoPageRoute(
        builder: (context) => UserCollectPage(isSelect: true, peer: peer),
      ),
    );

    // 如果用户选择了收藏消息，发送它
    if (result != null && mounted) {
      debugPrint('用户选择了收藏消息: kind=${result.kind}, kindId=${result.kindId}');
      debugPrint('收藏消息 info: ${result.info.toString()}');

      try {
        await _attachmentHandler.sendCollectMessage(context, result.info);
      } catch (e, s) {
        debugPrint('发送收藏消息失败: $e\n堆栈: $s');
        if (mounted) {
          EasyLoading.showError(t.operationFailedAgainLater);
        }
      }
    }
  }

  // 消息双击事件
  void _onMessageDoubleTap(
    BuildContext context,
    Message message, {
    required int index,
  }) {
    // 触发震动反馈
    HapticFeedback.lightImpact();

    if (message is TextMessage) {
      showTextMessage(message.text);
    } else if (message is FileMessage) {
      confirmOpenFile(context, message.source);
    } else if (message is ImageMessage) {
      // 打开图片查看器（使用 Riverpod）
      ref
          .read(imageGalleryProvider.notifier)
          .onImagePressed(message.id, message.source);
      iPrint('onImagePressed tapped: ${message.id} ${message.source}');
      setState(() {
        _showAppBar = false;
      });
    } else if (message is CustomMessage) {
      String txt = message.metadata?['quote_text'] ?? '';
      if (txt.isNotEmpty) showTextMessage(txt);
    }
  }

  // 新增：消息点击事件
  void _onMessageTap(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    // 取消引用状态
    if (quoteMessage?.id == message.id) {
      updateQuoteMessage(null);
    }

    // 可以在这里添加其他点击逻辑
    iPrint('Message tapped: ${message.id}, type: ${message.runtimeType}');
  }

  // 新增：消息辅助点击事件（右键或长按）
  void _onMessageSecondaryTap(
    BuildContext context,
    Message message, {
    required int index,
    TapUpDetails? details,
  }) {
    // 触发震动反馈
    HapticFeedback.mediumImpact();

    // 显示快捷菜单或执行特定操作
    final isSentByMe = message.authorId == UserRepoLocal.to.currentUid;

    // 如果是自己的消息且是发送失败状态，提供重试选项
    if (isSentByMe && message.status == MessageStatus.error) {
      _showRetryMenu(context, message);
    } else {
      // 显示简化的操作菜单
      _showQuickActionMenu(context, message);
    }
  }

  // 显示重试菜单（使用 MessageQuickActionMenu 组件）
  void _showRetryMenu(BuildContext context, Message message) {
    MessageQuickActionMenu.showRetryMenu(
      context: context,
      message: message,
      onRetry: () => _onMessageRetry(message.id),
      onDelete: () => deleteMessageForMe(context, message, pop: false),
    );
  }

  // 显示快捷操作菜单（使用 MessageQuickActionMenu 组件）
  void _showQuickActionMenu(BuildContext context, Message message) {
    MessageQuickActionMenu.showQuickActionMenu(
      context: context,
      message: message,
      onReply: () => updateQuoteMessage(message),
      onSaveFile: (name, uri) =>
          ref.read(chatProvider.notifier).saveFile(name, uri),
      onCopy: () {
        if (message is TextMessage) {
          _messageActionHandler.copyMessageText(message);
        }
      },
      onForward: () => _messageActionHandler.forwardMessage(context, message),
      onCollect: () => _messageActionHandler.collectMessage(message),
      onRevoke: () => _messageActionHandler.revokeMessage(message),
      onDelete: () => _messageActionHandler.deleteMessageForMe(
        context,
        message,
        pop: false,
      ),
    );
  }

  // 处理输入状态变化
  void _handleInputChanged(String text) {
    // 仅单聊支持输入状态
    if (_chatType != 'C2C') return;

    if (text.isEmpty) {
      // Send stop typing
      _sendTypingStatus(TypingStatus.stop);
      return;
    }

    final now = DateTime.now();
    // 每3秒发送一次正在输入状态
    if (_lastTypingSendTime == null ||
        now.difference(_lastTypingSendTime!) > const Duration(seconds: 3)) {
      _sendTypingStatus(TypingStatus.start);
      _lastTypingSendTime = now;
    }

    // Reset timer to send stop if no input for 5 seconds
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 5), () {
      _sendTypingStatus(TypingStatus.stop);
    });
  }

  // 发送输入状态
  void _sendTypingStatus(TypingStatus status) {
    MessagingFacade.instance.sendInputStatus(
      conversationUk3: _conversationUk3,
      toId: widget.peerId,
      msgType: _chatType,
      status: status,
    );
  }

  // 发送文本消息
  Future<bool> _handleSendPressed(String text) async {
    iPrint(
      'handleSendPressed 开始: text=$text, _editingMessageId=$_editingMessageId',
    );

    // 防抖：检查是否在短时间内重复发送
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _sendDebounceDuration) {
      iPrint('消息发送防抖触发：距离上次发送不足 ${_sendDebounceDuration.inMilliseconds}ms');
      return false;
    }

    // 检查是否是编辑消息
    if (_editingMessageId != null && _editingMessageId!.isNotEmpty) {
      iPrint('执行编辑消息: messageId=$_editingMessageId, newContent=$text');

      // 发送编辑消息
      bool result = await MessagingFacade.instance.sendEditMessage(
        _editingMessageId!,
        _chatType,
        text,
      );

      iPrint('编辑消息结果: $result');

      // 清除编辑状态
      _editingMessageId = null;

      return result;
    } else if (quoteMessage == null) {
      iPrint(t.sendNewMessage);
      final result = await _sendTextMessage(text);
      if (result) {
        _lastSendTime = DateTime.now();
      }
      return result;
    } else {
      final result = await _sendQuoteMessage(text);
      if (result) {
        _lastSendTime = DateTime.now();
      }
      return result;
    }
  }

  // 发送普通文本消息
  Future<bool> _sendTextMessage(String text) async {
    // 构建 metadata，包含 mentions 字段（仅群聊）
    final metadata = _withBurnMetadata({'peer_id': widget.peerId});

    // 如果是群聊且有 @提及，添加 mentions 字段
    if (_chatType == MessageFlowType.c2g && _currentMentionIds.isNotEmpty) {
      metadata['mentions'] = _currentMentionIds;
      // 发送后清空 @提及 列表
      _currentMentionIds = [];
    }

    final textMessage = TextMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      text: text,
      metadata: metadata,
    );
    return await _addMessage(textMessage);
  }

  // 发送引用消息
  Future<bool> _sendQuoteMessage(String text) async {
    String quoteMsgAuthorName = quoteMessage!.authorId == widget.peerId
        ? widget.peerTitle
        : UserRepoLocal.to.current.nickname;
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'msg_type': 'quote',
        'peer_id': widget.peerId,
        'quote_msg': quoteMessage?.toJson(),
        'quote_msg_author_name': quoteMsgAuthorName,
        'quote_text': text,
      }),
    );
    bool res = await _addMessage(message);
    if (res) updateQuoteMessage(null);
    return res;
  }

  // 消息状态点击事件
  void _onMessageStatusTap(BuildContext ctx, Message msg) {
    // 检查是否为发送失败的消息，如果是则触发重试
    if (msg.status == MessageStatus.error &&
        msg.authorId == UserRepoLocal.to.currentUid) {
      _onMessageRetry(msg.id);
      return;
    }

    // 原有逻辑：处理已发送和发送中的消息
    // 注意：这部分逻辑已废弃，因为与重试逻辑重复
    if (msg.status != MessageStatus.sent &&
        msg.status != MessageStatus.sending) {
      return;
    }
  }

  // 消息长按事件
  void _onMessageLongPress(
    BuildContext c1,
    Message message, {
    required int index,
    required LongPressStartDetails details,
  }) {
    iPrint('_onMessageLongPress');
    final isSentByMe = message.authorId == UserRepoLocal.to.currentUid;
    final canEdit = canEditMessage(message);

    // 检查消息是否可以重试（发送失败的消息）
    final canRetry = isSentByMe && message.status == MessageStatus.error;

    // 使用现代化的消息操作菜单，保留所有现有功能
    showMessageActionMenu(
      context: c1,
      message: message,
      isSentByMe: isSentByMe,
      canEdit: canEdit,
      onReply: () => updateQuoteMessage(message),
      onCopy: () {
        if (message is TextMessage) {
          copyMessageText(message);
        } else if (message is CustomMessage &&
            message.metadata?['msg_type'] == 'quote') {
          // 引用消息的复制功能
          final quoteText = message.metadata?['quote_text'] ?? '';
          if (quoteText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: quoteText));
            EasyLoading.showToast(t.copied);
          }
        }
      },
      onEdit: () => editMessage(message),
      onDelete: () => deleteMessageForMe(context, message, pop: false),
      onDeleteForEveryone: isSentByMe
          ? () => deleteMessageForEveryone(context, message)
          : null,
      onForward: () => forwardMessage(message),
      onReaction: (emoji) => addReaction(message, emoji),
      // 新增的操作回调
      onRevoke: isSentByMe ? () => revokeMessage(message) : null,
      onSave: canSaveMessage(message)
          ? () => saveMessageContent(message)
          : null,
      onCollect: canCollectMessage(message)
          ? () => collectMessage(message)
          : null,
      onRetry: canRetry ? () => _onMessageRetry(message.id) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    // state = chatState; // 不再需要本地 state 引用

    // 更新 composerHeightNotifier（响应 composerHeight 变化）
    if (composerHeightNotifier.value != chatState.composerHeight) {
      composerHeightNotifier.value = chatState.composerHeight;
    }

    final theme = Theme.of(context);
    final topRightWidget = [
      IconButton(
        onPressed: _navigateToChatSettings,
        icon: Icon(
          Icons.more_horiz,
          color: themeNotifier.getThemeColor('textPrimary'),
        ),
      ),
    ];
    return PopScope(
      canPop: !(chatState.composerHeight > 52), // 面板或键盘展开时禁止返回（约定基础高度≈52）
      onPopInvokedWithResult: (didPop, result) async {
        // 如果已经执行了返回操作，不需要处理
        if (didPop) return;

        // 优先收起面板/键盘，避免"返回上一页"
        if (chatState.composerHeight > 52) {
          final navigator = Navigator.of(context);
          _chatInputKey.currentState?.hideAllPanel();
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          navigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 禁用系统自动避让，改为手动控制高度以避免抖动
        appBar: _showAppBar
            ? GlassAppBar(
                titleWidget: Text(
                  newGroupName.isEmpty ? widget.peerTitle : newGroupName,
                  style: TextStyle(
                    color: themeNotifier.getThemeColor('textPrimary'),
                    fontSize: themeNotifier.getFontSize(FontSizeType.title),
                  ),
                ),
                rightDMActions: topRightWidget,
                automaticallyImplyLeading: true,
              )
            : null,
        body: Column(
          children: [
            chatState.connected
                ? const SizedBox.shrink()
                : NetworkFailureTips(),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _chatInputKey.currentState?.hideAllPanel();
                },
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    _buildChatWidget(context, theme, chatState),
                    // 使用 Riverpod 的 ConsumerWidget 监听图片画廊状态
                    Consumer(
                      builder: (context, ref, _) {
                        final galleryState = ref.watch(imageGalleryProvider);
                        if (!galleryState.isImageViewVisible) {
                          return const SizedBox.shrink();
                        }
                        return IMBoyImageGallery(
                          images: galleryState.gallery,
                          pageController: ref
                              .read(imageGalleryProvider.notifier)
                              .galleryPageController!,
                          onClosePressed: () {
                            // 关闭图片画廊
                            ref
                                .read(imageGalleryProvider.notifier)
                                .onCloseGalleryPressed();
                            setState(() => _showAppBar = true);
                          },
                          options: const IMBoyImageGalleryOptions(
                            maxScale: PhotoViewComputedScale.covered,
                            minScale: PhotoViewComputedScale.contained,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // 输入状态指示器
            TypingIndicatorWidget(
              conversationUk3: _conversationUk3,
              peerId: widget.peerId,
              peerTitle: widget.peerTitle,
            ),
            // 将输入框移出 Stack，放入 Column 底部，实现消息列表与输入框的自然联动
            ChatInputHeightListener(
              composerHeight: composerHeightNotifier,
              child: _buildChatInput(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 导航到聊天设置页面
  Widget _buildChatInput(BuildContext context) {
    return ChatInput(
      key: _chatInputKey,
      composerHeight: composerHeightNotifier, // 使用可动画的高度
      type: _chatType,
      peerId: widget.peerId,
      onSendPressed: _handleSendPressed,
      onTextChanged: _handleInputChanged,
      // @提及变更回调
      onMentionsChanged: _chatType == MessageFlowType.c2g
          ? (mentionIds) {
              _currentMentionIds = mentionIds;
            }
          : null,
      // sendButtonVisibilityMode: SendButtonVisibilityMode.editing,
      voiceWidget: VoiceWidget(
        startRecord: () {},
        stopRecord: _handleVoiceSelection,
        height: 46,
        margin: EdgeInsets.zero,
      ),
      extraWidget: ExtraItems(
        type: _chatType,
        handleImageSelection: _handleImageSelection,
        handleFileSelection: _handleFileSelection,
        handlePickerSelection: _handlePickerSelection,
        handleLocationSelection: _handleLocationSelection,
        handleVisitCardSelection: _handleVisitCardSelection,
        handleCollectSelection: _handleCollectSelection,
        options: {
          "to": widget.peerId,
          "title": widget.peerTitle,
          "avatar": widget.peerAvatar,
          "sign": widget.peerSign,
        },
      ),
      quoteTipsWidget: QuoteTipsWidget(
        title:
            (quoteMessage != null &&
                quoteMessage?.authorId == UserRepoLocal.to.currentUid)
            ? UserRepoLocal.to.current.nickname
            : widget.peerTitle,
        message: quoteMessage,
        close: () => updateQuoteMessage(null),
      ),
    );
  }

  /// 构建聊天背景装饰（使用 ChatBackgroundManager）
  BoxDecoration _buildBackgroundDecoration(
    ChatBackgroundState backgroundState,
  ) {
    return ref
        .read(chatBackgroundManagerProvider.notifier)
        .getCurrentBackgroundDecoration();
  }

  /// 构建聊天主界面
  Widget _buildChatWidget(
    BuildContext context,
    ThemeData theme,
    ChatState chatState,
  ) {
    // 使用 provider 获取聊天背景状态
    final backgroundState = ref.watch(chatBackgroundManagerProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    // 使用 flutter_chat_ui 的 Chat widget
    return flutter_chat_ui.Chat(
      currentUserId: currentUser.id,
      backgroundColor: Colors.transparent,
      chatController:
          ref.read(chatProvider.notifier).chatService ??
          SqliteChatController(ref.container),
      onMessageSend: _handleSendPressed,
      onMessageLongPress: _onMessageLongPress,
      onMessageTap: _onMessageTap,
      onMessageSecondaryTap: _onMessageSecondaryTap,
      // onMessageStatusTap: _onMessageStatusTap,
      decoration: _buildBackgroundDecoration(backgroundState),
      resolveUser: (id) => Future.value(switch (id) {
        'me' => currentUser,
        'recipient' => _peerUser,
        _ => null,
      }),
      // timeFormat: DateFormat("y-MM-dd HH:mm"),
      timeFormat: RelativeDateFormat(),
      theme: ChatThemeConfig.chatTheme,
      builders: Builders(
        chatAnimatedListBuilder: (context, itemBuilder) {
          // 直接使用 chatState 而不是 Obx
          // 使用 Column 布局后，不再需要底部的 padding，联动效果更自然
          const bottomGap = 0.0;

          // 只在第一次 build 时滚动到底部（防止重复创建回调）
          if (!_hasScrolledToBottom && widget.msgId.isEmpty) {
            _hasScrolledToBottom = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // 检查 widget 是否仍然 mounted（防止页面销毁后执行）
              if (!mounted) return;
              try {
                // 再次检查 mounted，确保安全
                if (mounted) {
                  ref.read(chatProvider.notifier).chatService?.scrollToBottom();
                }
              } catch (e) {
                debugPrint('滚动到底部失败: $e');
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: bottomGap),
            child: NotificationListener<ScrollNotification>(
              onNotification: (sn) {
                if (sn is UserScrollNotification) {
                  _chatInputKey.currentState?.hideAllPanel();
                }
                return false;
              },
              child: _useOptimizedMessageList
                  ? _buildOptimizedMessageList()
                  : _buildOriginalMessageList(itemBuilder, chatState),
            ),
          );
        },
        // 输入框已移至外部 Column，这里返回空
        composerBuilder: (context) => const SizedBox.shrink(),
        // 自定义回到底部按钮（自动避让 Composer）
        scrollToBottomBuilder: (ctx, animation, onPressed) => ScrollToBottom(
          animation: animation,
          onPressed: onPressed,
          right: 16,
          bottom: 20,
          useComposerHeightForBottomOffset: false, // 已经在 Column 内部，无需额外偏移
          mini: true,
        ),
        // 自定义空态文案
        emptyChatListBuilder: (ctx) {
          if (chatState.isLoading && chatState.hasMoreMessage) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!chatState.hasMoreMessage &&
              (ref.read(chatProvider.notifier).chatService?.messages.isEmpty ??
                  true)) {
            return EmptyChatList(text: t.noData);
          }
          return const SizedBox.shrink();
        },
        customMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              // 获取当前会话的所有消息，用于图片预览时的跨消息导航
              final allMessages = ref
                  .read(chatProvider.notifier)
                  .chatService
                  ?.messages;
              return CustomMessageBuilder(
                type: _chatType,
                message: message,
                messages: allMessages,
              );
            },
        imageMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              // 用 GestureDetector 包裹，实现点击预览功能
              return GestureDetector(
                onTap: () => _previewImageMessage(message, index),
                child: FlyerChatImageMessage(
                  message: message,
                  index: index,
                  showStatus: false,
                  showTime: true,
                ),
              );
            },
        systemMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              return FlyerChatSystemMessage(message: message, index: index);
            },
        textMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              return FlyerChatTextMessage(
                message: message,
                index: index,
                showStatus: false,
                showTime: true,
              );
            },
        // 文本流消息组件（用于 AI 对话等流式输出场景）
        // 注意：当前使用简化的加载状态，完整实现需要集成 StreamStateManager
        textStreamMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              // 暂时使用加载状态显示，等待流式状态管理实现
              return FlyerChatTextStreamMessage(
                message: message,
                index: index,
                streamState: const StreamStateLoading(),
                showStatus: false,
                showTime: true,
                loadingText: '...',
              );
            },
        fileMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              return FlyerChatFileMessage(
                message: message,
                index: index,
                showStatus: false,
                showTime: true,
              );
            },
        // 视频消息组件
        videoMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              return FlyerChatVideoMessage(
                message: message,
                index: index,
                showStatus: false,
                showTime: true,
              );
            },
        // 音频消息组件 - 连接 VoicePlaybackService
        audioMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              // 监听语音播放状态
              final playbackState = ref.watch(voicePlaybackServiceProvider);

              return FlyerChatAudioMessage(
                message: message,
                index: index,
                showStatus: false,
                showTime: true,
                isPlaying:
                    playbackState.currentMessageId == message.id &&
                    playbackState.isPlaying,
                isPaused:
                    playbackState.currentMessageId == message.id &&
                    playbackState.isPaused,
                currentPositionMs: playbackState.currentMessageId == message.id
                    ? playbackState.currentPosition
                    : 0,
                currentDurationMs: playbackState.currentMessageId == message.id
                    ? playbackState.currentDuration
                    : 0,
                onPlayPause: (audioPath, msg, totalDuration) {
                  // 使用 VoicePlaybackService 统一管理播放
                  ref
                      .read(voicePlaybackServiceProvider.notifier)
                      .play(
                        path: audioPath,
                        messageId: msg.id,
                        durationMs: totalDuration.inMilliseconds,
                      );
                },
              );
            },
        chatMessageBuilder:
            (
              context,
              message,
              index,
              animation,
              child, {
              bool? isRemoved,
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              // 如果是目标消息，包裹 Key
              if (widget.msgId.isNotEmpty && message.id == widget.msgId) {
                child = Container(key: _targetMessageKey, child: child);
              }
              final isSystemMessage = message.authorId == 'system';
              final isFirstInGroup = groupStatus?.isFirst ?? true;
              final isLastInGroup = groupStatus?.isLast ?? true;
              final shouldShowAvatar =
                  !isSystemMessage && isLastInGroup && isRemoved != true;
              final isCurrentUser = message.authorId == currentUser.id;
              final shouldShowUsername =
                  !isSystemMessage && isFirstInGroup && isRemoved != true;

              Widget? statusIcon;
              switch (message.status) {
                case MessageStatus.sending:
                  statusIcon = Icon(
                    Icons.access_time,
                    size: 16,
                    color: themeNotifier.getThemeColor('textSecondary'),
                  );
                  break;
                case MessageStatus.sent:
                case MessageStatus.delivered:
                  statusIcon = Icon(
                    Icons.done_all,
                    size: 16,
                    color: themeNotifier.getThemeColor('primary'),
                  );
                  break;
                case MessageStatus.seen:
                  statusIcon = Icon(
                    Icons.done_all,
                    size: 16,
                    color: themeNotifier.getChatColor('sendMessageBg'),
                  );
                  break;
                case MessageStatus.error:
                  statusIcon = Icon(
                    Icons.error_outline,
                    size: 16,
                    color: themeNotifier.getThemeColor('error'),
                  );
                  break;
                default:
                  statusIcon = null;
              }
              Widget? avatar;
              if (shouldShowAvatar) {
                avatar = Padding(
                  padding: EdgeInsets.only(
                    left: isCurrentUser ? 8 : 0,
                    right: isCurrentUser ? 0 : 8,
                  ),
                  // 使用 flutter_chat_ui 的 Avatar 组件，它会通过 userId
                  // 自动从 UserCache 获取用户信息和头像
                  child: flutter_chat_ui.Avatar(
                    userId: message.authorId,
                    size: 40,
                  ),
                );
              } else if (!isSystemMessage) {
                avatar = const SizedBox(width: 40);
              }

              // 在消息末尾添加状态图标
              final burnBadge = _isBurnMessage(message)
                  ? BurnBadge(
                      isSentByMe: isCurrentUser,
                      burnAfterMs: _burnAfterMsFromMessage(message),
                      burnReadAtMs: (message.metadata?['burn_read_at'] is int)
                          ? message.metadata!['burn_read_at'] as int
                          : int.tryParse(
                                  '${message.metadata?['burn_read_at'] ?? 0}',
                                ) ??
                                0,
                      burnTicker: _burnTicker,
                    )
                  : null;

              Widget messageBody = burnBadge == null
                  ? child
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        child,
                        const SizedBox(height: 2),
                        Padding(
                          padding: EdgeInsets.only(
                            right: isCurrentUser ? 2 : 0,
                            left: isCurrentUser ? 0 : 2,
                          ),
                          child: burnBadge,
                        ),
                      ],
                    );

              if (isCurrentUser && statusIcon != null) {
                statusIcon = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onMessageStatusTap(context, message),
                  child: statusIcon,
                );
                child = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: messageBody),
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                );
              } else {
                child = messageBody;
              }
              final chatMsg = ChatMessage(
                message: message,
                index: index,
                animation: animation,
                isRemoved: isRemoved,
                groupStatus: groupStatus,
                topWidget: shouldShowUsername
                    ? Padding(
                        padding: EdgeInsets.only(
                          bottom: 4,
                          left: isCurrentUser ? 0 : 48,
                          right: isCurrentUser ? 48 : 0,
                        ),
                        child: Username(userId: message.authorId),
                      )
                    : null,
                leadingWidget: !isCurrentUser
                    ? avatar
                    : isSystemMessage
                    ? null
                    : const SizedBox(width: 40),
                trailingWidget: isCurrentUser
                    ? avatar
                    : isSystemMessage
                    ? null
                    : const SizedBox(width: 40),
                receivedMessageScaleAnimationAlignment:
                    (message is SystemMessage)
                    ? Alignment.center
                    : Alignment.centerLeft,
                receivedMessageAlignment: (message is SystemMessage)
                    ? AlignmentDirectional.center
                    : AlignmentDirectional.centerStart,
                horizontalPadding: (message is SystemMessage) ? 0 : 8,
                child: child,
              );
              // 可视阈值已读（受隐私设置控制）
              final s = UserRepoLocal.to.setting;
              if (!s.enableVisibilityRead) {
                return chatMsg;
              }
              final double fractionThreshold = (() {
                final v = s.visibilityReadFraction;
                if (v.isNaN) return 0.6;
                if (v < 0.1) return 0.1;
                if (v > 1.0) return 1.0;
                return v;
              })();
              final int delayMs = s.visibilityReadDelayMs <= 0
                  ? 400
                  : s.visibilityReadDelayMs;
              // 当来自对方的消息可视比例达到阈值并持续 delayMs 后推进水位
              return VisibilityDetector(
                key: Key('msg_vis_${message.id}'),
                onVisibilityChanged: (info) {
                  final fraction = info.visibleFraction;
                  // 标记当前消息是否可见（用于后续检查）
                  if (fraction > 0.1) {
                    performanceMonitor.markMessageVisible(message.id);
                  } else {
                    performanceMonitor.markMessageInvisible(message.id);
                  }

                  // 仅处理来自对方的消息
                  final isIncoming = message.authorId != currentUser.id;
                  if (!isIncoming) return;
                  // 已处理过的消息无需重复
                  if (_readCommitted.contains(message.id)) return;

                  // 达到可视阈值，启动延时判定
                  if (fraction >= fractionThreshold) {
                    _readDelayTimers[message.id]?.cancel();
                    _readDelayTimers[message.id] = Timer(
                      Duration(milliseconds: delayMs),
                      () async {
                        if (!mounted) return;
                        // 仍处于可见状态才推进水位
                        if (performanceMonitor.isMessageVisible(message.id)) {
                          try {
                            final ok = await ref
                                .read(chatProvider.notifier)
                                .markAsRead(_chatType, widget.peerId, [
                                  message.id,
                                ], syncToServer: true);
                            if (ok) {
                              _readCommitted.add(message.id);
                              if (_isBurnMessage(message) &&
                                  (message.metadata?['burn_read_at'] ?? 0) ==
                                      0) {
                                ref
                                    .read(chatProvider.notifier)
                                    .markBurnReadAt(
                                      conversation,
                                      message.id,
                                      readAtMs: DateTimeHelper.millisecond(),
                                    );
                              }
                            }
                          } catch (_) {}
                        }
                      },
                    );
                  } else {
                    // 可见比例下降，取消未完成的判定
                    _readDelayTimers[message.id]?.cancel();
                    _readDelayTimers.remove(message.id);
                  }
                },
                child: chatMsg,
              );
            },
      ),
    );
  }

  // 导航到聊天设置
  void _navigateToChatSettings() {
    final options = {
      "peer_id": widget.peerId,
      "peerAvatar": widget.peerAvatar,
      "peerTitle": widget.peerTitle,
      "peerSign": widget.peerSign,
      "conversationUk3": _conversationUk3,
    };
    final chatState = ref.read(chatProvider);

    // 使用 go_router 路由跳转
    if (_chatType == MessageFlowType.c2g) {
      // 群组聊天 - 跳转到群组详情页
      context
          .push<GroupDetailPage>(
            '/group/${widget.peerId}/detail',
            extra: {
              'groupId': widget.peerId,
              'memberCount': chatState.memberCount,
              'title': widget.peerTitle,
              'options': options,
              'callBack': (v) {},
            },
          )
          .then((value) => _handleChatSettingsResult(value));
    } else {
      // 单人聊天 - 跳转到聊天设置页
      context
          .push<ChatSettingPage>(
            '/chat_setting/${widget.peerId}',
            extra: {
              'peerId': widget.peerId,
              'type': _chatType,
              'options': options,
            },
          )
          .then((value) => _handleChatSettingsResult(value));
    }
  }

  /// 构建优化的消息列表（性能优化版）
  Widget _buildOptimizedMessageList() {
    final messages =
        ref.read(chatProvider.notifier).chatService?.messages ?? [];

    return ChatMessageList(
      messages: messages,
      currentUserId: currentUser.id,
      scrollController: ref
          .read(messageScrollManagerProvider.notifier)
          .scrollController,
      onMessageLongPress: (message) => _onMessageLongPress(
        context,
        message,
        index: 0,
        details: LongPressStartDetails(
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      ),
      onMessageDoubleTap: (message) =>
          _onMessageDoubleTap(context, message, index: 0),
      onMessageTap: (message) => _onMessageTap(
        context,
        message,
        index: 0,
        details: TapUpDetails(
          kind: PointerDeviceKind.unknown,
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      ),
    );
  }

  /// 构建原始消息列表（ChatAnimatedList）
  Widget _buildOriginalMessageList(ChatItem itemBuilder, ChatState chatState) {
    return ChatAnimatedList(
      scrollController: ref
          .read(messageScrollManagerProvider.notifier)
          .scrollController,
      reversed: true,
      itemBuilder: itemBuilder,
      onEndReached: () async {
        if (_conversationUk3.isNotEmpty &&
            !chatState.isLoading &&
            chatState.hasMoreMessage) {
          await ref.read(chatProvider.notifier).loadMoreMessages(conversation);
        }
      },
      onStartReached: () async {
        if (_conversationUk3.isNotEmpty &&
            !chatState.isLoadingNewer &&
            chatState.hasMoreMessage) {
          await ref.read(chatProvider.notifier).loadNewerMessages(conversation);
        }
      },
      messageGroupingTimeoutInSeconds: 60,
    );
  }

  // 处理聊天设置返回结果
  Future<void> _handleChatSettingsResult(dynamic value) async {
    if (value == false) {
      ref.read(chatProvider.notifier).updateNextAutoId(0);
      await ref
          .read(chatProvider.notifier)
          .loadMoreMessages(conversation, isInitial: true);
    }
    if (value == true) {
      await _reloadConversationSettings();
    }
    if (value is Map<String, dynamic>) {
      int num = value['memberCount'] ?? 0;
      if (num > 0) {
        ref.read(chatProvider.notifier).updateMemberCount(num);
        newGroupName = await ref
            .read(chatProvider.notifier)
            .groupTitle(widget.peerId, widget.peerTitle, num);
        if (mounted) setState(() {});
      }
    }
  }

  /// 显示E2EE密钥不匹配对话框
  ///
  /// 当检测到E2EE密钥不匹配时，引导用户选择解决方案
  void _showE2EEKeyMismatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('消息无法解密'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('此消息无法解密，可能原因是：'),
            SizedBox(height: 8),
            Text('• 您在其他设备上登录'),
            Text('• 设备密钥已过期'),
            Text('• 应用数据损坏'),
            SizedBox(height: 16),
            Text('请选择解决方案：'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _refreshE2EEKeys();
            },
            child: const Text('重新创建密钥（推荐）'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _relogin();
            },
            child: const Text('重新登录'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后提醒我'),
          ),
        ],
      ),
    );
  }

  /// 重新创建E2EE密钥
  Future<void> _refreshE2EEKeys() async {
    try {
      EasyLoading.showToast('正在重新创建密钥...');

      // 1. 清除E2EE缓存
      E2EEService.clearCache();

      // 2. 重新生成密钥对（RSA服务会自动处理）
      // 这里我们只需清理缓存，下次使用时会自动生成新的密钥对
      // 并上传到服务器

      // 3. 重新获取当前用户的设备密钥
      final currentUid = UserRepoLocal.to.currentUid;
      if (currentUid.isNotEmpty) {
        // 清除标记，强制重新获取
        await StorageService.to.remove('e2ee_key_refresh_time');
        await E2EEService.getUserDevicePublicKeys(currentUid);
      }

      EasyLoading.showSuccess('密钥已重新创建');
      iPrint('E2EE: 密钥已重新创建');
    } catch (e) {
      EasyLoading.showError('密钥创建失败: $e');
      iPrint('E2EE: 密钥创建失败: $e');
    }
  }

  /// 重新登录
  void _relogin() {
    EasyLoading.showToast('请重新登录');
    // 跳转到首页（由路由守卫处理未登录重定向）
    context.go('/');
  }

  /// 预览图片消息，支持左右滑动查看会话中的其他图片
  void _previewImageMessage(ImageMessage message, int currentIndex) {
    // 获取当前会话中的所有图片 URL
    final List<String> allImageUrls = _getAllImageUrlsInConversation();

    if (allImageUrls.isEmpty) {
      // 没有找到图片，不处理
      return;
    }

    if (allImageUrls.length == 1) {
      // 如果只有一张图片，使用单图预览
      zoomInPhotoView(context, message.source);
    } else {
      // 计算当前图片在所有图片中的索引
      final indexOfCurrentImage = allImageUrls.indexOf(message.source);

      // 使用多图预览功能，并跳转到当前图片
      final initialPage = indexOfCurrentImage >= 0 ? indexOfCurrentImage : 0;
      zoomInPhotoViewGalleryWithInitialPage(context, allImageUrls, initialPage);
    }
  }

  /// 获取当前会话中的所有图片 URL
  List<String> _getAllImageUrlsInConversation() {
    try {
      final List<String> imageUrls = [];
      final messages =
          ref.read(chatProvider.notifier).chatService?.messages ?? [];

      for (final msg in messages) {
        // ImageMessage 类型
        if (msg is ImageMessage) {
          final uri = msg.source;
          if (uri.isNotEmpty) {
            imageUrls.add(uri);
          }
        }
        // CustomMessage 类型 - 单图或多图
        else if (msg is CustomMessage) {
          final metadata = msg.metadata ?? {};
          final effectiveMsgType =
              metadata['effective_msg_type'] ?? metadata['msg_type'] ?? '';

          // 单图消息
          if (effectiveMsgType == 'image') {
            final uri = metadata['source'] ?? metadata['uri'] ?? '';
            if (uri.isNotEmpty) {
              imageUrls.add(uri);
            }
          }
          // 多图消息
          else if (effectiveMsgType == 'imageMulti') {
            final images = metadata['images'] as List<dynamic>?;
            if (images != null) {
              for (final img in images) {
                final uri = img['uri'] ?? '';
                if (uri.isNotEmpty) {
                  imageUrls.add(uri);
                }
              }
            }
          }
        }
      }

      return imageUrls;
    } catch (e) {
      iPrint('获取会话图片列表失败: $e');
      return [];
    }
  }
}
