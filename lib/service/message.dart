import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
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

    // 定期清理过期的内容哈希缓存
    // Periodically clean up expired content hash cache
    Timer.periodic(const Duration(seconds: 60), (_) {
      _cleanupExpiredContentHashes();
    });
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
    // 【改进】使用 AckManager 发送 ACK，支持自动重试
    try {
      AckManager.to.sendAck(type, msgId);
    } catch (e) {
      iPrint('❌ [ACK_SEND] AckManager调用失败: type=$type, msgId=$msgId, error=$e');
      // 降级处理：使用统一的 ACK 生成方法直接发送（不重试）
      // AckManager 内部已处理 deviceId 检查，generateAckMessage 会验证参数
      try {
        final ackMsg = AckManager.to.generateAckMessage(type, msgId);
        WebSocketService.to.sendMessage(ackMsg, null);
        iPrint('⚠️ [ACK_SEND] 降级发送成功: type=$type, msgId=$msgId');
      } catch (e2) {
        iPrint('❌ [ACK_SEND] 降级发送也失败: type=$type, msgId=$msgId, error=$e2');
      }
    }
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
    final msgId = data['id']?.toString() ?? 'unknown';
    final from = data['from']?.toString() ?? 'unknown';
    final to = data['to']?.toString() ?? 'unknown';
    iPrint('📥 [processMessage] type=$type, msgId=$msgId, from=$from, to=$to');

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
  /// 优化版：先更新UI，再异步处理数据存储
  /// 注意：ACK已在websocket.dart的_onMessage中立即发送，此处不再发送
  Future<void> _receiveMessage(Map data) async {
    final startTime = DateTimeHelper.millisecond();
    final msgId = data['id'] as String;
    final msgType = data['type'] as String;
    iPrint('⏱️ [1] _receiveMessage 开始: $startTime, msgId: $msgId');

    // ACK已在websocket.dart:_onMessage中发送，此处不再重复发送
    // ACK发送已移至websocket.dart，确保在最早期发送，避免任何处理延迟

    // 强制 cast 为 Map<String, dynamic>
    // Safely cast payload to Map<String, dynamic>
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>();
    if (payload == null) return;

    // 计算端到端延迟：从发送客户端到接收客户端的总延迟
    // Calculate end-to-end latency: from sender client to receiver client
    if (payload.containsKey('client_send_ts')) {
      final clientSendTs = payload['client_send_ts'] as int;
      final e2eLatency = startTime - clientSendTs;
      iPrint('📊 [端到端延迟] $msgId: ${e2eLatency}ms (A发送 → B接收)');
    }

    // 归一化 created_at 时间戳
    // Normalize timestamp field
    var createdAt = data['created_at'];
    if (createdAt is String) {
      createdAt = DateTimeHelper.rfc3339ToMillisecond(createdAt);
      data['created_at'] = createdAt;
    }

    final repo = to.getMessageRepo(msgType);

    // 【修复】先检查数据库中是否已存在，避免重复显示
    // Check database first to avoid duplicate display
    final existing = await repo.find(msgId);
    if (existing != null) {
      iPrint('⚠️ 消息已存在（数据库检查），跳过处理: $msgId');
      return;
    }

    // 【新增】检查消息是否正在加载（防止 page_view 加载时重复显示）
    // Check if message is being loaded (to prevent duplicate display during page_view loading)
    if (_loadingMessageIds.contains(msgId)) {
      iPrint('⚠️ 消息正在加载中（page_view），跳过重复显示: $msgId');
      return;
    }

    // 【新增】基于消息内容的去重检查
    // 如果发现相同内容但不同 msg_id 的消息，记录警告
    final contentHash = _generateContentHash(data);
    if (_recentMessageContents.containsKey(contentHash)) {
      final previousMsgId = _recentMessageContents[contentHash];
      iPrint('⚠️ [内容重复] 检测到重复消息: 之前msgId=$previousMsgId, 当前msgId=$msgId, from=${data['from']}, to=${data['to']}, type=$msgType');
      // 【可选】自动跳过重复消息
      // 如果服务器发送了相同消息但不同 msg_id，直接跳过
      return;
    }
    _recentMessageContents[contentHash] = msgId;

    // 快速检查消息是否已存在（仅检查内存缓存，不阻塞UI）
    // Quick duplicate check using in-memory set only (non-blocking)
    final receivingMsgKey = '${msgType}_$msgId';
    if (_receivingMessages.contains(receivingMsgKey)) {
      iPrint('消息正在处理中，跳过重复: $msgId');
      return;
    }
    _receivingMessages.add(receivingMsgKey);
    iPrint('⏱️ [3] 去重检查完成: +${DateTimeHelper.millisecond() - startTime}ms');

    try {
      // 先构造基本消息对象用于UI显示（使用默认peer信息）
      // First create basic message for UI display with default peer info
      final peerId = msgType == 'C2G' ? data['to'] : data['from'];
      final isFromCurrentUser = data['from'] == UserRepoLocal.to.currentUid;

      // 构造 subtitle
      String subtitle = payload['text'] ?? '';
      final messageType = payload['msg_type'] ?? '';
      if (messageType == 'custom') {
        subtitle = '';
      } else if (messageType == 'quote') {
        subtitle = payload['quote_text'] ?? '';
      } else if (messageType == 'location') {
        subtitle = payload['title'] ?? '';
      }

      // 创建临时会话对象用于立即显示
      // Create temporary conversation for immediate UI display
      final tempConv = ConversationModel(
        peerId: peerId,
        avatar: '', // 稍后异步更新
        title: msgType == 'C2G' ? '群聊' : '用户', // 稍后异步更新
        subtitle: subtitle,
        type: msgType,
        msgType: messageType,
        lastMsgId: msgId,
        lastTime: data['created_at'] ?? DateTimeHelper.millisecond(),
        unreadNum: isFromCurrentUser ? 0 : 1,
        id: 0,
      );

      // 创建临时消息对象用于立即显示
      // Create temporary message for immediate UI display
      final tempMsg = MessageModel(
        msgId,
        autoId: 0,
        type: msgType,
        fromId: data['from'],
        toId: data['to'],
        payload: payload,
        createdAt: data['created_at'],
        isAuthor: isFromCurrentUser ? 1 : 0,
        topicId: data['topic_id'] ?? 0,
        conversationUk3: tempConv.uk3,
        status: IMBoyMessageStatus.delivered,
      );
      iPrint('⏱️ [4] 消息对象构造完成: +${DateTimeHelper.millisecond() - startTime}ms');

      // 【修复】不在前台触发 eventBus，避免重复投递
      // 改为只在后台处理完成后触发一次 UI 更新
      // eventBus.fire(tempConv);
      // iPrint('⏱️ [5] eventBus.fire(conv) 完成: +${DateTimeHelper.millisecond() - startTime}ms');

      // 不等待 toTypeMessage，直接用原始消息更新 UI
      // Don't wait for toTypeMessage, update UI with raw message immediately
      // 【修复】不在前台触发 eventBus，避免重复投递
      // eventBus.fire(tempMsg);
      // iPrint('⏱️ [6] eventBus.fire(msg) 完成: +${DateTimeHelper.millisecond() - startTime}ms');

      // 后台异步处理数据存储和完整消息转换（不阻塞UI）
      // Process data storage and full message conversion asynchronously in background (non-blocking)
      await _processMessageInBackground(data, payload, tempConv, tempMsg, repo);
    } finally {
      // 【修复】立即清理标记，不再延迟 5 秒
      // 立即清理可以避免正常的重复消息被错误过滤
      _receivingMessages.remove(receivingMsgKey);
    }
  }

  /// 正在接收的消息集合（用于快速去重，不阻塞UI）
  /// Set of messages being received (for fast deduplication, non-blocking)
  final Set<String> _receivingMessages = <String>{};

  /// 正在加载的消息ID集合（用于防止 page_view 加载时重复显示）
  /// Set of message IDs being loaded (to prevent duplicate display during page_view loading)
  final Set<String> _loadingMessageIds = <String>{};

  /// 添加正在加载的消息ID
  /// Add message ID to loading set
  void addLoadingMessageId(String msgId) {
    _loadingMessageIds.add(msgId);
  }

  /// 移除正在加载的消息ID
  /// Remove message ID from loading set
  void removeLoadingMessageId(String msgId) {
    _loadingMessageIds.remove(msgId);
  }

  /// 检查消息是否正在加载
  /// Check if message is being loaded
  bool isLoadingMessage(String msgId) {
    return _loadingMessageIds.contains(msgId);
  }

  /// 最近接收的消息内容哈希（用于检测内容重复但 msg_id 不同的消息）
  /// Map: contentHash -> msgId
  final Map<String, String> _recentMessageContents = <String, String>{};

  /// 生成消息内容的哈希值（用于去重）
  /// Generate content hash for deduplication
  /// 使用非加密的关键字段：from, to, type, msg_type, created_at, client_send_ts
  String _generateContentHash(Map data) {
    final from = data['from']?.toString() ?? '';
    final to = data['to']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final createdAt = data['created_at']?.toString() ?? '';

    final payload = data['payload'] as Map?;
    final msgType = payload?['msg_type']?.toString() ?? '';
    final clientSendTs = payload?['client_send_ts']?.toString() ?? '';

    // 使用关键字段生成哈希（不包含加密的文本内容）
    // 客户端发送时间戳是唯一的，如果相同说明是同一消息
    return '$from:$to:$type:$msgType:$createdAt:$clientSendTs';
  }

  /// 清理过期的内容哈希缓存
  /// Clean up expired content hash cache
  void _cleanupExpiredContentHashes() {
    _recentMessageContents.clear();
  }

  /// 群组信息内存缓存（用于快速显示，减少网络请求）
  /// Group info memory cache (for fast display, reduce network requests)
  final Map<String, GroupModel> _groupCache = {};

  /// 缓存过期时间（5分钟）
  /// Cache expiration time (5 minutes)
  static const _groupCacheExpiration = 5 * 60 * 1000;

  /// 缓存时间戳
  /// Cache timestamps
  final Map<String, int> _groupCacheTime = {};

  /// 在后台异步处理消息数据存储
  /// Process message data storage asynchronously in background
  Future<void> _processMessageInBackground(
    Map data,
    Map<String, dynamic> payload,
    ConversationModel tempConv,
    MessageModel tempMsg,
    MessageRepo repo,
  ) async {
    final msgId = data['id'] as String;
    final msgType = data['type'];

    try {
      // 并行获取 peer 信息和检查用户状态
      // Parallel fetch peer info and check user status
      final results = await Future.wait([
        _fetchPeerInfo(msgType, data),
        _isUserCurrentlyInChat(tempConv),
      ]);

      final peerInfo = results[0] as Map<String, String>;
      final isUserInChat = results[1] as bool;

      // 更新会话信息
      // Update conversation with complete peer info
      final conv = ConversationModel(
        peerId: peerInfo['peerId']!,
        avatar: peerInfo['avatar']!,
        title: peerInfo['title']!,
        subtitle: tempConv.subtitle,
        type: msgType,
        msgType: tempConv.msgType,
        lastMsgId: msgId,
        lastTime: tempConv.lastTime,
        unreadNum: tempConv.unreadNum,
        id: 0,
      );
      final savedConv = await _conversationRepo.save(conv);

      // 保存消息到 sqlite
      // Persist message to local DB
      final msg = MessageModel(
        msgId,
        autoId: 0,
        type: msgType,
        fromId: data['from'],
        toId: data['to'],
        payload: payload,
        createdAt: data['created_at'],
        isAuthor: tempMsg.isAuthor,
        topicId: tempMsg.topicId,
        conversationUk3: savedConv.uk3,
        status: IMBoyMessageStatus.delivered,
      );
      final existed = await repo.save(msg);

      // 【修复】如果消息已存在（count > 0），跳过后续处理
      // save 方法返回的是数据库中已存在的记录数
      // 如果 count > 0，说明消息已存在，只是更新了数据，不需要触发通知
      if (existed != null && existed > 0) {
        iPrint('⚠️ 消息已存在（数据库检查），跳过后续处理: $msgId, count=$existed');
        return;
      }

      // 更新未读计数
      // Update unread count
      final isFromCurrentUser = data['from'] == UserRepoLocal.to.currentUid;
      if (!isUserInChat && !isFromCurrentUser) {
        await _conversationLogic.increaseConversationRemind(savedConv, 1);
      }

      // 再次触发 UI 更新以显示完整的 peer 信息
      // Trigger UI update again to show complete peer info
      eventBus.fire(savedConv);
      final tMsg = await msg.toTypeMessage();
      eventBus.fire(tMsg);

      iPrint('✅ 消息后台处理完成: $msgId, peer: ${peerInfo['title']}');
    } catch (e, stack) {
      iPrint('❌ 消息后台处理失败: $msgId, 错误: $e');
      iPrint('堆栈: $stack');

      // 处理失败，从 UI 中移除该消息
      // Failed to process, remove message from UI
      _handleMessageProcessingFailure(msgId, msgType, tempConv, e);
    }
  }

  /// 处理消息处理失败的情况
  /// Handle message processing failure
  void _handleMessageProcessingFailure(
    String msgId,
    String msgType,
    ConversationModel tempConv,
    dynamic error,
  ) {
    try {
      iPrint('🔧 开始清理失败的消息: $msgId');

      // 构造删除消息的事件通知 UI
      // Construct delete message event to notify UI
      final deleteEvent = {
        'action': 'delete_message',
        'msg_id': msgId,
        'conversation_uk3': tempConv.uk3,
        'error': error.toString(),
      };

      // 触发 UI 删除该消息
      // Trigger UI to delete this message
      eventBus.fire(deleteEvent);

      // 如果这是最后一条消息，需要回退会话信息
      // If this was the last message, need to rollback conversation
      // 这里发送一个特殊事件让会话列表更新
      eventBus.fire({
        'action': 'rollback_conversation',
        'peer_id': tempConv.peerId,
        'type': msgType,
        'last_msg_id': tempConv.lastMsgId,
      });

      iPrint('✅ 失败消息清理完成: $msgId');
    } catch (e) {
      iPrint('❌ 清理失败消息时出错: $e');
    }
  }

  /// 公共方法：手动从 UI 移除指定消息（供 UI 层调用）
  /// Public method: manually remove message from UI (for UI layer to call)
  void removeMessageFromUI(String msgId, String conversationUk3) {
    eventBus.fire({
      'action': 'delete_message',
      'msg_id': msgId,
      'conversation_uk3': conversationUk3,
    });
  }

  /// 并行获取 peer 信息（带缓存优化）
  /// Fetch peer info in parallel with cache optimization
  Future<Map<String, String>> _fetchPeerInfo(String msgType, Map data) async {
    String peerId, avatar, title;

    if (msgType == 'C2G') {
      peerId = data['to'];

      // 检查内存缓存
      // Check memory cache first
      final nowMs = DateTimeHelper.millisecond();
      final cachedTime = _groupCacheTime[peerId] ?? 0;
      GroupModel? g;

      if (_groupCache.containsKey(peerId) && (nowMs - cachedTime < _groupCacheExpiration)) {
        // 使用缓存的群组信息
        // Use cached group info
        g = _groupCache[peerId];
        iPrint('✅ 使用群组缓存: $peerId');
      } else {
        // 缓存过期或不存在，从数据库/网络获取
        // Cache expired or not exists, fetch from DB/network
        g = await GroupDetailLogic().detail(gid: peerId);

        // 更新缓存
        // Update cache
        if (g != null) {
          _groupCache[peerId] = g;
          _groupCacheTime[peerId] = nowMs;

          // 限制缓存大小，防止内存泄漏（最多缓存100个群组）
          // Limit cache size to prevent memory leak (max 100 groups)
          if (_groupCache.length > 100) {
            final oldestKey = _groupCacheTime.keys.first;
            _groupCache.remove(oldestKey);
            _groupCacheTime.remove(oldestKey);
          }
        }
      }

      avatar = g?.avatar ?? '';
      title = g?.title ?? '群聊';
    } else {
      peerId = data['from'];
      final ct = await _contactRepo.findByUid(data['from']);
      avatar = ct?.avatar ?? '';
      title = ct?.title ?? '用户';
    }

    return {
      'peerId': peerId,
      'avatar': avatar,
      'title': title,
    };
  }

  /// 清空群组缓存（用于群组信息更新后刷新）
  /// Clear group cache (for refresh after group info update)
  void clearGroupCache({String? groupId}) {
    if (groupId != null) {
      _groupCache.remove(groupId);
      _groupCacheTime.remove(groupId);
      iPrint('🗑️ 清空群组缓存: $groupId');
    } else {
      _groupCache.clear();
      _groupCacheTime.clear();
      iPrint('🗑️ 清空所有群组缓存');
    }
  }

  /// Handle server-side ACK for sent messages
  /// 处理服务端发送确认
  Future<void> _receiveServerAck(Map data) async {
    final msgId = data['id'] as String;
    final type = data['type'] as String;

    // 【改进】添加SERVER_ACK接收日志
    iPrint('📥 [SERVER_ACK] 收到服务端ACK: msgId=$msgId, type=$type');

    // 【重要】从重试队列中移除该消息，避免重复发送
    if (Get.isRegistered<MessageRetry>()) {
      MessageRetry.to.removeFromRetryQueue(msgId);
      iPrint('✅ [SERVER_ACK] 已从重试队列移除: msgId=$msgId');
    }

    final repo = to.getMessageRepo(type);
    final msg = await to.updateStatus(repo, msgId, IMBoyMessageStatus.sent);

    if (msg != null) {
      // 【改进】确认消息状态已更新
      iPrint('✅ [SERVER_ACK] 消息状态已更新为 sent: msgId=$msgId');

      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([await msg.toTypeMessage()]);

      // 确保会话列表中的lastMsgStatus也得到更新
      await _conversationLogic.updateConversationByMsgId(msgId, {
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
      });
    } else {
      // 【改进】消息未找到
      iPrint('⚠️ [SERVER_ACK] 消息未找到: msgId=$msgId');
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
    final code = int.tryParse(data['code']?.toString() ?? '') ?? 0;
    // * Msg2.code = 1 无需弹窗错误，可以记录日志后直接忽略错误 Msg2.payload 可能为空，不需要处理
    // * Msg2.code = 2 带title弹窗，Msg2.payload 不能为空 必须包含 title content 字段
    // * Msg2.code = 3 无title弹窗，Msg2.payload 不能为空 必须包含 content 字段
    if (ErrorCode.shouldReLogin(code)) {
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
  void addToRetryQueue(String messageId, String type) =>
      retry.addToRetryQueue(messageId, type);
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
