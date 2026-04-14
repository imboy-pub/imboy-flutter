import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/service/active_conversation_notifier.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/message_conversation_utils.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/config/init.dart' show AppInitializer, navigateToSignIn;
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/event_subscription_manager.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/group/group_detail/group_detail_service.dart';

import 'message_actions.dart';
import 'message_s2c.dart';
import 'message_webrtc.dart';
import 'notification.dart';
import 'notification_provider.dart';

// Legacy compatibility surface. External callers should now import
// `package:imboy/modules/messaging/public.dart`; this file remains the
// implementation behind the messaging facade until internal migration ends.
/// Temporary compatibility wrapper for the messaging module shell.
/// New callers should prefer `package:imboy/modules/messaging/public.dart`.
///
/// MessageService
///
/// 负责消息处理的核心服务，包括可靠传递、状态同步、UI 通知。
/// Core service for message handling: reliable delivery, state sync, UI updates.
///
/// Compatibility note:
/// Prefer importing `package:imboy/modules/messaging/public.dart` in upper
/// layers. This service remains as the legacy implementation behind the
/// messaging module facade during the migration.
///
/// ## 架构说明
///
/// 此服务采用**模块化架构**，原有功能已拆分到以下文件：
/// - `message_actions.dart`: 消息操作，撤回、编辑等功能
/// - `message_webrtc.dart`: WebRTC 消息处理
/// - `message_s2c.dart`: 服务端到客户端消息
/// - `ack_manager.dart`: ACK 确认管理
///
/// ## 职责范围
///
/// ### 核心职责：
/// 1. **消息接收与分发**：处理来自 WebSocket 的消息（C2C、C2G、C2S、S2C）
/// 2. **消息状态管理**：更新消息状态（待发送、已发送、已送达、已读）
/// 3. **UI 通知**：通过 EventBus 通知 UI 层更新
/// 4. **消息去重**：防止重复消息显示
/// 5. **网络状态监控**：监听 WebSocket 连接状态，处理离线/在线切换
///
/// ### 委托的职责：
/// - **撤回/编辑**：委托给 `MessageActions`
/// - **WebRTC**：委托给 `MessageWebrtc`
/// - **ACK 发送**：委托给 `AckManager`
///
/// ## 相关服务
///
/// - `WebSocketService`: WebSocket 连接管理
/// - `MessageActions`: 消息操作（撤回、编辑）
/// - `AckManager`: ACK 确认管理
/// - `MessageOfflineService`: 离线消息处理
///
/// MessageService
///
/// 负责消息处理的核心服务，包括可靠传递、状态同步、UI 通知。
/// Core service for message handling: reliable delivery, state sync, UI updates.
///
/// ## 架构说明
///
/// 此服务采用**模块化架构**，原有功能已拆分到以下文件：
/// - `message_actions.dart`: 消息操作，撤回、编辑等功能
/// - `message_webrtc.dart`: WebRTC 消息处理
/// - `message_s2c.dart`: 服务端到客户端消息
/// - `ack_manager.dart`: ACK 确认管理
///
/// ## 职责范围
///
/// ### 核心职责：
/// 1. **消息接收与分发**：处理来自 WebSocket 的消息（C2C、C2G、C2S、S2C）
/// 2. **消息状态管理**：更新消息状态（待发送、已发送、已送达、已读）
/// 3. **UI 通知**：通过 EventBus 通知 UI 层更新
/// 4. **消息去重**：防止重复消息显示
/// 5. **网络状态监控**：监听 WebSocket 连接状态，处理离线/在线切换
///
/// ### 委托的职责：
/// - **撤回/编辑**：委托给 `MessageActions`
/// - **WebRTC**：委托给 `MessageWebrtc`
/// - **ACK 发送**：委托给 `AckManager`
///
/// ## 相关服务
///
/// - `WebSocketService`: WebSocket 连接管理
/// - `MessageActions`: 消息操作（撤回、编辑）
/// - `AckManager`: ACK 确认管理
/// - `MessageOfflineService`: 离线消息处理
///
/// ## 使用方式
///
/// ```dart
/// // 获取服务实例（单例）
/// final messageService = MessageService();
///
/// // 或者使用静态访问器
/// MessageService.instance.processMessage(type, data);
/// ```
class MessageService with EventSubscriptionManager {
  /// 单例实例
  static MessageService? _instance;

  /// 获取单例实例
  static MessageService get instance {
    _instance ??= MessageService._internal();
    return _instance!;
  }

  /// 静态访问器
  static MessageService get to => instance;

  /// 私有构造函数
  MessageService._internal() {
    _init();
  }

  /// 委托给各个模块
  MessageActions get actions => MessageActions.instance;
  MessageWebrtc get webrtc => MessageWebrtc.instance;

  final MessageActions _messageActions = MessageActions.instance;

  // 共享 ProviderContainer — 必须在 run() 中通过 setProviderContainer 注入
  // 与 Widget 树的 UncontrolledProviderScope 共享同一个容器，确保状态同步
  static ProviderContainer _providerContainer = ProviderContainer();

  /// 注入应用级 ProviderContainer（在 run.dart 中调用）
  /// 确保 MessageService 与 UI 共享同一个 Riverpod 状态
  static void setProviderContainer(ProviderContainer container) {
    _providerContainer = container;
  }

  // 获取会话逻辑的 Riverpod Provider
  ConversationNotifier get _conversationNotifier =>
      _providerContainer.read(conversationProvider.notifier);

  // 获取活跃会话管理的 Riverpod Provider
  ActiveConversationNotifier get _activeConversationNotifier =>
      _providerContainer.read(activeConversationProvider.notifier);

  // 获取通知服务的 Riverpod Provider
  NotificationService get _notificationService =>
      _providerContainer.read(notificationServiceProvider);

  // 缓存常用仓库实例
  final ConversationRepo _conversationRepo = ConversationRepo();
  final ContactRepo _contactRepo = ContactRepo();

  /// 根据消息类型获取对应的 MessageRepo
  MessageRepo getMessageRepo(String type) =>
      MessageRepo(tableName: MessageRepo.getTableName(type));

  // 本地添加消息锁，防止并发重复添加
  bool addMessageLock = false;

  // 网络状态监听（使用 Stream 替代 RxBool）
  bool _isOnline = true;
  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();

  /// 网络在线状态流
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;

  /// 当前在线状态
  bool get isOnline => _isOnline;

  // 消息发送进度跟踪
  final Map<String, double> sendingProgress = {};

  // Timer 用于定期清理过期的内容哈希缓存
  Timer? _cleanupTimer;

  /// 内部初始化方法
  void _init() {
    // 延迟初始化网络监控，避免在服务注册阶段访问其他服务
    Future.microtask(() => initNetworkMonitoring());

    // 定期清理过期的内容哈希缓存
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cleanupExpiredContentHashes(),
    );

    // 订阅 WebSocket 消息接收事件
    subscribeTo(
      AppEventBus.on<WebSocketMessageReceivedEvent>().listen((event) {
        processMessage(event.type, event.data);
      }),
    );

    // 订阅消息状态更新请求事件
    subscribeTo(
      AppEventBus.on<MessageStatusUpdateRequestedEvent>().listen((event) {
        _handleStatusUpdateRequest(event);
      }),
    );
  }

  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    _onlineStatusController.close();
    cancelAllSubscriptions();
  }

  /// 初始化网络状态监控
  void initNetworkMonitoring() {
    subscribeTo(
      AppEventBus.on<WebSocketStatusChangedEvent>().listen((event) {
        final isConnected = event.status == 'connected';
        _isOnline = isConnected;
        _onlineStatusController.add(isConnected);
        if (isConnected) {
          AppEventBus.fire(
            RetryMessagesRequestedEvent(
              source: 'WebSocketConnected',
              reason: 'WebSocket 连接恢复',
            ),
          );
          unawaited(
            AppInitializer.triggerGroupMembershipSelfHeal(
              source: 'ws_connected',
            ),
          );
        }
      }),
    );
  }

  /// 处理消息状态更新请求事件
  Future<void> _handleStatusUpdateRequest(
    MessageStatusUpdateRequestedEvent event,
  ) async {
    try {
      final repo = getMessageRepo(event.messageType);
      await updateStatus(repo, event.messageId, event.newStatus);

      if (event.notifyUI) {
        final updatedMsg = await repo.find(event.messageId);
        if (updatedMsg != null) {
          final typeMessage = await updatedMsg.toTypeMessage();
          AppEventBus.fireData([typeMessage], 'List<Message>');
        }
      }
    } catch (e) {
      iPrint(
        '❌ [STATUS_UPDATE] 更新消息状态失败: messageId=${event.messageId}, status=${event.newStatus}, error=$e',
      );
    }
  }

  /// 改变消息状态
  Future<MessageModel?> changeStatus(String tb, String msgId, int status) {
    final repo = MessageRepo(tableName: tb);
    return updateStatus(repo, msgId, status);
  }

  /// 更新消息状态并同步会话
  Future<MessageModel?> updateStatus(
    MessageRepo repo,
    String msgId,
    int status,
  ) async {
    await repo.update({'id': msgId, 'status': status});
    iPrint('> message_core: 更新消息状态 $msgId 为 $status');
    await _conversationNotifier.updateConversationByMsgId(msgId, {
      ConversationRepo.lastMsgStatus: status,
    });
    return repo.find(msgId);
  }

  /// 获取消息发送进度
  double getSendingProgress(String messageId) {
    return sendingProgress[messageId] ?? 0.0;
  }

  /// 更新消息发送进度
  void updateSendingProgress(String messageId, double progress) {
    sendingProgress[messageId] = progress;
    AppEventBus.fireData({
      'progress_update': messageId,
      'progress': progress,
    }, 'ProgressUpdate');
  }

  /// 清理发送进度
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

    // WebSocket API v2.0: 从顶层读取 action 字段（用于 S2C 消息）
    final action = data['action']?.toString();

    // 【重构】所有 ACK 统一在 websocket.dart 中处理，此处不再发送
    if (type.startsWith('WEBRTC_')) {
      await webrtc.handleWebRTC(type, data);
    } else if (type.endsWith('_SERVER_ACK')) {
      await _receiveServerAck(data);
    } else if (type == 'S2C') {
      // S2C 消息优先走 switchS2C（包含所有 S2C action 处理）
      await MessageS2CService.switchS2C(data);
    } else if (action != null && action.isNotEmpty) {
      // C2C/C2G/C2S 的 action 走 handleActionMessage
      await _messageActions.handleActionMessage(action, data);
    } else {
      switch (type) {
        case 'C2C':
        case 'C2G':
        case 'C2S':
          await _receiveMessage(data);
          break;
        case 'ERROR':
          await _handleError(data);
          break;
        default:
          iPrint('Unhandled message type: $type');
      }
    }
  }

  /// 处理 C2C/C2G 消息接收（WebSocket API v2.0）
  ///
  /// ## v2.0 API 规范
  /// - **顶层字段**：`msg_type`（消息类型）、`e2ee`（端到端加密元数据）
  /// - **payload**：
  ///   - 普通（非 E2EE）消息：JSON 对象，包含消息内容
  ///   - E2EE 消息：密文字符串（格式：`base64(nonce).base64(ciphertext)`）
  /// - **e2ee 元数据**：分离的加密参数（nonce、keys 等），不包含密文
  ///
  /// ## 处理流程
  /// 1. 检查是否是 S2C 消息，如果是则委托给 MessageS2CService
  /// 2. 从顶层读取 `msg_type`（不再从 payload 读取）
  /// 3. 检查是否有 `e2ee` 字段（判断是否为 E2EE 消息）
  /// 4. 如果是 E2EE 消息，调用 `_handleE2EEMessage` 解密
  /// 5. 根据 `msg_type` 分发到不同的处理方法
  ///
  /// ## 支持的消息类型
  /// - `text`：文本消息
  /// - `image`：图片消息
  /// - `voice`：语音消息
  /// - `video`：视频消息
  /// - `file`：文件消息
  /// - `quote`：引用消息
  /// - `location`：位置消息
  /// - `custom`：自定义消息
  /// - `e2ee`：端到端加密消息
  ///
  /// ## v2.0 消息格式示例
  /// ```json
  /// {
  ///   "id": "msg123",
  ///   "type": "C2C",
  ///   "msg_type": "text",
  ///   "from": "user1",
  ///   "to": "user2",
  ///   "created_at": 1234567890,
  ///   "payload": {
  ///     "text": "Hello"
  ///   }
  /// }
  /// ```
  ///
  /// ## v2.0 E2EE 消息格式示例
  /// ```json
  /// {
  ///   "id": "msg123",
  ///   "type": "C2C",
  ///   "msg_type": "text",
  ///   "from": "user1",
  ///   "to": "user2",
  ///   "created_at": 1234567890,
  ///   "e2ee": {
  ///     "e2ee": true,
  ///     "e2ee_ver": 1,
  ///     "e2ee_suite": "RSA-OAEP-256+AES-256-GCM",
  ///     "nonce": "base64_nonce",
  ///     "keys": [{"did": "deviceA", "kid": "key_v1", "wrap_alg": "RSA-OAEP-256", "ek": "base64_ek"}]
  ///   },
  ///   "payload": "base64_nonce.base64_ciphertext"
  /// }
  /// ```
  Future<void> _receiveMessage(Map data) async {
    final startTime = DateTimeHelper.millisecond();
    final msgId = parseModelString(data['id']);
    final msgType = parseModelString(data['type']);
    if (msgId.isEmpty || msgType.isEmpty) {
      iPrint('❌ [消息格式] 缺少 id/type 字段: id=$msgId, type=$msgType');
      return;
    }
    iPrint('⏱️ [1] _receiveMessage 开始: $startTime, msgId: $msgId');

    // ACK已在websocket.dart:_onMessage中发送，此处不再重复发送
    // ACK发送已移至websocket.dart，确保在最早期发送，避免任何处理延迟

    // v2.0: 从顶层读取 e2ee 字段（可能是字符串形式的 JSON）
    final e2eeRaw = data['e2ee'];
    Map<String, dynamic>? e2ee;

    // 解析 e2ee（可能是字符串或 Map）
    if (e2eeRaw != null && e2eeRaw.toString().isNotEmpty) {
      if (e2eeRaw is String) {
        try {
          e2ee = jsonDecode(e2eeRaw);
          if (e2ee is! Map) {
            e2ee = null;
          } else {
            e2ee = e2ee!.cast<String, dynamic>();
          }
        } catch (e) {
          iPrint('❌ [E2EE] e2ee 字符串解析失败: msgId=$msgId, error=$e');
        }
      } else if (e2eeRaw is Map) {
        e2ee = e2eeRaw.cast<String, dynamic>();
      }
    }

    // v2.0: 处理 E2EE 消息（payload 为字符串）
    // 或普通消息（payload 为 Map）
    Map<String, dynamic>? payload;
    final payloadRaw = data['payload'];

    // 归一化 created_at 时间戳（需要在解密前准备）
    // Normalize timestamp field
    var createdAt = data['created_at'];
    if (createdAt is String) {
      createdAt = DateTimeHelper.rfc3339ToMillisecond(createdAt);
      data['created_at'] = createdAt;
    }
    final createdAtMs = parseModelInt(
      data['created_at'],
      defaultValue: DateTimeHelper.millisecond(),
    );

    // v2.0: E2EE 解密处理（复用前面解析的 e2ee 变量）
    // 检查是否有 e2ee 字段（表示消息已加密）
    if (e2ee != null && e2ee.isNotEmpty) {
      // E2EE 加密消息：payload 应该是密文字符串
      if (payloadRaw is! String || payloadRaw.isEmpty) {
        iPrint('❌ [E2EE] E2EE 消息的 payload 应该是密文字符串: msgId=$msgId');
        return;
      }

      // v2.0 E2EE 格式：使用新的解密方法
      final decryptedPayload = await _handleE2EEMessage(
        data: data,
        msgId: msgId,
        msgType: msgType,
        createdAtMs: createdAtMs,
      );

      // 解密后的 payload
      payload = decryptedPayload;
    } else {
      // 普通（非 E2EE）消息：payload 应该是 Map
      if (payloadRaw is Map) {
        payload = parseModelJsonMap(payloadRaw);
      } else if (payloadRaw is String && payloadRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(payloadRaw);
          if (decoded is Map) {
            payload = parseModelJsonMap(decoded);
          }
        } catch (e) {
          iPrint('❌ [Payload] 无法解析 payload 字符串: msgId=$msgId, error=$e');
        }
      }
    }

    if (payload == null) return;
    data['payload'] = payload;

    final senderDid = data['sender_did'];
    if (senderDid != null && payload['sender_did'] == null) {
      payload['sender_did'] = senderDid;
    }
    final senderDtype = data['sender_dtype'];
    if (senderDtype != null && payload['sender_dtype'] == null) {
      payload['sender_dtype'] = senderDtype;
    }

    // 计算端到端延迟：从发送客户端到接收客户端的总延迟
    // Calculate end-to-end latency: from sender client to receiver client
    if (payload.containsKey('client_send_ts')) {
      final clientSendTs = parseModelInt(payload['client_send_ts']);
      if (clientSendTs > 0) {
        final e2eLatency = startTime - clientSendTs;
        iPrint('📊 [端到端延迟] $msgId: ${e2eLatency}ms (A发送 → B接收)');
      }
    }

    // 确保 payload 为 non-nullable（用于后续调用）
    final nonNullPayload = payload;
    final repo = getMessageRepo(msgType);

    // === 去重检查（廉价内存检查优先，昂贵的数据库查询放最后） ===

    // 1. 检查消息是否正在接收中（TTL 5 秒，内存 Map）
    final receivingMsgKey = '${msgType}_$msgId';
    final now = DateTimeHelper.millisecond();
    const ttlMs = 5000;
    _cleanExpiredReceivingMarks(now, ttlMs);

    if (_receivingMessages.containsKey(receivingMsgKey)) {
      final timestamp = _receivingMessages[receivingMsgKey]!;
      if (now - timestamp < ttlMs) {
        iPrint('消息正在处理中，跳过重复: $msgId');
        return;
      }
      _receivingMessages.remove(receivingMsgKey);
    }
    _receivingMessages[receivingMsgKey] = now;

    // 2. 检查消息是否正在加载（page_view 场景，内存 Set）
    if (_loadingMessageIds.contains(msgId)) {
      iPrint('⚠️ 消息正在加载中（page_view），跳过重复显示: $msgId');
      return;
    }

    // 3. 基于内容的去重检查（LRU 缓存，内存 Map）
    final contentHash = _generateContentHash(data);
    iPrint('🔑 [去重检查] contentHash=$contentHash, msgId=$msgId');

    if (_recentMessageContents.containsKey(contentHash)) {
      final previousMsgId = _recentMessageContents[contentHash]!.msgId;
      iPrint(
        '⚠️ [内容重复] 检测到重复消息: 之前msgId=$previousMsgId, 当前msgId=$msgId, from=${data['from']}, to=${data['to']}, type=$msgType',
      );
      return;
    }
    _addToContentHashCache(contentHash, msgId);

    // 4. 数据库查询（最昂贵的检查，放最后）
    final existing = await repo.find(msgId);
    if (existing != null) {
      iPrint('⚠️ 消息已存在（数据库检查），跳过处理: $msgId');
      return;
    }

    iPrint('⏱️ [3] 去重检查完成: +${DateTimeHelper.millisecond() - startTime}ms');

    try {
      // 先构造基本消息对象用于UI显示（使用默认peer信息）
      // First create basic message for UI display with default peer info
      final peerId = resolveConversationPeerId(
        msgType: msgType,
        data: data,
        currentUid: UserRepoLocal.to.currentUid,
      );
      final isFromCurrentUser = data['from'] == UserRepoLocal.to.currentUid;

      // v2.0: 从顶层读取 msg_type（不再兼容 v1.0）
      final messageType = data['msg_type']?.toString() ?? '';
      if (messageType.isEmpty) {
        iPrint('❌ [消息格式] 缺少 msg_type 字段: msgId=$msgId');
        return;
      }

      // v2.0: 根据消息类型进行特定的处理（日志记录、特殊逻辑等）
      _dispatchMessageByType(messageType, data, nonNullPayload);

      // v2.0: 使用 switch 处理不同的 msg_type，构造会话副标题
      String subtitle = _getMessageSubtitle(messageType, nonNullPayload);

      // 创建临时会话对象用于立即显示
      // Create temporary conversation for immediate UI display
      final tempConv = ConversationModel(
        peerId: parseModelInt(peerId),
        avatar: '', // 稍后异步更新
        title: msgType == 'C2G' ? t.groupChat : t.user, // 稍后异步更新
        subtitle: subtitle,
        type: msgType,
        msgType: messageType,
        lastMsgId: parseModelInt(msgId),
        lastTime: data['created_at'] ?? DateTimeHelper.millisecond(),
        unreadNum: 0,
        id: 0,
      );

      // 创建临时消息对象用于立即显示
      // Create temporary message for immediate UI display
      final tempMsg = MessageModel(
        parseModelInt(data['id']),
        autoId: 0,
        type: msgType,
        fromId: parseModelInt(data['from']),
        toId: parseModelInt(data['to']),
        payload: nonNullPayload,
        createdAt: parseModelInt(
          data['created_at'],
          defaultValue: DateTimeHelper.millisecond(),
        ),
        isAuthor: isFromCurrentUser ? 1 : 0,
        topicId: parseModelInt(data['topic_id']),
        conversationUk3: tempConv.uk3,
        status: IMBoyMessageStatus.delivered,
        msgType: parseModelNullableString(data['msg_type']), // ✅ 修复：传递 msg_type
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
      await _processMessageInBackground(
        data,
        nonNullPayload,
        tempConv,
        tempMsg,
        repo,
      );
    } finally {
      // 优化：TTL 自动过期，无需手动清理
      // 清理由 _cleanExpiredReceivingMarks 自动处理
    }
  }

  /// 正在接收的消息集合（用于快速去重，不阻塞UI）
  /// Set of messages being received (for fast deduplication, non-blocking)
  /// 优化：使用 Map 存储时间戳，支持 TTL 自动过期
  final Map<String, int> _receivingMessages =
      <String, int>{}; // msgKey -> timestamp

  /// 清理过期的接收标记
  /// Clean up expired receiving marks
  void _cleanExpiredReceivingMarks(int now, int ttlMs) {
    if (_receivingMessages.isEmpty) return;

    final expiredKeys = <String>[];
    for (final entry in _receivingMessages.entries) {
      if (now - entry.value > ttlMs) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _receivingMessages.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      iPrint('🧹 [DEDUP] 清理 ${expiredKeys.length} 个过期接收标记');
    }
  }

  /// 手动清理接收标记（供特殊情况使用）
  void clearReceivingMark(String receivingMsgKey) {
    _receivingMessages.remove(receivingMsgKey);
    iPrint('🧹 [DEDUP] 手动清理接收标记: $receivingMsgKey');
  }

  /// 清理所有接收标记（用于测试或调试）
  void clearAllReceivingMarks() {
    final count = _receivingMessages.length;
    _receivingMessages.clear();
    iPrint('🧹 [DEDUP] 清理所有接收标记: $count 个');
  }

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
  /// Map: contentHash -> (msgId, timestamp)
  final Map<String, _ContentHashEntry> _recentMessageContents =
      <String, _ContentHashEntry>{};

  /// 内容哈希缓存 TTL（10 分钟）
  static const _contentHashTtlMs = 10 * 60 * 1000;

  /// 生成消息内容的哈希值（用于去重）
  /// Generate content hash for deduplication
  ///
  /// 优先使用 msgId 作为唯一标识（最可靠的去重方式）
  /// 只有在没有 msgId 的情况下，才回退到基于内容字段的哈希
  String _generateContentHash(Map data) {
    // 优先使用 msgId 进行去重（最可靠）
    final msgId = data['id']?.toString() ?? '';

    if (msgId.isNotEmpty) {
      // 【调试】输出使用 msgId 的情况
      // iPrint('🔑 [生成哈希] 使用msgId: $msgId');
      return msgId;
    }

    // 如果没有 msgId，使用组合字段生成哈希（回退方案）
    final from = data['from']?.toString() ?? '';
    final to = data['to']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final createdAt = data['created_at']?.toString() ?? '';

    // v2.0: 只从顶层读取 msg_type
    final msgType = data['msg_type']?.toString() ?? '';
    final payload = parseModelJsonMap(data['payload']);
    final clientSendTs = payload?['client_send_ts']?.toString() ?? '';

    // 使用关键字段生成哈希（不包含加密的文本内容）
    final hash = '$from:$to:$type:$msgType:$createdAt:$clientSendTs';

    // 【调试】输出使用组合字段的情况（应该很少发生）
    // iPrint('🔑 [生成哈希] 使用组合字段: $hash (msgId为空)');

    return hash;
  }

  /// 添加到缓存
  void _addToContentHashCache(String hash, String msgId) {
    _recentMessageContents[hash] = _ContentHashEntry(
      msgId: msgId,
      timestamp: DateTimeHelper.millisecond(),
    );
  }

  /// 清理过期的内容哈希缓存（TTL 10 分钟）
  void _cleanupExpiredContentHashes() {
    final now = DateTimeHelper.millisecond();
    _recentMessageContents.removeWhere(
      (_, entry) => now - entry.timestamp > _contentHashTtlMs,
    );
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
    final msgId = parseModelString(data['id']);
    final msgType = parseModelString(data['type']); // 消息会话类型 (C2C/C2G/C2S)
    // WebSocket API v2.0: 从顶层读取消息内容类型
    final rawMsgType = data['msg_type']?.toString(); // voice/text/image 等

    // 【重构】使用 MessageTypeNormalizer 进行类型归一化
    // 仅做合法性校验与空白处理（不做旧命名兼容）
    final msgContentType = MessageTypeNormalizer.normalize(
      msgType: rawMsgType,
      payload: payload,
    );

    try {
      // 并行获取 peer 信息和检查用户状态
      // Parallel fetch peer info and check user status
      final results = await Future.wait([
        _fetchPeerInfo(msgType, data),
        _isUserCurrentlyInChat(tempConv),
      ]);

      final peerInfo = results[0] as Map<String, String>;
      final isUserInChat = parseModelBool(results[1]);

      // 更新会话信息
      // Update conversation with complete peer info
      final isFromCurrentUser = data['from'] == UserRepoLocal.to.currentUid;
      final unreadIncrement = computeConversationUnreadIncrement(
        isFromCurrentUser: isFromCurrentUser,
        isUserInChat: isUserInChat,
      );
      // C7-β: 计算 @ 未读增量（与 unread 同短路条件 + mentionIds 判定）
      final mentionIncrement = computeMentionUnreadIncrement(
        isFromCurrentUser: isFromCurrentUser,
        isUserInChat: isUserInChat,
        mentionIds: extractMentionIdsFromPayload(payload),
        currentUid: UserRepoLocal.to.currentUid,
      );

      final conv = ConversationModel(
        peerId: parseModelInt(peerInfo['peerId']),
        avatar: peerInfo['avatar']!,
        title: peerInfo['title']!,
        subtitle: tempConv.subtitle,
        type: msgType,
        msgType: msgContentType, // 【修复】使用修正后的消息类型
        lastMsgId: parseModelInt(msgId),
        lastTime: tempConv.lastTime,
        unreadNum: unreadIncrement,
        mentionUnread: mentionIncrement, // C7-β
        id: 0,
      );
      final savedConv = await _conversationRepo.save(conv);

      // 保存消息到 sqlite
      // Persist message to local DB
      if (kDebugMode) {
        iPrint(
          '🔍 [DEBUG] 保存消息: msgId=$msgId, data[\'msg_type\']=${data['msg_type']}, msgContentType=$msgContentType',
        );
      }
      final msg = MessageModel(
        parseModelInt(msgId),
        autoId: 0,
        type: msgType, // 消息会话类型 (C2C/C2G/C2S)
        fromId: parseModelInt(data['from']),
        toId: parseModelInt(data['to']),
        payload: payload,
        createdAt: parseModelInt(
          data['created_at'],
          defaultValue: DateTimeHelper.millisecond(),
        ),
        isAuthor: tempMsg.isAuthor,
        topicId: parseModelInt(data['topic_id'], defaultValue: tempMsg.topicId),
        conversationUk3: savedConv.uk3,
        status: IMBoyMessageStatus.delivered,
        msgType: msgContentType, // WebSocket API v2.0: 从顶层读取消息内容类型
      );
      final existed = await repo.save(msg);
      if (kDebugMode) {
        iPrint('🔍 [DEBUG] 消息保存完成: msgType=${msg.msgType}, existed=$existed');
      }

      // 【修复】如果消息已存在（count > 0），跳过后续处理
      // save 方法返回的是数据库中已存在的记录数
      // 如果 count > 0，说明消息已存在，只是更新了数据，不需要触发通知
      if (existed != null && existed > 0) {
        iPrint('⚠️ 消息已存在（数据库检查），跳过后续处理: $msgId, count=$existed');
        return;
      }

      // 单一来源：以会话快照统一同步会话与提醒，避免局部字段漂移
      _conversationNotifier.applyConversationSnapshot(savedConv);

      // 再次触发 UI 更新以显示完整的 peer 信息
      // Trigger UI update again to show complete peer info
      AppEventBus.fireData(savedConv);
      final tMsg = await msg.toTypeMessage();
      AppEventBus.fireData(tMsg);

      // 触发消息通知（如果需要）
      // 只有当用户不在当前会话且消息不是自己发送的时候才显示通知
      // C7-α-2：用户为该会话开启了免打扰（isMuted > 0）时也抑制通知
      if (!isFromCurrentUser &&
          !isUserInChat &&
          !shouldSuppressNotification(isMuted: savedConv.isMuted)) {
        _showMessageNotification(
          msg: msg,
          senderName: peerInfo['title'] ?? '',
          conversationUk3: savedConv.uk3,
          peerId: peerInfo['peerId'] ?? '',
          msgType: msgType,
        );
      }

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
      AppEventBus.fireData(deleteEvent);

      // 如果这是最后一条消息，需要回退会话信息
      // If this was the last message, need to rollback conversation
      // 这里发送一个特殊事件让会话列表更新
      AppEventBus.fireData({
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
    AppEventBus.fireData({
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
      peerId = parseModelString(data['to']);

      // 检查内存缓存
      // Check memory cache first
      final nowMs = DateTimeHelper.millisecond();
      final cachedTime = _groupCacheTime[peerId] ?? 0;
      GroupModel? g;

      if (_groupCache.containsKey(peerId) &&
          (nowMs - cachedTime < _groupCacheExpiration)) {
        // 使用缓存的群组信息
        // Use cached group info
        g = _groupCache[peerId];
        iPrint('✅ 使用群组缓存: $peerId');
      } else {
        // 缓存过期或不存在，从数据库/网络获取
        // Cache expired or not exists, fetch from DB/network
        g = await GroupDetailService().detail(gid: peerId);

        // 更新缓存
        // Update cache
        if (g != null) {
          _groupCache[peerId] = g;
          _groupCacheTime[peerId] = nowMs;

          // 限制缓存大小，防止内存泄漏（最多缓存100个群组）
          // Limit cache size to prevent memory leak (max 100 groups)
          // 驱逐最旧的缓存项（基于时间戳排序）
          if (_groupCache.length > 100) {
            final oldestKey = _groupCacheTime.entries
                .reduce((a, b) => a.value < b.value ? a : b)
                .key;
            _groupCache.remove(oldestKey);
            _groupCacheTime.remove(oldestKey);
          }
        }
      }

      avatar = g?.avatar ?? '';
      title = g?.title ?? '群聊';
    } else {
      peerId = resolveConversationPeerId(
        msgType: msgType,
        data: data,
        currentUid: UserRepoLocal.to.currentUid,
      );
      final ct = await _contactRepo.findByUid(peerId);
      avatar = ct?.avatar ?? '';
      title = ct?.title ?? '用户';
    }

    return {'peerId': peerId, 'avatar': avatar, 'title': title};
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
    final msgId = parseModelString(data['id']);
    final type = parseModelString(data['type']);
    if (msgId.isEmpty || type.isEmpty) return;

    // 【改进】添加SERVER_ACK接收日志
    iPrint('📥 [SERVER_ACK] 收到服务端ACK: msgId=$msgId, type=$type');

    // 【重要】从重试队列中移除该消息，避免重复发送（解耦：通过事件总线）
    // Remove from retry queue to avoid duplicate sending (decoupling: via event bus)
    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: msgId,
        messageType: type,
        reason: 'server_ack',
      ),
    );
    iPrint('✅ [SERVER_ACK] 请求从重试队列移除: msgId=$msgId');

    final repo = getMessageRepo(type);
    final msg = await updateStatus(repo, msgId, IMBoyMessageStatus.sent);

    if (msg != null) {
      // 【改进】确认消息状态已更新
      iPrint('✅ [SERVER_ACK] 消息状态已更新为 sent: msgId=$msgId');

      // 更新会话里面的消息列表的特定消息状态
      // 修复：使用正确的 dataType 'messages' 以匹配监听器
      AppEventBus.fireData([await msg.toTypeMessage()], 'messages');

      // 确保会话列表中的lastMsgStatus也得到更新
      await _conversationNotifier.updateConversationByMsgId(msgId, {
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
      });
    } else {
      // 【改进】消息未找到
      iPrint('⚠️ [SERVER_ACK] 消息未找到: msgId=$msgId');
    }
  }

  /// 检查用户当前是否正在浏览指定会话
  ///
  /// 通过 ActiveConversationNotifier Riverpod Provider 跟踪当前活动会话
  Future<bool> _isUserCurrentlyInChat(ConversationModel conv) async {
    try {
      // 使用 Riverpod Provider 访问活跃会话状态
      return _activeConversationNotifier.isConversationActive(conv.uk3);
    } catch (e) {
      iPrint('❌ [ACTIVE_CONVERSATION] 检查失败: $e');
      return false; // 失败时返回 false，保守增加未读数
    }
  }

  /// 显示消息通知
  ///
  /// 当收到新消息且用户不在当前会话时，显示系统通知
  /// 通知点击后可以跳转到对应的会话
  ///
  /// [msg] 消息模型
  /// [senderName] 发送者昵称
  /// [conversationUk3] 会话 UK3
  /// [peerId] 对方 ID
  /// [msgType] 消息类型（C2C 或 C2G）
  Future<void> _showMessageNotification({
    required MessageModel msg,
    required String senderName,
    required String conversationUk3,
    required String peerId,
    required String msgType,
  }) async {
    try {
      // 获取通知内容
      final content = _getNotificationContent(msg);

      // 调用通知服务显示通知
      await _notificationService.showMessageNotification(
        senderName: senderName,
        content: content,
        conversationUk3: conversationUk3,
        peerId: peerId,
        msgType: msgType,
      );

      iPrint(
        '🔔 [Notification] 消息通知已触发: '
        'sender=$senderName, uk3=$conversationUk3',
      );
    } catch (e) {
      iPrint('❌ [Notification] 显示消息通知失败: $e');
    }
  }

  /// 根据消息类型生成显示文本（通知/副标题通用）
  String _messageTypeLabel(
    String messageType,
    Map<String, dynamic> payload, {
    String fallback = '[消息]',
  }) {
    switch (messageType) {
      case 'text':
        return payload['text']?.toString() ?? '';
      case 'image':
        return '[图片]';
      case 'voice':
        final duration = payload['duration']?.toInt() ?? 0;
        return duration > 0 ? '[语音 $duration"]' : '[语音]';
      case 'video':
        return '[视频]';
      case 'file':
        final filename = payload['filename']?.toString() ?? '';
        return filename.isNotEmpty ? '📄 $filename' : '[文件]';
      case 'quote':
        return payload['quote_text']?.toString() ?? '[引用]';
      case 'location':
        return '[位置] ${payload['title']?.toString() ?? ''}';
      case 'webrtc_audio':
        return '[语音通话]';
      case 'webrtc_video':
        return '[视频通话]';
      case 'revoked':
        return '[消息已撤回]';
      case 'custom':
        return '';
      default:
        final text = payload['text']?.toString();
        return (text != null && text.isNotEmpty) ? text : fallback;
    }
  }

  /// 获取通知内容
  String _getNotificationContent(MessageModel msg) {
    return _messageTypeLabel(
      msg.msgType ?? '',
      msg.payload,
      fallback: '[新消息]',
    );
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
      navigateToSignIn(source: 'message_service_relogin');
    }
  }

  /// v2.0: 根据消息类型构造会话副标题
  String _getMessageSubtitle(String messageType, Map<String, dynamic> payload) {
    return _messageTypeLabel(messageType, payload, fallback: '[消息]');
  }

  // 便捷转发方法

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
  }) =>
      webrtc.changeLocalMsgState(msgId, state, startAt: startAt, endAt: endAt);

  /// 发送撤回消息请求
  /// Send revoke message request.
  Future<bool> sendRevokeMessage(String messageId, String messageType) =>
      actions.sendRevokeMessage(messageId, messageType);

  /// 发送编辑消息请求
  /// Send edit message request.
  Future<bool> sendEditMessage(
    String messageId,
    String messageType,
    String newContent,
  ) => actions.sendEditMessage(messageId, messageType, newContent);

  /// 发送输入状态
  /// Send input status (typing/stopped).
  Future<void> sendInputStatus({
    required String conversationUk3,
    required String toId,
    required String msgType,
    required TypingStatus status,
  }) => actions.sendInputStatus(
    conversationUk3: conversationUk3,
    toId: toId,
    msgType: msgType,
    status: status,
  );

  /// 检查消息是否可以撤回
  /// Check if message can be revoked.
  Future<bool> canRevokeMessage(MessageModel msg) =>
      actions.canRevokeMessage(msg);

  /// 检查消息是否可以编辑
  /// Check if message can be edited.
  Future<bool> canEditMessage(MessageModel msg) => actions.canEditMessage(msg);

  /// 处理 E2EE 消息解密（v2.0 格式）
  ///
  /// ## v2.0 E2EE 格式
  /// - **payload**：密文字符串（格式：`base64(nonce).base64(ciphertext)`）
  /// - **e2ee 元数据**：包含加密参数（keys 数组、nonce、suite 等）
  ///
  /// ## 解密流程
  /// 1. 从 payload 获取密文字符串
  /// 2. 从 e2ee 元数据获取加密参数
  /// 3. 调用 `E2EEService.decryptE2EEMessage` 解密
  /// 4. 解析解密后的 JSON 内容
  /// 5. 返回解密后的 payload
  ///
  /// ## 参数
  /// - [data]: 原始消息数据（包含 payload 和 e2ee 字段）
  /// - [msgId]: 消息 ID
  /// - [msgType]: 消息类型（C2C/C2G）
  /// - [createdAtMs]: 创建时间戳（毫秒）
  ///
  /// ## 返回值
  /// 解密后的 payload（Map），如果解密失败则返回包含 `_e2ee_failed` 标记的 payload
  Future<Map<String, dynamic>> _handleE2EEMessage({
    required Map data,
    required String msgId,
    required String msgType,
    required int createdAtMs,
  }) async {
    // WebSocket API v2.0: 保留原始消息的 msg_type（内容类型）
    final originalMsgType = parseModelString(
      data['msg_type'],
      defaultValue: 'text',
    );

    // 1. 获取密文字符串
    final ciphertext = data['payload']?.toString();
    if (ciphertext == null || ciphertext.isEmpty) {
      iPrint('❌ [E2EE] payload 为空: msgId=$msgId');
      return {
        'msg_type': originalMsgType, // 保留原始消息类型
        'text': '[加密消息]',
        '_e2ee_failed': true,
        '_e2ee_reason': 'empty_payload',
      };
    }

    // 2. 获取 e2ee 元数据
    final e2eeRaw = data['e2ee'];
    Map<String, dynamic>? e2ee;

    if (e2eeRaw != null && e2eeRaw.toString().isNotEmpty) {
      if (e2eeRaw is String) {
        try {
          final decoded = jsonDecode(e2eeRaw);
          if (decoded is Map) {
            e2ee = decoded.cast<String, dynamic>();
          }
        } catch (e) {
          iPrint('❌ [E2EE] e2ee 字符串解析失败: msgId=$msgId, error=$e');
        }
      } else if (e2eeRaw is Map) {
        e2ee = e2eeRaw.cast<String, dynamic>();
      }
    }

    if (e2ee == null || e2ee.isEmpty) {
      iPrint('❌ [E2EE] e2ee 元数据为空: msgId=$msgId');
      return {
        'msg_type': originalMsgType, // 保留原始消息类型
        'text': '[加密消息]',
        '_e2ee_failed': true,
        '_e2ee_reason': 'missing_e2ee_metadata',
        // 保存原始密文以便后续重试解密
        '_e2ee_raw_ciphertext': ciphertext,
        '_e2ee_raw_e2ee': e2ee,
        '_e2ee_original_msg_type': originalMsgType,
      };
    }

    // 3. 调用 E2EEService.decryptE2EEMessage 解密
    try {
      final plaintext = await E2EEService.decryptE2EEMessage(
        ciphertext: ciphertext,
        e2ee: e2ee,
      );

      // 4. 解析解密后的 JSON 内容
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map) {
        throw Exception('解密后的内容不是 JSON 对象');
      }

      final payload = decoded.cast<String, dynamic>();

      // 5. 保留原始消息类型（如果解密后的内容没有 msg_type）
      if (!payload.containsKey('msg_type') || payload['msg_type'] == null) {
        payload['msg_type'] = originalMsgType;
        iPrint('🔧 [E2EE] 保留原始 msg_type: $originalMsgType');
      }

      // 6. 保留原始元数据
      if (data.containsKey('client_send_ts')) {
        payload['client_send_ts'] = data['client_send_ts'];
      }
      if (data.containsKey('sender_did')) {
        payload['sender_did'] = data['sender_did'];
      }
      if (data.containsKey('sender_dtype')) {
        payload['sender_dtype'] = data['sender_dtype'];
      }

      // 7. 保存原始消息元数据（避免循环引用）
      if (!payload.containsKey('_e2ee')) {
        // 只保存必要的元数据，避免循环引用
        payload['_e2ee'] = {
          'id': data['id'],
          'type': data['type'],
          'from': data['from'],
          'to': data['to'],
          'msg_type': originalMsgType,
          'created_at': data['created_at'],
        };
      }

      iPrint(
        '✅ [E2EE] v2.0 解密成功: msgId=$msgId, msgType=${payload['msg_type']}',
      );
      return payload;
    } catch (e) {
      iPrint('❌ [E2EE] 解密失败: msgId=$msgId, error=$e');

      // 检查是否是密钥不匹配错误
      final errorStr = e.toString().toLowerCase();
      final isKeyMismatch =
          errorStr.contains('no key found for device') ||
          errorStr.contains('密钥') ||
          errorStr.contains('device');

      if (isKeyMismatch) {
        // 获取发送方 UID（消息来源），用于通知发送方刷新我们的公钥缓存
        final peerId = data['from']?.toString();

        // 触发E2EE密钥不匹配事件，引导用户重新登录
        AppEventBus.fire(
          E2EEKeyMismatchEvent(
            messageId: msgId,
            reason: '密钥不匹配',
            peerId: peerId, // 发送方 UID，用于清除发送方对我们的公钥缓存
          ),
        );

        // 密钥不匹配：保存原始密文以便后续重试解密
        return {
          'msg_type': originalMsgType,
          'text':
              '🔒 此消息无法解密\n\n可能原因：\n• 您在其他设备上登录\n• 设备密钥已过期\n\n建议：\n点击下方按钮重新登录以获取最新密钥',
          '_e2ee_failed': true,
          '_e2ee_reason': 'key_mismatch',
          '_e2ee_error': e.toString(),
          '_show_relogin_button': true, // 标记需要显示重新登录按钮
          // 保存原始密文以便后续重试解密
          '_e2ee_raw_ciphertext': ciphertext,
          '_e2ee_raw_e2ee': e2ee,
          '_e2ee_original_msg_type': originalMsgType,
        };
      }

      // 其他解密错误
      return {
        'msg_type': originalMsgType, // 保留原始消息类型
        'text': '🔒 [加密消息无法解密]\n\n错误：${e.toString()}',
        '_e2ee_failed': true,
        '_e2ee_reason': 'decrypt_error',
        '_e2ee_error': e.toString(),
        // 保存原始密文以便后续重试解密
        '_e2ee_raw_ciphertext': ciphertext,
        '_e2ee_raw_e2ee': e2ee,
        '_e2ee_original_msg_type': originalMsgType,
      };
    }
  }

  /// 处理文本消息
  void _handleTextMessage(Map data, Map<String, dynamic> payload) {
    final text = payload['text']?.toString() ?? '';
    iPrint(
      '📝 [文本消息] ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
    );
  }

  /// 处理图片消息
  void _handleImageMessage(Map data, Map<String, dynamic> payload) {
    final url = payload['url']?.toString() ?? '';
    iPrint('🖼️ [图片消息] $url');
  }

  /// 处理语音消息
  void _handleVoiceMessage(Map data, Map<String, dynamic> payload) {
    final duration = payload['duration']?.toInt() ?? 0;
    final url = payload['url']?.toString() ?? '';
    iPrint('🎤 [语音消息] 时长: $duration秒, URL: $url');
  }

  /// 处理视频消息
  void _handleVideoMessage(Map data, Map<String, dynamic> payload) {
    final url = payload['url']?.toString() ?? '';
    final duration = payload['duration']?.toInt() ?? 0;
    iPrint('🎬 [视频消息] 时长: $duration秒, URL: $url');
  }

  /// 处理文件消息
  void _handleFileMessage(Map data, Map<String, dynamic> payload) {
    final filename = payload['filename']?.toString() ?? '';
    final size = payload['size']?.toInt() ?? 0;
    iPrint('📎 [文件消息] 文件名: $filename, 大小: $size 字节');
  }

  /// 处理引用消息
  void _handleQuoteMessage(Map data, Map<String, dynamic> payload) {
    final quoteText = payload['quote_text']?.toString() ?? '';
    final text = payload['text']?.toString() ?? '';
    iPrint('💬 [引用消息] 引用: $quoteText, 内容: $text');
  }

  /// 处理位置消息
  void _handleLocationMessage(Map data, Map<String, dynamic> payload) {
    final title = payload['title']?.toString() ?? '';
    final address = payload['address']?.toString() ?? '';
    iPrint('📍 [位置消息] 标题: $title, 地址: $address');
  }

  /// 处理自定义消息
  void _handleCustomMessage(Map data, Map<String, dynamic> payload) {
    final contentType =
        data['msg_type']?.toString() ??
        payload['msg_type']?.toString() ??
        'custom';
    iPrint('🔧 [自定义消息] 类型: $contentType');
  }

  /// 根据 msg_type 分发消息处理（v2.0）
  ///
  /// ## 参数
  /// - [messageType]: 消息类型（从顶层 msg_type 字段读取）
  /// - [data]: 原始消息数据
  /// - [payload]: 消息负载内容
  ///
  /// ## 支持的消息类型
  /// - `text`：文本消息
  /// - `image`：图片消息
  /// - `voice`：语音消息
  /// - `video`：视频消息
  /// - `file`：文件消息
  /// - `quote`：引用消息
  /// - `location`：位置消息
  /// - `custom`：自定义消息
  /// - `e2ee`：端到端加密消息（已解密）
  void _dispatchMessageByType(
    String messageType,
    Map data,
    Map<String, dynamic> payload,
  ) {
    switch (messageType) {
      case 'text':
        _handleTextMessage(data, payload);
        break;
      case 'image':
        _handleImageMessage(data, payload);
        break;
      case 'voice':
        _handleVoiceMessage(data, payload);
        break;
      case 'video':
        _handleVideoMessage(data, payload);
        break;
      case 'file':
        _handleFileMessage(data, payload);
        break;
      case 'quote':
        _handleQuoteMessage(data, payload);
        break;
      case 'location':
        _handleLocationMessage(data, payload);
        break;
      case 'custom':
        _handleCustomMessage(data, payload);
        break;
      default:
        iPrint('⚠️ [未知消息类型] messageType=$messageType');
    }
  }
}

/// 内容哈希缓存条目（带时间戳支持 TTL 清理）
class _ContentHashEntry {
  final String msgId;
  final int timestamp;

  const _ContentHashEntry({required this.msgId, required this.timestamp});
}
