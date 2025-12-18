import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 消息发送状态枚举
enum MessageStatus {
  sending,   // 发送中
  sent,      // 已发送
  delivered, // 已送达
  seen,      // 已读
  error,     // 发送失败
}

/// 消息发送状态管理器
/// 处理消息发送、重试、状态显示等
class MessageSendStateManager extends GetxController {
  static MessageSendStateManager get to => Get.find();
  
  // 发送中的消息队列 {messageId: Message}
  final Map<String, dynamic> _sendingMessages = {};
  
  // 发送状态的可观察值
  final RxBool isSending = false.obs;
  final RxInt sendingCount = 0.obs;
  final RxString currentSendingMessage = ''.obs;
  
  // 重试队列 {messageId: retryCount}
  final Map<String, int> _retryQueue = {};
  
  // 消息发送进度 {messageId: progress (0.0-1.0)}
  final Map<String, double> _sendProgress = {};
  
  /// 添加消息到发送队列
  void addMessageToQueue(String messageId, String content) {
    _sendingMessages[messageId] = {
      'content': content,
      'startTime': DateTime.now(),
      'retryCount': 0,
    };
    
    sendingCount.value = _sendingMessages.length;
    currentSendingMessage.value = content;
    isSending.value = true;
    
    // 30秒后自动清理
    Future.delayed(const Duration(seconds: 30), () {
      removeMessageFromQueue(messageId);
    });
  }
  
  /// 从发送队列移除消息
  void removeMessageFromQueue(String messageId) {
    _sendingMessages.remove(messageId);
    _sendProgress.remove(messageId);
    _retryQueue.remove(messageId);
    
    sendingCount.value = _sendingMessages.length;
    currentSendingMessage.value = _sendingMessages.isNotEmpty 
        ? _sendingMessages.values.first['content'] 
        : '';
    isSending.value = _sendingMessages.isNotEmpty;
  }
  
  /// 更新消息发送进度
  void updateSendProgress(String messageId, double progress) {
    if (_sendingMessages.containsKey(messageId)) {
      _sendProgress[messageId] = progress.clamp(0.0, 1.0);
    }
  }
  
  /// 获取消息发送进度
  double getSendProgress(String messageId) {
    return _sendProgress[messageId] ?? 0.0;
  }
  
  /// 添加消息到重试队列
  void addToRetryQueue(String messageId, int retryCount) {
    _retryQueue[messageId] = retryCount;
  }
  
  /// 获取消息重试次数
  int getRetryCount(String messageId) {
    return _retryQueue[messageId] ?? 0;
  }
  
  /// 检查消息是否正在发送
  bool isMessageSending(String messageId) {
    return _sendingMessages.containsKey(messageId);
  }
  
  /// 清理所有发送状态
  void clearAllSendingStatus() {
    _sendingMessages.clear();
    _sendProgress.clear();
    _retryQueue.clear();
    
    sendingCount.value = 0;
    currentSendingMessage.value = '';
    isSending.value = false;
  }
}

/// 消息发送状态指示器组件
class MessageSendStatusIndicator extends StatelessWidget {
  const MessageSendStatusIndicator({
    super.key,
    required this.messageId,
    required this.status,
    this.size = 16,
  });
  
  final String messageId;
  final MessageStatus status;
  final double size;
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<MessageSendStateManager>(
      init: MessageSendStateManager.to,
      builder: (controller) {
        // 如果消息正在发送，显示进度指示器
        if (controller.isMessageSending(messageId)) {
          final progress = controller.getSendProgress(messageId);
          return SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress > 0 ? progress : null,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          );
        }
        
        // 根据消息状态显示不同图标
        switch (status) {
          case MessageStatus.sending:
            return Icon(
              Icons.access_time,
              size: size,
              color: Theme.of(context).disabledColor,
            );
          case MessageStatus.sent:
          case MessageStatus.delivered:
            return Icon(
              Icons.done,
              size: size,
              color: Theme.of(context).primaryColor,
            );
          case MessageStatus.seen:
            return Icon(
              Icons.done_all,
              size: size,
              color: Theme.of(context).primaryColor,
            );
          case MessageStatus.error:
            final retryCount = controller.getRetryCount(messageId);
            return Stack(
              children: [
                Icon(
                  Icons.error_outline,
                  size: size,
                  color: Theme.of(context).colorScheme.error,
                ),
                if (retryCount > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$retryCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 6,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }
}

/// 消息发送进度条组件
class MessageSendProgressBar extends StatelessWidget {
  const MessageSendProgressBar({
    super.key,
    required this.messageId,
    required this.content,
  });
  
  final String messageId;
  final String content;
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<MessageSendStateManager>(
      init: MessageSendStateManager.to,
      builder: (controller) {
        if (!controller.isMessageSending(messageId)) {
          return const SizedBox.shrink();
        }
        
        final progress = controller.getSendProgress(messageId);
        final retryCount = controller.getRetryCount(messageId);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      content.length > 30 
                          ? '${content.substring(0, 30)}...' 
                          : content,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (retryCount > 0)
                    Text(
                      '重试 $retryCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
