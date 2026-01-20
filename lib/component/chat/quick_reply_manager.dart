import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

/// 快捷回复管理器
/// 提供智能快捷回复建议
class QuickReplyManager {
  static const List<String> _defaultReplies = [
    '好的',
    '收到',
    '谢谢',
    '明白了',
    '稍等',
    '没问题',
    '马上到',
    '好的，谢谢',
    '👍',
    '👌',
    '😊',
  ];

  static const Map<String, List<String>> _contextReplies = {
    '问候': ['你好！', '最近怎么样？', '好久不见', '忙什么呢？'],
    '感谢': ['不客气', '应该的', '互相帮助', '乐意效劳'],
    '道歉': ['没关系', '不要紧', '理解', '没事的'],
    '邀请': ['好的，有时间', '看情况', '下次吧', '谢谢邀请'],
    '告别': ['再见', '保持联系', '有空聊', '拜拜'],
    '工作': ['收到，马上处理', '好的，明白了', '稍后回复您', '正在处理中'],
    '询问': ['是的', '不是', '可能吧', '让我想想'],
  };

  /// 获取默认快捷回复
  static List<String> getDefaultReplies() {
    return List<String>.from(_defaultReplies);
  }

  /// 根据上下文获取智能快捷回复
  static List<String> getContextualReplies(String lastMessage) {
    final message = lastMessage.toLowerCase();

    // 根据关键词返回相应的快捷回复
    if (message.contains('谢') || message.contains('thank')) {
      return _contextReplies['感谢'] ?? _defaultReplies;
    }

    if (message.contains('对不') ||
        message.contains('抱歉') ||
        message.contains('sorry')) {
      return _contextReplies['道歉'] ?? _defaultReplies;
    }

    if (message.contains('邀请') ||
        message.contains('一起') ||
        message.contains('join')) {
      return _contextReplies['邀请'] ?? _defaultReplies;
    }

    if (message.contains('再见') ||
        message.contains('bye') ||
        message.contains('拜拜')) {
      return _contextReplies['告别'] ?? _defaultReplies;
    }

    if (message.contains('工作') ||
        message.contains('任务') ||
        message.contains('work')) {
      return _contextReplies['工作'] ?? _defaultReplies;
    }

    if (message.contains('吗') ||
        message.contains('?') ||
        message.contains('？')) {
      return _contextReplies['询问'] ?? _defaultReplies;
    }

    if (message.contains('你好') ||
        message.contains('hi') ||
        message.contains('hello')) {
      return _contextReplies['问候'] ?? _defaultReplies;
    }

    return _defaultReplies;
  }

  /// 添加自定义快捷回复
  static List<String> addCustomReply(
    List<String> currentReplies,
    String customReply,
  ) {
    if (customReply.trim().isNotEmpty &&
        !currentReplies.contains(customReply)) {
      final newReplies = List<String>.from(currentReplies);
      newReplies.add(customReply);
      return newReplies;
    }
    return currentReplies;
  }
}

/// 快捷回复面板组件
class QuickReplyPanel extends StatelessWidget {
  const QuickReplyPanel({
    super.key,
    required this.onReplySelected,
    required this.lastMessage,
    this.customReplies = const [],
  });

  final Function(String) onReplySelected;
  final String lastMessage;
  final List<String> customReplies;

  @override
  Widget build(BuildContext context) {
    // 获取智能快捷回复
    final contextualReplies = QuickReplyManager.getContextualReplies(
      lastMessage,
    );

    // 合并默认回复和自定义回复
    final allReplies = [...contextualReplies, ...customReplies];

    // 去重
    final uniqueReplies = allReplies.toSet().toList();

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: uniqueReplies.length,
        itemBuilder: (context, index) {
          final reply = uniqueReplies[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              onPressed: () => onReplySelected(reply),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                reply,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 消息操作菜单组件
class MessageActionMenu extends StatelessWidget {
  const MessageActionMenu({
    super.key,
    required this.message,
    required this.onAction,
  });

  final Message message;
  final Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildActionItems(context),
      ),
    );
  }

  List<Widget> _buildActionItems(BuildContext context) {
    final items = <Widget>[];

    // 复制
    if (message is TextMessage) {
      items.add(
        _buildActionItem(context, '复制', Icons.copy, () => onAction('copy')),
      );
    }

    // 回复
    items.add(
      _buildActionItem(context, '回复', Icons.reply, () => onAction('reply')),
    );

    // 转发
    items.add(
      _buildActionItem(context, '转发', Icons.forward, () => onAction('forward')),
    );

    // 收藏
    items.add(
      _buildActionItem(
        context,
        '收藏',
        Icons.bookmark_border,
        () => onAction('collect'),
      ),
    );

    // 删除
    items.add(
      _buildActionItem(
        context,
        '删除',
        Icons.delete_outline,
        () => onAction('delete'),
        isDestructive: true,
      ),
    );

    return items;
  }

  Widget _buildActionItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).iconTheme.color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).textTheme.titleMedium?.color,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
