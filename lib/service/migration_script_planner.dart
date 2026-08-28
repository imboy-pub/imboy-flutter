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
// - 完整路径校验（WP1）：区间内**每个**需要的块都必须存在（历史跳号除外，
//   见 [MigrationScriptPlanner.allowedVersionGaps]），升降级两个方向都不
//   允许"缺块静默跳过"。缺块抛 [MissingMigrationPathException]/
//   [MissingMigrationScriptException]，绝不返回空/部分计划当成功。
//
// Responsibility (SRP): given from/to versions and a script map, return the
// scripts to execute in the correct order. Upgrades ascending, downgrades
// descending. Selection interval: (min, max] — half-open because a block
// tagged `VERSION: N` represents the transition N-1 ↔ N. Every required
// block in the interval must exist (except explicitly declared version
// gaps); a missing block throws instead of being silently skipped.
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

/// 请求的迁移路径不完整：区间内存在没有脚本的版本块（WP1）。
///
/// 与 [MissingMigrationScriptException] 的分工：
/// - 升级且**只**缺目标块 → 旧异常（A-23 历史语义，调用方已依赖）。
/// - 其余任何缺失（降级缺块、升级中间缺块、空脚本 map 的降级）→ 本异常。
///
/// 后果（修复前，研究文档 §2.2 P0）：降级 30→29 时 planner 返回空计划、
/// `migrate()` 返回 success、sqflite 推进 `user_version=29`，但 schema 仍是
/// v30 —— 数据库版本号撒谎，后续升级无法可靠判断状态。
class MissingMigrationPathException implements Exception {
  MissingMigrationPathException({
    required this.requestFromVersion,
    required this.requestToVersion,
    required this.missingBlocks,
    required this.isUpgrade,
  }) : assert(missingBlocks.isNotEmpty, 'missingBlocks must not be empty');

  /// 请求的起始版本（完整 from/to 必须出现在错误信息中）。
  final int requestFromVersion;

  /// 请求的目标版本。
  final int requestToVersion;

  /// 全部缺失的块号（`VERSION: N` 的 N），按执行顺序排列
  /// （升级升序 / 降级降序）；first 即第一条缺边的承载块。
  final List<int> missingBlocks;

  /// 请求方向（升级 true / 降级 false），决定缺边的表述方向。
  final bool isUpgrade;

  /// 执行顺序上的第一条缺失块。
  int get firstMissingBlock => missingBlocks.first;

  /// 历史跳号版本没有自己的块，跨号边的表述需要折叠跳号
  /// （如块 16 在跳过 v15 时实际边是 v14 → v16 / v16 → v14）。
  static String _edgeLabel(int block, bool upgrade, Set<int> gaps) {
    var lower = block - 1;
    while (gaps.contains(lower)) {
      lower--;
    }
    return upgrade ? 'v$lower → v$block' : 'v$block → v$lower';
  }

  @override
  String toString() {
    final dir = isUpgrade ? '升级' : '降级';
    final firstEdge = _edgeLabel(
      firstMissingBlock,
      isUpgrade,
      MigrationScriptPlanner.allowedVersionGaps,
    );
    final all = missingBlocks.join(', ');
    return 'MissingMigrationPathException: $dir '
        'v$requestFromVersion → v$requestToVersion 路径不完整，'
        '第一条缺边（按执行顺序）：$firstEdge '
        '（${isUpgrade ? 'upgrade' : 'downgrade'} 块 '
        'VERSION: $firstMissingBlock 缺失）；'
        '全部缺失块：[$all]';
  }
}

class MigrationScriptPlanner {
  const MigrationScriptPlanner._();

  /// 历史合法跳号（显式 allowlist，WP1 钉死）。
  ///
  /// v15 在 upgrade/downgrade 中均无块（历史废弃版本号），v14 → v16 是
  /// 合法单步升级。此前该事实只存在于代码注释里，"跳号合法"与"中间块
  /// 缺失"不可区分；现在路径校验只豁免本集合内的版本号，其余区间内
  /// 版本没有块一律视为缺边抛错。新增版本块时若跳号，必须在这里登记。
  static const Set<int> allowedVersionGaps = {15};

  /// 根据起止版本从 [scripts] 中选出需要执行的脚本并按执行顺序排序；
  /// 路径上任何所需块缺失时抛错，绝不返回不完整的计划。
  /// Selects and orders scripts from [scripts] to migrate
  /// from [fromVersion] to [toVersion]; throws when any required block
  /// is missing instead of returning a partial/empty plan.
  static List<MigrationScript> plan({
    required Map<int, MigrationScript> scripts,
    required int fromVersion,
    required int toVersion,
  }) {
    if (fromVersion == toVersion) return const [];

    final isUpgrade = toVersion > fromVersion;
    final lo = isUpgrade ? fromVersion : toVersion;
    final hi = isUpgrade ? toVersion : fromVersion;

    // 路径完整性（WP1）：区间 (lo, hi] 内每个非跳号版本都必须有块；
    // 目标边界（升级的 hi）即使是跳号也必须有块 —— 没有块就永远不可能
    // 合法"到达"该版本，返回空计划只会让 sqflite 推进版本号制造错配。
    // 升级中间缺块（如 v9→v31 缺 16）与降级缺块（如 31→25 缺 30/27/26）
    // 都会让 user_version 推进而 schema 停留在旧状态 —— 静默错配，
    // 因此两个方向都 fail-fast。
    final requiredBlocks = [
      for (var v = lo + 1; v <= hi; v++)
        if (v == hi || !allowedVersionGaps.contains(v)) v,
    ];
    final missing =
        requiredBlocks.where((v) => !scripts.containsKey(v)).toList()..sort(
          isUpgrade
              ? (a, b) =>
                    a.compareTo(b) // 升级：第一条缺边 = 最小缺失块
              : (a, b) => b.compareTo(a),
        ); // 降级：第一条缺边 = 最大缺失块

    if (missing.isNotEmpty) {
      // 升级且只缺目标块：保留 A-23 的历史异常类型（既有调用方与测试
      // 依赖其语义）；其余缺失一律用更精确的路径异常。
      if (isUpgrade && missing.length == 1 && missing.first == hi) {
        throw MissingMigrationScriptException(
          fromVersion: fromVersion,
          toVersion: toVersion,
        );
      }
      throw MissingMigrationPathException(
        requestFromVersion: fromVersion,
        requestToVersion: toVersion,
        missingBlocks: missing,
        isUpgrade: isUpgrade,
      );
    }

    // 选择 (lo, hi] 区间内的 block（按 version 键 — 即 block 的起始版本标签）
    // Select blocks whose `version` tag falls in (lo, hi]
    final selected = scripts.values
        .where((s) => s.version > lo && s.version <= hi)
        .toList();

    selected.sort(
      (a, b) => isUpgrade
          ? a.version.compareTo(b.version) // 升级：升序
          : b.version.compareTo(a.version), // 降级：降序
    );

    return selected;
  }
}
