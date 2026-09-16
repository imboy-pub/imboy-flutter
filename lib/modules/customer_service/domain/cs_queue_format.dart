/// 待接列表展示格式化（§12.5.1 CSM-01）
///
/// 纯 Dart（零 Flutter 依赖），可单测。等待时长只由服务端下发的
/// `waiting_since`（毫秒时间戳字符串）与当前时刻计算，不做任何
/// 本地队列行数推断。文案不在此硬编码：本模块返回结构化结果，
/// UI 层映射到 i18n 模板（justNow / minutes / hoursMinutes / daysHours）。
library;

/// 等待时长的结构化展示（unit + 数值），UI 按档位取 i18n 模板。
class CsWaitingText {
  /// 档位：justNow | minutes | hoursMinutes | daysHours。
  final String unit;

  /// 第一个数值（minutes 档 = 分钟数；hours 档 = 小时；days 档 = 天）。
  final int n;

  /// 第二数值（hoursMinutes 的分 / daysHours 的小时；其余档为 null）。
  final int? m;

  const CsWaitingText.justNow() : unit = 'justNow', n = 0, m = null;

  const CsWaitingText.minutes(this.n) : unit = 'minutes', m = null;

  const CsWaitingText.hoursMinutes(this.n, this.m) : unit = 'hoursMinutes';

  const CsWaitingText.daysHours(this.n, this.m) : unit = 'daysHours';
}

/// 由毫秒时间戳字符串计算等待展示结构。
///
/// 非法 / 空 / 未来时间戳一律回落「刚刚」档（不抛错、不推断）。
CsWaitingText csWaitingSince(String waitingSinceMs, DateTime now) {
  final ms = int.tryParse(waitingSinceMs.trim());
  if (ms == null || ms <= 0) return const CsWaitingText.justNow();
  final since = DateTime.fromMillisecondsSinceEpoch(ms);
  final d = now.difference(since);
  if (d.isNegative || d.inMinutes < 1) return const CsWaitingText.justNow();
  if (d.inHours < 1) return CsWaitingText.minutes(d.inMinutes);
  if (d.inDays < 1) {
    return CsWaitingText.hoursMinutes(
      d.inHours,
      d.inMinutes - d.inHours * Duration.minutesPerHour,
    );
  }
  return CsWaitingText.daysHours(
    d.inDays,
    d.inHours - d.inDays * Duration.hoursPerDay,
  );
}
