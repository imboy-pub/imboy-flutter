/// 消息发送状态枚举
enum MessageStatus {
  sending, // 发送中
  sent, // 已发送
  delivered, // 已送达
  seen, // 已读
  error, // 发送失败
}

/// 消息发送状态数据模型
class MessageSendState {
  final bool isSending;
  final int sendingCount;
  final String currentSendingMessage;

  const MessageSendState({
    this.isSending = false,
    this.sendingCount = 0,
    this.currentSendingMessage = '',
  });

  MessageSendState copyWith({
    bool? isSending,
    int? sendingCount,
    String? currentSendingMessage,
  }) {
    return MessageSendState(
      isSending: isSending ?? this.isSending,
      sendingCount: sendingCount ?? this.sendingCount,
      currentSendingMessage:
          currentSendingMessage ?? this.currentSendingMessage,
    );
  }
}

/// 注意：此类已迁移为简化版本，完整功能需要在父组件中实现状态管理
/// 消息发送状态管理器（已废弃，请使用 Riverpod Provider）
/// 处理消息发送、重试、状态显示等
@Deprecated('请使用 Riverpod Provider 管理消息发送状态')
class MessageSendStateManager {
  // 空实现，保留用于向后兼容
}
