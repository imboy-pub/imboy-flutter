import 'package:flutter/cupertino.dart';
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
import 'package:imboy/theme/default/app_colors.dart';
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
                      final date = await _pickCupertinoDate(
                        context,
                        initial: selectedDate,
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
                      final time = await _pickCupertinoTime(
                        context,
                        initial: selectedTime,
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

          // 【审计修复 F-14】client_msg_id 用于去重：服务端群广播若重新分配 id，
          // 客户端靠此字段识别"这是我自己发的"，避免回推时重复显示卡片。
          // local_origin 标记本地发起，与服务器回推的卡片在 type 层面区分。
          final clientMsgId = Xid().toString();
          final message = CustomMessage(
            authorId: currentUid,
            id: clientMsgId,
            createdAt: DateTime.now(),
            metadata: {
              'msg_type': 'groupSchedule',
              'id': schedule['id']?.toString() ?? '',
              'group_id': widget.groupId,
              'title': titleController.text,
              'start_time': timeStr,
              'local_origin': true,
              'client_msg_id': clientMsgId,
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

  /// iOS 风格日期选择器（底部滚轮），替代 Material showDatePicker。
  Future<DateTime?> _pickCupertinoDate(
    BuildContext context, {
    required DateTime initial,
  }) async {
    DateTime temp = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(t.common.cancel),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  child: Text(t.common.confirm),
                  onPressed: () => Navigator.pop(ctx, temp),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                // minimumDate 必须 <= initialDateTime，否则 CupertinoDatePicker
                // 断言崩溃。initial 是弹窗前捕获的时间戳，这里若用 DateTime.now()
                // 会取到"更晚的现在">initial → 点开选日期必现断言失败。改用今日
                // 零点（恒 <= initial，同时仍限制不能选过去）。
                minimumDate: DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                ),
                maximumDate: DateTime.now().add(const Duration(days: 365)),
                onDateTimeChanged: (d) => temp = d,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// iOS 风格时间选择器（底部滚轮），替代 Material showTimePicker。
  Future<TimeOfDay?> _pickCupertinoTime(
    BuildContext context, {
    required TimeOfDay initial,
  }) async {
    DateTime temp = DateTime(2026, 1, 1, initial.hour, initial.minute);
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(t.common.cancel),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  child: Text(t.common.confirm),
                  onPressed: () => Navigator.pop(ctx, temp),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: temp,
                onDateTimeChanged: (d) => temp = d,
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return null;
    return TimeOfDay(hour: result.hour, minute: result.minute);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupSchedule.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _createSchedule,
            child: const Icon(CupertinoIcons.add, size: 22),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final schedule = _schedules[index];
          return _buildScheduleItem(schedule);
        },
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startTime = _toInt(schedule['start_time'] ?? schedule['start_at']);
    final dt = DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
    final scheduleId = _resolveScheduleRouteId(schedule);

    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        padding: const EdgeInsets.all(AppSpacing.regular),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: AppRadius.borderRadiusRegular,
        ),
        child: Row(
          children: [
            // 日期块（iOS 风格圆角方块）
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.iosRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${dt.day}',
                    style: context.textStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w700,
                      color: AppColors.iosRed,
                    ),
                  ),
                  Text(
                    _getMonthName(dt.month),
                    style: context.textStyle(
                      FontSizeType.caption2,
                      color: AppColors.iosRed,
                    ),
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
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.tiny),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.clock,
                        size: 14,
                        color: AppColors.iosGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ],
                  ),
                  if (schedule['location'] != null) ...[
                    const SizedBox(height: AppSpacing.tiny),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location_solid,
                          size: 14,
                          color: AppColors.iosGray,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            schedule['location'] as String,
                            style: context.textStyle(
                              FontSizeType.footnote,
                              color: AppColors.iosGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.iosGray3,
            ),
          ],
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
