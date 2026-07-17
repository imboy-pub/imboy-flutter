import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter/rendering.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:imboy/component/chat/message.dart' show CustomMessageBuilder;
import 'package:imboy/page/chat/widget/message_bubble_style.dart'
    as bubble_style;
import 'package:imboy/plugins/registry/message_type_registry.dart';

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
    this.messageTypeRegistry,
    this.targetMsgId,
    this.targetMessageKey,
  });

  final List<Message> messages;
  final String currentUserId;
  final void Function(Message) onMessageLongPress;
  final void Function(Message) onMessageDoubleTap;
  final void Function(Message)? onMessageTap;
  final ScrollController? scrollController;
  final Future<void> Function()? onEndReached;
  final Future<void> Function()? onStartReached;
  final MessageTypeRegistry? messageTypeRegistry;
  final String? targetMsgId;
  final Key? targetMessageKey;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      scrollCacheExtent: const ScrollCacheExtent.pixels(500.0),
      // 移除定高 itemExtent 以支持自适应内容高度，避免滚动跳动
      physics: const BouncingScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.authorId == currentUserId;

        // 如果是目标消息，绑定 GlobalKey
        Key? itemKey;
        if (targetMsgId != null && message.id == targetMsgId) {
          itemKey = targetMessageKey;
        }

        return _MessageItem(
          key: itemKey,
          message: message,
          isMe: isMe,
          messageTypeRegistry: messageTypeRegistry,
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
    super.key,
    required this.message,
    required this.isMe,
    this.messageTypeRegistry,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
  });

  final Message message;
  final bool isMe;
  final MessageTypeRegistry? messageTypeRegistry;
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
            )
          : _ReceivedMessageWrapper(
              message: message,
              messageTypeRegistry: messageTypeRegistry,
            ),
    );
  }
}

/// 接收方消息包装器（优化版 - 避免条件渲染）
class _ReceivedMessageWrapper extends StatelessWidget {
  const _ReceivedMessageWrapper({
    required this.message,
    this.messageTypeRegistry,
  });

  final Message message;
  final MessageTypeRegistry? messageTypeRegistry;

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
            ),
          ),
        ],
      ),
    );
  }
}

/// 发送方消息包装器（优化版 - 避免条件渲染）
class _SentMessageWrapper extends StatelessWidget {
  const _SentMessageWrapper({required this.message, this.messageTypeRegistry});

  final Message message;
  final MessageTypeRegistry? messageTypeRegistry;

  @override
  Widget build(BuildContext context) {
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
            ),
          ),
          AppSpacing.horizontalSmall,
          const _MessageStatusIcon(),
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
  static const Color _deliveredColor = AppColors.onlineIndicator;

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.done_all, size: 16, color: _deliveredColor);
  }
}

/// 消息气泡组件
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.messageTypeRegistry,
  });

  final Message message;
  final bool isMe;
  final MessageTypeRegistry? messageTypeRegistry;

  @override
  Widget build(BuildContext context) {
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
