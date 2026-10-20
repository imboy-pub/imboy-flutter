import 'package:flutter/material.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 群作业创建/编辑共用的表单结果
class GroupTaskFormResult {
  const GroupTaskFormResult({required this.title, required this.description});

  final String title;
  final String description;
}

/// 创建/编辑群作业的表单底部面板。
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
  return showModalBottomSheet<GroupTaskFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: ResourcePageLayout.maxWidth),
    builder: (_) => _TaskFormSheet(
      title: dialogTitle,
      initialTitle: initialTitle ?? '',
      initialDescription: initialDescription ?? '',
      confirmKey: confirmKey,
      titleFieldKey: titleFieldKey,
    ),
  );
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({
    required this.title,
    required this.initialTitle,
    required this.initialDescription,
    required this.confirmKey,
    required this.titleFieldKey,
  });

  final String title, initialTitle, initialDescription;
  final Key confirmKey, titleFieldKey;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _description = TextEditingController(
    text: widget.initialDescription,
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: AppSpacing.allRegular,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_toolbar(), AppSpacing.verticalRegular, ..._fields()],
        ),
      ),
    ),
  );

  Widget _toolbar() => Row(
    children: [
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.common.cancel),
      ),
      Expanded(
        child: Text(
          widget.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _confirmAction(),
    ],
  );

  Widget _confirmAction() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _title,
    builder: (_, value, _) => CupertinoButton(
      key: widget.confirmKey,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      onPressed: value.text.trim().isEmpty
          ? null
          : () => Navigator.pop(
              context,
              GroupTaskFormResult(
                title: _title.text.trim(),
                description: _description.text.trim(),
              ),
            ),
      child: Text(context.t.common.confirm),
    ),
  );

  List<Widget> _fields() => [
    Text(context.t.groupTask.taskTitle),
    AppSpacing.verticalSmall,
    CupertinoTextField(
      key: widget.titleFieldKey,
      controller: _title,
      padding: AppSpacing.allMedium,
      placeholder: context.t.groupTask.taskTitle,
      textInputAction: TextInputAction.next,
    ),
    AppSpacing.verticalRegular,
    Text(context.t.groupTask.taskDescription),
    AppSpacing.verticalSmall,
    CupertinoTextField(
      controller: _description,
      padding: AppSpacing.allMedium,
      minLines: 3,
      maxLines: 6,
      placeholder: context.t.groupTask.taskDescription,
    ),
  ];
}
