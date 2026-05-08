import 'package:flutter/material.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';

// 对话框类型枚举
enum DialogType {
  confirm, // 确认对话框
  warning, // 警告对话框
  info, // 信息对话框
  error, // 错误对话框
}

class EasyDialog extends StatelessWidget {
  final DialogType type;
  final String? title;
  final Widget? content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool barrierDismissible;
  final bool showCloseButton;

  const EasyDialog({
    super.key,
    required this.type,
    this.title,
    this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.barrierDismissible = true,
    this.showCloseButton = false,
  });

  // 显示确认对话框
  static Future<T?> showConfirm<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => EasyDialog(
        type: DialogType.confirm,
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  // 显示警告对话框
  static Future<T?> showWarning<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required String confirmText,
    String? cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => EasyDialog(
        type: DialogType.warning,
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText ?? '取消',
        onConfirm: onConfirm,
        onCancel: onCancel,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  // 显示信息对话框
  static Future<T?> showInfo<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? confirmText,
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => EasyDialog(
        type: DialogType.info,
        title: title,
        content: content,
        confirmText: confirmText ?? '确定',
        onConfirm: onConfirm ?? () => Navigator.of(context).pop(),
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  // 显示错误对话框
  static Future<T?> showError<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? confirmText,
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => EasyDialog(
        type: DialogType.error,
        title: title,
        content: content,
        confirmText: confirmText ?? '确定',
        onConfirm: onConfirm ?? () => Navigator.of(context).pop(),
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContentDialog(context);
  }

  Widget _buildContentDialog(BuildContext context) {
    final theme = Theme.of(context);

    // 根据对话框类型确定图标和颜色
    IconData iconData;
    Color iconColor;
    Color dialogColor;
    Color actionButtonColor;

    switch (type) {
      case DialogType.confirm:
        iconData = Icons.help_outline;
        iconColor = theme.colorScheme.primary;
        dialogColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.1);
        actionButtonColor = theme.colorScheme.primary;
        break;
      case DialogType.warning:
        iconData = Icons.warning_amber_outlined;
        iconColor = Colors.orange;
        dialogColor = Colors.orange.withValues(alpha: 0.1);
        actionButtonColor = Colors.orange;
        break;
      case DialogType.error:
        iconData = Icons.error_outline;
        iconColor = theme.colorScheme.error;
        dialogColor = theme.colorScheme.error.withValues(alpha: 0.1);
        actionButtonColor = theme.colorScheme.error;
        break;
      case DialogType.info:
        iconData = Icons.info_outline;
        iconColor = theme.colorScheme.secondary;
        dialogColor = theme.colorScheme.secondaryContainer.withValues(
          alpha: 0.1,
        );
        actionButtonColor = theme.colorScheme.primary;
        break;
    }

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      title: type == DialogType.confirm
          ? Text(
              title ?? '',
              style: ThemeManager.instance.getTextStyle(
                FontSizeType.large,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: dialogColor,
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(iconData, size: 24, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title ?? '',
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (showCloseButton) ...[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
      content: content ?? const SizedBox.shrink(),
      actions: _buildActions(context, actionButtonColor),
    );
  }

  List<Widget> _buildActions(BuildContext context, Color actionButtonColor) {
    final theme = Theme.of(context);

    switch (type) {
      case DialogType.confirm:
      case DialogType.warning:
        return [
          TextButton(
            onPressed: () {
              onCancel?.call();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusSmall,
              ),
            ),
            child: Text(
              cancelText ?? '取消',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusSmall,
              ),
            ),
            child: Text(
              confirmText ?? '确定',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ];
      case DialogType.info:
      case DialogType.error:
        return [
          ElevatedButton(
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusSmall,
              ),
            ),
            child: Text(
              confirmText ?? '确定',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ];
    }
  }
}
