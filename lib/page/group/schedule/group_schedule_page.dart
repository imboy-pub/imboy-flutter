import 'group_schedule_create_dialog.dart';
import 'group_schedule_ui.dart';

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
          ..._buildGroupedSections(),
        ],
      ),
    );
  }

  /// 按今天 / 本周 / 更晚 分组渲染（Apple Calendar 分组惯例），
  /// 每组内按开始时间升序。已取消的日程跟随其原时间归组但整条灰化。
  List<Widget> _buildGroupedSections() {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));

    final groups = <_ScheduleSection, List<Map<String, dynamic>>>{};
    for (final schedule in _schedules) {
      final startAt = _toInt(schedule['start_time'] ?? schedule['start_at']);
      final start = DateTime.fromMillisecondsSinceEpoch(startAt * 1000);
      // 今天（含已开始/进行中）→ 明天起一周内 → 更晚。
      final section = start.isBefore(tomorrowStart)
          ? _ScheduleSection.today
          : start.isBefore(weekEnd)
          ? _ScheduleSection.tomorrowToWeek
          : _ScheduleSection.later;
      (groups[section] ??= []).add(schedule);
    }
    for (final list in groups.values) {
      list.sort(
        (a, b) =>
            _toInt(a['start_time'] ?? a['start_at'])
                .compareTo(_toInt(b['start_time'] ?? b['start_at'])),
      );
    }

    final sections = _ScheduleSection.values;
    final widgets = <Widget>[];
    for (final section in sections) {
      final items = groups[section];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.regular,
              AppSpacing.regular,
              AppSpacing.tiny,
            ),
            child: Text(
              _sectionLabel(section),
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
                color: AppColors.iosGray,
              ),
            ),
          ),
        ),
      );
      for (final item in items) {
        widgets.add(SliverToBoxAdapter(child: _buildScheduleItem(item)));
      }
    }
    return widgets;
  }

  String _sectionLabel(_ScheduleSection section) {
    final t = context.t;
    return switch (section) {
      _ScheduleSection.today => t.groupSchedule.sectionToday,
      // 明天起 7 天内统称"本周"。
      _ScheduleSection.tomorrowToWeek => t.groupSchedule.sectionThisWeek,
      _ScheduleSection.later => t.groupSchedule.sectionLater,
    };
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startAt = _toInt(schedule['start_time'] ?? schedule['start_at']);
    final endAt = _toInt(schedule['end_time'] ?? schedule['end_at']);
    final dt = DateTime.fromMillisecondsSinceEpoch(startAt * 1000);
    final scheduleId = _resolveScheduleRouteId(schedule);
    final state = resolveScheduleTimeState(
      status: _toInt(schedule['status']),
      startAtSec: startAt,
      endAtSec: endAt,
      nowSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final isCancelled = state == GroupScheduleTimeState.cancelled;
    final title = _toText(schedule['title']);

    return GestureDetector(
      onTap: () => _openScheduleDetail(scheduleId),
      child: Opacity(
        opacity: isCancelled ? 0.6 : 1,
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
              ScheduleDateBlock(dateTime: dt, muted: isCancelled),
              const SizedBox(width: AppSpacing.regular),
              Expanded(
                child: _ScheduleItemBody(
                  title: title,
                  start: dt,
                  end: endAt > startAt
                      ? DateTime.fromMillisecondsSinceEpoch(endAt * 1000)
                      : null,
                  location: _toText(schedule['location']),
                  state: state,
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
      ),
    );
  }

  Future<void> _openScheduleDetail(String scheduleId) async {
    if (scheduleId.isEmpty) {
      AppLoading.showToast(t.groupSchedule.scheduleIdMissing);
      return;
    }
    final encodedId = Uri.encodeComponent(scheduleId);
    await context.push('/group/${widget.groupId}/schedule/$encodedId');
    if (mounted) {
      _loadSchedules();
    }
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
}

/// 列表分组：今天 / 明天（至本周） / 更晚。
enum _ScheduleSection { today, tomorrowToWeek, later }

/// 列表条目正文：标题（已取消删除线）+ 时间范围 + 地点，附状态徽章。
class _ScheduleItemBody extends StatelessWidget {
  const _ScheduleItemBody({
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.state,
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final String location;
  final GroupScheduleTimeState state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCancelled = state == GroupScheduleTimeState.cancelled;
    // 局部变量才能类型提升；字段 `end` 非 private 不可提升。
    final endAt = end;
    final titleColor = isCancelled
        ? AppColors.iosGray
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context
                    .textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    )
                    .copyWith(
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.tiny),
            ScheduleStatusBadge(state: state),
          ],
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
            Expanded(
              child: Text(
                // 缺结束时间只展示开始，避免"11:23 – 11:23"。
                endAt == null
                    ? formatScheduleStartTime(context, start)
                    : formatScheduleTimeRange(context, start, endAt),
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
        if (location.isNotEmpty) ...[
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
                  location,
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
    );
  }
}
