import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';

class MessageInboxAction {
  const MessageInboxAction(
    this.label,
    this.onPressed, {
    this.destructive = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool destructive;
}

/// Long press exposes the same actions as swiping, without requiring a gesture.
Future<void> showMessageInboxActions(
  BuildContext context, {
  required String title,
  String? message,
  required List<MessageInboxAction> actions,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final action in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: action.destructive,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              action.onPressed();
            },
            child: Text(action.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(t.common.buttonCancel),
      ),
    ),
  );
}
