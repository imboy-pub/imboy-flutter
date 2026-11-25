part of 'chat_message_list.dart';

/// 消息项组件（优化版 - 移除 Dismissible 和 AnimatedBuilder）
class _MessageItem extends StatelessWidget {
  const _MessageItem({
    super.key,
    required this.message,
    required this.isMe,
    this.messageTypeRegistry,
    this.messageContent,
    this.statusProvided = false,
    this.status,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
  });

  final Message message;
  final bool isMe;
  final MessageTypeRegistry? messageTypeRegistry;
  final Widget? messageContent;
  final bool statusProvided;
  final Widget? status;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: isMe
          ? _SentMessageWrapper(
              message: message,
              messageTypeRegistry: messageTypeRegistry,
              messageContent: messageContent,
              statusProvided: statusProvided,
              status: status,
            )
          : _ReceivedMessageWrapper(
              message: message,
              messageTypeRegistry: messageTypeRegistry,
              messageContent: messageContent,
            ),
    );
  }
}

/// 接收方消息包装器（优化版 - 避免条件渲染）
class _ReceivedMessageWrapper extends StatelessWidget {
  const _ReceivedMessageWrapper({
    required this.message,
    this.messageTypeRegistry,
    this.messageContent,
  });

  final Message message;
  final MessageTypeRegistry? messageTypeRegistry;
  final Widget? messageContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Avatar(),
          AppSpacing.horizontalSmall,
          Flexible(
            child: _MessageBubble(
              message: message,
              isMe: false,
              messageTypeRegistry: messageTypeRegistry,
              messageContent: messageContent,
            ),
          ),
        ],
      ),
    );
  }
}

/// 发送方消息包装器（优化版 - 避免条件渲染）
class _SentMessageWrapper extends StatelessWidget {
  const _SentMessageWrapper({
    required this.message,
    this.messageTypeRegistry,
    this.messageContent,
    required this.statusProvided,
    this.status,
  });

  final Message message;
  final MessageTypeRegistry? messageTypeRegistry;
  final Widget? messageContent;
  final bool statusProvided;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    if (statusProvided && status != null && isMessageOutcomeUnknown(message)) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MessageBubble(
              message: message,
              isMe: true,
              messageTypeRegistry: messageTypeRegistry,
              messageContent: messageContent,
            ),
            AppSpacing.verticalTiny,
            status!,
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: _MessageBubble(
              message: message,
              isMe: true,
              messageTypeRegistry: messageTypeRegistry,
              messageContent: messageContent,
            ),
          ),
          if (!statusProvided || status != null) AppSpacing.horizontalSmall,
          if (statusProvided) ?status else const _MessageStatusIcon(),
        ],
      ),
    );
  }
}

/// 头像组件（优化版 - const 构件）
class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      ),
      child: Icon(
        CupertinoIcons.person,
        size: 20,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}

/// 消息状态图标（优化版 - 直接使用颜色值避免查询）
class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon();

  // 使用固定颜色值，避免运行时查询
  static const Color _deliveredColor = AppColors.onlineIndicator;

  @override
  Widget build(BuildContext context) {
    return const Icon(
      CupertinoIcons.checkmark_alt,
      size: 16,
      color: _deliveredColor,
    );
  }
}

/// 消息气泡组件
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.messageTypeRegistry,
    this.messageContent,
  });

  final Message message;
  final bool isMe;
  final MessageTypeRegistry? messageTypeRegistry;
  final Widget? messageContent;

  @override
  Widget build(BuildContext context) {
    if (messageContent != null) return messageContent!;
    if (message is CustomMessage) {
      final customMessage = message as CustomMessage;
      return CustomMessageBuilder(
        type: customMessage.metadata?['type']?.toString() ?? 'C2C',
        message: customMessage,
        registry: messageTypeRegistry,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.7;

        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: bubble_style.MessageBubbleStyle.getBubbleDecoration(
            context: context,
            isSentByMe: isMe,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MessageTextPlaceholder(),
              SizedBox(height: 4),
              _MessageTimePlaceholder(),
            ],
          ),
        );
      },
    );
  }
}

/// 消息文本占位符（实际使用时需要传入 message）
class _MessageTextPlaceholder extends StatelessWidget {
  const _MessageTextPlaceholder();

  @override
  Widget build(BuildContext context) {
    // 这是一个占位符，实际实现需要根据 message 类型渲染
    // 在 flutter_chat_ui 的 Chat 组件中会替换为实际的文本组件
    return const SizedBox.shrink();
  }
}

/// 消息时间占位符
class _MessageTimePlaceholder extends StatelessWidget {
  const _MessageTimePlaceholder();

  @override
  Widget build(BuildContext context) {
    // 这是一个占位符，实际实现会显示时间
    return const SizedBox.shrink();
  }
}
