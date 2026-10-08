import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class GroupScheduleDraft {
  const GroupScheduleDraft(this.title, this.start);
  final String title;
  final DateTime start;
}

/// 日历与 24 小时时钟选择；始终回显具体日期时间，不再叠加底部滚轮。
class GroupScheduleCreateDialog extends StatefulWidget {
  const GroupScheduleCreateDialog({super.key, this.initialStart});
  final DateTime? initialStart;
  @override
  State<GroupScheduleCreateDialog> createState() =>
      _GroupScheduleCreateDialogState();
}

class _GroupScheduleCreateDialogState extends State<GroupScheduleCreateDialog> {
  final _title = TextEditingController();
  late DateTime _start;
  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialStart ?? DateTime.now().add(const Duration(hours: 1));
    _start = DateTime(
      initial.year,
      initial.month,
      initial.day,
      initial.hour,
      initial.minute,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _start = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _start.hour,
          _start.minute,
        );
      });
    }
  }

  Future<void> _time() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _start = DateTime(
          _start.year,
          _start.month,
          _start.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Widget _fields(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.regular),
        CupertinoTextField(
          controller: _title,
          placeholder: t.groupSchedule.scheduleTitle,
          enableSuggestions: true,
          autocorrect: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.regular),
        CupertinoButton(
          onPressed: _date,
          child: Row(
            children: [
              const Icon(CupertinoIcons.calendar),
              const SizedBox(width: AppSpacing.small),
              Expanded(child: Text(localizations.formatMediumDate(_start))),
            ],
          ),
        ),
        CupertinoButton(
          onPressed: _time,
          child: Row(
            children: [
              const Icon(CupertinoIcons.clock),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  localizations.formatTimeOfDay(
                    TimeOfDay.fromDateTime(_start),
                    alwaysUse24HourFormat: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(t.groupSchedule.createSchedule),
    content: _fields(context),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: Text(t.common.cancel),
      ),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: _title.text.trim().isEmpty || !_start.isAfter(DateTime.now())
            ? null
            : () => Navigator.pop(
                context,
                GroupScheduleDraft(_title.text.trim(), _start),
              ),
        child: Text(t.common.confirm),
      ),
    ],
  );
}
