// 迁移脚本规划器（纯 Dart 函数，零依赖）
// Migration script planner (pure Dart function, zero deps)
//
// 职责（SRP）：给定"起始/目标版本 + 脚本 map"，返回按正确顺序需执行的脚本。
//
// - 升级：升序 (V9 → V10 → V11)
// - 降级：降序 (V11 → V10 → V9) — 防止在高版本 schema 上执行低版本 SQL
//   导致 ALTER/DROP 引用不存在的旧表名而失败
// - 选择区间：(min(from,to), max(from,to)] — 开下界、闭上界，因为 block
//   `VERSION: N` 表示"跨越 N-1 ↔ N 的转换"，所以 N 本身须被选中
//   而 from 版本不需要（已是当前状态）
//
// Responsibility (SRP): given from/to versions and a script map, return the
// scripts to execute in the correct order. Upgrades ascending, downgrades
// descending. Selection interval: (min, max] — half-open because a block
// tagged `VERSION: N` represents the transition N-1 ↔ N.
library;

import 'package:imboy/service/migration_script.dart';

class MigrationScriptPlanner {
  const MigrationScriptPlanner._();

  /// 根据起止版本从 [scripts] 中选出需要执行的脚本并按执行顺序排序。
  /// Selects and orders scripts from [scripts] to migrate
  /// from [fromVersion] to [toVersion].
  static List<MigrationScript> plan({
    required Map<int, MigrationScript> scripts,
    required int fromVersion,
    required int toVersion,
  }) {
    if (fromVersion == toVersion) return const [];

    final isUpgrade = toVersion > fromVersion;
    final lo = isUpgrade ? fromVersion : toVersion;
    final hi = isUpgrade ? toVersion : fromVersion;

    // 选择 (lo, hi] 区间内的 block（按 version 键 — 即 block 的起始版本标签）
    // Select blocks whose `version` tag falls in (lo, hi]
    final selected = scripts.values
        .where((s) => s.version > lo && s.version <= hi)
        .toList();

    selected.sort(
      (a, b) => isUpgrade
          ? a.version.compareTo(b.version) // 升级：升序
          : b.version.compareTo(a.version),
    ); // 降级：降序

    return selected;
  }
}
