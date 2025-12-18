import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/config/init.dart';

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

    // 监听网络状态变化
    ever(MessageService.to.isOnline, (bool online) {
      if (online) {
        // 网络恢复时重试失败的消息
        retryFailedMessages();
      }
    });
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

  /// 将消息添加到重试队列
  /// Add message to retry queue.
  void addToRetryQueue(String messageId, String type, Map<String, dynamic> messageData) {
    _retryQueue[messageId] = MessageRetryInfo(
      messageId: messageId,
      type: type,
      messageData: messageData,
      retryCount: 0,
      lastRetryTime: DateTime.now(),
    );
    iPrint('消息加入重试队列: $messageId');
  }

  /// 重试失败的消息
  /// Retry failed messages.
  Future<void> retryFailedMessages() async {
    if (!MessageService.to.isOnline.value || _retryQueue.isEmpty) return;

    final now = DateTime.now();
    final retryList = _retryQueue.values.where((info) {
      // 检查是否超过最大重试次数
      if (info.retryCount >= 3) return false;
      
      // 检查是否超过重试间隔时间
      final interval = Duration(seconds: 30 * (info.retryCount + 1));
      return now.difference(info.lastRetryTime) >= interval;
    }).toList();

    for (final info in retryList) {
      await _retryMessage(info);
    }
  }

  /// 重试单个消息
  /// Retry single message.
  Future<void> _retryMessage(MessageRetryInfo info) async {
    try {
      iPrint('重试发送消息: ${info.messageId}, 第${info.retryCount + 1}次重试');
      
      // 更新消息状态为发送中
      final repo = MessageService.to.getMessageRepo(info.type);
      await repo.update({
        'id': info.messageId,
        'status': IMBoyMessageStatus.sending,
      });
      
      // 发送消息
      final success = await WebSocketService.to.sendMessage(json.encode(info.messageData), info.messageId);
      
      if (success) {
        // 发送成功，从重试队列中移除
        _retryQueue.remove(info.messageId);
        iPrint('消息重试成功: ${info.messageId}');
        
        // 更新UI状态
        final msg = await repo.find(info.messageId);
        if (msg != null) {
          final updatedMessage = await msg.toTypeMessage();
          eventBus.fire([updatedMessage]);
        }
      } else {
        // 发送失败，更新重试信息
        info.retryCount++;
        info.lastRetryTime = DateTime.now();
        
        if (info.retryCount >= 3) {
          // 超过最大重试次数，标记为失败
          await repo.update({
            'id': info.messageId,
            'status': IMBoyMessageStatus.error,
          });
          _retryQueue.remove(info.messageId);
          
          // 更新UI状态
          final msg = await repo.find(info.messageId);
          if (msg != null) {
            final updatedMessage = await msg.toTypeMessage();
            eventBus.fire([updatedMessage]);
          }
          
          iPrint('消息重试失败，超过最大重试次数: ${info.messageId}');
        }
      }
    } catch (e) {
      iPrint('重试消息错误: ${info.messageId}, $e');
      info.retryCount++;
      info.lastRetryTime = DateTime.now();
    }
  }

  /// 手动重试消息
  /// Manually retry message.
  Future<bool> retryMessage(String messageId, String type) async {
    try {
      final repo = MessageService.to.getMessageRepo(type);
      final msg = await repo.find(messageId);
      if (msg == null) return false;

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
        addToRetryQueue(messageId, type, messageData);
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
  final Map<String, dynamic> messageData;
  int retryCount;
  DateTime lastRetryTime;

  MessageRetryInfo({
    required this.messageId,
    required this.type,
    required this.messageData,
    required this.retryCount,
    required this.lastRetryTime,
  });
}