import 'group_schedule_create_dialog.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_schedule_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群日程页面
class GroupSchedulePage extends ConsumerStatefulWidget {
  final String groupId;

  /// 从聊天 + 面板"日程"直达时为 true：进入后自动弹出创建表单（≤2 步）
  final bool autoCreate;

  const GroupSchedulePage({
    super.key,
    required this.groupId,
    this.autoCreate = false,
  });

  @override
  ConsumerState<GroupSchedulePage> createState() => _GroupSchedulePageState();
}

class _GroupSchedulePageState extends ConsumerState<GroupSchedulePage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    if (widget.autoCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _createSchedule();
      });
    }
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final schedules = await GroupScheduleService.to.getSchedules(
        groupId: widget.groupId,
      );

      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createSchedule() async {
    final draft = await showCupertinoDialog<GroupScheduleDraft>(
      context: context,
      builder: (_) => const GroupScheduleCreateDialog(),
    );
    if (draft == null || !mounted) return;
    final schedule = await GroupScheduleService.to.createSchedule(
      groupId: widget.groupId,
      title: draft.title,
      startTime: draft.start.millisecondsSinceEpoch ~/ 1000,
    );
    if (!mounted) return;
    if (schedule == null) {
      AppLoading.showError(t.common.tipFailed);
    } else {
      _loadSchedules();
      if (schedule['message_status'] == 'failed') {
        AppLoading.showError(t.common.sendFailed);
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
          // 纯图标按钮须显式 Semantics，CupertinoButton 无 tooltip 参数。
          Semantics(
            identifier: 'auto.group.schedule.create',
            button: true,
            label: t.groupSchedule.createSchedule,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _createSchedule,
              child: const Icon(CupertinoIcons.add, size: 22),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return AsyncStateView(
      isLoading: _isLoading,
      error: _error,
      isEmpty: _schedules.isEmpty,
      onRetry: _loadSchedules,
      emptyText: t.groupSchedule.noSchedule,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _loadSchedules),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final schedule = _schedules[index];
              return _buildScheduleItem(schedule);
            }, childCount: _schedules.length),
          ),
        ],
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
          AppLoading.showToast(t.groupSchedule.scheduleIdMissing);
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
