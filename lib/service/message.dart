import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:imboy/service/message_retry.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message_actions.dart';
import 'message_s2c.dart';
import 'message_webrtc.dart';

/// MessageService
/// 负责消息处理的核心服务，包括可靠传递、状态同步、UI 通知。
/// Core service for message handling: reliable delivery, state sync, UI updates.
/// 
/// 此文件已重构为模块化架构，原有功能已拆分到以下文件：
/// This file has been refactored into a modular architecture, original functionality split into:
/// - message_core.dart: 核心服务，基础初始化和事件分发
/// - message_handler.dart: 消息处理器，处理不同类型消息
/// - message_actions.dart: 消息操作，撤回、编辑等功能
/// - message_webrtc.dart: WebRTC 消息处理
/// - message_retry.dart: 消息重试机制
class MessageService extends GetxService {
  static MessageService get to => Get.find();

  // 委托给各个模块
  // Delegate to each module
  MessageActions get actions => MessageActions.to;
  MessageWebrtc get webrtc => MessageWebrtc.to;
  MessageRetry get retry => MessageRetry.to;


  final MessageActions _messageActions = MessageActions.to;

  // 懒加载 ConversationLogic 实例
  ConversationLogic get _conversationLogic => Get.find<ConversationLogic>();

  // 缓存常用仓库实例，避免重复 new。
  // Cache repository instances to avoid repeated instantiation.
  final ConversationRepo _conversationRepo = ConversationRepo();
  final ContactRepo _contactRepo = ContactRepo();


  /// 根据消息类型获取对应的 MessageRepo
  /// Helper: get MessageRepo by message type.
  MessageRepo getMessageRepo(String type) =>
      MessageRepo(tableName: MessageRepo.getTableName(type));

  /// 本地添加消息锁，防止并发重复添加
  /// Lock to prevent concurrent duplicate local messages.
  bool addMessageLock = false;

  /// 网络状态监听
  /// Network status monitoring.
  final RxBool isOnline = true.obs;

  /// 消息发送进度跟踪
  /// Message sending progress tracking.
  final Map<String, double> sendingProgress = {};

  @override
  void onInit() {
    super.onInit();

    // 延迟初始化网络监控，避免在服务注册阶段访问其他服务
    // Delay network monitoring initialization to avoid accessing services during registration phase
    Future.microtask(() {
      if (Get.isRegistered<WebSocketService>()) {
        initNetworkMonitoring();
      }
    });

    // 所有子模块现在都在 init.dart 中使用 lazyPut 注册
    // All sub-modules are now registered using lazyPut in init.dart
  }


  /// 初始化网络状态监控
  /// Initialize network status monitoring.
  void initNetworkMonitoring() {
    // 监听WebSocket连接状态
    ever(WebSocketService.to.status, (SocketStatus status) {
      isOnline.value = status == SocketStatus.connected;
      if (isOnline.value) {
        // 网络恢复时重试失败的消息
        if (Get.isRegistered<MessageRetry>()) {
          MessageRetry.to.retryFailedMessages();
        }
      }
    });
  }

  /// Send reliable ACK back to server/peer
  /// 发送消息回执
  /// type is ['C2C' | 'S2C' | 'C2G' | 'C2S | 'WEBRTC']
  void sendAckMsg(String type, String msgId) {
    WebSocketService.to.sendMessage('CLIENT_ACK,$type,$msgId,$deviceId', msgId);
  }

  /// 对外保留：改变消息状态（兼容旧调用）
  /// Public API: change message status (for backward compatibility)
  Future<MessageModel?> changeStatus(String tb, String msgId, int status) {
    final repo = MessageRepo(tableName: tb);
    return updateStatus(repo, msgId, status);
  }

  /// Internal: update message status and conversation state
  /// 内部：更新消息状态并同步会话
  Future<MessageModel?> updateStatus(
      MessageRepo repo,
      String msgId,
      int status,
      ) async {
    await repo.update({'id': msgId, 'status': status});
    iPrint('> message_core: 更新消息状态 $msgId 为 $status');
    // 获取会话逻辑实例
    final conversationLogic = Get.find<ConversationLogic>();
    await conversationLogic.updateConversationByMsgId(msgId, {
      ConversationRepo.lastMsgStatus: status,
    });
    return repo.find(msgId);
  }

  /// 获取消息发送进度
  /// Get message sending progress.
  double getSendingProgress(String messageId) {
    return sendingProgress[messageId] ?? 0.0;
  }

  /// 更新消息发送进度
  /// Update message sending progress.
  void updateSendingProgress(String messageId, double progress) {
    sendingProgress[messageId] = progress;
    // 通知UI更新进度
    eventBus.fire({'progress_update': messageId, 'progress': progress});
  }

  /// 清理发送进度
  /// Clear sending progress.
  void clearSendingProgress(String messageId) {
    sendingProgress.remove(messageId);
  }

  /// 处理消息的主入口
  /// Main entry point for message processing
  Future<void> processMessage(String type, Map data) async {
    // 检查payload中是否有action字段
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>();
    final action = payload?['action']?.toString();

    // 所有消息均需回执 ACK
    // Always send ACK for receipt
    if (type.startsWith('WEBRTC_')) {
      sendAckMsg('WEBRTC', data['id']);
      await webrtc.handleWebRTC(type, data);
    } else if (type.endsWith('_SERVER_ACK')) {
      await _receiveServerAck(data);
    } else if (action != null && action.isNotEmpty) {
      // 基于action的消息处理
      await _messageActions.handleActionMessage(action, data);
    } else {
      switch (type) {
        case 'C2C':
        case 'C2G':
        case 'C2S':
          await _receiveMessage(data);
          break;
        case 'S2C':
          await MessageS2CService.switchS2C(data);
          break;
        case 'ERROR':
          await _handleError(data);
          break;
        default:
          iPrint('Unhandled message type: $type');
      }
    }
  }

  /// Process incoming chat messages (C2C/C2G/C2S)
  /// 处理文本/自定义/位置等消息
  Future<void> _receiveMessage(Map data) async {
    // 强制 cast 为 Map<String, dynamic>
    // Safely cast payload to Map<String, dynamic>
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>();
    if (payload == null) return;

    // 归一化 created_at 时间戳
    // Normalize timestamp field
    var createdAt = data['created_at'];
    if (createdAt is String) {
      createdAt = DateTimeHelper.rfc3339ToMillisecond(createdAt);
      data['created_at'] = createdAt;
    }

    final repo = to.getMessageRepo(data['type']);
    final existing = await repo.find(data['id']);
    if (existing != null) {
      to.sendAckMsg(data['type'], data['id']);
      return;
    }

    // 检查消息是否已被删除（阅后即焚）
    if (await ChatLogic.isMessageDeleted(data['id'])) {
      iPrint('消息已被删除，忽略重复投递: ${data['id']}');
      to.sendAckMsg(data['type'], data['id']);
      return;
    }

    // 区分单聊/群聊，获取 peer 信息
    // Determine peer info for C2C or C2G
    String peerId, avatar, title;
    if (data['type'] == 'C2G') {
      peerId = data['to'];
      final g = await GroupDetailLogic().detail(gid: peerId);
      avatar = g?.avatar ?? '';
      title = g?.title ?? '';
    } else {
      final ct = await _contactRepo.findByUid(data['from']);
      peerId = data['from'];
      avatar = ct?.avatar ?? '';
      title = ct?.title ?? '';
    }

    // 构造会话列表要显示的 subtitle
    // Derive subtitle based on msg_type
    String msgType = payload['msg_type'] ?? '';
    String subtitle = payload['text'] ?? '';
    if (msgType == 'custom') {
      msgType = payload['custom_type'] ?? '';
      subtitle = '';
    } else if (msgType == 'quote') {
      subtitle = payload['quote_text'] ?? '';
    } else if (msgType == 'location') {
      subtitle = payload['title'] ?? '';
    }

    // 保存或更新会话
    // Persist conversation record
    var conv = ConversationModel(
      peerId: peerId,
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      type: data['type'],
      msgType: msgType,
      lastMsgId: data['id'],
      lastTime: data['created_at'] ?? DateTimeHelper.millisecond(),
      unreadNum: 1,
      id: 0,
    );
    conv = await _conversationRepo.save(conv);

    // 保存消息到 sqlite
    // Persist message to local DB
    final msg = MessageModel(
      data['id'],
      autoId: 0,
      type: data['type'],
      fromId: data['from'],
      toId: data['to'],
      payload: payload,
      createdAt: data['created_at'],
      isAuthor: data['from'] == UserRepoLocal.to.currentUid ? 1 : 0,
      topicId: data['topic_id'] ?? 0,
      conversationUk3: conv.uk3,
      status: IMBoyMessageStatus.delivered,
    );
    final existed = await repo.save(msg);

    // 发送 ACK 给服务端或对端
    // Send ACK back
    // data['type'] C2C | C2G | C2S
    to.sendAckMsg(data['type'], data['id']);

    // 如果已存在则不再触发通知
    // If duplicate, skip UI update
    if (existed != null && existed > 0) return;

    // 检查用户是否正在查看该会话，避免重复计数
    // Check if user is currently viewing this conversation to avoid duplicate counting
    bool isUserInChat = await _isUserCurrentlyInChat(conv);
    // 只有当消息不是当前用户发送的，且用户不在聊天页面时，才增加未读计数
    // Only increase unread count when message is not from current user and user is not in chat page
    bool isFromCurrentUser = data['from'] == UserRepoLocal.to.currentUid;
    if (!isUserInChat && !isFromCurrentUser) {
      await _conversationLogic.increaseConversationRemind(conv, 1);
    }
    eventBus.fire(conv);
    final tMsg = await msg.toTypeMessage();
    eventBus.fire(tMsg);
  }

  /// Handle server-side ACK for sent messages
  /// 处理服务端发送确认
  Future<void> _receiveServerAck(Map data) async {
    final repo = to.getMessageRepo(data['type']);
    final msg = await to.updateStatus(repo, data['id'], IMBoyMessageStatus.sent);
    // iPrint("> rtc msg S_RECEIVED: msg:${msg?.toJson().toString()} ;");
    if (msg != null) {
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([await msg.toTypeMessage()]);

      // 确保会话列表中的lastMsgStatus也得到更新
      await _conversationLogic.updateConversationByMsgId(data['id'], {
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
      });
    }
  }

  /// 检查用户是否正在查看特定会话
  /// Check if user is currently viewing a specific conversation
  Future<bool> _isUserCurrentlyInChat(ConversationModel conv) async {
    try {
      // 检查是否有ChatLogic实例且当前会话匹配
      if (Get.isRegistered<ChatLogic>()) {
        final chatLogic = Get.find<ChatLogic>();
        // 检查当前聊天页面的会话ID是否与传入的会话匹配
        if (chatLogic.state.currentConversationId.value == conv.uk3) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('检查用户会话状态时出错: $e');
      return false;
    }
  }

  /// Handle error codes from server
  /// 处理服务端错误通知
  Future<void> _handleError(Map data) async {
    final code = data['code']?.toString() ?? '';
    // * Msg2.code = 1 无需弹窗错误，可以记录日志后直接忽略错误 Msg2.payload 可能为空，不需要处理
    // * Msg2.code = 2 带title弹窗，Msg2.payload 不能为空 必须包含 title content 字段
    // * Msg2.code = 3 无title弹窗，Msg2.payload 不能为空 必须包含 content 字段
    if (code == '706') {
      UserRepoLocal.to.quitLogin();
      Get.offAll(() => const LoginPage());
    }
  }


  // 兼容性方法，保持原有 API
  // Compatibility methods to maintain original API


  /// Add a local WebRTC message record (UI only)
  /// 本地添加一条 WebRTC 消息记录，仅更新 UI
  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) => webrtc.addLocalMsg(
    media: media,
    caller: caller,
    msgId: msgId,
    peer: peer,
  );

  /// Update local WebRTC message state (UI only)
  /// 更新本地 WebRTC 消息状态，仅更新 UI
  Future<void> changeLocalMsgState(
    String msgId,
    int state, {
    int startAt = -1,
    int endAt = -1,
  }) => webrtc.changeLocalMsgState(
    msgId,
    state,
    startAt: startAt,
    endAt: endAt,
  );

  /// 将消息添加到重试队列
  /// Add message to retry queue.
  void addToRetryQueue(String messageId, String type, Map<String, dynamic> messageData) =>
      retry.addToRetryQueue(messageId, type, messageData);

  /// 手动重试消息
  /// Manually retry message.
  Future<bool> retryMessage(String messageId, String type) =>
      retry.retryMessage(messageId, type);

  /// 发送撤回消息请求
  /// Send revoke message request.
  Future<bool> sendRevokeMessage(String messageId, String messageType) =>
      actions.sendRevokeMessage(messageId, messageType);

  /// 发送编辑消息请求
  /// Send edit message request.
  Future<bool> sendEditMessage(String messageId, String messageType, String newContent) =>
      actions.sendEditMessage(messageId, messageType, newContent);

  /// 检查消息是否可以撤回
  /// Check if message can be revoked.
  Future<bool> canRevokeMessage(MessageModel msg) => actions.canRevokeMessage(msg);

  /// 检查消息是否可以编辑
  /// Check if message can be edited.
  Future<bool> canEditMessage(MessageModel msg) => actions.canEditMessage(msg);
}
