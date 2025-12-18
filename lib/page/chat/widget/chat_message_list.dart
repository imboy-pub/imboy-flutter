import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
import 'package:imboy/page/chat/widget/message_bubble_style.dart' as bubble_style;

/// 增强的聊天消息列表组件
/// 提供现代化的交互体验和性能优化
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.onMessageLongPress,
    required this.onMessageDoubleTap,
    required this.onMessageSwipe,
    this.highlightedMessageId,
    this.onMessageTap,
  });

  final List<Message> messages;
  final String currentUserId;
  final Function(Message) onMessageLongPress;
  final Function(Message) onMessageDoubleTap;
  final Function(Message) onMessageSwipe;
  final String? highlightedMessageId;
  final Function(Message)? onMessageTap;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList>
    with TickerProviderStateMixin {
  
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 处理消息高亮动画
    if (widget.highlightedMessageId != null && 
        widget.highlightedMessageId != oldWidget.highlightedMessageId) {
      _highlightController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _highlightController.reverse();
        });
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isMe = message.authorId == widget.currentUserId;
        final isHighlighted = message.id == widget.highlightedMessageId;
        
        return _buildMessageItem(
          message: message,
          isMe: isMe,
          isHighlighted: isHighlighted,
          index: index,
        );
      },
    );
  }

  /// 构建消息项
  Widget _buildMessageItem({
    required Message message,
    required bool isMe,
    required bool isHighlighted,
    required int index,
  }) {
    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => widget.onMessageTap?.call(message),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onMessageLongPress(message);
          },
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            widget.onMessageDoubleTap(message);
          },
          child: Dismissible(
            key: Key(message.id),
            direction: isMe 
                ? DismissDirection.endToStart 
                : DismissDirection.startToEnd,
            confirmDismiss: (direction) async {
              HapticFeedback.lightImpact();
              widget.onMessageSwipe(message);
              return false; // 不实际删除，只触发回调
            },
            background: _buildSwipeBackground(isMe),
            child: Container(
              decoration: isHighlighted
                  ? BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 
                        0.1 * _highlightAnimation.value,
                      ),
                    )
                  : null,
              child: _buildMessageContent(message, isMe),
            ),
          ),
        );
      },
    );
  }

  /// 构建滑动背景
  Widget _buildSwipeBackground(bool isMe) {
    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.reply,
        color: Theme.of(context).primaryColor,
        size: 24,
      ),
    );
  }

  /// 构建消息内容
  Widget _buildMessageContent(Message message, bool isMe) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
      child: Row(
        mainAxisAlignment: isMe 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(message),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: _buildMessageBubble(message, isMe),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildMessageStatus(message),
        ],
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(Message message) {
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

  /// 构建消息气泡
  Widget _buildMessageBubble(Message message, bool isMe) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: bubble_style.MessageBubbleStyle.getBubbleDecoration(
        isSentByMe: isMe,
        isHighlighted: message.id == widget.highlightedMessageId,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageText(message, isMe),
          const SizedBox(height: 4),
          _buildMessageTime(message),
        ],
      ),
    );
  }

  /// 构建消息文本
  Widget _buildMessageText(Message message, bool isMe) {
    if (message is TextMessage) {
      return Text(
        message.text,
        style: bubble_style.MessageBubbleStyle.getMessageTextStyle(
          isSentByMe: isMe,
          context: context,
        ),
      );
    }
    
    // 其他消息类型的处理
    return Text(
      '不支持的消息类型',
      style: bubble_style.MessageBubbleStyle.getMessageTextStyle(
        isSentByMe: isMe,
        context: context,
      ),
    );
  }

  /// 构建消息时间
  Widget _buildMessageTime(Message message) {
    return Text(
      _formatTime(message.createdAt ?? DateTime.now()),
      style: bubble_style.MessageBubbleStyle.getTimestampStyle(context),
    );
  }

  /// 构建消息状态
  Widget _buildMessageStatus(Message message) {
    return Column(
      children: [
        Icon(
          Icons.done_all,
          size: 16,
          color: bubble_style.MessageBubbleStyle.getStatusIconColor(
            isSentByMe: true,
            context: context,
            status: bubble_style.MessageStatus.delivered,
          ),
        ),
      ],
    );
  }

  /// 格式化时间
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}