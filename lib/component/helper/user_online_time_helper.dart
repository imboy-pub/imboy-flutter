import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:imboy/i18n/strings.g.dart';

enum LastSeenStatus {
  online, // 在线
  justNow, // 刚刚
  withinMinutes, // 几分钟内
  withinHours, // 几小时内
  withinDays, // 几天内
  withinWeeks, // 几周内
  withinMonths, // 几个月内
  longTimeAgo, // 很久以前
  hidden, // 已隐藏（例如用户设置了隐私）
}

class UserOnlineStatus {
  final LastSeenStatus status;
  final DateTime? lastSeenAt;
  final String? statusText;
  final int? timeValue; // 用于显示的时间数值（如5分钟、3小时等）

  UserOnlineStatus({
    required this.status,
    this.lastSeenAt,
    this.statusText,
    this.timeValue,
  });

  bool get isOnline => status == LastSeenStatus.online;
}

class UserOnlineTimeHelper {
  static const int justNowThresholdSeconds = 60;
  static const int minutesThresholdHours = 1;
  static const int hoursThresholdDays = 1;
  static const int daysThresholdWeeks = 1;
  static const int weeksThresholdMonths = 1;
  static const int monthsThresholdLongTime = 6;
  static const int longTimeThresholdDays = 180;

  static UserOnlineStatus calculateOnlineStatus({
    required bool isOnline,
    required int? lastSeenTimestamp,
    required bool hideOnlineStatus,
  }) {
    if (hideOnlineStatus) {
      return UserOnlineStatus(
        status: LastSeenStatus.hidden,
        statusText: t.main.lastSeenHide,
      );
    }

    if (isOnline) {
      return UserOnlineStatus(
        status: LastSeenStatus.online,
        statusText: t.chat.online,
      );
    }

    if (lastSeenTimestamp == null || lastSeenTimestamp == 0) {
      return UserOnlineStatus(
        status: LastSeenStatus.longTimeAgo,
        statusText: t.main.lastSeenNever,
      );
    }

    final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenTimestamp);
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    );
    final difference = now.difference(lastSeen);

    if (difference.inSeconds <= justNowThresholdSeconds) {
      return UserOnlineStatus(
        status: LastSeenStatus.justNow,
        lastSeenAt: lastSeen,
        statusText: t.common.lastSeenJustNow,
      );
    }

    if (difference.inMinutes < 60) {
      return UserOnlineStatus(
        status: LastSeenStatus.withinMinutes,
        lastSeenAt: lastSeen,
        statusText: t.common.lastSeenMinutesAgo(
          param: difference.inMinutes.toString(),
        ),
        timeValue: difference.inMinutes,
      );
    }

    if (difference.inHours < 24) {
      return UserOnlineStatus(
        status: LastSeenStatus.withinHours,
        lastSeenAt: lastSeen,
        statusText: t.common.lastSeenHoursAgo(
          param: difference.inHours.toString(),
        ),
        timeValue: difference.inHours,
      );
    }

    if (difference.inDays < 7) {
      return UserOnlineStatus(
        status: LastSeenStatus.withinDays,
        lastSeenAt: lastSeen,
        statusText: t.common.lastSeenDaysAgo(
          param: difference.inDays.toString(),
        ),
        timeValue: difference.inDays,
      );
    }

    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return UserOnlineStatus(
        status: LastSeenStatus.withinWeeks,
        lastSeenAt: lastSeen,
        statusText: t.main.lastSeenWeeksAgo(param: weeks.toString()),
        timeValue: weeks,
      );
    }

    if (difference.inDays < monthsThresholdLongTime * 30) {
      final months = (difference.inDays / 30).floor();
      return UserOnlineStatus(
        status: LastSeenStatus.withinMonths,
        lastSeenAt: lastSeen,
        statusText: t.common.lastSeenMonthsAgo(param: months.toString()),
        timeValue: months,
      );
    }

    return UserOnlineStatus(
      status: LastSeenStatus.longTimeAgo,
      lastSeenAt: lastSeen,
      statusText: t.common.lastSeenLongTimeAgo,
    );
  }

  static String formatExactTime(DateTime dateTime) {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    );
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return '${t.common.yesterday} ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm').format(dateTime);
    } else {
      return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
    }
  }

  static String getStatusIcon(LastSeenStatus status) {
    switch (status) {
      case LastSeenStatus.online:
        return 'online';
      case LastSeenStatus.justNow:
      case LastSeenStatus.withinMinutes:
      case LastSeenStatus.withinHours:
        return 'recently';
      case LastSeenStatus.withinDays:
      case LastSeenStatus.withinWeeks:
        return 'this_week';
      case LastSeenStatus.withinMonths:
        return 'this_month';
      case LastSeenStatus.longTimeAgo:
        return 'long_time_ago';
      case LastSeenStatus.hidden:
        return 'hidden';
    }
  }

  static Color getStatusColor(LastSeenStatus status, BuildContext context) {
    switch (status) {
      case LastSeenStatus.online:
        return AppColors.iosGreen;
      case LastSeenStatus.justNow:
      case LastSeenStatus.withinMinutes:
      case LastSeenStatus.withinHours:
        return AppColors.iosOrange;
      case LastSeenStatus.withinDays:
      case LastSeenStatus.withinWeeks:
        return AppColors.iosBlue;
      case LastSeenStatus.withinMonths:
        return AppColors.iosPurple;
      case LastSeenStatus.longTimeAgo:
        return AppColors.iosGray;
      case LastSeenStatus.hidden:
        return Colors.grey.withValues(alpha: 0.5);
    }
  }
}
