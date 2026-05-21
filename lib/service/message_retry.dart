import 'dart:async';
import 'dart:convert';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/event_subscription_manager.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// MessageRetry
/// 消息重试机制，处理失败消息的重试逻辑
/// Message retry mechanism for handling failed message retries
class MessageRetry with EventSubscriptionManager {
  /// 单例实例
  static MessageRetry? _instance;

  /// 获取单例实例
  static MessageRetry get instance {
    _instance ??= MessageRetry._internal();
    return _instance!;
  }

  /// 私有构造函数
  MessageRetry._internal() {
    _init();
  }

  /// 消息重试队列，存储发送失败的消息
  /// Message retry queue for failed messages.
  final Map<String, MessageRetryInfo> _retryQueue = {};

  /// 最大自动重试次数（不含首次发送）
  static const int _maxRetryAttempts = 4;

  /// 重试定时器
  /// Retry timer.
  Timer? _retryTimer;

  /// 网络在线状态
  /// Network online status.
  bool _isOnline = true;

  /// 获取在线状态
  bool get isOnline => _isOnline;

  /// 内部初始化方法
  void _init() {
    // 启动消息重试机制
    startRetryTimer();

    // 订阅网络连接状态事件（解耦：使用事件总线而非直接监听 MessageService）
    // Subscribe to network connection status event (decoupling: use event bus instead of directly listening to MessageService)
    subscribeTo(
      AppEventBus.on<NetworkConnectionEvent>().listen((event) {
        _isOnline = event.isConnected;
        if (event.isConnected) {
          // 网络恢复时重试失败的消息
          // Retry failed messages when network recovers
          unawaited(retryFailedMessages());
        }
      }),
    );

    // 订阅重试消息请求事件（解耦：通过事件总线接收重试请求）
    // Subscribe to retry messages request event (decoupling: receive retry requests via event bus)
    subscribeTo(
      AppEventBus.on<RetryMessagesRequestedEvent>().listen((event) {
        unawaited(retryFailedMessages());
        iPrint(
          '🔄 [RETRY_QUEUE] 触发消息重试: source=${event.source}, reason=${event.reason}',
        );
      }),
    );

    // 【新增】应用启动时扫描失败消息并添加到重试队列
    unawaited(_scanAndRetryFailedMessages());

    // 【新增】订阅从重试队列移除请求事件（解耦：通过事件总线接收移除请求）
    // Subscribe to remove from retry queue request event (decoupling: receive removal requests via event bus)
    // 使用 EventSubscriptionManager 管理
    subscribeTo(
      AppEventBus.on<RemoveFromRetryQueueRequestedEvent>().listen((event) {
        removeFromRetryQueue(event.messageId);
        iPrint(
          '🗑️ [RETRY_QUEUE] 从重试队列移除: messageId=${event.messageId}, reason=${event.reason}',
        );
      }),
    );
  }

  /// 释放资源
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryQueue.clear();
    // 【新增】使用 EventSubscriptionManager 统一取消所有事件订阅
    // Cancel all event subscriptions using EventSubscriptionManager
    cancelAllSubscriptions();
    _instance = null;
  }

  /// 清空重试队列（不影响订阅和定时器）
  void clearRetryQueue() {
    _retryQueue.clear();
  }

  /// 启动重试定时器（自适应：队列为空时自动停止以节省 CPU）
  /// Start retry timer (adaptive: auto-stops when queue is empty).
  void startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_retryQueue.isEmpty) {
        _retryTimer?.cancel();
        _retryTimer = null;
        return;
      }
      retryFailedMessages();
    });
  }

  /// 确保定时器运行（添加消息时调用）
  void _ensureTimerRunning() {
    if (_retryTimer == null || !_retryTimer!.isActive) {
      startRetryTimer();
    }
  }

  /// 获取消息仓库（内联方法，避免依赖 MessageService）
  /// Get message repository (inlined method to avoid dependency on MessageService)
  MessageRepo getMessageRepo(String type) =>
      MessageRepo(tableName: MessageRepo.getTableName(type));

  /// 【新增】扫描数据库中的失败消息并添加到重试队列
  /// Scan failed messages from database and add to retry queue.
  Future<void> _scanAndRetryFailedMessages() async {
    try {
      // 测试/早期启动阶段可能尚未初始化 StorageService，跳过扫描避免噪音日志
      if (!_isStorageReadyForRetryScan()) {
        iPrint('⚠️ [RETRY_SCAN] Storage 未就绪，跳过失败消息扫描');
        return;
      }

      iPrint('🔍 [RETRY_SCAN] 开始扫描失败消息...');

      // 需要重试的消息状态：sending（发送中）和 error（错误）
      final statusesToRetry = [
        IMBoyMessageStatus.sending,
        IMBoyMessageStatus.error,
      ];

      // 获取所有消息表
      final tables = ['c2c', 'c2g', 'c2s'];

      int totalFound = 0;
      int totalAdded = 0;

      for (final table in tables) {
        try {
          final repo = getMessageRepo(table);

          for (final status in statusesToRetry) {
            // 查询该状态下最近的消息（限制最近100条）
            final messages = await repo.page(page: 1, size: 100, kwd: '');

            // 过滤出需要重试的消息
            final failedMessages = messages.where((msg) {
              return msg.status == status &&
                  msg.isAuthor == 1 && // 只重试自己发送的消息
                  msg.id.isNotEmpty; // 确保 msgId 非空
            }).toList();

            for (final msg in failedMessages) {
              totalFound++;

              // 检查消息是否已经在重试队列中
              if (!_retryQueue.containsKey(msg.id)) {
                // 添加到重试队列
                addToRetryQueue(msg.id, table);
                totalAdded++;
                iPrint(
                  '✅ [RETRY_SCAN] 添加失败消息到重试队列: msgId=${msg.id}, status=$status, table=$table',
                );
              }
            }
          }
        } catch (e) {
          iPrint('⚠️ [RETRY_SCAN] 扫描表 $table 失败: $e');
        }
      }

      iPrint(
        '📊 [RETRY_SCAN] 扫描完成: 发现 $totalFound 条失败消息，添加 $totalAdded 条到重试队列',
      );

      // 如果网络已连接，立即尝试重试
      if (isOnline && totalAdded > 0) {
        iPrint('🚀 [RETRY_SCAN] 网络已连接，立即重试失败消息...');
        await retryFailedMessages();
      }
    } catch (e) {
      iPrint('❌ [RETRY_SCAN] 扫描失败消息出错: $e');
    }
  }

  bool _isStorageReadyForRetryScan() {
    try {
      // 触发一次最小读取验证 StorageService 是否可用
      UserRepoLocal.to.currentUid;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 将消息添加到重试队列
  /// Add message to retry queue.
  void addToRetryQueue(String messageId, String type) {
    final normalizedType = _normalizeMessageType(type);
    final existing = _retryQueue[messageId];
    if (existing != null) {
      iPrint(
        '⚠️ [RETRY_QUEUE] 消息已在重试队列中，跳过重复添加: $messageId, retryCount=${existing.retryCount}',
      );
      return;
    }

    _retryQueue[messageId] = MessageRetryInfo(
      messageId: messageId,
      type: normalizedType,
      retryCount: 0,
      lastRetryTime: DateTimeHelper.millisecond(),
    );
    _ensureTimerRunning();
    iPrint('消息加入重试队列: $messageId, type=$normalizedType');
  }

  /// 从重试队列中移除消息
  /// Remove message from retry queue.
  void removeFromRetryQueue(String messageId) {
    if (_retryQueue.remove(messageId) != null) {
      iPrint('消息从重试队列移除: $messageId');
    }
  }

  /// 重试失败的消息
  /// Retry failed messages.
  Future<void> retryFailedMessages() async {
    if (!isOnline || _retryQueue.isEmpty) return;

    final now = DateTimeHelper.millisecond();

    // 重试间隔配置：3秒、5秒、10秒、20秒
    const intervals = [3000, 5000, 10000, 20000];

    // 筛选需要重试的消息
    final List<MessageRetryInfo> toRemove = [];
    final retryList = <MessageRetryInfo>[];

    for (final info in _retryQueue.values) {
      // 检查是否超过最大重试次数
      if (info.retryCount >= _maxRetryAttempts) {
        await _markMessageAsError(info);
        toRemove.add(info);
        continue;
      }

      // 检查是否超过重试间隔时间
      final intervalMs =
          intervals[info.retryCount.clamp(0, intervals.length - 1)];
      if ((now - info.lastRetryTime) < intervalMs) {
        continue;
      }

      // 检查消息状态，已成功则无需重试
      final repo = getMessageRepo(info.type);
      final msg = await repo.find(info.messageId);

      if (msg == null) {
        // 消息不存在，从队列移除
        toRemove.add(info);
        continue;
      }

      if (msg.status == IMBoyMessageStatus.sent ||
          msg.status == IMBoyMessageStatus.delivered ||
          msg.status == IMBoyMessageStatus.seen) {
        // 消息已成功，从队列移除
        iPrint(
          '✅ [RETRY] 消息已成功，从重试队列移除: ${info.messageId}, status=${msg.status}',
        );
        toRemove.add(info);
        continue;
      }

      retryList.add(info);
    }

    // 清理不需要重试的消息
    for (final info in toRemove) {
      _retryQueue.remove(info.messageId);
    }

    // 重试消息
    for (final info in retryList) {
      await _retryMessage(info);
    }
  }

  /// 重试单个消息
  /// Retry single message.
  ///
  /// 【修复 H3】使用数据库事务防止竞态条件
  /// 确保消息状态检查和更新的原子性
  Future<void> _retryMessage(MessageRetryInfo info) async {
    try {
      final repo = getMessageRepo(info.type);

      // 使用 CAS (Compare-And-Set) 防止并发状态覆盖：
      // 仅允许 error/sending 状态进入重试发送路径。
      final updatedRows = await repo.updateWithConditions(
        {'id': info.messageId, 'status': IMBoyMessageStatus.sending},
        where: "id = ? AND status IN (?, ?)",
        whereArgs: [
          info.messageId,
          IMBoyMessageStatus.error,
          IMBoyMessageStatus.sending,
        ],
      );

      // 如果没有更新任何行，说明消息状态已被其他操作改变，跳过重试
      if (updatedRows == 0) {
        final msg = await repo.find(info.messageId);
        if (msg == null) {
          iPrint('⚠️ [RETRY] 消息不存在，从重试队列移除: ${info.messageId}');
        } else {
          iPrint(
            '⚠️ [RETRY] 消息状态已变更，跳过重试: ${info.messageId}, 当前状态: ${msg.status}',
          );
        }
        _retryQueue.remove(info.messageId);
        return;
      }

      // 记录一次重试尝试（发送提交即记一次，ACK 到达后由外部移除队列）
      info.retryCount++;
      info.lastRetryTime = DateTimeHelper.millisecond();
      iPrint('重试发送消息: ${info.messageId}, 第${info.retryCount}次重试');

      // 重新读取消息数据（构造完整的消息对象）
      final msg = await repo.find(info.messageId);
      if (msg == null) {
        iPrint('⚠️ [RETRY] 消息被删除，取消重试: ${info.messageId}');
        _retryQueue.remove(info.messageId);
        return;
      }

      // 构造消息数据（从数据库读取）
      // WebSocket API v2.0: msg_type、action、e2ee 字段提升到顶层
      final messageData = {
        'id': msg.id,
        'type': msg.type,
        'from': msg.fromId,
        'to': msg.toId,
        // v2.0: 添加顶层字段
        'msg_type': msg.msgType ?? '',
        'action': msg.action ?? '',
        'e2ee': msg.e2ee, // Map 类型（如果存在）
        'payload': msg.payload,
        'created_at': msg.createdAt,
      };

      // 【解耦】通过事件总线发送消息重试请求，而不是直接调用 WebSocketService
      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(messageData),
          messageId: info.messageId,
        ),
      );

      // 闭环策略：重试提交后保留在队列中，等待 SERVER_ACK 或状态成功后移除
      iPrint('消息重试已提交，等待确认: ${info.messageId}');

      // 更新UI状态
      final updatedMsg = await repo.find(info.messageId);
      if (updatedMsg != null) {
        final updatedMessage = await updatedMsg.toTypeMessage();
        AppEventBus.fireData([updatedMessage], 'List<Message>');
      }
    } catch (e) {
      iPrint('重试消息错误: ${info.messageId}, $e');
      // 异常也计入一次尝试，避免异常场景无穷重试
      info.retryCount++;
      info.lastRetryTime = DateTimeHelper.millisecond();
      if (info.retryCount >= _maxRetryAttempts) {
        await _markMessageAsError(info);
        _retryQueue.remove(info.messageId);
      }
    }
  }

  /// 手动重试消息
  /// Manually retry message.
  Future<bool> retryMessage(String messageId, String type) async {
    try {
      final normalizedType = _normalizeMessageType(type);
      final repo = getMessageRepo(normalizedType);
      final msg = await repo.find(messageId);
      if (msg == null) {
        iPrint('⚠️ [MANUAL_RETRY] 消息不存在: $messageId');
        return false;
      }

      // 【关键修复】检查消息是否已经成功
      if (msg.status == IMBoyMessageStatus.sent ||
          msg.status == IMBoyMessageStatus.delivered ||
          msg.status == IMBoyMessageStatus.seen) {
        iPrint(
          '⚠️ [MANUAL_RETRY] 消息已成功(msgId=$messageId, status=${msg.status})，无需重试',
        );
        // 从重试队列中移除（如果存在）
        _retryQueue.remove(messageId);
        return false; // 返回 false 表示无需重试
      }

      // 更新状态为发送中
      await repo.update({
        'id': messageId,
        'status': IMBoyMessageStatus.sending,
      });

      // 构造消息数据
      // WebSocket API v2.0: msg_type、action、e2ee 字段提升到顶层
      Map<String, dynamic> messageData = {
        'id': msg.id,
        'type': msg.type,
        'from': msg.fromId,
        'to': msg.toId,
        // v2.0: 添加顶层字段
        'msg_type': msg.msgType ?? '',
        'action': msg.action ?? '',
        'e2ee': msg.e2ee, // Map 类型（如果存在）
        'payload': msg.payload,
        'created_at': msg.createdAt,
      };

      // 【解耦】通过事件总线发送消息重试请求，而不是直接调用 WebSocketService
      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(messageData),
          messageId: messageId,
        ),
      );

      // 手动重试也纳入闭环：等待 ACK/状态成功后移除
      addToRetryQueue(messageId, normalizedType);
      final retryInfo = _retryQueue[messageId];
      if (retryInfo != null) {
        retryInfo.retryCount++;
        retryInfo.lastRetryTime = DateTimeHelper.millisecond();
      }
      iPrint('手动重试已提交，等待确认: $messageId');

      // 更新UI状态
      final updatedMsg = await repo.find(messageId);
      if (updatedMsg != null) {
        final updatedMessage = await updatedMsg.toTypeMessage();
        AppEventBus.fireData([updatedMessage], 'List<Message>');
      }

      return true;
    } catch (e) {
      iPrint('手动重试消息错误: $messageId, $e');
      return false;
    }
  }

  String _normalizeMessageType(String type) {
    final t = type.trim().toUpperCase();
    switch (t) {
      case 'MSG_C2C':
      case 'C2C':
        return 'C2C';
      case 'MSG_C2G':
      case 'C2G':
        return 'C2G';
      case 'MSG_C2S':
      case 'C2S':
        return 'C2S';
      case 'MSG_S2C':
      case 'S2C':
        return 'S2C';
      default:
        return t;
    }
  }

  Future<void> _markMessageAsError(MessageRetryInfo info) async {
    try {
      final repo = getMessageRepo(info.type);
      final msg = await repo.find(info.messageId);
      if (msg == null) return;

      if (msg.status == IMBoyMessageStatus.sent ||
          msg.status == IMBoyMessageStatus.delivered ||
          msg.status == IMBoyMessageStatus.seen) {
        return;
      }

      await repo.update({
        'id': info.messageId,
        'status': IMBoyMessageStatus.error,
      });

      final updated = await repo.find(info.messageId);
      if (updated != null) {
        final updatedMessage = await updated.toTypeMessage();
        AppEventBus.fireData([updatedMessage], 'List<Message>');
      }
      iPrint('❌ [RETRY] 达到最大重试次数，标记消息失败: ${info.messageId}');
    } catch (e) {
      iPrint('⚠️ [RETRY] 标记消息失败时出错: ${info.messageId}, $e');
    }
  }

  // ---- 仅用于测试/调试 ----
  int get retryQueueSize => _retryQueue.length;
  MessageRetryInfo? getRetryInfo(String messageId) => _retryQueue[messageId];
}

/// 消息重试信息类
/// Message retry information class.
class MessageRetryInfo {
  final String messageId;
  final String type;
  int retryCount;
  int lastRetryTime; // 毫秒时间戳

  MessageRetryInfo({
    required this.messageId,
    required this.type,
    required this.retryCount,
    required this.lastRetryTime,
  });
}
