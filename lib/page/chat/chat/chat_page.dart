import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/page/chat/widget/chat_input_height_listener.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';
import 'package:imboy/page/chat/widget/chat_background_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as flutter_chat_ui;
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show
        ChatMessage,
        Avatar,
        Username,
        ScrollToBottom,
        EmptyChatList,
        ChatAnimatedList;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flyer_chat_audio_message/flyer_chat_audio_message.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_system_message/flyer_chat_system_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:flyer_chat_video_message/flyer_chat_video_message.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/config/chat_theme_config.dart';
import 'package:image/image.dart' as img;
import 'package:map_launcher/map_launcher.dart';
import 'package:mime/mime.dart';
import 'package:photo_view/photo_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/chat/message.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/component/chat/performance_monitor.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/page/mine/user_collect/user_collect_page.dart';
import 'package:imboy/page/mine/user_collect/user_collect_provider.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
// import 'package:imboy/page/chat/chat/chat_logic.dart'; // 已删除
import 'package:imboy/service/active_conversation_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as old_provider;

import '../../../component/helper/picker_method.dart' show PickMethod;
import '../widget/chat_input.dart';
import '../widget/extra_item.dart';
import '../widget/quote_tips.dart';
import '../widget/select_friend.dart';
// import 'chat_logic.dart'; // 已删除 - 使用 Riverpod Provider 替代
import 'chat_provider.dart';
import 'sqlite_chat_controller.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

// 性能优化开关：设置为 true 使用优化的 ChatMessageList，false 使用原 ChatAnimatedList
const bool _useOptimizedMessageList = true;

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

class ChatPageState extends ConsumerState<ChatPage> {
  // 使用 Riverpod Provider 替代 GetX
  // state 已移除 - 在 build 方法中通过 ref.watch(chatProvider) 获取

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
  final GlobalKey<ChatInputState> chatInputKey = GlobalKey<ChatInputState>();
  final performanceMonitor = ChatPerformanceMonitor();
  late final ValueNotifier<double> composerHeightNotifier;
  Timer? _cleanupTimer;
  // 可视阈值已读：延迟计时与去重集合
  final Map<String, Timer> _readDelayTimers = {};
  final Set<String> _readCommitted = {};
  // 消息ID集合，用于防止 eventBus 重复渲染消息
  final Set<String> msgIds = {};
  final User currentUser = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );
  late ConversationModel conversation; // 当前会话
  late User peer; // 对方用户信息
  String? _editingMessageId; // 当前正在编辑的消息ID
  bool _burnEnabled = false;
  int _burnAfterMs = 30000;
  // StreamSubscription<ConnectivityResult>? _connectivitySubscription; // 网络状态监听

  // 用于定位目标消息的 GlobalKey
  final GlobalKey _targetMessageKey = GlobalKey();

  // 保存 ChatNotifier 引用，用于在 dispose 中安全访问
  late final ChatNotifier _chatNotifier;

  // ===== 便利访问器（替代 UIEventHandlerMixinState 接口） =====

  // 获取消息滚动管理器（兼容旧代码）
  MessageScrollManager get messageScrollNotifier =>
      ref.read(messageScrollManagerProvider.notifier);

  // 安全获取 conversationUk3
  // 避免 LateInitializationError：优先从 widget.options 获取，否则从已初始化的 conversation 获取
  String get _conversationUk3 {
    // 优先从 widget.options 获取（如果页面是通过路由参数传过来的）
    return widget.options?['conversationUk3'] ??
        // 如果 conversation 已初始化，直接使用
        (_isConversationInitialized ? conversation.uk3 : null) ??
        // 否则根据 type、peerId 和 currentUid 动态构造
        (widget.type == 'C2C' || widget.type == 'C2G' || widget.type == 'C2S'
            ? '${widget.type}_${widget.peerId}_${UserRepoLocal.to.currentUid}'
            : '');
  }

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

      // 发送活动会话事件（用于未读数管理）
      _notifyChatActive(true);

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

    // 注意：ref.listen 必须在 build 方法中调用，不能在 initState 中调用
    // 状态监听已移至 build 方法中的 ref.watch
  }

  // 检查消息是否可以编辑
  bool canEditMessage(Message message) {
    if (message.authorId != UserRepoLocal.to.currentUid) return false;
    if (message is! TextMessage) return false;
    final nowMs = DateTimeHelper.millisecond();
    final messageTimeMs = message.createdAt?.millisecondsSinceEpoch ?? nowMs;
    final timeDiffMs = nowMs - messageTimeMs;
    return timeDiffMs < 15 * 60 * 1000; // 15分钟内可编辑
  }

  /// 初始化聊天相关数据
  Future<void> _initChat() async {
    try {
      // 获取 ChatLogic 实例
      // logic 已移除 - 使用 Riverpod Provider

      ref.read(chatProvider.notifier).initChatService(widget.type);
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
    peer = User(
      id: widget.peerId,
      name: widget.peerTitle,
      imageSource: widget.peerAvatar,
    );
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        // 更新 Riverpod Provider 中的 connected 状态
        ref.read(chatProvider.notifier).updateConnected(false);
      } else {
        ref.read(chatProvider.notifier).updateConnected(true);
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
  }

  /// 设置会话
  Future<void> _setupConversation() async {
    bool showConversation = widget.options?['showConversation'] ?? true;

    final conversationResult = await ref
        .read(conversationProvider.notifier)
        .createConversation(
          type: widget.type,
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
      final c = await ConversationRepo().findByPeerId(
        widget.type,
        widget.peerId,
      );
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
    } catch (_) {}
  }

  Future<void> _applySecureFlag() async {
    try {
      await _secureChannel.invokeMethod(_burnEnabled ? 'enable' : 'disable');
    } catch (_) {}
  }

  bool _isBurnMessage(Message message) {
    final m = message.metadata;
    return m?['burn'] == true || m?['is_burn'] == true;
  }

  int _burnAfterMsFromMessage(Message message) {
    final m = message.metadata;
    final raw = m?['burn_after_ms'] ?? m?['expiry_time'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Map<String, dynamic> _withBurnMetadata(Map<String, dynamic> base) {
    if (!_burnEnabled) return base;
    return <String, dynamic>{
      ...base,
      'burn': true,
      'burn_after_ms': _burnAfterMs,
    };
  }

  // 初始化群组信息
  Future<void> _initGroupInfo() async {
    if (widget.type == 'C2G') {
      final memberCount = widget.options?['memberCount'] ?? 0;
      ref.read(chatProvider.notifier).updateMemberCount(memberCount);
      newGroupName = await ref
          .read(chatProvider.notifier)
          .groupTitle(widget.peerId, widget.peerTitle, memberCount);
    }
  }

  StreamSubscription<ChatExtendEvent>? _ssMsgExt;
  StreamSubscription<DataWrapperEvent>? _ssMsg;
  StreamSubscription<DataWrapperEvent>? _ssMsgState;
  StreamSubscription<ReEditMessageEvent>? _ssReEdit;
  StreamSubscription<AppErrorEvent>? _ssAppError;

  void _setupEventListeners() {
    try {
      // 一些异步操作事件的监听
      _ssMsgExt = AppEventBus.on<ChatExtendEvent>().listen(
        (ChatExtendEvent obj) async {
          try {
            // 监听新成员加入
            if (obj.type == 'join_group' &&
                obj.payload['groupId'] == widget.peerId &&
                (obj.payload['isFirst'] ?? false)) {
              final currentCount = ref.read(chatProvider).memberCount;
              ref
                  .read(chatProvider.notifier)
                  .updateMemberCount(currentCount + 1);
              newGroupName = await ref
                  .read(chatProvider.notifier)
                  .groupTitle(
                    widget.peerId,
                    widget.peerTitle,
                    currentCount + 1,
                  );
              if (mounted) setState(() {});
            } else if (obj.type == 'clean_msg' &&
                ((obj.payload['uk3'] ?? '') == _conversationUk3)) {
              ref.read(chatProvider.notifier).updateNextAutoId(0);
              await ref
                  .read(chatProvider.notifier)
                  .loadMoreMessages(conversation, isInitial: true);
            } else if (obj.type == 'delete_msg' &&
                obj.payload['conversation'] != null &&
                (_isConversationInitialized &&
                    obj.payload['conversation'].id == conversation.id)) {
              ref
                  .read(chatProvider.notifier)
                  .chatService
                  ?.removeMessageById(obj.payload['msg']?.id ?? '');
            }
          } catch (e) {
            debugPrint('_setupEventListeners ssMsgExt error: $e');
          }
        },
        onError: (error) {
          debugPrint('ssMsgExt stream error: $error');
        },
      );

      // 接收到新的消息订阅 for c2c c2g
      _ssMsg = AppEventBus.on<DataWrapperEvent>().listen(
        (event) async {
          // 检查数据类型，只处理消息类型的事件
          if (event.dataType != 'Message' && event.dataType != 'message') {
            // 跳过非消息事件（如 ConversationModel）
            return;
          }

          // 安全地转换数据
          if (event.data is! Message) {
            return;
          }

          final Message msg = event.data as Message;
          try {
            final String conversationUk3 =
                msg.metadata?['conversation_uk3'] ?? '';
            if (conversationUk3 != _conversationUk3 ||
                msgIds.contains(msg.id)) {
              return;
            }
            msgIds.add(msg.id);
            final i =
                ref
                    .read(chatProvider.notifier)
                    .chatService
                    ?.messages
                    .indexWhere((e) => e.id == msg.id) ??
                -1;
            if (i == -1) {
              // 不再强制立即置为已读，交由"可视阈值已读"推进水位
              ref
                  .read(chatProvider.notifier)
                  .chatService
                  ?.insertMessage(
                    msg,
                    index:
                        ref
                            .read(chatProvider.notifier)
                            .chatService
                            ?.messages
                            .length ??
                        0,
                  );
              if (msg is ImageMessage) {
                // 图片画廊已迁移至 Riverpod，由 ChatProvider 处理
              }
            }
            // 为节省内存，5秒后从 msgIds 移出 msg.id
            Future.delayed(
              const Duration(seconds: 5),
              () => msgIds.remove(msg.id),
            );
          } catch (e) {
            debugPrint('_setupEventListeners ssMsg error: $e');
          }
        },
        onError: (error) {
          debugPrint('ssMsg stream error: $error');
        },
      );

      // 消息状态更新订阅, 这里无需用锁 for c2g
      _ssMsgState = AppEventBus.on<DataWrapperEvent>().listen(
        (event) {
          // 检查数据类型，只处理消息列表类型的事件
          if (event.dataType != 'MessageList' && event.dataType != 'messages') {
            // 跳过非消息列表事件（如 ConversationModel）
            return;
          }

          // 安全地转换数据
          if (event.data is! List) {
            return;
          }

          final List<Message> e = (event.data as List).cast<Message>();
          try {
            if (e.isEmpty) return;
            Message msg = e.first;
            iPrint('收到消息状态更新事件: msgId=${msg.id}, type=${msg.runtimeType}');
            final i =
                ref
                    .read(chatProvider.notifier)
                    .chatService
                    ?.messages
                    .indexWhere((e) => e.id == msg.id) ??
                -1;
            final messageCount =
                ref.read(chatProvider.notifier).chatService?.messages.length ??
                0;
            iPrint('在消息列表中查找消息: index=$i, 总消息数=$messageCount');
            if (i > -1 &&
                mounted &&
                ref.read(chatProvider.notifier).chatService != null) {
              final old = ref
                  .read(chatProvider.notifier)
                  .chatService!
                  .messages[i];
              iPrint('更新消息UI: ${msg.id}');
              ref
                  .read(chatProvider.notifier)
                  .chatService!
                  .updateMessage(
                    ref.read(chatProvider.notifier).chatService!.messages[i],
                    msg,
                  );
              final didBecomeSeen =
                  old.status != MessageStatus.seen &&
                  msg.status == MessageStatus.seen;
              if (didBecomeSeen &&
                  _isBurnMessage(msg) &&
                  (msg.metadata?['burn_read_at'] ?? 0) == 0) {
                ref
                    .read(chatProvider.notifier)
                    .markBurnReadAt(
                      conversation,
                      msg.id,
                      readAtMs: DateTimeHelper.millisecond(),
                    );
              }
            } else {
              iPrint('消息未找到或组件未挂载: msgId=${msg.id}, mounted=$mounted');
            }
          } catch (e) {
            debugPrint('_setupEventListeners ssMsgState error: $e');
          }
        },
        onError: (error) {
          debugPrint('ssMsgState stream error: $error');
        },
      );

      // 监听重新编辑消息事件
      _ssReEdit = AppEventBus.on<ReEditMessageEvent>().listen(
        (msg) async {
          try {
            if (msg.messageId != null && msg.messageId!.isNotEmpty) {
              // 设置当前正在编辑的消息ID
              _editingMessageId = msg.messageId;
              iPrint('重新编辑消息: messageId=${msg.messageId}, text=${msg.text}');
            }
            // 将消息文本填充到输入框
            chatInputKey.currentState?.setText(msg.text);
          } catch (e) {
            debugPrint('ssReEdit error: $e');
          }
        },
        onError: (error) {
          debugPrint('ssReEdit stream error: $error');
        },
      );

      // 监听全局错误事件（如 not_a_friend）
      _ssAppError = AppEventBus.on<AppErrorEvent>().listen(
        (error) {
          try {
            if (!mounted) return;
            // 只处理聊天相关的错误
            if (error.errorType == 'not_a_friend' ||
                error.message.contains('非好友')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error.message),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(label: '确定', onPressed: () {}),
                ),
              );
              iPrint('✅ [AppErrorEvent] 显示 SnackBar: ${error.message}');
            }
          } catch (e) {
            debugPrint('ssAppError error: $e');
          }
        },
        onError: (error) {
          debugPrint('ssAppError stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('_setupEventListeners error: $e');
    }
  }

  @override
  void dispose() {
    // 发送离开会话事件（用于未读数管理）
    _notifyChatActive(false);

    // 取消所有订阅
    _ssMsgExt?.cancel();
    _ssMsg?.cancel();
    _ssMsgState?.cancel();
    _ssReEdit?.cancel();
    _ssAppError?.cancel();

    // 使用保存的引用而不是 ref.read（避免在 dispose 中使用 ref）
    _chatNotifier.markAsDisposed();

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

    // 安全地清理聊天控制器（使用保存的引用）
    try {
      _chatNotifier.chatService?.setMessages([]);
      _chatNotifier.chatService?.dispose();
    } catch (e) {
      debugPrint('Error disposing chat controller: $e');
    }

    // Riverpod Provider 会自动处理资源释放
    try {
      _secureChannel.invokeMethod('disable');
    } catch (_) {}

    super.dispose();
  }

  /// 发送活动会话事件（用于未读数管理）
  void _notifyChatActive(bool isActive) {
    try {
      final conversationUk3 = ConversationUk3Generator.generateSmart(
        type: widget.type,
        currentUserId: UserRepoLocal.to.currentUid,
        peerId: widget.peerId,
      );

      // 使用 Riverpod Provider 管理活跃会话状态
      if (isActive) {
        ref
            .read(activeConversationProvider.notifier)
            .setActiveConversation(conversationUk3);
      } else {
        ref.read(activeConversationProvider.notifier).clearActiveConversation();
      }
    } catch (e) {
      debugPrint('Error updating active conversation: $e');
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
        await WidgetsBinding.instance.endOfFrame;
        // 渐进式等待：前几次快一点，后面慢一点
        await Future.delayed(Duration(milliseconds: attempt < 3 ? 100 : 200));

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

      ref
          .read(messageScrollManagerProvider.notifier)
          .highlightMessage(widget.msgId);
    } catch (e) {
      debugPrint("滚动到目标消息失败: $e");
      // 降级处理：使用简单的索引滚动
      _fallbackScrollToMessage();
    }
  }

  // 降级滚动方法
  void _fallbackScrollToMessage() {
    try {
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

        // 延迟高亮
        Future.delayed(const Duration(milliseconds: 300), () {
          ref
              .read(messageScrollManagerProvider.notifier)
              .highlightMessage(widget.msgId);
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
            widget.type == 'null' ? 'C2C' : widget.type,
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
          .retryMessage(messageId, widget.type);

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

  // 选择文件
  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    await _uploadFile(result.files.single);
  }

  // 上传文件
  Future<void> _uploadFile(PlatformFile file) async {
    await AttachmentApi.uploadFile(
      "files",
      file,
      (Map<String, dynamic> resp, String uri) async {
        final message = FileMessage(
          id: Xid().toString(),
          authorId: currentUser.id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            DateTimeHelper.millisecond(),
            isUtc: true,
          ),
          mimeType: lookupMimeType(file.path!),
          name: file.name,
          size: file.size,
          source: uri,
          status: MessageStatus.sending,
          metadata: _withBurnMetadata({
            'peer_id': widget.peerId,
            'md5': resp['data']['md5'].toString(),
          }),
        );
        _addMessage(message);
      },
      (Error error) => debugPrint("File upload error: ${error.toString()}"),
    );
  }

  // 拍摄照片或视频
  Future<void> _handlePickerSelection(BuildContext context) async {
    // 在异步操作前检查 context 是否已挂载
    if (!context.mounted) {
      return;
    }
    try {
      // 请求相机权限
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission || !context.mounted) {
        // 添加 mounted 检查
        return;
      }
      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: const CameraPickerConfig(
          enableRecording: true,
          onlyEnableRecording: false,
          enableTapRecording: true,
          maximumRecordingDuration: Duration(seconds: 24),
        ),
      );
      // 检查上下文是否仍然有效
      if (!context.mounted || entity == null) return;
      await _uploadCameraAsset(entity);
    } catch (e) {
      debugPrint("Camera picker error: $e");
      if (context.mounted) {
        // 错误处理时检查 mounted
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t.cameraShootFailed}: $e')));
      }
    }
  }

  // 上传拍摄的资源
  Future<void> _uploadCameraAsset(AssetEntity entity) async {
    await AttachmentApi.uploadVideo(
      "camera",
      entity,
      (Map<String, dynamic> resp, String imgUrl) async {
        imgUrl += "&width=${MediaQuery.of(context).size.width.toInt()}";
        if (entity.type == AssetType.image) {
          await _handleImageUpload(resp, imgUrl, entity);
        } else if (entity.type == AssetType.video) {
          await _handleVideoUpload(resp);
        }
      },
      (Error error) => debugPrint("Camera upload error: ${error.toString()}"),
      uploadOriginalImage: true,
    );
    // 上传后删除临时文件
    (await entity.file)?.deleteSync();
  }

  // 处理图片上传
  Future<void> _handleImageUpload(
    Map<String, dynamic> resp,
    String imgUrl,
    AssetEntity entity,
  ) async {
    final message = ImageMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: resp["data"]["size"],
      source: imgUrl,
      metadata: _withBurnMetadata({
        'peer_id': widget.peerId,
        'md5': resp['data']['md5'].toString(),
      }),
    );
    _addMessage(message);
  }

  // 处理视频上传
  Future<void> _handleVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'video',
        'peer_id': widget.peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      }),
    );
    _addMessage(message);
  }

  // 选择资源(图片/视频)
  Future<void> _selectAssets(PickMethod model) async {
    final List<AssetEntity>? result = await model.method(context, assets);
    if (result != null) {
      assets = List<AssetEntity>.from(result);
      if (mounted) setState(() {});
    }
  }

  // 发送收藏消息
  Future<void> _handleCollectSelection() async {
    final peer = {
      'peer_id': widget.peerId,
      'avatar': widget.peerAvatar,
      'title': widget.peerTitle,
    };
    final collect = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => UserCollectPage(peer: peer, isSelect: true),
      ),
    );
    if (collect != null) {
      await _sendCollectMessage(collect);
    }
  }

  // 发送收藏消息
  Future<void> _sendCollectMessage(UserCollectModel collect) async {
    final data = collect.info
      ..addAll({
        MessageRepo.id: Xid().toString(),
        MessageRepo.from: UserRepoLocal.to.currentUid,
        MessageRepo.to: widget.peerId,
        MessageRepo.status: 10,
        MessageRepo.conversationUk3: _conversationUk3,
        MessageRepo.createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
      });
    final msg0 = await MessageModel.fromJson(data).toTypeMessage();
    final msg = _burnEnabled
        ? msg0.copyWith(
            metadata: _withBurnMetadata(
              Map<String, dynamic>.from(msg0.metadata ?? {}),
            ),
          )
        : msg0;
    final res = await _addMessage(msg);
    if (res) {
      // 使用 UserCollectLogic 更新收藏状态
      UserCollectLogic().change(collect.kindId);
      EasyLoading.showSuccess(t.tipSuccess);
    } else {
      EasyLoading.showError(t.tipFailed);
    }
  }

  // 发送个人名片
  Future<void> _handleVisitCardSelection() async {
    final peer = {
      'peer_id': widget.peerId,
      'avatar': widget.peerAvatar,
      'title': widget.peerTitle,
    };
    final contact = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => SelectFriendPage(peer: peer)),
    );
    if (contact != null) {
      await _sendVisitCardMessage(contact);
    }
  }

  // 发送个人名片消息
  Future<void> _sendVisitCardMessage(ContactModel contact) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'visit_card',
        'peer_id': widget.peerId,
        'uid': contact.peerId,
        'title': contact.title,
        'avatar': contact.avatar,
      }),
    );
    final res = await _addMessage(message);
    if (res) {
      EasyLoading.showSuccess(t.tipSuccess);
    } else {
      EasyLoading.showError(t.tipFailed);
    }
  }

  // 发送位置消息
  Future<void> _handleLocationSelection(
    String id,
    Uint8List? imageBytes,
    String address,
    String title,
    String latitude,
    String longitude,
  ) async {
    if (imageBytes == null) return;
    final image = img.decodeImage(imageBytes)!;
    final result = img.encodeJpg(image, quality: 65);
    await AttachmentApi.uploadBytes(
      "location",
      result,
      (Map<String, dynamic> resp, String imgUrl) async {
        double w = MediaQuery.of(context).size.width;
        imgUrl += "&width=${w.toInt()}";
        final message = CustomMessage(
          authorId: currentUser.id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            DateTimeHelper.millisecond(),
            isUtc: true,
          ),
          id: Xid().toString(),
          metadata: _withBurnMetadata({
            'custom_type': 'location',
            'peer_id': widget.peerId,
            'title': title,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'thumb': imgUrl,
            'size': resp['data']['size'],
            'md5': resp['data']['md5'].toString(),
          }),
        );
        _addMessage(message);
      },
      (Error error) => debugPrint("Location upload error: ${error.toString()}"),
      process: false,
    );
  }

  // 选择图片/视频
  Future<void> _handleImageSelection() async {
    // Request photo permission before accessing assets
    bool hasPermission = await requestPhotoPermission();
    if (!hasPermission) {
      return; // Permission denied, exit early
    }
    await _selectAssets(
      PickMethod.cameraAndStay(maxAssetsCount: maxAssetsCount),
    );
    await _uploadSelectedAssets();
  }

  // 上传选择的资源
  Future<void> _uploadSelectedAssets() async {
    for (var entity in assets) {
      await AttachmentApi.uploadVideo(
        "img",
        entity,
        (Map<String, dynamic> resp, String imgUrl) async {
          if (entity.type == AssetType.image) {
            await _handleSelectedImageUpload(resp, imgUrl, entity);
          } else if (entity.type == AssetType.video) {
            await _handleSelectedVideoUpload(resp);
          }
          _removeUploadedAsset(entity);
        },
        (Error error) => debugPrint("Asset upload error: ${error.toString()}"),
        uploadOriginalImage: true,
      );
    }
  }

  // 处理选择的图片上传
  Future<void> _handleSelectedImageUpload(
    Map<String, dynamic> resp,
    String imgUrl,
    AssetEntity entity,
  ) async {
    double w = MediaQuery.of(context).size.width;
    imgUrl += "&width=${w.toInt()}";
    final message = ImageMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: resp["data"]["size"],
      source: imgUrl,
      metadata: _withBurnMetadata({
        'peer_id': widget.peerId,
        'md5': resp['data']['md5'].toString(),
      }),
    );
    _addMessage(message);
  }

  // 处理选择的视频上传
  Future<void> _handleSelectedVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'video',
        'peer_id': widget.peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      }),
    );
    _addMessage(message);
  }

  // 移除已上传的资源
  void _removeUploadedAsset(AssetEntity entity) {
    assets.removeWhere((element) => element.id == entity.id);
    if (mounted) setState(() {});
  }

  // 发送语音消息
  Future<void> _handleVoiceSelection(AudioFile? obj) async {
    if (obj == null || (await obj.file.readAsBytes()).isEmpty) return;
    await AttachmentApi.uploadFile(
      'audio',
      obj.file,
      (Map<String, dynamic> resp, String uri) async {
        final message = CustomMessage(
          authorId: currentUser.id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            DateTimeHelper.millisecond(),
            isUtc: true,
          ),
          id: Xid().toString(),
          metadata: _withBurnMetadata({
            'custom_type': 'audio',
            'peer_id': widget.peerId,
            'uri': uri,
            'size': (await obj.file.readAsBytes()).length,
            'duration_ms': obj.duration.inMilliseconds,
            'waveform': obj.waveform,
            'mime_type': obj.mimeType,
            'md5': resp['data']['md5'].toString(),
          }),
        );
        obj.file.delete(recursive: true);
        _addMessage(message);
      },
      (Error error) => debugPrint("Voice upload error: ${error.toString()}"),
      process: false,
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

  // 显示重试菜单
  void _showRetryMenu(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: Text(t.chatResend),
                onTap: () {
                  Navigator.pop(context);
                  _onMessageRetry(message.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(t.chatDeleteMessage),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(context, message, pop: false);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 显示快捷操作菜单
  void _showQuickActionMenu(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 根据消息类型显示不同的选项
              if (message is TextMessage) ...[
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(t.buttonCopy),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text));
                    EasyLoading.showToast(t.copied);
                  },
                ),
              ],
              if (message is ImageMessage) ...[
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text(t.chatSaveImage),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(chatProvider.notifier)
                        .saveFile(message.text ?? message.id, message.source);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(t.chatReply),
                onTap: () {
                  Navigator.pop(context);
                  updateQuoteMessage(message);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 更新引用消息
  Future<void> updateQuoteMessage(Message? msg) async {
    setState(() => quoteMessage = msg);
  }

  // 发送文本消息
  Future<bool> _handleSendPressed(String text) async {
    iPrint(
      'handleSendPressed 开始: text=$text, _editingMessageId=$_editingMessageId',
    );

    // 检查是否是编辑消息
    if (_editingMessageId != null && _editingMessageId!.isNotEmpty) {
      iPrint('执行编辑消息: messageId=$_editingMessageId, newContent=$text');

      // 发送编辑消息
      bool result = await MessageActions.to.sendEditMessage(
        _editingMessageId!,
        widget.type,
        text,
      );

      iPrint('编辑消息结果: $result');

      // 清除编辑状态
      _editingMessageId = null;

      return result;
    } else if (quoteMessage == null) {
      iPrint(t.sendNewMessage);
      return await _sendTextMessage(text);
    } else {
      return await _sendQuoteMessage(text);
    }
  }

  // 发送普通文本消息
  Future<bool> _sendTextMessage(String text) async {
    final textMessage = TextMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      text: text,
      metadata: _withBurnMetadata({'peer_id': widget.peerId}),
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
        'custom_type': 'quote',
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
    // 保留此方法用于未来扩展（如查看消息发送详情）
    if (msg.status != MessageStatus.sent &&
        msg.status != MessageStatus.sending) {
      return;
    }
    // TODO: 添加点击消息状态的扩展功能（如查看发送详情）
    // 目前暂时为空，避免与重试逻辑冲突
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
          _copyMessageText(message);
        } else if (message is CustomMessage &&
            message.metadata?['custom_type'] == 'quote') {
          // 引用消息的复制功能
          final quoteText = message.metadata?['quote_text'] ?? '';
          if (quoteText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: quoteText));
            EasyLoading.showToast(t.copied);
          }
        }
      },
      onEdit: () => _editMessage(message),
      onDelete: () => _deleteMessageForMe(context, message, pop: false),
      onDeleteForEveryone: isSentByMe
          ? () => _deleteMessageForEveryone(context, message)
          : null,
      onForward: () => _forwardMessage(message),
      onReaction: (emoji) => _addReaction(message, emoji),
      // 新增的操作回调
      onRevoke: isSentByMe ? () => _revokeMessage(message) : null,
      onSave: _canSaveMessage(message)
          ? () => _saveMessageContent(message)
          : null,
      onCollect: _canCollectMessage(message)
          ? () => _collectMessage(message)
          : null,
      onRetry: canRetry ? () => _onMessageRetry(message.id) : null,
    );
  }

  /// 检查消息是否可以保存
  bool _canSaveMessage(Message message) {
    if (message is ImageMessage) {
      return true;
    } else if (message is FileMessage) {
      return true;
    } else if (message is CustomMessage) {
      final customType = message.metadata?['custom_type'] ?? '';
      return customType == 'video' || customType == 'audio';
    }
    return false;
  }

  /// 检查消息是否可以收藏
  bool _canCollectMessage(Message message) {
    return UserCollectLogic.getCollectKind(message) > 0;
  }

  /// 编辑消息
  Future<void> _editMessage(Message message) async {
    if (message is TextMessage) {
      iPrint(
        '✅ _editMessage 被调用: messageId=${message.id}, text="${message.text}"',
      );

      // 记录当前正在编辑的消息ID（必须在设置文本之前）
      _editingMessageId = message.id;

      iPrint('✅ _editingMessageId 已设置为: $_editingMessageId');

      // 将消息文本填充到输入框
      chatInputKey.currentState?.setText(message.text);

      // 聚焦输入框
      chatInputKey.currentState?.inputFocusNode.requestFocus();

      iPrint('✅ _editMessage 完成: _editingMessageId=$_editingMessageId');
    }
  }

  /// 添加消息反应
  void _addReaction(Message message, String emoji) async {
    try {
      HapticFeedback.lightImpact();
      final res = await ref
          .read(chatProvider.notifier)
          .toggleReaction(
            chatType: widget.type == 'null' ? 'C2C' : widget.type,
            peerId: widget.peerId,
            messageId: message.id,
            emoji: emoji,
          );
      if (!mounted) return;
      if (res == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res ? '${t.reactionAdded} $emoji' : '${t.reactionCancelled} $emoji',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  // 删除消息(仅自己)
  Future<void> _deleteMessageForMe(
    BuildContext context,
    Message msg, {
    bool pop = true,
  }) async {
    final nav = Navigator.of(context);
    if (widget.type == 'C2G') {
      await _sendDeleteForMeMessage(msg);
    }
    bool res = await ref
        .read(chatProvider.notifier)
        .removeMessage(conversation, msg);
    if (res) {
      await ref
          .read(chatProvider.notifier)
          .chatService
          ?.removeMessageById(msg.id);
    }
    if (pop) {
      nav.pop();
    }
  }

  // 发送删除消息请求(仅自己)
  Future<void> _sendDeleteForMeMessage(Message msg) async {
    final msg2 = {
      'id': Xid().toString(),
      'from': msg.authorId,
      'to': msg.metadata?['peer_id'],
      'type': 'S2C',
      'payload': {
        'old_msg_id': msg.id,
        'to': msg.metadata?['peer_id'],
        'msg_type': '${widget.type}_DEL_FOR_ME',
      },
      'created_at': DateTimeHelper.millisecond(),
    };
    await ref.read(chatProvider.notifier).sendMessage(msg2);
  }

  // 删除消息(所有人)
  Future<void> _deleteMessageForEveryone(
    BuildContext context,
    Message msg,
  ) async {
    final nav = Navigator.of(context);
    final msg2 = {
      'id': Xid().toString(),
      'from': msg.authorId,
      'to': msg.metadata?['peer_id'],
      'type': 'S2C',
      'payload': {
        'old_msg_id': msg.id,
        'to': msg.metadata?['peer_id'],
        'msg_type': '${widget.type}_DEL_EVERYONE',
      },
      'created_at': DateTimeHelper.millisecond(),
    };
    await ref.read(chatProvider.notifier).sendMessage(msg2);
    bool res = await ref
        .read(chatProvider.notifier)
        .removeMessage(conversation, msg);
    if (res) {
      await ref
          .read(chatProvider.notifier)
          .chatService
          ?.removeMessageById(msg.id);
    }
    nav.pop();
  }

  // 复制消息文本
  void _copyMessageText(TextMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    EasyLoading.showToast(t.copied);
  }

  // 保存消息内容
  Future<void> _saveMessageContent(Message msg) async {
    if (msg is CustomMessage) {
      await ref
          .read(chatProvider.notifier)
          .saveFile(msg.metadata!['md5'], msg.metadata!['uri']);
    } else if (msg is ImageMessage) {
      await ref
          .read(chatProvider.notifier)
          .saveFile(msg.text ?? Xid().toString(), msg.source);
    } else if (msg is FileMessage) {
      await ref.read(chatProvider.notifier).saveFile(msg.name, msg.source);
    }
  }

  // 收藏消息
  Future<void> _collectMessage(Message msg) async {
    String tb = MessageRepo.getTableName(widget.type);
    final collectLogic = UserCollectLogic();
    bool res = await collectLogic.add(tb: tb, msg: msg);
    EasyLoading.showToast(res ? t.collected : t.operationFailedAgainLater);
  }

  // 撤回消息
  Future<void> _revokeMessage(Message msg) async {
    try {
      // 显示加载状态
      EasyLoading.show(status: t.revoking);

      iPrint('🔍 使用新的action机制撤回消息: msgId=${msg.id}, type=${widget.type}');

      // 使用新的MessageActions撤回机制
      bool result = await MessageActions.to.sendRevokeMessage(
        msg.id,
        widget.type,
      );
      iPrint('🔍 撤回消息发送结果: $result');

      EasyLoading.dismiss();

      if (result) {
        EasyLoading.showSuccess(t.revokeSuccess);
        iPrint('🔍 撤回请求发送完成，等待服务端确认');
      } else {
        EasyLoading.showError(
          '${t.revokeFailed}, ${t.pleaseCheckNetworkConnection}',
        );
      }
    } catch (e, stack) {
      iPrint('撤回消息异常: $e\n$stack');
      EasyLoading.dismiss();
      EasyLoading.showError(
        '${t.revokeOperationAbnormal}, ${t.pleaseTryAgain}',
      );
    }
  }

  // 转发消息
  void _forwardMessage(Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SendToPage(msg: msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
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
          color: ThemeManager.instance.getThemeColor('textPrimary'),
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
          chatInputKey.currentState?.hideAllPanel();
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          navigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // 启用系统键盘避让，获得更丝滑的交互体验
        appBar: _showAppBar
            ? GlassAppBar(
                titleWidget: Text(
                  newGroupName.isEmpty ? widget.peerTitle : newGroupName,
                  style: TextStyle(
                    color: ThemeManager.instance.getThemeColor('textPrimary'),
                    fontSize: ThemeManager.instance.getFontSize(
                      FontSizeType.title,
                    ),
                  ),
                ),
                backgroundColor: ThemeManager.instance.getThemeColor('surface'),
                rightDMActions: topRightWidget,
                automaticallyImplyLeading: true,
                // popTime: widget.options?['popTime'] ?? 1,
              )
            : null,
        body: Column(
          // 替换 n.Column
          children: [
            // 使用 Consumer 替代 Obx
            chatState.connected
                ? const SizedBox.shrink()
                : NetworkFailureTips(),
            Expanded(
              child: Stack(
                // 替换 n.Stack
                children: [
                  // 优化2：Provider 注入你的 onMessageLongPress 回调
                  GestureDetector(
                    onTapDown: (details) {
                      // 检查点击位置是否在输入区域外部
                      final screenHeight = MediaQuery.of(context).size.height;
                      final composerHeight = chatState.composerHeight;
                      final clickY = details.globalPosition.dy;
                      final inputAreaTop = screenHeight - composerHeight;
                      if (clickY < inputAreaTop) {
                        chatInputKey.currentState?.hideAllPanel();
                      }
                    },
                    // 只响应点击手势，不响应滑动手势，避免在输入框中滑动时误触收起面板
                    behavior: HitTestBehavior.translucent,
                    child: old_provider.MultiProvider(
                      providers: [
                        old_provider.Provider<Function>(
                          create: (_) => _onMessageDoubleTap,
                        ),
                      ],
                      // 以下回调与参数已由 Chat 通过 props 注入 Provider（见 _buildChatWidget 的 Chat(...)），无需在此重复注入：
                      // Provider<OnMessageLongPressCallback>.value(
                      //   value: _onMessageLongPress,
                      // ),
                      // Provider<OnMessageSendCallback>.value(
                      //   value: _handleSendPressed,
                      // ),
                      // Provider<UserID>.value(value: currentUser.id),
                      // Provider<OnMessageTapCallback>.value(
                      //   value: ,
                      // ),
                      // Provider<OnAttachmentTapCallback>.value(
                      //   value: _onAttachmentTap,
                      // ),
                      // 你还可以注入 OnMessageTapCallback、UserID 等 Provider
                      child: _buildChatWidget(context, theme, chatState),
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }

  /// 导航到聊天设置页面
  Widget _buildChatInput(BuildContext context) {
    return ChatInput(
      key: chatInputKey,
      composerHeight: composerHeightNotifier, // 使用可动画的高度
      type: widget.type,
      peerId: widget.peerId,
      onSendPressed: _handleSendPressed,
      // sendButtonVisibilityMode: SendButtonVisibilityMode.editing,
      voiceWidget: VoiceWidget(
        startRecord: () {},
        stopRecord: _handleVoiceSelection,
        height: 46,
        margin: EdgeInsets.zero,
      ),
      extraWidget: ExtraItems(
        type: widget.type,
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

  /// 构建聊天背景装饰
  BoxDecoration _buildBackgroundDecoration(
    ChatBackgroundState backgroundState,
  ) {
    final theme = ThemeManager.instance;

    switch (backgroundState.currentBackground) {
      case 'pattern_1':
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: const AssetImage(
              'assets/images/chat_backgrounds/pattern_1.png',
            ),
            repeat: ImageRepeat.repeat,
            opacity: backgroundState.backgroundOpacity,
          ),
        );

      case 'pattern_2':
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: const AssetImage(
              'assets/images/chat_backgrounds/pattern_2.png',
            ),
            repeat: ImageRepeat.repeat,
            opacity: backgroundState.backgroundOpacity,
          ),
        );

      case 'pattern_3':
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: const AssetImage(
              'assets/images/chat_backgrounds/pattern_3.png',
            ),
            repeat: ImageRepeat.repeat,
            opacity: backgroundState.backgroundOpacity,
          ),
        );

      case 'gradient_1':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.getThemeColor('primary').withValues(alpha: 0.1),
              theme.getThemeColor('surface'),
            ],
          ),
        );

      case 'gradient_2':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.getThemeColor('primary').withValues(alpha: 0.15),
              theme.getThemeColor('surface'),
              theme.getThemeColor('primary').withValues(alpha: 0.05),
            ],
          ),
        );

      case 'solid_color':
        return BoxDecoration(
          color: backgroundState.useCustomColor
              ? backgroundState.customColor
              : theme.getThemeColor('surface'),
        );

      case 'custom_image':
        // TODO: 支持自定义图片背景
        return BoxDecoration(color: theme.getThemeColor('surface'));

      default:
        return BoxDecoration(color: theme.getThemeColor('surface'));
    }
  }

  /// 构建聊天主界面
  Widget _buildChatWidget(
    BuildContext context,
    ThemeData theme,
    ChatState chatState,
  ) {
    // 使用 provider 获取聊天背景状态
    final backgroundState = ref.watch(chatBackgroundManagerProvider);

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
        'recipient' => peer,
        _ => null,
      }),
      // timeFormat: DateFormat("y-MM-dd HH:mm"),
      timeFormat: RelativeDateFormat(),
      theme: ChatThemeConfig.chatTheme,
      builders: Builders(
        chatAnimatedListBuilder: (context, itemBuilder) {
          // 直接使用 chatState 而不是 Obx
          final bottomGap = chatState.composerHeight;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (widget.msgId.isEmpty) {
                ref.read(chatProvider.notifier).chatService?.scrollToBottom();
              }
            } catch (_) {}
          });

          return Padding(
            padding: EdgeInsets.only(bottom: bottomGap),
            child: NotificationListener<ScrollNotification>(
              onNotification: (sn) {
                if (sn is UserScrollNotification) {
                  chatInputKey.currentState?.hideAllPanel();
                }
                return false;
              },
              child: _useOptimizedMessageList
                  ? _buildOptimizedMessageList()
                  : _buildOriginalMessageList(itemBuilder, chatState),
            ),
          );
        },
        // composerBuilder: (context) => SizedBox.shrink(),
        composerBuilder: (context) => Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ChatInputHeightListener(
            composerHeight: composerHeightNotifier,
            animationDuration: Duration.zero,
            animationCurve: Curves.linear,
            child: _buildChatInput(context),
          ),
        ),
        // 自定义回到底部按钮（自动避让 Composer）
        scrollToBottomBuilder: (ctx, animation, onPressed) => ScrollToBottom(
          animation: animation,
          onPressed: onPressed,
          right: 16,
          bottom: 20,
          useComposerHeightForBottomOffset: true,
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
              return CustomMessageBuilder(type: widget.type, message: message);
            },
        imageMessageBuilder:
            (
              context,
              message,
              index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              return FlyerChatImageMessage(
                message: message,
                index: index,
                showStatus: false,
                showTime: true,
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
                    color: ThemeManager.instance.getThemeColor('textSecondary'),
                  );
                  break;
                case MessageStatus.sent:
                case MessageStatus.delivered:
                  statusIcon = Icon(
                    Icons.done_all,
                    size: 16,
                    color: ThemeManager.instance.getThemeColor('primary'),
                  );
                  break;
                case MessageStatus.seen:
                  statusIcon = Icon(
                    Icons.done_all,
                    size: 16,
                    color: ThemeManager.instance.getChatColor('sendMessageBg'),
                  );
                  break;
                case MessageStatus.error:
                  statusIcon = Icon(
                    Icons.error_outline,
                    size: 16,
                    color: ThemeManager.instance.getThemeColor('error'),
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
                  child: Avatar(userId: message.authorId),
                );
              } else if (!isSystemMessage) {
                avatar = const SizedBox(width: 40);
              }

              // 在消息末尾添加状态图标
              final burnBadge = _isBurnMessage(message)
                  ? _BurnBadge(
                      isSentByMe: isCurrentUser,
                      burnAfterMs: _burnAfterMsFromMessage(message),
                      burnReadAtMs: (message.metadata?['burn_read_at'] is int)
                          ? message.metadata!['burn_read_at'] as int
                          : int.tryParse(
                                  '${message.metadata?['burn_read_at'] ?? 0}',
                                ) ??
                                0,
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
                                .markAsRead(
                                  widget.type == 'null' ? 'C2C' : widget.type,
                                  widget.peerId,
                                  [message.id],
                                  syncToServer: true,
                                );
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
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => widget.type == 'C2G'
            ? GroupDetailPage(
                groupId: widget.peerId,
                memberCount: chatState.memberCount,
                title: widget.peerTitle,
                options: options,
                callBack: (v) {},
              )
            : ChatSettingPage(
                widget.peerId,
                type: widget.type,
                options: options,
              ),
      ),
    ).then((value) => _handleChatSettingsResult(value));
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
}

class _BurnBadge extends StatelessWidget {
  final bool isSentByMe;
  final int burnAfterMs;
  final int burnReadAtMs;

  const _BurnBadge({
    required this.isSentByMe,
    required this.burnAfterMs,
    required this.burnReadAtMs,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final bg = Theme.of(context).colorScheme.surface;

    if (burnReadAtMs <= 0 || burnAfterMs <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderRadiusMedium,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              '阅后',
              style: TextStyle(fontSize: 10, color: color, height: 1.0),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<int>(
      stream: ChatPageState._burnTicker,
      builder: (context, snapshot) {
        final now = DateTimeHelper.millisecond();
        final expireAt = burnReadAtMs + burnAfterMs;
        final remainMs = expireAt - now;
        final remainSec = (remainMs / 1000).ceil();
        final text = remainSec <= 0 ? '0s' : '${remainSec}s';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 12, color: color),
              const SizedBox(width: 2),
              Text(
                text,
                style: TextStyle(fontSize: 10, color: color, height: 1.0),
              ),
            ],
          ),
        );
      },
    );
  }
}
