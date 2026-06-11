import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 朋友圈模块专用的确认对话框。
///
/// 约束：
/// - barrier 点击视为"取消"，返回 false（防止点空白误触发破坏性操作）。
/// - `isDestructive = true` 时 confirm 按钮文字色切到 `AppColors.iosRed`。
/// - 不自带 i18n 文案，调用方传入已翻译好的字符串；helper 只负责结构。
Future<bool> showMomentConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) async {
  final t = context.t;
  final theme = Theme.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel ?? t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel ?? t.common.confirm,
              style: TextStyle(
                color: isDestructive
                    ? AppColors.iosRed
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
