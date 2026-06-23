import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:xid/xid.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_schedule_service.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群日程页面
class GroupSchedulePage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupSchedulePage({super.key, required this.groupId});

  @override
  ConsumerState<GroupSchedulePage> createState() => _GroupSchedulePageState();
}

class _GroupSchedulePageState extends ConsumerState<GroupSchedulePage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);

    final schedules = await GroupScheduleService.to.getSchedules(
      groupId: widget.groupId,
    );

    if (mounted) {
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    }
  }

  Future<void> _createSchedule() async {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.groupSchedule.createSchedule),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: t.groupSchedule.scheduleTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.regular),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(t.groupSchedule.selectDate),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        selectedDate = date;
                      }
                    },
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(t.groupSchedule.selectTime),
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        selectedTime = time;
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      final startTime =
          DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          ).millisecondsSinceEpoch ~/
          1000;

      final schedule = await GroupScheduleService.to.createSchedule(
        groupId: widget.groupId,
        title: titleController.text,
        startTime: startTime,
      );
      if (schedule != null && mounted) {
        _loadSchedules();

        // 自动向群内分发一条交互式群日程卡片消息
        try {
          final currentUid = UserRepoLocal.to.currentUid;
          final timeStr =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

          final message = CustomMessage(
            authorId: currentUid,
            id: Xid().toString(),
            createdAt: DateTime.now(),
            metadata: {
              'msg_type': 'groupSchedule',
              'id': schedule['id']?.toString() ?? '',
              'group_id': widget.groupId,
              'title': titleController.text,
              'start_time': timeStr,
            },
          );

          await ref
              .read(chatProvider.notifier)
              .addMessage(
                currentUid,
                widget.groupId,
                '', // Group Avatar
                '', // Group Title
                'C2G', // MessageFlowType.c2g
                message,
              );
        } catch (e) {
          debugPrint('发送群日程消息失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupSchedule.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createSchedule,
            tooltip: t.groupSchedule.createSchedule,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_schedules.isEmpty) {
      return NoDataView(
        text: t.groupSchedule.noSchedule,
        onTop: _loadSchedules,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final schedule = _schedules[index];
          return _buildScheduleItem(schedule);
        },
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final startTime = _toInt(schedule['start_time'] ?? schedule['start_at']);
    final dt = DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
    final scheduleId = _resolveScheduleRouteId(schedule);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: InkWell(
        onTap: () async {
          if (scheduleId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.groupSchedule.scheduleIdMissing)),
            );
            return;
          }
          final encodedId = Uri.encodeComponent(scheduleId);
          await context.push('/group/${widget.groupId}/schedule/$encodedId');
          if (mounted) {
            _loadSchedules();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.regular),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${dt.day}',
                      style: TextStyle(
                        fontSize: FontSizeType.extraLarge.size,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getMonthName(dt.month),
                      style: TextStyle(fontSize: FontSizeType.small.size),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.regular),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['title'] as String? ?? '',
                      style: TextStyle(
                        fontSize: FontSizeType.medium.size,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.verticalTiny,
                    Text(
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (schedule['location'] != null) ...[
                      AppSpacing.verticalTiny,
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14),
                          Text(
                            schedule['location'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _toText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _resolveScheduleRouteId(Map<String, dynamic> schedule) {
    final scheduleId = _toText(schedule['schedule_id']);
    if (scheduleId.isNotEmpty) {
      return scheduleId;
    }
    return _toText(schedule['id']);
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
