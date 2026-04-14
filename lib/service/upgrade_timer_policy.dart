// 升级定时检查策略（纯 Dart，零依赖）
// Upgrade periodic-check timer policy (pure Dart, zero deps)
//
// 职责：把服务端下发的 `check_interval_hours` 转换为 Dart `Duration`，
// 并对非法值（<= 0）返回 null 以示"不启动定时器"。此契约防止
// Timer.periodic(Duration.zero) 造成的紧循环死锁。
//
// Responsibility: convert server-sent `check_interval_hours` into a Dart
// Duration. Returns null for invalid values (<= 0) meaning "do not start a
// timer". Prevents Timer.periodic(Duration.zero) tight loops.
library;

class UpgradeTimerPolicy {
  const UpgradeTimerPolicy._();

  /// 根据小时数计算定时检查间隔。
  ///
  /// - `intervalHours > 0` → 返回 `Duration(hours: intervalHours)`
  /// - `intervalHours <= 0` → 返回 null（不应启动定时器，避免死循环）
  ///
  /// Returns a Duration for positive hours, or null for non-positive input
  /// (signals "do not start a timer") to avoid tight-loop bugs.
  static Duration? computeInterval(int intervalHours) {
    if (intervalHours <= 0) return null;
    return Duration(hours: intervalHours);
  }
}
