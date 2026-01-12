import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/performance_monitor.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/chat/chat/chat_state.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/service/event_bus.dart';

import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:get/get.dart' as getx;

/// 聊天页面生命周期管理 Mixin
/// 
/// 这个 Mixin 负责处理聊天页面的初始化、事件监听、资源清理等生命周期相关功能。
/// 主要包括：
/// - 页面初始化和数据加载
/// - 会话设置和管理
/// - 事件监听器设置
/// - 网络状态监听
/// - 资源清理和释放
mixin ChatLifecycleMixin<T extends StatefulWidget> on State<T> {
  // 聊天逻辑控制器
  late final ChatLogic logic;
  late final ChatState state;
  late final ConversationLogic conversationLogic;
  
  // 性能监控器
  final performanceMonitor = ChatPerformanceMonitor();
  
  // 内存清理定时器
  Timer? _cleanupTimer;
  
  // 消息ID集合，用于防止 eventBus 重复渲染消息
  final Set<String> msgIds = {};
  
  // 当前会话
  late ConversationModel conversation;
  
  // 可用地图列表
  List<AvailableMap> availableMaps = [];

  @override
  void initState() {
    super.initState();
    try {
      iPrint('ChatLifecycleMixin: initState 开始初始化');
      
      // 初始化控制器
      logic = getx.Get.find<ChatLogic>();
      state = logic.state;
      conversationLogic = getx.Get.find<ConversationLogic>();
      
      // 清理消息ID集合
      msgIds.clear();
      
      // 重置状态
      state.nextAutoId.value = 0;
      state.hasMoreMessage.value = true;
      state.isLoading.value = false;
      
      // 重置 ChatLogic 的释放状态，确保可以重新初始化
      logic.resetDisposedState();
      
      // 初始化聊天
      _initChat();
      
      // 初始化数据
      _initData();
      
      // 启动内存清理定时器
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        performanceMonitor.cleanupInvisibleMessages();
        if (kDebugMode) {
          final stats = performanceMonitor.getMemoryStats();
          debugPrint('内存使用统计: $stats');
        }
      });
      
      iPrint('ChatLifecycleMixin: initState 初始化完成');
    } catch (e, stack) {
      debugPrint('Error in initState: $e\n$stack');
    }
  }

  /// 初始化聊天相关数据
  Future<void> _initChat() async {
    try {
      // 初始化聊天控制器
      logic.initChatController((widget as ChatPage).type);
      
      // 创建或获取会话
      await _setupConversation();
      
      // 加载消息
      await logic.loadMoreMessages(conversation, isInitial: true);
      
      // 设置事件监听器
      _setupEventListeners();
    } catch (e, stack) {
      debugPrint('_initChat error: $e\n$stack');
      
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('聊天初始化失败: $e')),
        );
      }
    }
  }

  /// 初始化数据
  Future<void> _initData() async {
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        state.connected.value = false;
      } else {
        state.connected.value = true;
      }
    });

    // 初始化可用地图
    if (availableMaps.isEmpty) {
      try {
        availableMaps = await MapLauncher.installedMaps;
      } catch (e) {
        debugPrint('初始化地图失败: $e');
      }
    }

    // 初始化群组信息
    await _initGroupInfo();

    // 加载特定消息（优化版）
    final chatPage = widget as ChatPage;
    if (chatPage.msgId.isNotEmpty) {
      // 延迟执行消息定位，确保页面渲染和消息加载完成
      _scrollToTargetMessageWithDelay(chatPage.msgId);
    }
  }

  /// 设置会话
  Future<void> _setupConversation() async {
    final chatPage = widget as ChatPage;
    bool showConversation = chatPage.options?['showConversation'] ?? true;
    
    conversation = await conversationLogic.createConversation(
      type: chatPage.type,
      peerId: chatPage.peerId,
      avatar: chatPage.peerAvatar,
      title: chatPage.peerTitle,
      subtitle: "",
      lastTime: showConversation ? DateTimeHelper.millisecond() : 0,
    );
    
    if (showConversation) {
      AppEventBus.fireData(conversation);
    }
    
    state.nextAutoId.value = 0;
  }

  /// 初始化群组信息
  Future<void> _initGroupInfo() async {
    final chatPage = widget as ChatPage;
    if (chatPage.type == 'C2G') {
      state.memberCount.value = chatPage.options?['memberCount'] ?? 0;
      final newGroupName = await logic.groupTitle(
        chatPage.peerId,
        chatPage.peerTitle,
        state.memberCount.value,
      );
      
      // 更新UI
      if (mounted) {
        setState(() {
          // 更新群组名称
          (this as dynamic).newGroupName = newGroupName;
        });
      }
    }
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    try {
      // 监听聊天扩展事件
      state.ssMsgExt = AppEventBus.on<ChatExtendEvent>().listen((ChatExtendEvent obj) async {
        try {
          final chatPage = widget as ChatPage;
          
          // 监听新成员加入
          if (obj.type == 'join_group' &&
              obj.payload['groupId'] == chatPage.peerId &&
              (obj.payload['isFirst'] ?? false)) {
            state.memberCount.value += 1;
            final newGroupName = await logic.groupTitle(
              chatPage.peerId,
              chatPage.peerTitle,
              state.memberCount.value,
            );
            
            if (mounted) {
              setState(() {
                // 更新群组名称
                (this as dynamic).newGroupName = newGroupName;
              });
            }
          } else if (obj.type == 'clean_msg' &&
              ((obj.payload['uk3'] ?? '') == conversation.uk3)) {
            state.nextAutoId.value = 0;
            await logic.loadMoreMessages(conversation, isInitial: true);
          } else if (obj.type == 'delete_msg' &&
              obj.payload['conversation'] != null && 
              obj.payload['conversation'].id == conversation.id) {
            logic.chatController?.removeMessageById(obj.payload['msg']?.id ?? '');
          } else if (obj.type == 'revoke_msg' &&
              obj.payload['conversation'] != null && 
              obj.payload['conversation'].id == conversation.id) {
            // 处理撤回消息事件
            String msgId = obj.payload['msgId'] ?? '';
            String revokeUser = obj.payload['revokeUser'] ?? '';
            iPrint('收到撤回消息事件: msgId=$msgId, revokeUser=$revokeUser');
            
            if (msgId.isNotEmpty) {
              // 从聊天控制器中移除该消息
              logic.chatController?.removeMessageById(msgId);
              
              // 重新加载消息以显示撤回状态
              await logic.loadNewerMessages(conversation);
            }
          }
        } catch (e) {
          debugPrint('_setupEventListeners ssMsgExt error: $e');
        }
      }, onError: (error) {
        debugPrint('ssMsgExt stream error: $error');
      });
      
      // 监听新消息
      state.ssMsg = AppEventBus.on<DataWrapperEvent>().listen((event) async { final Message msg = event.data as Message;
        try {
          final String conversationUk3 = msg.metadata?['conversation_uk3'] ?? '';
          if (conversationUk3 != conversation.uk3 || msgIds.contains(msg.id)) {
            return;
          }
          
          msgIds.add(msg.id);
          final i = logic.chatController?.messages.indexWhere((e) => e.id == msg.id) ?? -1;
          
          if (i == -1) {
            // 不再强制立即置为已读，交由“可视阈值已读”推进水位
            logic.chatController!.insertMessage(
              msg,
              index: logic.chatController!.messages.length,
            );
            // 如果是图片消息，添加到图片画廊
            if (msg is ImageMessage) {
              final galleryLogic = (this as dynamic).galleryLogic;
              galleryLogic.pushToLast(msg.id, msg.source);
            }
          }
          
          // 为节省内存，5秒后从 msgIds 移出 msg.id
          Future.delayed(const Duration(seconds: 5), () => msgIds.remove(msg.id));
        } catch (e) {
          debugPrint('_setupEventListeners ssMsg error: $e');
        }
      }, onError: (error) {
        debugPrint('ssMsg stream error: $error');
      });
      
      // 监听消息状态更新
      state.ssMsgState = AppEventBus.on<DataWrapperEvent>().listen((event) { final List<Message> e = (event.data as List).cast<Message>();
        try {
          if (e.isEmpty) return;
          Message msg = e.first;
          
          final i = logic.chatController?.messages.indexWhere((e) => e.id == msg.id) ?? -1;
          if (i > -1 && mounted) {
            if (i >= 0 && logic.chatController != null) {
              logic.chatController!.updateMessage(logic.chatController!.messages[i], msg);
            }
          }
        } catch (e) {
          debugPrint('_setupEventListeners ssMsgState error: $e');
        }
      }, onError: (error) {
        debugPrint('ssMsgState stream error: $error');
      });
    } catch (e) {
      debugPrint('_setupEventListeners error: $e');
    }
  }

  /// 延迟滚动到目标消息（优化版）
  Future<void> _scrollToTargetMessageWithDelay(String messageId) async {
    try {
      iPrint('准备滚动到目标消息: $messageId');

      // 等待页面完全渲染和初始消息加载完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 确保页面仍然存在
      if (!mounted) {
        iPrint('页面已销毁，取消滚动');
        return;
      }

      final chatPage = widget as ChatPage;

      // 多次尝试定位消息，提高成功率
      const maxAttempts = 3;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          iPrint('尝试定位消息，第 ${attempt + 1}/$maxAttempts 次: $messageId');

          // 检查消息是否已在内存中
          bool messageExists = logic.chatController?.messages.any((m) => m.id == messageId) ?? false;

          if (messageExists) {
            iPrint('消息已在内存中，直接滚动: $messageId');
            await logic.scrollToMessage(chatPage.type, messageId);
            break;
          } else {
            // 如果消息不在内存中，尝试加载更多历史消息
            iPrint('消息不在内存中，尝试加载历史消息: $messageId');
            await logic.loadMoreMessages(conversation);

            // 等待加载完成
            await Future.delayed(const Duration(milliseconds: 300));

            // 再次尝试定位
            await logic.scrollToMessage(chatPage.type, messageId);
          }
        } catch (e) {
          iPrint('第 ${attempt + 1} 次定位尝试失败: $e');

          if (attempt < maxAttempts - 1) {
            // 等待一段时间后重试
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      }

      iPrint('消息定位完成: $messageId');
    } catch (e) {
      iPrint('滚动到目标消息失败: $messageId, 错误: $e');
    }
  }

  @override
  void dispose() {
    // 首先标记 ChatLogic 为已释放状态，阻止新的异步操作
    logic.markAsDisposed();
    
    // 取消所有订阅
    state.ssMsgExt?.cancel();
    state.ssMsg?.cancel();
    state.ssMsgState?.cancel();
    
    // 清理消息ID集合
    msgIds.clear();
    
    // 停止内存清理定时器
    _cleanupTimer?.cancel();
    
    // 清理性能监控内存
    performanceMonitor.cleanupInvisibleMessages();
    
    // 安全地清理聊天控制器
    try {
      // 先清空消息列表，但不触发事件
      if (logic.chatController != null && !logic.chatController!.isDisposed) {
        logic.chatController!.clearMessages();
      }
    } catch (e) {
      debugPrint('Error clearing chat messages: $e');
    }
    
    // 延迟释放聊天控制器，确保所有异步操作完成
    // 注意：ChatLogic是全局单例，onClose()永远不会被调用，所以需要在这里处理
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        if (logic.chatController != null && !logic.chatController!.isDisposed) {
          debugPrint('ChatLifecycleMixin dispose() 销毁聊天控制器');
          logic.chatController!.dispose();
          logic.chatController = null;
        }
      } catch (e) {
        debugPrint('Error disposing chat controller: $e');
      }
    });
    
    // 删除图片画廊逻辑
    try {
      getx.Get.delete<IMBoyImageGalleryController>();
    } catch (e) {
      debugPrint('Error deleting IMBoyImageGalleryController: $e');
    }
    
    super.dispose();
  }
}

/// 聊天页面生命周期管理状态接口
/// 
/// 这个接口定义了 ChatLifecycleMixin 需要的状态和方法，
/// 使用此 Mixin 的类需要实现这些接口。
abstract class ChatLifecycleMixinState {
  /// 获取当前聊天页面
  ChatPage get widget;
  
  /// 设置状态
  void setState(VoidCallback fn);
  
  /// 检查组件是否已挂载
  bool get mounted;
}
