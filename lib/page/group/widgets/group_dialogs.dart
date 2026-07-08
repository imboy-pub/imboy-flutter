import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';

/// 群聊模块统一弹层组件。
///
/// 消除 Material `AlertDialog` / `showDialog` 与 iOS `CupertinoAlertDialog` /
/// `CupertinoActionSheet` 混用导致的视觉割裂。全模块一律走这两个入口。
class GroupDialogs {
  GroupDialogs._();

  /// iOS 风格确认弹窗（替代 Material AlertDialog）。
  ///
  /// [title] 标题；[content] 正文；[confirmText]/[cancelText] 按钮文案；
  /// [destructive] 确认按钮是否为危险样式（红色）。
  /// 返回 `true` 表示用户点了确认。
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? content,
    String? confirmText,
    String? cancelText,
    bool destructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText ?? t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText ?? t.common.buttonConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// iOS 风格底部操作表（替代 Material showModalBottomSheet 的简单菜单场景）。
  ///
  /// [actions] 为 `(文案, 是否危险, 回调)` 列表；自动追加「取消」按钮。
  static Future<void> actionSheet(
    BuildContext context, {
    String? title,
    required List<({String label, bool destructive, VoidCallback onPressed})>
    actions,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: actions
            .map(
              (a) => CupertinoActionSheetAction(
                isDestructiveAction: a.destructive,
                onPressed: () {
                  Navigator.pop(ctx);
                  a.onPressed();
                },
                child: Text(a.label),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }
}
