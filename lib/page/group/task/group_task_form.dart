import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 群作业创建/编辑共用的表单结果
class GroupTaskFormResult {
  const GroupTaskFormResult({required this.title, required this.description});

  final String title;
  final String description;
}

/// 创建/编辑群作业的 Cupertino 表单弹窗。
///
/// 标题为空时确认不生效（弹窗保持打开），与既有测试行为一致。
/// [confirmKey] / [titleFieldKey] 供 widget 测试定位，创建与编辑场景可分别命名。
Future<GroupTaskFormResult?> showGroupTaskFormDialog(
  BuildContext context, {
  required String dialogTitle,
  String? initialTitle,
  String? initialDescription,
  Key confirmKey = const Key('create_task_confirm'),
  Key titleFieldKey = const Key('task_title_field'),
}) async {
  final t = context.t;
  final titleController = TextEditingController(text: initialTitle ?? '');
  final descController = TextEditingController(text: initialDescription ?? '');

  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          CupertinoTextField(
            enableSuggestions: true,
            autocorrect: true,
            key: titleFieldKey,
            controller: titleController,
            placeholder: t.groupTask.taskTitle,
          ),
          const SizedBox(height: AppSpacing.regular),
          CupertinoTextField(
            enableSuggestions: true,
            autocorrect: true,
            controller: descController,
            maxLines: 3,
            placeholder: t.groupTask.taskDescription,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          key: confirmKey,
          isDefaultAction: true,
          onPressed: () {
            if (titleController.text.trim().isNotEmpty) {
              Navigator.pop(ctx, true);
            }
          },
          child: Text(t.common.confirm),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;
  final title = titleController.text.trim();
  if (title.isEmpty) return null;
  return GroupTaskFormResult(
    title: title,
    description: descController.text.trim(),
  );
}
