import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/i18n/strings.g.dart';

class DateTimeHelper {
  /// 显示时间统一使用设备本地时区；相对间隔仍按同一瞬间计算。
  static String dateTimeFmt(
    DateTime dt, {
    String pattern = 'y-MM-dd HH:mm',
    bool relative = true,
  }) {
    if (!relative) {
      return DateFormat(pattern).format(dt.toLocal());
    }
    // 使用同步后的时间计算 diff（应用 NTP/服务器时间偏移）
    final nowMs = millisecond();
    final dtMs = dt.toUtc().millisecondsSinceEpoch;
    final diffMs = nowMs - dtMs;
    final diffDays = diffMs / (24 * 3600 * 1000);

    if (diffDays > 7) {
      // 超过 7 天，显示完整日期时间
      return DateFormat(pattern).format(dt.toLocal());
    } else if (diffDays > 2) {
      // 超过 2 天，显示"月-日 时:分"（数字格式，避免 EEEE 星期名落回 en_US 显示英文）
      return DateFormat('MM-dd HH:mm').format(dt.toLocal());
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

  /// DateTime -> RFC3339 字符串，支持 UTC 或本地。
  ///
  /// R21-B 修复（W1 登记）：小数秒 6 位必须是 `毫秒*1000 + 微秒`——
  /// 旧实现只写 `d.microsecond`（0-999，不含毫秒位），209ms 被写成
  /// `.000209`（=209µs，千倍误差）。现在 209ms 37µs 输出 `.209037`。
  static String toRfc3339(DateTime dt, {bool isUtc = false}) {
    final d = isUtc ? dt.toUtc() : dt.toLocal();
    final tz = d.timeZoneOffset;
    final offsetSign = tz.isNegative ? '-' : '+';
    final offsetHours = tz.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (tz.inMinutes.abs() % 60).toString().padLeft(2, '0');

    final subSecond = (d.millisecond * 1000 + d.microsecond).toString().padLeft(
      6,
      '0',
    );
    final formatted =
        "${DateFormat('yyyy-MM-dd HH:mm:ss').format(d)}.$subSecond"
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

/// R21-A：API / 历史 / SQLite 时间字段的显式解析入口。
///
/// 与 [DateTimeHelper.parseTimestamp] 的 legacy 启发式（int 一律当毫秒、
/// 任意 String 走 `DateTime.parse`、失败回填 `millisecond()`=now）不同：
///
/// - 每个入口只接受合同声明的单位/形态，调用方必须按端点合同选择入口；
/// - 失败一律返回 `null`，**绝不回填当前时间**；需要 0 哨兵由调用方显式
///   `?? 0`（R21-1 default0 语义），UI 对未知值自行呈现"未知"或隐藏；
/// - 需要当前时间必须显式调用 [DateTimeHelper.millisecond]。
///
/// B 阶段（R21-B）按调用点逐步迁移，本文件不改变 legacy 入口行为。
class ApiTime {
  ApiTime._();

  /// 宽松数字 → int：接受 int、可无损转 int 的 num、十进制整数字符串。
  ///
  /// 拒绝 null / bool / 小数（3.5）/ 空串 / 非十进制（0x1、1e3）/ List。
  /// 注：Dart `int.tryParse` 默认接受 `0x` 前缀（`'0x1f'` → 31），与"十进制
  /// 整数字符串"合同不符，故字符串先过十进制形态正则再解析（R08-FL 发现）。
  static int? _parseIntLike(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      if (value != value.truncateToDouble()) return null;
      return value.toInt();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (!RegExp(r'^[+-]?\d+$').hasMatch(trimmed)) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  /// epoch 秒 → 毫秒（秒 * 1000）。仅接受 int / 可整转数字。
  ///
  /// 0 与负 epoch 是合法瞬间（0=1970-01-01T00:00:00Z）；解析失败返回 null。
  static int? parseEpochSeconds(dynamic value) {
    final seconds = _parseIntLike(value);
    if (seconds == null) return null;
    // Web 的毫秒结果必须保持在 JavaScript 安全整数范围内。
    final limit = kIsWeb
        ? BigInt.from(9007199254740)
        : BigInt.parse('9223372036854775');
    if (BigInt.from(seconds).abs() > limit) return null;
    return seconds * 1000;
  }

  /// epoch 毫秒直用（不做单位换算）。仅接受 int / 可整转数字。
  static int? parseEpochMillis(dynamic value) {
    return _parseIntLike(value);
  }

  /// 带显式时区（结尾 `Z`/`z` 或 `±HH:MM`/`±HHMM`）的 ISO/RFC3339 → UTC DateTime。
  ///
  /// 不带 zone（如 `2026-09-16T23:06:40`）返回 null——不猜本地时区；
  /// 纯数字/紧凑数字字符串（`1789600000000`、`20260916T230640Z`）返回
  /// null，不误入 ISO 分支——`DateTime.tryParse` 原生接受紧凑形态，
  /// 故先用严格形态正则把关（日期必须 `-` 分隔、时间必须 `:` 分隔）。
  static DateTime? parseIsoZoned(String input) {
    if (input.isEmpty) return null;
    final trimmed = input.trim();
    final wellFormed = RegExp(
      r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?)?(Z|z|[+-]\d{2}:?\d{2})$',
    ).hasMatch(trimmed);
    if (!wellFormed) return null;
    final dt = DateTime.tryParse(trimmed);
    // Dart 对无 zone 输入返回本地时间（isUtc=false）；正则已拦，双保险。
    if (dt == null || !dt.isUtc) return null;
    return dt;
  }

  /// `YYYY-MM-DD` 纯日期 → UTC 零点（无时间语义，展示直接用年月日字段）。
  ///
  /// 拒绝带时间/zone 的输入（那是 [parseIsoZoned] 的领域）；
  /// 拒绝非严格形态（`2026-9-1`）与不存在的日历日（`2026-02-30`）。
  static DateTime? parseDateOnly(String input) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return null;
    final parts = input.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final dt = DateTime.utc(y, m, d);
    // Dart 构造函数会 normalize 越界值（2026-02-30 → 2026-03-02），回验拒绝。
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  /// 秒数 duration（按合同单位）。仅接受 int / 可整转数字。
  static Duration? parseDurationSeconds(dynamic value) {
    final seconds = _parseIntLike(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// 毫秒数 duration（按合同单位）。仅接受 int / 可整转数字。
  static Duration? parseDurationMillis(dynamic value) {
    final millis = _parseIntLike(value);
    return millis == null ? null : Duration(milliseconds: millis);
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
