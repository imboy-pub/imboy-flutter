import 'package:intl/intl.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/i18n/strings.g.dart';

class DateTimeHelper {
  /// 通用日期时间格式化
  static String dateTimeFmt(DateTime dt, {String pattern = 'y-MM-dd HH:mm'}) {
    // 使用同步后的时间计算 diff（应用 NTP/服务器时间偏移）
    final nowMs = millisecond();
    final dtMs = dt.toUtc().millisecondsSinceEpoch;
    final diffMs = nowMs - dtMs;
    final diffDays = diffMs / (24 * 3600 * 1000);

    if (diffDays > 7) {
      // 超过 7 天，显示完整日期时间
      return DateFormat(pattern).format(dt);
    } else if (diffDays > 2) {
      // 超过 2 天，显示星期+时间
      return DateFormat('EEEE HH:mm').format(dt);
    } else {
      // 最近两天，显示相对时间（使用同步后的时间）
      return _formatRelativeTime(dtMs);
    }
  }

  /// 格式化相对时间（使用同步后的时间，支持多语言）
  static String _formatRelativeTime(int timestampMs) {
    final nowMs = millisecond();
    final diffMs = nowMs - timestampMs;

    if (diffMs < 60 * 1000) {
      return t.timeJustNow;
    } else if (diffMs < 3600 * 1000) {
      final minutes = (diffMs / (60 * 1000)).floor();
      return t.timeMinutesAgo(param: minutes.toString());
    } else if (diffMs < 24 * 3600 * 1000) {
      final hours = (diffMs / (3600 * 1000)).floor();
      return t.timeHoursAgo(param: hours.toString());
    } else {
      final days = (diffMs / (24 * 3600 * 1000)).floor();
      return t.timeDaysAgo(param: days.toString());
    }
  }

  /// 上次事件时间戳格式化
  static String lastTimeFmt(int lastTime, {String pattern = 'y-MM-dd HH:mm'}) {
    DateTime dt = DateTimeHelper.millisecondToDateTime(lastTime, isUtc: true);
    return dateTimeFmt(dt, pattern: pattern);
  }

  /// 格式化日期时间（秒级时间戳）
  /// [timestamp] 秒级时间戳
  /// [pattern] 格式化模式，默认 'y-MM-dd HH:mm'
  static String formatDateTime(int timestamp, {String pattern = 'y-MM-dd HH:mm'}) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: false);
    return DateFormat(pattern).format(dt);
  }

  /// RFC3339 字符串转 DateTime，可选返回 local 或 UTC
  static DateTime fromRfc3339(String input, {bool toUtc = true}) {
    DateTime dt = DateTime.parse(input);
    return toUtc ? dt.toUtc() : dt.toLocal();
  }

  /// 毫秒时间戳 -> RFC3339
  static String millisecondToRfc3339(int millis, {bool isUtc = true}) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);
    return toRfc3339(dt, isUtc: isUtc);
  }

  /// 毫秒时间戳 -> DateTime
  static DateTime millisecondToDateTime(int millis, {bool isUtc = true}) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);
  }

  /// DateTime -> RFC3339 字符串，支持 UTC 或本地
  static String toRfc3339(DateTime dt, {bool isUtc = false}) {
    final d = isUtc ? dt.toUtc() : dt.toLocal();
    final tz = d.timeZoneOffset;
    final offsetSign = tz.isNegative ? '-' : '+';
    final offsetHours = tz.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (tz.inMinutes.abs() % 60).toString().padLeft(2, '0');

    final formatted =
        "${DateFormat('yyyy-MM-dd HH:mm:ss').format(d)}.${d.microsecond.toString().padLeft(6, '0')}"
        "${isUtc ? 'Z' : '$offsetSign$offsetHours:$offsetMinutes'}";
    return formatted;
  }

  /// RFC3339 -> 毫秒
  static int rfc3339ToMillisecond(String rfc3339) {
    DateTime dt = DateTime.parse(rfc3339);
    return dt.toUtc().millisecondsSinceEpoch;
  }

  /// UTC 秒
  ///
  /// 注意：此方法已自动应用 NTP/服务器时间同步
  static int second() {
    return millisecond() ~/ 1000;
  }

  /// UTC 毫秒
  ///
  /// 注意：此方法已自动应用 NTP/服务器时间同步，返回准确的服务器时间
  static int millisecond() {
    return NtpHelper.millisecond();
  }

  /// 将 DateTime/int/String 类型转换为毫秒时间戳（int 类型）
  /// 支持的输入类型：
  /// - DateTime: 直接转换为毫秒时间戳
  /// - int: 直接返回（假设已经是毫秒时间戳）
  /// - String: 尝试解析为 DateTime 后转换为毫秒时间戳
  /// - 其他: 返回默认值（默认为当前时间戳）
  static int parseTimestamp(dynamic value, {int defaultValue = 0}) {
    if (value == null) {
      return defaultValue > 0 ? defaultValue : millisecond();
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    } else if (value is int) {
      return value;
    } else if (value is String) {
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } on FormatException {
        return defaultValue > 0 ? defaultValue : millisecond();
      }
    } else {
      return defaultValue > 0 ? defaultValue : millisecond();
    }
  }
}

/// 相对时间格式化器，兼容 DateFormat.format
class RelativeDateFormat extends DateFormat {
  RelativeDateFormat() : super('relative');

  @override
  String format(DateTime date) {
    // 始终使用 UTC 计算相对时间
    return DateTimeHelper.dateTimeFmt(date.toUtc());
  }
}
