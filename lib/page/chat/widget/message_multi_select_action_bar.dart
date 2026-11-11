import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 多选模式底部操作栏（chat_multi_select_v1 / W2-E）。
///
/// ChatPage 在多选激活时用它替换输入区（TypingIndicator + ChatInput）：
/// - 左上：退出按钮（✕，44×44pt 触达）+ 已选计数；
/// - 右上：全不选（清空已选、保持多选，见 MessageSelectionNotifier.clear）；
/// - 第二行：逐条转发 / 合并转发 / 导出 三个动作位。
///
/// 动作位本波只暴露 **typed callbacks**（Central Wiring 接真实实现，
/// 见计划 §12）；callback 为 null 或选中数为 0 时按钮禁用。
/// [selectedMessages] 由 ChatPage 按冻结合同 §4.3（createdAt 从旧到新、
/// 同时间按列表稳定序）排序后传入 —— 本组件不重排、不取数。
class MessageMultiSelectActionBar extends StatelessWidget {
  const MessageMultiSelectActionBar({
    super.key,
    required this.selectedMessages,
    required this.onCancel,
    this.onClearSelection,
    this.onForwardEach,
    this.onForwardBundle,
    this.onExport,
  });

  /// 当前已选消息（旧→新）。空列表 = 多选激活但未勾选任何条目。
  final List<Message> selectedMessages;

  /// 退出多选模式（返回键 / ✕ 共用同一语义：exit 并清空）。
  final VoidCallback onCancel;

  /// 全不选：清空已选、保持多选激活（null 时隐藏按钮）。
  final VoidCallback? onClearSelection;

  /// 逐条转发（typed callback，Central Wiring 接线）。
  final void Function(List<Message> selectedMessages)? onForwardEach;

  /// 合并转发（typed callback，Central Wiring 接线）。
  final void Function(List<Message> selectedMessages)? onForwardBundle;

  /// 导出 / 系统分享（typed callback，Central Wiring 接线）。
  final void Function(List<Message> selectedMessages)? onExport;

  /// 退出按钮触达区（DESIGN.md §13.2 Hard Rule 1：≥44×44pt）。
  static const double kCancelTouchTarget = 44.0;

  bool get _hasSelection => selectedMessages.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          padding: AppSpacing.allSmall,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('multi_select_cancel'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onCancel,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: kCancelTouchTarget,
                        minHeight: kCancelTouchTarget,
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 20,
                          color: colorScheme.onSurface,
                          semanticLabel: t.chat.multiSelectCancel,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t.chat.multiSelectCount(count: selectedMessages.length),
                      key: const ValueKey('multi_select_count'),
                      style: context
                          .textStyle(FontSizeType.normal)
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                  if (onClearSelection != null)
                    GestureDetector(
                      key: const ValueKey('multi_select_clear'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _hasSelection ? onClearSelection : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.small,
                            ),
                            child: Text(
                              t.chat.multiSelectDeselectAll,
                              style: context
                                  .textStyle(FontSizeType.normal)
                                  .copyWith(
                                    color: _hasSelection
                                        ? colorScheme.primary
                                        : colorScheme.onSurface.withValues(
                                            alpha: 0.4,
                                          ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  _buildActionButton(
                    context: context,
                    key: const ValueKey('multi_select_forward_each'),
                    icon: CupertinoIcons.arrowshape_turn_up_right,
                    label: t.chat.multiSelectForwardEach,
                    enabled: _hasSelection,
                    onTap: onForwardEach,
                  ),
                  AppSpacing.horizontalTiny,
                  _buildActionButton(
                    context: context,
                    key: const ValueKey('multi_select_forward_bundle'),
                    icon: CupertinoIcons.square_stack_3d_up,
                    label: t.chat.multiSelectForwardBundle,
                    enabled: _hasSelection,
                    onTap: onForwardBundle,
                  ),
                  AppSpacing.horizontalTiny,
                  _buildActionButton(
                    context: context,
                    key: const ValueKey('multi_select_export'),
                    icon: CupertinoIcons.share,
                    label: t.chat.multiSelectExport,
                    enabled: _hasSelection,
                    onTap: onExport,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String label,
    required bool enabled,
    required void Function(List<Message>)? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    // typed callback 未接线（null）时同样禁用：Central Wiring 接线前按钮
    // 只作为占位动作位存在，不可触发任何行为。
    final bool actionable = enabled && onTap != null;
    final Color foreground = actionable
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.4);
    return Expanded(
      child: Semantics(
        button: true,
        enabled: actionable,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: actionable ? () => onTap(selectedMessages) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Container(
              padding: AppSpacing.allSmall,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: 0.08),
                borderRadius: AppRadius.borderRadiusMedium,
                border: Border.all(color: foreground.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: foreground),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context
                        .textStyle(FontSizeType.caption2)
                        .copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
