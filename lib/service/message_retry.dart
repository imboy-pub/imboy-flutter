import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// MessageRetry
/// 消息重试机制，处理失败消息的重试逻辑
/// Message retry mechanism for handling failed message retries
class MessageRetry extends GetxService {
  static MessageRetry get to => Get.find();

  /// 消息重试队列，存储发送失败的消息
  /// Message retry queue for failed messages.
  final Map<String, MessageRetryInfo> _retryQueue = {};

  /// 重试定时器
  /// Retry timer.
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    // 启动消息重试机制
    startRetryTimer();

    // 延迟监听网络状态变化，避免循环依赖
    Future.microtask(() {
      if (Get.isRegistered<MessageService>()) {
        try {
          ever(MessageService.to.isOnline, (bool online) {
            if (online) {
              // 网络恢复时重试失败的消息
              retryFailedMessages();
            }
          });
        } catch (e) {
          iPrint('MessageRetry 初始化网络监听失败: $e');
        }
      }
    });

    // 【新增】应用启动时扫描失败消息并添加到重试队列
    _scanAndRetryFailedMessages();
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    super.onClose();
  }

  /// 启动重试定时器
  /// Start retry timer.
  void startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      retryFailedMessages();
    });
  }

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
          final repo = MessageRepo(tableName: table);

          for (final status in statusesToRetry) {
            // 查询该状态下最近的消息（限制最近100条）
            final messages = await repo.page(
              page: 1,
              size: 100,
              kwd: '',
            );

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
                iPrint('✅ [RETRY_SCAN] 添加失败消息到重试队列: msgId=${msg.id}, status=$status, table=$table');
              }
            }
          }
        } catch (e) {
          iPrint('⚠️ [RETRY_SCAN] 扫描表 $table 失败: $e');
        }
      }

      iPrint('📊 [RETRY_SCAN] 扫描完成: 发现 $totalFound 条失败消息，添加 $totalAdded 条到重试队列');

      // 如果网络已连接，立即尝试重试
      if (MessageService.to.isOnline.value && totalAdded > 0) {
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
    // 安全检查：确保 MessageService 已注册
    if (!Get.isRegistered<MessageService>()) {
      iPrint('MessageService 未注册，跳过消息重试');
      return;
    }

    if (!MessageService.to.isOnline.value || _retryQueue.isEmpty) return;

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
      final intervalMs = intervals[info.retryCount.clamp(0, intervals.length - 1)];
      if ((now - info.lastRetryTime) < intervalMs) {
        continue;
      }

      // 检查消息状态，如果已经是 sent 则跳过
      final repo = MessageService.to.getMessageRepo(info.type);
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
  Future<void> _retryMessage(MessageRetryInfo info) async {
    try {
      // 安全检查：确保 MessageService 已注册
      if (!Get.isRegistered<MessageService>()) {
        iPrint('MessageService 未注册，跳过重试消息: ${info.messageId}');
        return;
      }

      // 从数据库读取消息数据
      final repo = MessageService.to.getMessageRepo(info.type);
      final msg = await repo.find(info.messageId);

      if (msg == null) {
        iPrint('⚠️ [RETRY] 消息不存在，从重试队列移除: ${info.messageId}');
        _retryQueue.remove(info.messageId);
        return;
      }

      // 如果消息状态已经是 sent，说明已经收到 ACK，不需要重试
      if (msg.status == IMBoyMessageStatus.sent) {
        iPrint('✅ [RETRY] 消息已确认（状态为 sent），跳过重试: ${info.messageId}');
        _retryQueue.remove(info.messageId);
        return;
      }

      iPrint('重试发送消息: ${info.messageId}, 第${info.retryCount + 1}次重试, 当前状态: ${msg.status}');

      // 更新消息状态为发送中
      await repo.update({
        'id': info.messageId,
        'status': IMBoyMessageStatus.sending,
      });

      // 构造消息数据（从数据库读取）
      final messageData = {
        'id': msg.id,
        'type': msg.type,
        'from': msg.fromId,
        'to': msg.toId,
        'payload': msg.payload,
        'created_at': msg.createdAt,
      };

      // 发送消息
      final success = await WebSocketService.to.sendMessage(json.encode(messageData), info.messageId);

      if (success) {
        // 发送成功，从重试队列中移除
        _retryQueue.remove(info.messageId);
        iPrint('消息重试成功: ${info.messageId}');

        // 更新UI状态
        final updatedMsg = await repo.find(info.messageId);
        if (updatedMsg != null) {
          final updatedMessage = await updatedMsg.toTypeMessage();
          eventBus.fire([updatedMessage]);
        }
      } else {
        // 发送失败，更新重试信息
        info.retryCount++;
        info.lastRetryTime = DateTimeHelper.millisecond();

        if (info.retryCount >= 4) {
          // 超过最大重试次数，标记为失败
          await repo.update({
            'id': info.messageId,
            'status': IMBoyMessageStatus.error,
          });
          _retryQueue.remove(info.messageId);

          // 更新UI状态
          final updatedMsg = await repo.find(info.messageId);
          if (updatedMsg != null) {
            final updatedMessage = await updatedMsg.toTypeMessage();
            eventBus.fire([updatedMessage]);
          }

          iPrint('消息重试失败，超过最大重试次数: ${info.messageId}');
        }
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
      // 安全检查：确保 MessageService 已注册
      if (!Get.isRegistered<MessageService>()) {
        iPrint('MessageService 未注册，无法重试消息');
        return false;
      }

      final repo = MessageService.to.getMessageRepo(type);
      final msg = await repo.find(messageId);
      if (msg == null) {
        iPrint('⚠️ [MANUAL_RETRY] 消息不存在: $messageId');
        return false;
      }

      // 【关键修复】检查消息是否已经成功
      if (msg.status == IMBoyMessageStatus.sent ||
          msg.status == IMBoyMessageStatus.delivered ||
          msg.status == IMBoyMessageStatus.seen) {
        iPrint('⚠️ [MANUAL_RETRY] 消息已成功(msgId=$messageId, status=${msg.status})，无需重试');
        // 从重试队列中移除（如果存在）
        _retryQueue.remove(messageId);
        return false;  // 返回 false 表示无需重试
      }

      // 更新状态为发送中
      await repo.update({
        'id': messageId,
        'status': IMBoyMessageStatus.sending,
      });

      // 构造消息数据
      Map<String, dynamic> messageData = {
        'id': msg.id,
        'type': msg.type,
        'from': msg.fromId,
        'to': msg.toId,
        'payload': msg.payload,
        'created_at': msg.createdAt,
      };

      // 发送消息
      final success = await WebSocketService.to.sendMessage(json.encode(messageData), messageId);

      if (success) {
        // 从重试队列中移除（如果存在）
        _retryQueue.remove(messageId);
        iPrint('手动重试成功: $messageId');
      } else {
        // 失败时添加到重试队列
        addToRetryQueue(messageId, type);
        await repo.update({
          'id': messageId,
          'status': IMBoyMessageStatus.error,
        });
      }

      // 更新UI状态
      final updatedMsg = await repo.find(messageId);
      if (updatedMsg != null) {
        final updatedMessage = await updatedMsg.toTypeMessage();
        eventBus.fire([updatedMessage]);
      }

      return success;
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