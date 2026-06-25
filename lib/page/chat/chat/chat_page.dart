import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';

// Barrel exports - 减少导入语句
import 'barrel/ui_packages.dart';
import 'barrel/imboy_packages.dart';
import 'barrel/page_packages.dart';
import 'barrel/store_packages.dart';
import 'barrel/chat_widgets.dart';

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
import '../widget/message_quick_action_menu.dart';
import '../widget/typing_indicator.dart';

// 显式导入需要特殊处理的
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as flutter_chat_ui;
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/service/message_type_constants.dart';
// T4.2b: 域 MessageStatus（与 flutter_chat_core.MessageStatus 同名,用前缀避免冲突）
import 'package:imboy/modules/messaging/domain/message_status.dart'
    as domain_msg;

// CustomMessageBuilder 需要显式导入（与 flutter_chat_core 冲突）
import 'package:imboy/component/chat/message.dart' show CustomMessageBuilder;
import 'package:imboy/component/chat/mention_provider.dart'
    show mentionNotifierProvider;
import 'package:imboy/component/chat/mention_text_reducer.dart'
    show MentionTextReducer;

// 显式导入 StorageService（解决编译错误）
import 'package:imboy/service/storage.dart';

// 显式导入 E2EE 事件（barrel 用 show 白名单未含 E2EEPeerKeyChangedEvent）
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'e2ee_peer_key_warning_rule.dart';

import 'package:imboy/component/ui/avatar.dart' as imboy;

// 消息条目 Widget（从 chatMessageBuilder 闭包提取）
import 'chat_message_item.dart';

// 性能优化开关：设置为 true 使用优化的 ChatMessageList，false 使用原 ChatAnimatedList
const bool _useOptimizedMessageList = false;

// 聊天页面主Widget
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

  /// F5-A slice-4b: 当前用户在本群的角色
  /// - 0：未加载 / 非群聊 / 查无记录（decision 内核按"非 admin"安全默认处理）
  /// - 1..5：对齐后端 include/group_role.hrl
  /// 异步加载见 `_preloadCurrentUserGroupRole`；失败静默回退 0，不阻塞聊天
  int _currentUserGroupRole = 0;

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
  StreamSubscription<dynamic>? _connectivitySubscription; // 网络状态监听

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
      // 关键：在 first build 之前同步创建 chatService，让 Chat widget 通过
      // ref.read 拿到真正的 controller，而不是 fallback 的临时实例。
      // initChatService 仅赋值 notifier 内部字段，最终的 syncMessagesToState
      // 在消息为空时不改变 state，所以不会触发 Riverpod build-phase 异常。
      ref.read(chatProvider.notifier).initChatService(_chatType);
      // 会话加载、消息拉取、event listener、活动会话事件等带 context/UI 依赖的副作用
      // 仍延迟到首帧之后执行，避免 ScaffoldMessenger.of(context) 和 Provider
      // 写入在 widget tree build 期间被拒绝。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initChat();
        _initData();
        _chatNotifier.initConnectivityListener();
        _notifyChatActive(true);
      });

      // 启动内存清理定时器
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        performanceMonitor.cleanupInvisibleMessages();
        if (kDebugMode) {}
      });
    } catch (e) {
      iPrint('[chat_page] getMemoryStats error: $e');
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
    } catch (e) {
      // 显示错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.common.chatInitFailed}: $e')),
        );
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
    // 注意：_setupEventListeners 已在 _initChat 中调用，此处不再重复调用
    // 预加载E2EE设备密钥（优化加密性能）
    await _preloadE2EEDeviceKeys();
    // 预加载群成员名单，供 C1 @提及降级显示使用（fire-and-forget，不阻塞 UI）
    if (_chatType == MessageFlowType.c2g && mounted) {
      unawaited(
        ref
            .read(mentionNotifierProvider.notifier)
            .loadGroupMembers(widget.peerId),
      );
      // F5-A slice-4b: 预加载当前用户群角色，供 @所有人权限判定使用
      unawaited(_preloadCurrentUserGroupRole());
    }
  }

  /// F5-A slice-4b: 异步加载当前用户在本群的角色
  ///
  /// 失败静默回退 0 —— decision 内核 `canMentionAll(0) == false` 安全默认
  /// 拒绝 @所有人，保证不会因加载失败而错误放行。
  Future<void> _preloadCurrentUserGroupRole() async {
    try {
      final me = await GroupMemberRepo().findByUserId(
        widget.peerId,
        UserRepoLocal.to.currentUid,
      );
      if (!mounted || me == null) return;
      _currentUserGroupRole = me.role;
    } catch (e) {
      iPrint('[chat_page] GroupMemberRepo error: $e');
    }
  }

  /// 预加载E2EE设备密钥
  ///
  /// 在聊天页面初始化时预先获取对方设备的公钥，避免发送消息时等待
  Future<void> _preloadE2EEDeviceKeys() async {
    // 只在E2EE启用时预加载（本地开关或后端策略要求）
    if (!E2EESettings.isEnabled() &&
        !EncryptionModeService.current.requiresEncryption) {
      return;
    }

    try {
      if (_chatType == MessageFlowType.c2g) {
        // 群组：预加载群组成员设备密钥
        await E2EEService.getGroupDevicePublicKeys(widget.peerId);
      } else {
        // 单聊：预加载对方设备密钥
        await E2EEService.getUserDevicePublicKeys(widget.peerId);
      }
    } catch (e) {
      // 预加载失败不影响聊天，发送时会重试
    }
  }

  /// 设置会话
  Future<void> _setupConversation() async {
    bool showConversation =
        widget.options?['showConversation'] as bool? ?? true;

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
      final burnMs = parseBurnAfterMs(payload?['burn_after_ms']);
      if (burnMs != null) _burnAfterMs = burnMs;
      await _applySecureFlag();

      // 初始化附件处理器（在 _burnEnabled 和 _burnAfterMs 设置后）
      _attachmentHandler = ChatAttachmentHandler(
        peerId: widget.peerId,
        conversationUk3: _conversationUk3,
        type: _chatType,
        burnEnabled: _burnEnabled,
        burnAfterMs: _burnAfterMs,
        onMessageCreated: _addMessage,
        isMutedCheck: () => _isMuted,
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
        isMutedCheck: () => _isMuted,
      );
    } catch (e) {
      iPrint('[chat_page] block error: $e');
    }
  }

  Future<void> _applySecureFlag() async {
    try {
      await _secureChannel.invokeMethod(_burnEnabled ? 'enable' : 'disable');
    } catch (e) {
      iPrint('[chat_page] invokeMethod error: $e');
    }
  }

  // 检查消息是否为阅后即焚（使用工具类）
  bool _isBurnMessage(Message message) {
    return ChatPageUtils.isBurnMessage(message);
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
      final memberCount = (widget.options?['memberCount'] ?? 0) as int;
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
  StreamSubscription<E2EEPeerKeyChangedEvent>? _ssE2EEPeerKeyChanged;
  // 禁言事件监听
  StreamSubscription<UserMutedEvent>? _ssUserMuted;
  StreamSubscription<UserUnmutedEvent>? _ssUserUnmuted;
  // F5-A slice-4b-2: 群角色变更事件订阅（管理员变更当前用户角色时刷新 @所有人 权限）
  StreamSubscription<GroupMemberRoleEvent>? _ssGroupMemberRole;
  // slice-9c: 群成员禁言/解禁事件订阅（当前用户在群内被禁言/解禁时锁定/恢复输入框）
  StreamSubscription<GroupMemberMuteEvent>? _ssGroupMemberMute;
  StreamSubscription<GroupMemberUnmuteEvent>? _ssGroupMemberUnmute;
  Timer? _muteExpiryTimer;
  bool _isMuted = false;
  String? _muteMessage;

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
      _ssAppErrorLocal = AppEventBus.on<AppErrorEvent>().listen((error) {
        if (!mounted) return;
        if (isRelevantChatError(
          errorType: error.errorType,
          message: error.message,
        )) {
          AppLoading.showToast(error.message);
        }
      }, onError: (Object error) {});

      // 监听E2EE密钥不匹配事件，引导用户重新登录
      _ssE2EEKeyMismatch = AppEventBus.on<E2EEKeyMismatchEvent>().listen((
        event,
      ) {
        if (!mounted) return;
        _showE2EEKeyMismatchDialog();
      }, onError: (Object error) {});

      // TOFU 安全告警：对端 E2EE 密钥变更（重装/换设备）。仅当前 C2C 会话且
      // uid 匹配时提示，让用户警觉中间人风险（群聊 peerId 为群 id，天然不匹配）。
      _ssE2EEPeerKeyChanged = AppEventBus.on<E2EEPeerKeyChangedEvent>().listen((
        event,
      ) {
        if (!mounted) return;
        if (!shouldWarnPeerKeyChanged(
          isGroupChat: _chatType == MessageFlowType.c2g,
          eventUid: event.uid,
          currentPeerId: widget.peerId.toString(),
        )) {
          return;
        }
        AppLoading.showToast(t.common.e2eePeerKeyChanged);
      }, onError: (Object error) {});

      // 监听禁言事件
      _ssUserMuted = AppEventBus.on<UserMutedEvent>().listen((event) {
        if (!mounted) return;
        if (!muteEventMatchesConversation(
          eventConversationId: event.conversationId,
          currentConversationId: _conversationUk3,
        )) {
          return;
        }
        _applyMuteState(event);
      }, onError: (Object error) {});

      _ssUserUnmuted = AppEventBus.on<UserUnmutedEvent>().listen((event) {
        if (!mounted) return;
        if (!muteEventMatchesConversation(
          eventConversationId: event.conversationId,
          currentConversationId: _conversationUk3,
        )) {
          return;
        }
        _clearMuteState();
      }, onError: (Object error) {});

      // F5-A slice-4b-2: 订阅群成员角色变更，实时刷新 @所有人 权限
      // 只响应"本群 + 当前用户"的变更，其他群成员改角色与本页无关
      if (_chatType == MessageFlowType.c2g) {
        _ssGroupMemberRole = AppEventBus.on<GroupMemberRoleEvent>().listen((
          event,
        ) {
          if (!mounted) return;
          if (event.gid.toString() != widget.peerId) return;
          if (event.userId.toString() != UserRepoLocal.to.currentUid) return;
          _currentUserGroupRole = event.role;
        }, onError: (Object error) {});

        // slice-9c: 当前用户在群内被禁言/解禁时实时锁定/恢复输入框
        final currentUid = UserRepoLocal.to.currentUid;
        _ssGroupMemberMute = AppEventBus.on<GroupMemberMuteEvent>().listen((
          event,
        ) {
          if (!mounted) return;
          if (event.gid.toString() != widget.peerId) return;
          if (event.userId != currentUid) return;
          _applyGroupMemberMuteState(event);
        }, onError: (Object error) {});

        _ssGroupMemberUnmute = AppEventBus.on<GroupMemberUnmuteEvent>().listen((
          event,
        ) {
          if (!mounted) return;
          if (event.gid.toString() != widget.peerId) return;
          if (event.userId != currentUid) return;
          _clearMuteState();
        }, onError: (Object error) {});
      }
    } catch (e) {
      iPrint('[chat_page] _clearMuteState error: $e');
    }
  }

  /// 群成员被禁言时（通过 GroupMemberMuteEvent）更新输入框禁用状态。
  ///
  /// 仅在当前用户是被禁言方时调用（call-site 已过滤）。
  void _applyGroupMemberMuteState(GroupMemberMuteEvent event) {
    _muteExpiryTimer?.cancel();
    setState(() {
      _isMuted = true;
      // remainingSeconds 由后端计算；转分钟（向上取整）
      final minutes = (event.remainingSeconds / 60).ceil();
      if (minutes > 0) {
        _muteMessage = t.chat.youAreMutedWithTime(minutes: '$minutes');
        final remaining =
            event.muteUntilMs - DateTime.now().millisecondsSinceEpoch;
        if (remaining > 0) {
          _muteExpiryTimer = Timer(Duration(milliseconds: remaining), () {
            if (mounted) _clearMuteState();
          });
        }
      } else {
        _muteMessage = t.chat.youAreMuted;
      }
    });
  }

  /// 应用禁言状态
  void _applyMuteState(UserMutedEvent event) {
    _muteExpiryTimer?.cancel();

    if (!event.isMuted) {
      _clearMuteState();
      return;
    }

    setState(() {
      _isMuted = true;
      final minutes = event.remainingMinutes;
      if (minutes > 0) {
        _muteMessage = t.chat.youAreMutedWithTime(minutes: '$minutes');
        // 设置定时器在禁言到期时自动解除
        final remaining =
            event.muteUntilMs - DateTime.now().millisecondsSinceEpoch;
        _muteExpiryTimer = Timer(Duration(milliseconds: remaining), () {
          if (mounted) _clearMuteState();
        });
      } else {
        _muteMessage = t.chat.youAreMuted;
      }
    });
  }

  /// 清除禁言状态
  void _clearMuteState() {
    _muteExpiryTimer?.cancel();
    _muteExpiryTimer = null;
    if (_isMuted && mounted) {
      setState(() {
        _isMuted = false;
        _muteMessage = null;
      });
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
    _ssE2EEPeerKeyChanged?.cancel();

    // 取消禁言事件监听
    _ssUserMuted?.cancel();
    _ssUserUnmuted?.cancel();
    _ssGroupMemberRole?.cancel();
    _ssGroupMemberMute?.cancel();
    _ssGroupMemberUnmute?.cancel();
    _muteExpiryTimer?.cancel();

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
    } catch (e) {
      iPrint('[chat_page] invokeMethod error: $e');
    }

    super.dispose();
  }

  /// 发送活动会话事件（用于未读数管理）
  void _notifyChatActive(bool isActive) {
    // 检查 widget 是否仍然 mounted（在 dispose 中调用时可能已 unmounted）
    if (!mounted) {
      return;
    }

    try {
      final conversationUk3 = _conversationUk3;
      if (conversationUk3.isEmpty) {
        return;
      }

      // 使用 Riverpod Provider 管理活跃会话状态
      if (isActive) {
        ref
            .read(activeConversationProvider.notifier)
            .setActiveConversation(conversationUk3);

        // 移除进入聊天页面瞬间全量清空未读数的逻辑
        // 改为依赖 VisibilityDetector 的渐进式水位推进。
        // 未读数应当在用户切实“滚动并看到”新消息时，被 _readDelayTimers 逐步消化。
        // _clearUnreadOnEnter();
      } else {
        ref.read(activeConversationProvider.notifier).clearActiveConversation();
      }
    } catch (e) {
      iPrint('[chat_page] read error: $e');
    }
  }

  // 移除了 _clearUnreadOnEnter()，依靠消息本身的可见性检查来渐进式消除未读数

  // 滚动到目标消息
  Future<void> _scrollToTargetMessage() async {
    if (widget.msgId.isEmpty) return;

    try {
      // 确保消息列表已加载
      final messages =
          ref.read(chatProvider.notifier).chatService?.messages ?? [];
      if (messages.isEmpty) {
        return;
      }

      // 查找目标消息在列表中的索引
      final targetIndex = messages.indexWhere((m) => m.id == widget.msgId);
      if (targetIndex == -1) {
        return;
      }

      // 增加重试次数和间隔，确保在复杂布局或低端机上也能成功定位
      for (var attempt = 0; attempt < 15; attempt++) {
        // 检查 widget 是否仍然 mounted
        if (!mounted) {
          return;
        }

        // 渐进式等待
        await Future<dynamic>.delayed(
          Duration(milliseconds: attempt < 3 ? 100 : 300),
        );

        if (!mounted) return;

        // 尝试触发滚动
        await ref
            .read(chatProvider.notifier)
            .chatService
            ?.scrollToMessage(
              widget.msgId,
              duration: const Duration(milliseconds: 500),
              offset: 120.0, // 增加偏移量，避开 AppBar
            );

        // 检查目标消息是否已挂载到视图树中
        if (_targetMessageKey.currentContext != null) {
          break;
        }
      }

      // 无论是否成功通过 Key 定位，最后都尝试高亮（如果消息在列表中）
      if (mounted) {
        ref
            .read(messageScrollManagerProvider.notifier)
            .highlightMessage(widget.msgId);
      }
    } catch (e) {
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
      // 假设平均消息高度为100像素（带头像和间距的消息通常更高）
      double estimatedOffset = targetIndex * 100.0;

      final scrollController = ref
          .read(messageScrollManagerProvider.notifier)
          .scrollController;
      if (scrollController.hasClients) {
        final maxScroll = scrollController.position.maxScrollExtent;
        final targetPosition = estimatedOffset.clamp(0.0, maxScroll);

        scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      iPrint('[chat_page] Duration error: $e');
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
    } catch (e) {
      return false;
    }
  }

  /// 消息重试回调
  /// Message retry callback.
  Future<void> _onMessageRetry(String messageId) async {
    try {
      // 显示加载状态
      AppLoading.show(status: t.common.retryingSend);

      final success = await ref
          .read(chatProvider.notifier)
          .retryMessage(messageId, _chatType);

      AppLoading.dismiss();

      if (success) {
        AppLoading.showSuccess(t.common.retrySuccess);
      } else {
        AppLoading.showError(t.common.retryFailedPleaseCheckNetwork);
      }
    } catch (e) {
      AppLoading.dismiss();
      AppLoading.showError('${t.common.retryAbnormal}: $e');
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
    if (result != null && context.mounted) {
      await _attachmentHandler.sendVisitCardMessage(
        context,
        result.peerId.toString(),
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

    // 打开收藏页面（选择模式）
    final result = await Navigator.push<UserCollectModel>(
      context,
      CupertinoPageRoute<UserCollectModel>(
        builder: (context) => UserCollectPage(isSelect: true, peer: peer),
      ),
    );

    // 如果用户选择了收藏消息，发送它
    if (result != null && context.mounted) {
      try {
        await _attachmentHandler.sendCollectMessage(context, result.info);
      } catch (e) {
        if (mounted) {
          AppLoading.showError(t.common.operationFailedAgainLater);
        }
      }
    }
  }

  /// 处理贴图选择
  Future<void> _handleStickerSelection() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StickerPicker(
        onStickerSelected: (sticker) async {
          Navigator.of(context).pop();
          await _attachmentHandler.sendExpressionMessage(
            context,
            sticker.url,
            sticker.text,
          );
        },
      ),
    );
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
      String txt = message.metadata?['quote_text'] as String? ?? '';
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

    // E2EE 解密失败的「[加密消息]」气泡：点击引导用户前往密钥恢复中心，
    // 接通设备转移 / 社交恢复 / 本地备份导入，避免撞墙后无引导的死胡同。
    if (message.metadata?['_e2ee_failed'] == true) {
      showE2EERecoveryGuide(context, scene: E2EERecoveryScene.decryptFailed);
      return;
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

    // slice-C-2: 决策内核已抽到 typing_indicator_rules.dart 并有 12 个单测钉死,
    // 这里只保留 Timer/WebSocket 的 IO 组装。
    final decision = decideTypingIndicator(
      text: text,
      lastSentAt: _lastTypingSendTime,
      now: DateTime.now(),
    );

    switch (decision) {
      case TypingStopImmediately():
        _sendTypingStatus(TypingStatus.stop);
        return;
      case TypingStartAndResetIdle(:final newLastSentAt):
        _sendTypingStatus(TypingStatus.start);
        _lastTypingSendTime = newLastSentAt;
      case TypingResetIdleOnly():
        // 节流窗口内,不重发 start,但仍需刷新 idle 定时器
        break;
    }

    // 5 秒无输入则自动 stop
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
      chatType: _chatType,
      status: status,
    );
  }

  // 发送文本消息
  Future<bool> _handleSendPressed(String text) async {
    iPrint(
      'handleSendPressed 开始: text=$text, _editingMessageId=$_editingMessageId',
    );

    // slice-C-3a: 决策内核已抽到 send_mode_rules.dart 并有 14 个单测钉死优先级
    // (muted > debounce > edit > quote > new)。这里只保留 i18n toast / IO 副作用。
    final decision = decideSendMode(
      isMuted: _isMuted,
      now: DateTime.now(),
      lastSendTime: _lastSendTime,
      debounce: _sendDebounceDuration,
      editingMessageId: _editingMessageId,
      hasQuoteMessage: quoteMessage != null,
    );

    switch (decision) {
      case SendDenyMuted():
        AppLoading.showInfo(t.common.mutedCannotSend);
        return false;
      case SendDenyDebounced():
        iPrint('消息发送防抖触发：距离上次发送不足 ${_sendDebounceDuration.inMilliseconds}ms');
        return false;
      case SendAsEdit(:final messageId):
        iPrint('执行编辑消息: messageId=$messageId, newContent=$text');
        final result = await MessagingFacade.instance.sendEditMessage(
          messageId,
          _chatType,
          text,
        );
        iPrint('编辑消息结果: $result');
        _editingMessageId = null;
        return result;
      case SendAsNewText():
        iPrint(t.chat.sendNewMessage);
        final result = await _sendTextMessage(text);
        if (result) {
          _lastSendTime = DateTime.now();
        }
        return result;
      case SendAsQuote():
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

    // F5-A slice-4a/4b/4c: mentions 决策闸门
    // - slice-4c: 从 _currentMentionIds 中提取 'all' 字面量信号
    //   （chat_input.dart:425 对 @所有人注入 'all'，对齐后端 mention_ds.erl）
    // - DeniedAll：非 admin 尝试 @所有人 → toast 提示 + 阻塞发送
    if (_chatType == MessageFlowType.c2g) {
      final split = splitMentionIds(_currentMentionIds);
      final resolve = resolveMentionsForSend(
        isGroupChat: true,
        role: _currentUserGroupRole,
        uids: split.uids,
        isAllSelected: split.isAllSelected,
      );
      switch (resolve) {
        case MentionResolveOk(:final mentions):
          metadata['mentions'] = mentions;
        case MentionResolveEmpty():
          break;
        case MentionResolveDeniedAll():
          AppLoading.showToast(t.mention.mentionAllDenied);
          _currentMentionIds = [];
          return false;
      }
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
    final quoteMsgAuthorName = resolveQuoteAuthorName(
      quoteAuthorId: quoteMessage!.authorId,
      currentUid: UserRepoLocal.to.currentUid,
      myNickname: UserRepoLocal.to.current.nickname,
      peerTitle: widget.peerTitle,
    );
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
    final caps = resolveLongPressCapabilities(
      messageAuthorId: message.authorId,
      currentUid: UserRepoLocal.to.currentUid,
      // 边界映射: flutter_chat_core.MessageStatus → 域 MessageStatus(T4.2b)
      messageStatus: switch (message.status) {
        MessageStatus.error => domain_msg.MessageStatus.error,
        MessageStatus.sending => domain_msg.MessageStatus.sending,
        MessageStatus.delivered => domain_msg.MessageStatus.delivered,
        MessageStatus.seen => domain_msg.MessageStatus.seen,
        MessageStatus.sent || null => domain_msg.MessageStatus.sent,
      },
    );
    final canEdit = canEditMessage(message);

    showMessageActionMenu(
      context: c1,
      message: message,
      isSentByMe: caps.isSentByMe,
      canEdit: canEdit,
      onReply: () => updateQuoteMessage(message),
      onCopy: () {
        if (message is TextMessage) {
          copyMessageText(message);
        } else if (message is CustomMessage &&
            message.metadata?['msg_type'] == MessageType.quote) {
          // 引用消息的复制功能
          final quoteText = (message.metadata?['quote_text'] ?? '') as String;
          if (quoteText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: quoteText));
            AppLoading.showToast(t.main.copied);
          }
        }
      },
      onEdit: () => editMessage(message),
      onDelete: () => deleteMessageForMe(context, message, pop: false),
      onDeleteForEveryone: caps.canDeleteForEveryone
          ? () => deleteMessageForEveryone(context, message)
          : null,
      onForward: () => forwardMessage(message),
      onReaction: (emoji) => addReaction(message, emoji),
      onRevoke: caps.canRevoke ? () => revokeMessage(message) : null,
      onSave: canSaveMessage(message)
          ? () => saveMessageContent(message)
          : null,
      onCollect: canCollectMessage(message)
          ? () => collectMessage(message)
          : null,
      onRetry: caps.canRetry ? () => _onMessageRetry(message.id) : null,
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
          await Future<dynamic>.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          navigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 禁用系统自动避让，改为手动控制高度以避免抖动
        appBar: _showAppBar
            ? GlassAppBar(
                titleWidget: Row(
                  children: [
                    if (widget.peerAvatar.isNotEmpty) ...[
                      Hero(
                        tag: 'avatar_${widget.peerId}',
                        child: widget.type == 'C2G'
                            ? imboy.SmartGroupAvatar(
                                groupId: widget.peerId,
                                avatar: widget.peerAvatar,
                                size: 36,
                              )
                            : imboy.Avatar(
                                imgUri: widget.peerAvatar,
                                width: 36,
                                height: 36,
                              ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        newGroupName.isEmpty ? widget.peerTitle : newGroupName,
                        style: TextStyle(
                          color: themeNotifier.getThemeColor('textPrimary'),
                          fontSize: themeNotifier.getFontSize(
                            FontSizeType.title,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
            ChatInputHeightListener(
              composerHeight: composerHeightNotifier,
              child: ChatInput(
                key: _chatInputKey,
                composerHeight: composerHeightNotifier,
                type: _chatType,
                peerId: widget.peerId,
                onSendPressed: _handleSendPressed,
                onTextChanged: _handleInputChanged,
                isMuted: _isMuted,
                muteMessage: _muteMessage,
                onMentionsChanged: _chatType == MessageFlowType.c2g
                    ? (mentionIds) {
                        _currentMentionIds = mentionIds;
                      }
                    : null,
                voiceWidget: VoiceWidget(
                  startRecord: () {},
                  stopRecord: _handleVoiceSelection,
                  onConvertToText: (text) {
                    _handleSendPressed(text);
                  },
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
                  handleStickerSelection: _handleStickerSelection,
                  handleRedPacketSelection: handleRedPacketSelection,
                  handleTransferSelection: handleTransferSelection,
                  options: {
                    "to": widget.peerId,
                    "title": widget.peerTitle,
                    "avatar": widget.peerAvatar,
                    "sign": widget.peerSign,
                  },
                ),
                quoteTipsWidget: QuoteTipsWidget(
                  title: resolveQuoteAuthorName(
                    quoteAuthorId: quoteMessage?.authorId,
                    currentUid: UserRepoLocal.to.currentUid,
                    myNickname: UserRepoLocal.to.current.nickname,
                    peerTitle: widget.peerTitle,
                  ),
                  message: quoteMessage,
                  close: () => updateQuoteMessage(null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建聊天主界面
  Widget _buildChatWidget(
    BuildContext context,
    ThemeData theme,
    ChatState chatState,
  ) {
    // 使用 flutter_chat_ui 的 Chat widget
    // 注意：flutter_chat_ui 内部通过 `Provider.value(value: widget.chatController)` 把
    // controller 注入子 widget，chat_animated_list 在 initState 时 `context.read` 一次性
    // 拿到 controller 并订阅 operationsStream。Provider.value 在引用变化时不会让
    // 已建立的订阅刷新。所以：
    //   1. chatService 必须在 ChatPage initState 中同步初始化（已在 initState 处理）；
    //   2. 这里直接使用真实 chatService，不再 fallback 到新建 SqliteChatController，
    //      否则 chat_animated_list 会订阅 fallback 实例的 stream，真实 chatService
    //      插入的消息永远不会进入 UI。
    final activeController = ref.read(chatProvider.notifier).chatService;
    assert(
      activeController != null,
      'ChatService must be initialized synchronously in initState',
    );
    return flutter_chat_ui.Chat(
      currentUserId: currentUser.id,
      backgroundColor: Colors.transparent,
      chatController: activeController!,
      onMessageSend: _handleSendPressed,
      onMessageLongPress: _onMessageLongPress,
      onMessageTap: _onMessageTap,
      onMessageSecondaryTap: _onMessageSecondaryTap,
      // onMessageStatusTap: _onMessageStatusTap,
      decoration: ref
          .read(chatBackgroundManagerProvider.notifier)
          .getCurrentBackgroundDecoration(),
      resolveUser: (id) => Future.value(switch (id) {
        'me' => currentUser,
        'recipient' => _peerUser,
        _ => null,
      }),
      // timeFormat: DateFormat("y-MM-dd HH:mm"),
      timeFormat: RelativeDateFormat(),
      theme: ChatThemeConfig.chatTheme,
      builders: _buildMessageBuilders(context, chatState),
    );
  }

  /// 构建所有消息类型的 Builders 配置。
  ///
  /// 从 [_buildChatWidget] 提取，减少单方法行数。
  Builders _buildMessageBuilders(BuildContext context, ChatState chatState) {
    return Builders(
      chatAnimatedListBuilder: (context, itemBuilder) {
        if (!_hasScrolledToBottom && widget.msgId.isEmpty) {
          _hasScrolledToBottom = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              ref.read(chatProvider.notifier).chatService?.scrollToBottom();
            } catch (e) {
              // 滚动失败静默忽略
            }
          });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (sn) {
            if (sn is UserScrollNotification) {
              _chatInputKey.currentState?.hideAllPanel();
            }
            return false;
          },
          child: _useOptimizedMessageList
              ? ChatMessageList(
                  messages:
                      ref.read(chatProvider.notifier).chatService?.messages ??
                      [],
                  currentUserId: currentUser.id,
                  scrollController: ref
                      .read(messageScrollManagerProvider.notifier)
                      .scrollController,
                  targetMsgId: widget.msgId,
                  targetMessageKey: _targetMessageKey,
                  onMessageLongPress: (msg) => _onMessageLongPress(
                    context,
                    msg,
                    index: 0,
                    details: LongPressStartDetails(
                      globalPosition: Offset.zero,
                      localPosition: Offset.zero,
                    ),
                  ),
                  onMessageDoubleTap: (msg) =>
                      _onMessageDoubleTap(context, msg, index: 0),
                  onMessageTap: (msg) => _onMessageTap(
                    context,
                    msg,
                    index: 0,
                    details: TapUpDetails(
                      kind: PointerDeviceKind.unknown,
                      globalPosition: Offset.zero,
                      localPosition: Offset.zero,
                    ),
                  ),
                )
              : ChatAnimatedList(
                  scrollController: ref
                      .read(messageScrollManagerProvider.notifier)
                      .scrollController,
                  reversed: true,
                  itemBuilder: itemBuilder,
                  onEndReached: () async {
                    if (_conversationUk3.isNotEmpty &&
                        !chatState.isLoading &&
                        chatState.hasMoreMessage) {
                      await ref
                          .read(chatProvider.notifier)
                          .loadMoreMessages(conversation);
                    }
                  },
                  onStartReached: () async {
                    if (_conversationUk3.isNotEmpty &&
                        !chatState.isLoadingNewer &&
                        chatState.hasMoreMessage) {
                      await ref
                          .read(chatProvider.notifier)
                          .loadNewerMessages(conversation);
                    }
                  },
                  messageGroupingTimeoutInSeconds: 60,
                ),
        );
      },
      composerBuilder: (context) => const SizedBox.shrink(),
      scrollToBottomBuilder: (ctx, animation, onPressed) => ScrollToBottom(
        animation: animation,
        onPressed: onPressed,
        right: 16,
        bottom: 20,
        useComposerHeightForBottomOffset: false,
        mini: true,
      ),
      emptyChatListBuilder: (ctx) {
        if (chatState.isLoading && chatState.hasMoreMessage) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!chatState.hasMoreMessage &&
            (ref.read(chatProvider.notifier).chatService?.messages.isEmpty ??
                true)) {
          return EmptyChatList(text: t.common.noData);
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
            return GestureDetector(
              onTap: () => _previewImageMessage(message, index),
              child: FlyerChatImageMessage(
                message: message,
                index: index,
                showStatus: false,
                showTime: true,
                // ponytail: message.source 是 Garage object_key（非 URL），
                // 必须走 cachedImageProvider → IMBoyCachedImageProvider → viewUrl 授权；
                // 否则 FlyerChatImageMessage 默认用 CachedNetworkImage 直传 object_key，
                // cross_cache 无法识别 scheme → "Invalid source: cannot be processed"。
                customImageProvider: cachedImageProvider(message.source),
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
            // C1 Z 路径：用群当前活跃成员名集合对消息文本做降级投影。
            // 被 @ 用户已退群 → `~~@已退群成员~~`（GptMarkdown 渲染删除线）。
            final activeNames = ref
                .watch(mentionNotifierProvider)
                .userIdToName
                .values
                .toSet();
            final projected = MentionTextReducer.applyTo(message, activeNames);
            return FlyerChatTextMessage(
              message: projected,
              index: index,
              showStatus: false,
              showTime: true,
            );
          },
      textStreamMessageBuilder:
          (
            context,
            message,
            index, {
            required bool isSentByMe,
            MessageGroupStatus? groupStatus,
          }) {
            final streamStateMap = ref.watch(chatStreamStateNotifierProvider);
            final streamState =
                streamStateMap[message.id] ?? const StreamStateLoading();
            return FlyerChatTextStreamMessage(
              message: message,
              index: index,
              streamState: streamState,
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
      audioMessageBuilder:
          (
            context,
            message,
            index, {
            required bool isSentByMe,
            MessageGroupStatus? groupStatus,
          }) {
            final playbackState = ref.watch(voicePlaybackServiceProvider);
            bool isThis(String id) => playbackState.currentMessageId == id;
            return FlyerChatAudioMessage(
              message: message,
              index: index,
              showStatus: false,
              showTime: true,
              isPlaying: isThis(message.id) && playbackState.isPlaying,
              isPaused: isThis(message.id) && playbackState.isPaused,
              currentPositionMs: isThis(message.id)
                  ? playbackState.currentPosition
                  : 0,
              currentDurationMs: isThis(message.id)
                  ? playbackState.currentDuration
                  : 0,
              onPlayPause: (audioPath, msg, totalDuration) {
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
            return ChatMessageItem(
              message: message,
              index: index,
              animation: animation,
              currentUser: currentUser,
              targetMsgId: widget.msgId,
              targetMessageKey: _targetMessageKey,
              burnTicker: _burnTicker,
              performanceMonitor: performanceMonitor,
              readDelayTimers: _readDelayTimers,
              readCommitted: _readCommitted,
              onMessageStatusTap: _onMessageStatusTap,
              onVisibleRead: _onVisibleRead,
              isRemoved: isRemoved,
              groupStatus: groupStatus,
              child: child,
            );
          },
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
      "encryption_mode": EncryptionModeService.current.toApiString(),
    };
    final chatState = ref.read(chatProvider);

    // 使用 go_router 路由跳转
    if (_chatType == MessageFlowType.c2g) {
      // 群组聊天 - 跳转到群组详情页
      // 注意：注册路由是 `/group/detail/:groupId`（顺序不能颠倒为 /group/{id}/detail）
      context
          .push<GroupDetailPage>(
            '/group/detail/${widget.peerId}',
            extra: {
              'groupId': widget.peerId,
              'memberCount': chatState.memberCount,
              'title': widget.peerTitle,
              'options': options,
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

  /// 可视阈值已读：标记消息为已读并处理阅后即焚水位。
  ///
  /// 由 [ChatMessageItem.onVisibleRead] 回调触发，仅在消息持续可见超过
  /// 设定延迟后执行。
  Future<void> _onVisibleRead(Message message) async {
    if (!mounted) return;
    try {
      final ok = await ref.read(chatProvider.notifier).markAsRead(
        _chatType,
        widget.peerId,
        [message.id],
        syncToServer: true,
      );
      if (ok) {
        _readCommitted.add(message.id);
        if (_isBurnMessage(message) &&
            (message.metadata?['burn_read_at'] ?? 0) == 0) {
          ref
              .read(chatProvider.notifier)
              .markBurnReadAt(
                conversation,
                message.id,
                readAtMs: DateTimeHelper.millisecond(),
              );
        }
      }
    } catch (e) {
      // 读取失败静默忽略
    }
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
      int num = value['memberCount'] as int? ?? 0;
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.iosOrange),
            AppSpacing.horizontalMedium,
            Text(t.common.e2eeDecryptFailed),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.e2eeDecryptFailedReasons),
            AppSpacing.verticalSmall,
            Text(t.common.e2eeDecryptReasonOtherDevice),
            Text(t.common.e2eeDecryptReasonKeyExpired),
            Text(t.common.e2eeDecryptReasonDataCorrupt),
            AppSpacing.verticalRegular,
            Text(t.common.e2eeDecryptRecreateHint),
            AppSpacing.verticalRegular,
            Text(t.common.e2eeDecryptChooseSolution),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _refreshE2EEKeys();
            },
            child: Text(t.common.e2eeDecryptActionRecreateKey),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _relogin();
            },
            child: Text(t.common.e2eeDecryptActionRelogin),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.e2eeDecryptActionRemindLater),
          ),
        ],
      ),
    );
  }

  /// 重新创建 E2EE 密钥
  ///
  /// BUG-05 修复：旧实现仅清缓存 + 拉取本人**已有**公钥，并未真正重建密钥对，
  /// 却无条件弹出成功提示（欺骗性 UX）。现改为真正重新生成密钥对并上报新公钥。
  /// 旧私钥按 kid 归档（storage_secure C2 机制），历史密文不会因此丢失。
  Future<void> _refreshE2EEKeys() async {
    try {
      AppLoading.show(status: t.chat.e2eeRecreatingKey);

      // 1. 真正重新生成密钥对并上报新公钥到服务端
      final ok = await E2EEKeyService.regenerateAndReportDeviceKey();
      if (!ok) {
        AppLoading.showError(
          t.common.e2eeKeyRecreationFailed(error: 'report_failed'),
        );
        iPrint('E2EE: 密钥重建或上报失败');
        return;
      }

      // 2. 清本机内存公钥缓存，强制下次重新拉取对端最新公钥
      E2EEService.clearCache();
      await StorageService.to.remove('e2ee_key_refresh_time');

      AppLoading.showSuccess(t.chat.e2eeKeyRecreated);
      iPrint('E2EE: 密钥已重新创建并上报');
    } on Exception catch (e) {
      AppLoading.showError(
        t.common.e2eeKeyRecreationFailed(error: e.toString()),
      );
      iPrint('E2EE: 密钥创建失败: $e');
    }
  }

  /// 重新登录
  void _relogin() {
    AppLoading.showToast(t.account.pleaseRelogin);
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
      // 使用多图预览功能，并跳转到当前图片
      final initialPage = resolveInitialImagePage(allImageUrls, message.source);
      zoomInPhotoViewGalleryWithInitialPage(context, allImageUrls, initialPage);
    }
  }

  /// 获取当前会话中的所有图片 URL
  List<String> _getAllImageUrlsInConversation() {
    try {
      final messages =
          ref.read(chatProvider.notifier).chatService?.messages ?? [];
      return extractImageUrlsFromMessages(messages);
    } catch (e) {
      iPrint('获取会话图片列表失败: $e');
      return [];
    }
  }
}
