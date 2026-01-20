import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/page/chat/widget/message_bubble_style.dart'
    as bubble_style;

/// 聊天消息列表组件（性能优化版）
/// 移除 Dismissible 和 AnimatedBuilder 以提升滚动性能
///
/// 使用方式：
/// ```dart
/// ChatMessageList(
///   messages: messages,
///   currentUserId: currentUserId,
///   onMessageLongPress: (message) { ... },
///   onMessageDoubleTap: (message) { ... },
///   onMessageTap: (message) { ... },
/// )
/// ```
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.onMessageLongPress,
    required this.onMessageDoubleTap,
    this.onMessageTap,
    this.scrollController,
    this.onEndReached,
    this.onStartReached,
  });

  final List<Message> messages;
  final String currentUserId;
  final Function(Message) onMessageLongPress;
  final Function(Message) onMessageDoubleTap;
  final Function(Message)? onMessageTap;
  final ScrollController? scrollController;
  final Future<void> Function()? onEndReached;
  final Future<void> Function()? onStartReached;

  // 估算的消息项高度，用于 ListView 滚动优化
  static const double _estimatedItemExtent = 80.0;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      cacheExtent: 500.0,
      // 添加 itemExtent 帮助 ListView 预计算滚动位置
      itemExtent: _estimatedItemExtent,
      physics: const BouncingScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.authorId == currentUserId;

        return _MessageItem(
          message: message,
          isMe: isMe,
          onTap: () => onMessageTap?.call(message),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onMessageLongPress(message);
          },
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            onMessageDoubleTap(message);
          },
        );
      },
    );
  }
}

/// 消息项组件（优化版 - 移除 Dismissible 和 AnimatedBuilder）
class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.isMe,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
  });

  final Message message;
  final bool isMe;
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
          ? _SentMessageWrapper(message: message)
          : _ReceivedMessageWrapper(message: message),
    );
  }
}

/// 接收方消息包装器（优化版 - 避免条件渲染）
class _ReceivedMessageWrapper extends StatelessWidget {
  const _ReceivedMessageWrapper({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Avatar(),
          SizedBox(width: 8),
          Flexible(child: _MessageBubble(isMe: false)),
        ],
      ),
    );
  }
}

/// 发送方消息包装器（优化版 - 避免条件渲染）
class _SentMessageWrapper extends StatelessWidget {
  const _SentMessageWrapper({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: _MessageBubble(isMe: true)),
          SizedBox(width: 8),
          _MessageStatusIcon(),
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
        Icons.person,
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
  static const Color _deliveredColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.done_all, size: 16, color: _deliveredColor);
  }
}

/// 消息气泡组件
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.isMe});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.7;

        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: bubble_style.MessageBubbleStyle.getBubbleDecoration(
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
