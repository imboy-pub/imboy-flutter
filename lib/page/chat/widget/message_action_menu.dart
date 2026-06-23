import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// Reaction 表情按钮的最小触达尺寸（pt）。
///
/// 来源：DESIGN.md §13.2 Hard Rule 1 / iOS HIG 硬指标 ——
/// 任何可点击元素最小可触区域 44×44pt。
///
/// 视觉气泡（emoji + padding）尺寸保持 ~36pt 不变，
/// 通过 `BoxConstraints(minWidth/minHeight)` 仅扩展 hit area。
const double _kReactionMinTouchTarget = 44.0;

/// 消息操作菜单组件
/// 提供现代化的消息操作界面
class MessageActionMenu extends StatefulWidget {
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
  final VoidCallback onDelete; // 删除我的消息
  final VoidCallback onForward;
  final void Function(String) onReaction;
  final VoidCallback? onRevoke; // 新增：撤回功能
  final VoidCallback? onSave; // 新增：保存功能
  final VoidCallback? onCollect; // 新增：收藏功能
  final VoidCallback? onDeleteForEveryone; // 新增：删除所有人的消息
  final VoidCallback? onRetry; // 新增：重试功能
  final VoidCallback? onClose;
  final bool canEdit;

  @override
  State<MessageActionMenu> createState() => _MessageActionMenuState();
}

class _MessageActionMenuState extends State<MessageActionMenu> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusLarge,
        // DESIGN.md §5.2 例外：长按 ActionSheet 是 FAB-like 浮起 UI
        // 推荐值 0 2 8 rgba(0,0,0,0.08)；原双层强投影 (0.15+0.05) 收敛为单层柔光
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  AppColors.transparent,
                  Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  AppColors.transparent,
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
          // 触达层（≥44×44pt，DESIGN.md §13.2 Hard Rule 1）。
          // 视觉气泡保留原 padding(8)+fontSize(20) 紧凑外观，
          // 由 ConstrainedBox 把 hit area 扩到 44×44pt。
          return GestureDetector(
            key: ValueKey('reaction_$emoji'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onReaction(emoji);
              widget.onClose?.call();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kReactionMinTouchTarget,
                minHeight: _kReactionMinTouchTarget,
              ),
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: AppSpacing.allSmall,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusLarge,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    emoji,
                    style: context.textStyle(FontSizeType.extraLarge),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建操作区域
  Widget _buildActionSection(BuildContext context) {
    final t = context.t;
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
                label: t.main.quote,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onReply();
                  widget.onClose?.call();
                },
              ),
              _buildActionButton(
                context: context,
                icon: Icons.copy,
                label: t.common.buttonCopy,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onCopy();
                  widget.onClose?.call();
                },
              ),
              _buildActionButton(
                context: context,
                icon: Icons.moving,
                label: t.chat.forward,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onForward();
                  widget.onClose?.call();
                },
              ),
              if (widget.onCollect != null)
                _buildActionButton(
                  context: context,
                  icon: Icons.collections_bookmark,
                  label: t.main.favorites,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onCollect!();
                    widget.onClose?.call();
                  },
                ),
            ],
          ),

          // 第二行操作：保存和发送者操作
          AppSpacing.verticalSmall,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 保存按钮（适用于图片、文件、视频、语音）
              if (widget.onSave != null)
                _buildActionButton(
                  context: context,
                  icon: Icons.save_alt,
                  label: t.common.buttonSave,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSave!();
                    widget.onClose?.call();
                  },
                ),

              // 发送者可见的操作
              if (widget.isSentByMe) ...[
                // 重试按钮（仅发送失败的消息）
                if (widget.onRetry != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.refresh,
                    label: t.common.buttonRetry,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onRetry!();
                      widget.onClose?.call();
                    },
                  ),
                // 编辑按钮（仅文本消息且发送后2分钟内）
                if (widget.canEdit)
                  _buildActionButton(
                    context: context,
                    icon: Icons.edit,
                    label: t.common.edit,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onEdit();
                      widget.onClose?.call();
                    },
                  ),
                // 撤回按钮（发送者专有）
                if (widget.onRevoke != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.layers_clear_rounded,
                    label: t.chat.revoke,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onRevoke!();
                      widget.onClose?.call();
                    },
                  ),
                // 删除按钮（发送者：可选择删除所有人或仅自己）
                _buildActionButton(
                  context: context,
                  icon: Icons.delete,
                  label: t.common.buttonDelete,
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
                  label: t.common.deleteForMe,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onDelete();
                    widget.onClose?.call();
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
    final destructiveColor = AppColors.getIosRed(Theme.of(context).brightness);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
                        ? destructiveColor.withValues(alpha: 0.1)
                        : primaryColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusMedium,
                    border: Border.all(
                      color: isDestructive
                          ? destructiveColor.withValues(alpha: 0.2)
                          : primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? destructiveColor : primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: FontSizeType.caption2.size,
                    color: isDestructive
                        ? destructiveColor
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
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context) {
    final t = context.t;
    if (widget.isSentByMe) {
      // 发送者：可选择删除所有人或仅自己
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(t.common.buttonDelete),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(t.common.deleteForMe),
                  subtitle: Text(t.common.chatDeleteOnlyLocal),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onDelete();
                    widget.onClose?.call();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.group, color: AppColors.iosRed),
                  title: Text(t.common.deleteForEveryone),
                  subtitle: Text(t.common.chatDeleteAll),
                  onTap: () {
                    Navigator.of(context).pop();
                    // 删除所有人的消息
                    if (widget.onDeleteForEveryone != null) {
                      widget.onDeleteForEveryone!();
                    } else {
                      widget.onDelete(); // 后备方案
                    }
                    widget.onClose?.call();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(t.common.buttonCancel),
              ),
            ],
          );
        },
      );
    } else {
      // 接收者：仅可删除自己看到的
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(t.common.buttonDelete),
            content: Text(t.common.chatDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(t.common.buttonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDelete();
                  widget.onClose?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.getIosRed(
                    Theme.of(context).brightness,
                  ),
                ),
                child: Text(t.common.buttonDelete),
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
  required void Function(String) onReaction,
  VoidCallback? onRevoke, // 新增：撤回回调
  VoidCallback? onSave, // 新增：保存回调
  VoidCallback? onCollect, // 新增：收藏回调
  VoidCallback? onDeleteForEveryone, // 新增：删除所有人的消息
  VoidCallback? onRetry, // 新增：重试回调
  bool canEdit = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.transparent,
    builder: (BuildContext context) {
      return Container(
        margin: AppSpacing.allRegular,
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
