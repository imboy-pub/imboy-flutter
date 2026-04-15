import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 朋友圈模块专用的确认对话框。
///
/// 为什么不复用 `EasyDialog.showConfirm`：
/// - `EasyDialog` 是 callback 风格（`onConfirm`/`onCancel`），需要自己 pop；
///   这里的调用方希望 `Future<bool>` 直接 await，两种 API 叠加更乱。
/// - 破坏性操作（删除朋友圈、删除评论）需要 `AppColors.iosRed` 的确认按钮，
///   改共享 dialog 会污染其他模块；模块私有更安全。
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
            child: Text(cancelLabel ?? t.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel ?? t.confirm,
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
