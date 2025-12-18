import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';

class DateTimeHelper {
  /// 通用日期时间格式化
  static String dateTimeFmt(DateTime dt, {String pattern = 'y-MM-dd HH:mm'}) {
    // 使用 UTC 时间计算 diff，避免本地偏移
    int diff = Jiffy.now()
        .toUtc()
        .diff(Jiffy.parseFromDateTime(dt.toUtc()), unit: Unit.day) as int;

    if (diff > 6) {
      // 超过 7 天，显示完整日期时间
      return Jiffy.parseFromDateTime(dt).format(pattern: pattern);
    } else if (diff > 2) {
      // 超过 2 天，显示星期+时间
      return Jiffy.parseFromDateTime(dt).format(pattern: 'EEEE HH:mm');
    } else {
      // 最近两天，显示相对时间
      return Jiffy.parseFromDateTime(dt).startOf(Unit.minute).fromNow();
    }
  }

  /// 上次事件时间戳格式化
  static String lastTimeFmt(int lastTime, {String pattern = 'y-MM-dd HH:mm'}) {
    DateTime dt = DateTimeHelper.millisecondToDateTime(lastTime, isUtc: true);
    return dateTimeFmt(dt, pattern: pattern);
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

  /// 当前时间
  static DateTime now({bool isUtc = false}) {
    return isUtc ? DateTime.now().toUtc() : DateTime.now();
  }

  /// RFC3339 当前时间
  static String rfc3339({bool isUtc = false}) {
    return toRfc3339(now(isUtc: isUtc), isUtc: isUtc);
  }

  /// DateTime -> RFC3339 字符串，支持 UTC 或本地
  static String toRfc3339(DateTime dt, {bool isUtc = false}) {
    final d = isUtc ? dt.toUtc() : dt.toLocal();
    final tz = d.timeZoneOffset;
    final offsetSign = tz.isNegative ? '-' : '+';
    final offsetHours = tz.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (tz.inMinutes.abs() % 60).toString().padLeft(2, '0');

    final formatted =
        "${Jiffy.parseFromDateTime(d).format(pattern: "yyyy-MM-dd HH:mm:ss")}.${d.microsecond.toString().padLeft(6, '0')}"
        "${isUtc ? 'Z' : '$offsetSign$offsetHours:$offsetMinutes'}";
    return formatted;
  }

  /// RFC3339 -> 毫秒
  static int rfc3339ToMillisecond(String rfc3339) {
    DateTime dt = DateTime.parse(rfc3339);
    return dt.toUtc().millisecondsSinceEpoch;
  }

  /// RFC3339 -> 微秒
  static int rfc3339ToMicrosecond(String rfc3339) {
    DateTime dt = DateTime.parse(rfc3339);
    return dt.toUtc().microsecondsSinceEpoch;
  }

  /// UTC 秒
  static int second() {
    return millisecond() ~/ 1000;
  }

  /// UTC 毫秒
  static int millisecond() {
    return microsecond() ~/ 1000;
  }

  /// UTC 微秒
  static int microsecond() {
    return DateTime.now().toUtc().microsecondsSinceEpoch;
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
