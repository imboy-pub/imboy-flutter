import 'package:intl/intl.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/i18n/strings.g.dart';

class DateTimeHelper {
  /// 通用日期时间格式化
  static String dateTimeFmt(
    DateTime dt, {
    String pattern = 'y-MM-dd HH:mm',
    bool relative = true,
  }) {
    if (!relative) {
      return DateFormat(pattern).format(dt);
    }
    // 使用同步后的时间计算 diff（应用 NTP/服务器时间偏移）
    final nowMs = millisecond();
    final dtMs = dt.toUtc().millisecondsSinceEpoch;
    final diffMs = nowMs - dtMs;
    final diffDays = diffMs / (24 * 3600 * 1000);

    if (diffDays > 7) {
      // 超过 7 天，显示完整日期时间
      return DateFormat(pattern).format(dt);
    } else if (diffDays > 2) {
      // 超过 2 天，显示"月-日 时:分"（数字格式，避免 EEEE 星期名落回 en_US 显示英文）
      return DateFormat('MM-dd HH:mm').format(dt);
    } else {
      // 最近两天，显示相对时间（使用同步后的时间）
      return _formatRelativeTime(dtMs);
    }
  }

  /// 格式化相对时间（使用同步后的时间，支持多语言）
  static String _formatRelativeTime(int timestampMs) {
    final nowMs = millisecond();
    final diffMs = nowMs - timestampMs;

    // 三个 key 都是 slang plural：传 num 而非 String，由各语言的
    // cardinal resolver 选 one/other —— 英文此前恒取复数形式，出现 `1 days ago`。
    if (diffMs < 60 * 1000) {
      return t.common.timeJustNow;
    } else if (diffMs < 3600 * 1000) {
      final minutes = (diffMs / (60 * 1000)).floor();
      return t.common.timeMinutesAgo(n: minutes);
    } else if (diffMs < 24 * 3600 * 1000) {
      final hours = (diffMs / (3600 * 1000)).floor();
      return t.common.timeHoursAgo(n: hours);
    } else {
      final days = (diffMs / (24 * 3600 * 1000)).floor();
      return t.common.timeDaysAgo(n: days);
    }
  }

  /// 上次事件时间戳格式化。
  ///
  /// **必须构造本地时区 DateTime**：`DateFormat.format` 按 DateTime 自身的
  /// isUtc 输出字段值，传 UTC 进去就会把 UTC 时间当本地时间摆给用户看
  /// （BUG#84：东八区少 8 小时，设备管理列表 `08-01 16:13` vs 详情页
  /// `2026-08-02 00:13:36`，同一条记录差恰好一个时区）。
  ///
  /// 相对时间分支不受影响 —— `dateTimeFmt` 里算 diff 用的是
  /// `dt.toUtc().millisecondsSinceEpoch`，对同一时刻的两种表示结果相同。
  static String lastTimeFmt(int lastTime, {String pattern = 'y-MM-dd HH:mm'}) {
    DateTime dt = DateTimeHelper.millisecondToDateTime(lastTime, isUtc: false);
    return dateTimeFmt(dt, pattern: pattern);
  }

  /// 毫秒时间戳 → 可读时间；解析不出来返回空串。
  ///
  /// 用于「后端原样返回 created_at、UI 直接 toString 就把 `1785742186575`
  /// 摆给用户看」这类场景（BUG#51 相册副标题、相册照片详情页均属此列）。
  /// **宁可不显示，也不露原始值** —— 所以拿不到有效毫秒数时返回空串，
  /// 由调用方决定整块隐藏。
  static String millisFmtOrEmpty(
    dynamic value, {
    String pattern = 'y-MM-dd HH:mm',
  }) {
    final int millis = value is int
        ? value
        : (value is String ? int.tryParse(value) ?? 0 : 0);
    if (millis <= 0) return '';
    return lastTimeFmt(millis, pattern: pattern);
  }

  /// 格式化日期时间（秒级时间戳）
  /// [timestamp] 秒级时间戳
  /// [pattern] 格式化模式，默认 'y-MM-dd HH:mm'
  static String formatDateTime(
    int timestamp, {
    String pattern = 'y-MM-dd HH:mm',
  }) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: false,
    );
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
