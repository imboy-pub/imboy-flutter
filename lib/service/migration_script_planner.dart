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

/// 升级的目标版本没有对应脚本块（A-23）。
///
/// 静默跳过的后果链（A-21 实证）：plan 不含 v25 → migrate 走
/// `scripts.isEmpty` 直接 return success → sqflite 回调正常返回后自动把
/// `user_version` 设成 25 → **下次启动不再迁移** → 该版本的表结构永久缺失。
/// 数据库从此对自己的版本撒谎，且没有任何一处会再报错。
///
/// 抛出后经 `MigrationService.migrate` 转成 `MigrationResult.failure`，
/// 再由 `SqliteService._onUpgrade` rethrow，让 sqflite 回滚事务并**不推进版本号**。
/// 启动即失败好过静默的 schema 撒谎 —— 前者当场发现，后者要等到读写那张表时
/// 才以"消息读不出来"的形式暴露，而那时版本号已经无法回退。
class MissingMigrationScriptException implements Exception {
  const MissingMigrationScriptException({
    required this.fromVersion,
    required this.toVersion,
  });

  final int fromVersion;
  final int toVersion;

  @override
  String toString() =>
      'MissingMigrationScriptException: 升级 v$fromVersion → v$toVersion '
      '缺少 VERSION: $toVersion 脚本块；'
      'embedded_schema_scripts.dart 与 assets/migrations/upgrade.sql 可能未同步';
}

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

    // 升级的**目标版本**必须有块，否则抛（A-23）。
    //
    // 为什么只校验目标版本，不校验区间内每一个整数：
    // 版本号允许跳号 —— 本仓 v15 在 embedded 与 asset 里都不存在（历史废弃），
    // v14 → v16 就是合法的一步。按"连续整数"校验会把这种正常升级判成缺口，
    // 直接锁死所有 v14 及更早的存量装机。
    //
    // 目标版本则不同：它由 `SqliteService._dbVersion` 声明，是权威的"必须到达"，
    // 没有块就一定是漏同步（A-21）。中间块被漏掉的情形与跳号在这里不可区分，
    // planner 拿不到"应该存在哪些版本"的真源，不做无根据的推断。
    //
    // 降级方向不校验：`kDowngradeScriptSql` 止于 v18（v19~v25 全缺，A-21 已记为
    // 预存缺口）。在不补脚本的前提下严格化，只是把一个已知残缺的功能从"假成功"
    // 变成"旧版 app 直接打不开数据库"，没有净收益。补降级脚本是独立任务。
    if (isUpgrade && !selected.any((s) => s.version == hi)) {
      throw MissingMigrationScriptException(
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    }

    selected.sort(
      (a, b) => isUpgrade
          ? a.version.compareTo(b.version) // 升级：升序
          : b.version.compareTo(a.version),
    ); // 降级：降序

    return selected;
  }
}
