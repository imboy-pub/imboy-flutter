import 'dart:async';
import 'dart:convert';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/event_subscription_manager.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

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

  /// 兼容旧代码的访问方式
  static MessageRetry get to => instance;

  /// 私有构造函数
  MessageRetry._internal() {
    _init();
  }

  /// 消息重试队列，存储发送失败的消息
  /// Message retry queue for failed messages.
  final Map<String, MessageRetryInfo> _retryQueue = {};

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
          retryFailedMessages();
        }
      }),
    );

    // 订阅重试消息请求事件（解耦：通过事件总线接收重试请求）
    // Subscribe to retry messages request event (decoupling: receive retry requests via event bus)
    subscribeTo(
      AppEventBus.on<RetryMessagesRequestedEvent>().listen((event) {
        retryFailedMessages();
        iPrint(
          '🔄 [RETRY_QUEUE] 触发消息重试: source=${event.source}, reason=${event.reason}',
        );
      }),
    );

    // 【新增】应用启动时扫描失败消息并添加到重试队列
    _scanAndRetryFailedMessages();

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
    // 【新增】使用 EventSubscriptionManager 统一取消所有事件订阅
    // Cancel all event subscriptions using EventSubscriptionManager
    cancelAllSubscriptions();
  }

  /// 启动重试定时器
  /// Start retry timer.
  void startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      retryFailedMessages();
    });
  }

  /// 获取消息仓库（内联方法，避免依赖 MessageService）
  /// Get message repository (inlined method to avoid dependency on MessageService)
  MessageRepo getMessageRepo(String type) =>
      MessageRepo(tableName: MessageRepo.getTableName(type));

  /// 【新增】扫描数据库中的失败消息并添加到重试队列
  /// Scan failed messages from database and add to retry queue.
  Future<void> _scanAndRetryFailedMessages() async {
    try {
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
                  msg.id != null && // 确保 msgId 不为空
                  msg.id!.isNotEmpty; // 确保 msgId 不为空字符串
            }).toList();

            for (final msg in failedMessages) {
              totalFound++;

              // 检查消息是否已经在重试队列中
              if (!_retryQueue.containsKey(msg.id!)) {
                // 添加到重试队列
                addToRetryQueue(msg.id!, table);
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

  /// 将消息添加到重试队列
  /// Add message to retry queue.
  void addToRetryQueue(String messageId, String type) {
    _retryQueue[messageId] = MessageRetryInfo(
      messageId: messageId,
      type: type,
      retryCount: 0,
      lastRetryTime: DateTimeHelper.millisecond(),
    );
    iPrint('消息加入重试队列: $messageId');
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

    // 【修复】重试间隔配置：3秒、5秒、10秒、20秒
    final intervals = [3000, 5000, 10000, 20000];

    // 筛选需要重试的消息
    final List<MessageRetryInfo> toRemove = [];
    final retryList = <MessageRetryInfo>[];

    for (final info in _retryQueue.values) {
      // 检查是否超过最大重试次数（改为 4 次）
      if (info.retryCount >= 4) {
        toRemove.add(info);
        continue;
      }

      // 检查是否超过重试间隔时间
      final intervalMs =
          intervals[info.retryCount.clamp(0, intervals.length - 1)];
      if ((now - info.lastRetryTime) < intervalMs) {
        continue;
      }

      // 检查消息状态，如果已经是 sent 则跳过
      final repo = getMessageRepo(info.type);
      final msg = await repo.find(info.messageId);

      if (msg == null) {
        // 消息不存在，从队列移除
        toRemove.add(info);
        continue;
      }

      if (msg.status == IMBoyMessageStatus.sent) {
        // 消息已确认，从队列移除
        iPrint('✅ [RETRY] 消息已确认（状态为 sent），从重试队列移除: ${info.messageId}');
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

      // 【修复 H3】使用 CAS (Compare-And-Set) 操作防止竞态条件
      // 只更新特定状态的消息，避免与其他操作冲突
      // 只重试 error 状态的消息（41=发送失败）
      final updatedRows = await repo.updateWithConditions(
        {
          'id': info.messageId,
          'status': IMBoyMessageStatus.sending,
        },
        where: "id = ? AND status = ?",
        whereArgs: [
          info.messageId,
          IMBoyMessageStatus.error,
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

      iPrint(
        '重试发送消息: ${info.messageId}, 第${info.retryCount + 1}次重试',
      );

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

      // 【调整】从重试队列中移除（假设发送成功，失败时会通过其他机制重新加入队列）
      _retryQueue.remove(info.messageId);
      iPrint('消息重试已提交: ${info.messageId}');

      // 更新UI状态
      final updatedMsg = await repo.find(info.messageId);
      if (updatedMsg != null) {
        final updatedMessage = await updatedMsg.toTypeMessage();
        AppEventBus.fireData([updatedMessage], 'List<Message>');
      }
    } catch (e) {
      iPrint('重试消息错误: ${info.messageId}, $e');
      info.retryCount++;
      info.lastRetryTime = DateTimeHelper.millisecond();
    }
  }

  /// 手动重试消息
  /// Manually retry message.
  Future<bool> retryMessage(String messageId, String type) async {
    try {
      final repo = getMessageRepo(type);
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

      // 从重试队列中移除（假设发送成功）
      _retryQueue.remove(messageId);
      iPrint('手动重试已提交: $messageId');

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
