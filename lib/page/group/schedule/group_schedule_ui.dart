import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群日程三处界面（聊天卡片 / 日程列表 / 日程详情）共享的
/// 时间态推导与视觉组件。
///
/// 后端 group_schedule.status 只有 1（有效）与 4（已取消）两种，
/// "进行中 / 已结束"没有任何服务端流转 —— 必须由客户端按
/// start/end 与当前时间推导（见 [resolveScheduleTimeState]）。
enum GroupScheduleTimeState { notStarted, inProgress, ended, cancelled }

/// 按"取消 > 未开始 > 已结束 > 进行中"的优先级推导展示态。
GroupScheduleTimeState resolveScheduleTimeState({
  required int status,
  required int startAtSec,
  required int endAtSec,
  required int nowSec,
}) {
  if (status == 4) return GroupScheduleTimeState.cancelled;
  if (startAtSec > 0 && nowSec < startAtSec) {
    return GroupScheduleTimeState.notStarted;
  }
  if (endAtSec > 0 && nowSec > endAtSec) {
    return GroupScheduleTimeState.ended;
  }
  return GroupScheduleTimeState.inProgress;
}

/// 状态语义色（Apple Calendar / 飞书惯例）：
/// 未开始=蓝、进行中=绿、已结束=灰、已取消=红。
Color scheduleStateColor(GroupScheduleTimeState state, bool isDark) =>
    switch (state) {
      GroupScheduleTimeState.notStarted =>
        isDark ? AppColors.iosBlueDark : AppColors.iosBlue,
      GroupScheduleTimeState.inProgress => AppColors.onlineIndicator,
      GroupScheduleTimeState.ended => AppColors.iosGray,
      GroupScheduleTimeState.cancelled =>
        isDark ? AppColors.iosRedDark : AppColors.iosRed,
    };

/// 状态胶囊徽章：色底 12% + 同色图标与文字，弱背景强语义。
class ScheduleStatusBadge extends StatelessWidget {
  const ScheduleStatusBadge({super.key, required this.state});

  final GroupScheduleTimeState state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = scheduleStateColor(state, isDark);
    final label = switch (state) {
      GroupScheduleTimeState.notStarted =>
        context.t.groupSchedule.statusNotStarted,
      GroupScheduleTimeState.inProgress =>
        context.t.groupSchedule.statusInProgress,
      GroupScheduleTimeState.ended => context.t.groupSchedule.statusEnded,
      GroupScheduleTimeState.cancelled =>
        context.t.groupSchedule.statusCancelled,
    };
    final icon = switch (state) {
      GroupScheduleTimeState.notStarted => CupertinoIcons.clock,
      GroupScheduleTimeState.inProgress => CupertinoIcons.timer,
      GroupScheduleTimeState.ended => CupertinoIcons.check_mark,
      GroupScheduleTimeState.cancelled => CupertinoIcons.xmark_circle,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.tiny),
          Text(
            label,
            style: context.textStyle(
              FontSizeType.caption2,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS 日历风格的日期方块：星期缩写在上、日期数字在下。
/// [muted] 为 true 时整块灰化（已取消条目）。
class ScheduleDateBlock extends StatelessWidget {
  const ScheduleDateBlock({
    super.key,
    required this.dateTime,
    this.muted = false,
    this.size = 56,
  });

  final DateTime dateTime;
  final bool muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = muted
        ? AppColors.iosGray
        : (isDark ? AppColors.iosRedDark : AppColors.iosRed);
    final localizations = MaterialLocalizations.of(context);
    // narrowWeekdays 按 firstDayOfWeekIndex 排序，需换算下标才能
    // 取到"周一/周二…"的窄名（直接取 weekday%7 会拿到周日开头的错位名）。
    final weekdayIndex =
        (dateTime.weekday - localizations.firstDayOfWeekIndex + 7) % 7;
    final weekday = localizations.narrowWeekdays[weekdayIndex];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekday,
            style: context.textStyle(
              FontSizeType.caption2,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          Text(
            '${dateTime.day}',
            style: context.textStyle(
              FontSizeType.large,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// "10月9日 周五 11:23 – 12:23"；跨天时两端都带日期。
String formatScheduleTimeRange(
  BuildContext context,
  DateTime start,
  DateTime end,
) {
  final localizations = MaterialLocalizations.of(context);
  final startDay = localizations.formatMediumDate(start);
  final startClock = _clock(start);
  if (_sameDay(start, end)) {
    return '$startDay $startClock – ${_clock(end)}';
  }
  return '$startDay $startClock – ${localizations.formatMediumDate(end)} ${_clock(end)}';
}

/// 开始时间的人性化提示："今天 11:23 开始" / "明天 09:30 开始"，
/// 更远则直接给日期。
String scheduleStartsHint(BuildContext context, int startAtSec, int nowSec) {
  final t = context.t;
  final start = DateTime.fromMillisecondsSinceEpoch(startAtSec * 1000);
  final now = DateTime.fromMillisecondsSinceEpoch(nowSec * 1000);
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final dayGap = startDay.difference(today).inDays;
  final hint = switch (dayGap) {
    0 => t.groupSchedule.hintToday,
    1 => t.groupSchedule.hintTomorrow,
    _ => MaterialLocalizations.of(context).formatMediumDate(start),
  };
  return t.groupSchedule.startsHint(hint: hint, time: _clock(start));
}

/// 仅开始时间："10月9日 周五 11:23"。
/// 服务端 publish 的日程 payload 不带 end_time，聊天卡片/列表条目
/// 缺结束时用它，避免出现"11:23 – 11:23"这类重复区间。
String formatScheduleStartTime(BuildContext context, DateTime start) {
  return '${MaterialLocalizations.of(context).formatMediumDate(start)} '
      '${_clock(start)}';
}

/// 参与人确认状态：后端 participant.status 1=参加、2=不参加，其余视为待回应。
String participantStateLabel(BuildContext context, int status) =>
    switch (status) {
      1 => context.t.groupSchedule.participantAttending,
      2 => context.t.groupSchedule.participantDeclined,
      _ => context.t.groupSchedule.participantPending,
    };

Color participantStateColor(int status, bool isDark) => switch (status) {
  1 => AppColors.onlineIndicator,
  2 => isDark ? AppColors.iosRedDark : AppColors.iosRed,
  _ => AppColors.iosGray,
};

IconData participantStateIcon(int status) => switch (status) {
  1 => CupertinoIcons.check_mark,
  2 => CupertinoIcons.xmark,
  _ => CupertinoIcons.clock,
};

String _clock(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
