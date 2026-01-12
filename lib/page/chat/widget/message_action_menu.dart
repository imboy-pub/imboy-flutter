import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 消息操作菜单组件
/// 提供现代化的消息操作界面
class MessageActionMenu extends StatelessWidget {
  const MessageActionMenu({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.onReply,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
    required this.onForward,
    required this.onReaction,
    this.onRevoke,
    this.onSave,
    this.onCollect,
    this.onDeleteForEveryone, // 新增：删除所有人的消息
    this.onRetry, // 新增：重试功能
    this.onClose,
    this.canEdit = false,
  });

  final Message message;
  final bool isSentByMe;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;  // 删除我的消息
  final VoidCallback onForward;
  final Function(String) onReaction;
  final VoidCallback? onRevoke;  // 新增：撤回功能
  final VoidCallback? onSave;    // 新增：保存功能
  final VoidCallback? onCollect; // 新增：收藏功能
  final VoidCallback? onDeleteForEveryone; // 新增：删除所有人的消息
  final VoidCallback? onRetry; // 新增：重试功能
  final VoidCallback? onClose;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快速反应区域
          _buildReactionSection(context),

          // 分割线
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 操作按钮区域
          _buildActionSection(context),
        ],
      ),
    );
  }

  /// 构建快速反应区域
  Widget _buildReactionSection(BuildContext context) {
    final reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.map((emoji) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onReaction(emoji);
              onClose?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建操作区域
  Widget _buildActionSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // 第一行操作：通用操作
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                context: context,
                icon: Icons.reply,
                label: t.quote,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onReply();
                  onClose?.call();
                },
              ),
              _buildActionButton(
                context: context,
                icon: Icons.copy,
                label: t.buttonCopy,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCopy();
                  onClose?.call();
                },
              ),
              _buildActionButton(
                context: context,
                icon: Icons.moving,
                label: t.forward,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onForward();
                  onClose?.call();
                },
              ),
              if (onCollect != null)
                _buildActionButton(
                  context: context,
                  icon: Icons.collections_bookmark,
                  label: t.favorites,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCollect!();
                    onClose?.call();
                  },
                ),
            ],
          ),

          // 第二行操作：保存和发送者操作
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 保存按钮（适用于图片、文件、视频、语音）
              if (onSave != null)
                _buildActionButton(
                  context: context,
                  icon: Icons.save_alt,
                  label: t.buttonSave,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSave!();
                    onClose?.call();
                  },
                ),

              // 发送者可见的操作
              if (isSentByMe) ...[
                // 重试按钮（仅发送失败的消息）
                if (onRetry != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.refresh,
                    label: '重试',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onRetry!();
                      onClose?.call();
                    },
                  ),
                // 编辑按钮（仅文本消息且发送后2分钟内）
                if (canEdit)
                  _buildActionButton(
                    context: context,
                    icon: Icons.edit,
                    label: '编辑',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onEdit();
                      onClose?.call();
                    },
                  ),
                // 撤回按钮（发送者专有）
                if (onRevoke != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.layers_clear_rounded,
                    label: t.revoke,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onRevoke!();
                      onClose?.call();
                    },
                  ),
                // 删除按钮（发送者：可选择删除所有人或仅自己）
                _buildActionButton(
                  context: context,
                  icon: Icons.delete,
                  label: t.buttonDelete,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showDeleteConfirmation(context);
                  },
                  isDestructive: true,
                ),
              ] else ...[
                // 接收者：仅可删除自己看到的消息
                _buildActionButton(
                  context: context,
                  icon: Icons.delete,
                  label: t.deleteForMe,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                    onClose?.call();
                  },
                  isDestructive: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDestructive
                        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDestructive
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context) {
    if (isSentByMe) {
      // 发送者：可选择删除所有人或仅自己
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(t.buttonDelete),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(t.deleteForMe),
                  subtitle: Text('仅在你这里删除，对方仍可见'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                    onClose?.call();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.group, color: Colors.red),
                  title: Text(t.deleteForEveryone),
                  subtitle: Text('从所有人的聊天中删除，无法撤销'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // 删除所有人的消息
                    if (onDeleteForEveryone != null) {
                      onDeleteForEveryone!();
                    } else {
                      onDelete(); // 后备方案
                    }
                    onClose?.call();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(t.buttonCancel),
              ),
            ],
          );
        },
      );
    } else {
      // 接收者：仅可删除自己看到的
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(t.buttonDelete),
            content: Text('确定要删除这条消息吗？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(t.buttonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDelete();
                  onClose?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(t.buttonDelete),
              ),
            ],
          );
        },
      );
    }
  }
}

/// 显示消息操作菜单的工具函数
void showMessageActionMenu({
  required BuildContext context,
  required Message message,
  required bool isSentByMe,
  required VoidCallback onReply,
  required VoidCallback onCopy,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onForward,
  required Function(String) onReaction,
  VoidCallback? onRevoke,   // 新增：撤回回调
  VoidCallback? onSave,     // 新增：保存回调
  VoidCallback? onCollect,  // 新增：收藏回调
  VoidCallback? onDeleteForEveryone, // 新增：删除所有人的消息
  VoidCallback? onRetry,   // 新增：重试回调
  bool canEdit = false,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: MessageActionMenu(
          message: message,
          isSentByMe: isSentByMe,
          onReply: onReply,
          onCopy: onCopy,
          onEdit: onEdit,
          onDelete: onDelete,
          onForward: onForward,
          onReaction: onReaction,
          onRevoke: onRevoke,
          onSave: onSave,
          onCollect: onCollect,
          onDeleteForEveryone: onDeleteForEveryone,
          onRetry: onRetry,
          canEdit: canEdit,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    },
  );
}