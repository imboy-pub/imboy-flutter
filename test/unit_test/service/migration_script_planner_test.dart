// MigrationScriptPlanner 单元测试
// Unit tests for MigrationScriptPlanner
//
// 验证跨版本迁移脚本的选择与排序：
//   - 升级：升序执行 (V9 → V10 → V11)
//   - 降级：降序执行 (V11 → V10 → V9)，防止在高版本 schema 下执行低版本 SQL 失败
//   - 同版本：返回空列表
//   - 选择范围：仅 (min, max] 区间内的 block
//
// Verifies correct selection and ordering for multi-version migrations.
// For downgrades the order MUST be descending to avoid executing low-version
// SQL against a higher-version schema.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_script.dart';
import 'package:imboy/service/migration_script_planner.dart';

MigrationScript upgradeScript(int version) => MigrationScript(
  version: version,
  targetVersion: version,
  description: 'up to v$version',
  sqlStatements: ['-- up to v$version'],
);

MigrationScript downgradeScript(int version) => MigrationScript(
  version: version,
  targetVersion: version - 1,
  description: 'down from v$version',
  sqlStatements: ['-- down from v$version'],
);

void main() {
  group('MigrationScriptPlanner.plan — 升级 / upgrade', () {
    test('升级 V9→V11 应升序返回 [V10, V11] / ascending order', () {
      final scripts = {10: upgradeScript(10), 11: upgradeScript(11)};
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 9,
        toVersion: 11,
      );
      expect(plan.map((s) => s.version).toList(), [10, 11]);
    });

    test('升级 V9→V10 只含 V10 / single hop', () {
      final scripts = {10: upgradeScript(10), 11: upgradeScript(11)};
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 9,
        toVersion: 10,
      );
      expect(plan.map((s) => s.version).toList(), [10]);
    });

    // ⚠️ 本用例原名 "跳过不存在的 V12 脚本 / skips missing scripts"，
    // 断言的是 plan 返回 [10, 11] —— 即断言了缺陷本身（A-23）。
    // 静默跳过的后果：sqflite 回调正常返回 → user_version 被设成 12 →
    // 下次启动不再迁移 → V12 的表结构永久缺失（A-21 是这条链的真实实例）。
    // 按 Execution Rule 7 反转断言，而不是放宽它。
    test('升级 V9→V12 缺目标 V12 脚本必须抛异常 / missing target script throws', () {
      final scripts = {10: upgradeScript(10), 11: upgradeScript(11)};
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 12,
        ),
        throwsA(isA<MissingMigrationScriptException>()),
      );
    });

    // ⚠️ 版本号允许跳号：本仓 v15 在 embedded 与 asset 里都不存在（历史废弃），
    // v14 → v16 是合法的一步。这条守住"严格化没有锁死 v14 及更早的存量装机" ——
    // A-23 判据原文举的 "[14,16] 缺 15 抛异常" 恰恰是本仓的正常状态，不能照做。
    test('中间版本号跳号是合法的，不得抛 / skipped version numbers are legal', () {
      final scripts = {14: upgradeScript(14), 16: upgradeScript(16)};
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 13,
        toVersion: 16,
      );
      expect(plan.map((s) => s.version).toList(), [14, 16]);
    });

    // 降级方向不校验：kDowngradeScriptSql 止于 v18（v19~v25 全缺，A-21 记录的
    // 预存缺口）。不补脚本就严格化，只会让旧版 app 直接打不开数据库。
    test('降级缺脚本仍按原样返回（预存缺口，不在本任务范围） / downgrade unchanged', () {
      final scripts = {11: downgradeScript(11)};
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 11,
        toVersion: 9,
      );
      expect(plan.map((s) => s.version).toList(), [11]);
    });
  });

  group('MigrationScriptPlanner.plan — 降级 / downgrade', () {
    test('降级 V11→V9 应降序返回 [V11, V10] '
        '(防止在 V11 schema 执行 V10→V9 的 SQL)', () {
      final scripts = {
        10: downgradeScript(10), // 从 V10 降到 V9
        11: downgradeScript(11), // 从 V11 降到 V10
      };
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 11,
        toVersion: 9,
      );
      expect(
        plan.map((s) => s.version).toList(),
        [11, 10],
        reason:
            '降级必须降序：先 11→10，再 10→9；否则 V10→V9 的 SQL '
            '会在 V11 schema 上执行而失败',
      );
    });

    test('降级 V10→V9 只含 V10 / single hop descending', () {
      final scripts = {10: downgradeScript(10), 11: downgradeScript(11)};
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 10,
        toVersion: 9,
      );
      expect(plan.map((s) => s.version).toList(), [10]);
    });

    test('降级跨 3 版本 V12→V9 应 [V12, V11, V10] / three-hop descending', () {
      final scripts = {
        10: downgradeScript(10),
        11: downgradeScript(11),
        12: downgradeScript(12),
      };
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 12,
        toVersion: 9,
      );
      expect(plan.map((s) => s.version).toList(), [12, 11, 10]);
    });
  });

  group('MigrationScriptPlanner.plan — 边界 / edge cases', () {
    test('from == to 返回空列表 / no-op when versions equal', () {
      final scripts = {10: upgradeScript(10)};
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 10,
        toVersion: 10,
      );
      expect(plan, isEmpty);
    });

    // ⚠️ 原断言 "空 map 返回空列表" 同样是 A-23 的缺陷面：
    // 脚本一个都没加载成功（embedded 常量为空、asset 读取失败）时返回空计划，
    // MigrationService 走 `scripts.isEmpty` 分支直接 return success —— 迁移
    // 完全没发生却报成功。反转为"必须抛"。
    test('空 scripts map 必须抛异常 / empty map throws', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: <int, MigrationScript>{},
          fromVersion: 9,
          toVersion: 11,
        ),
        throwsA(isA<MissingMigrationScriptException>()),
      );
    });

    // 但 from == to 时空 map 仍是合法的 no-op（没有区间要覆盖），
    // 这条守住"严格化没有波及无需迁移的正常路径"。
    test('from == to 时空 map 不抛 / no-op stays a no-op', () {
      expect(
        MigrationScriptPlanner.plan(
          scripts: <int, MigrationScript>{},
          fromVersion: 11,
          toVersion: 11,
        ),
        isEmpty,
      );
    });

    test('选择区间为 (min, max]（开下界、闭上界） / half-open interval', () {
      final scripts = {
        9: upgradeScript(9),
        10: upgradeScript(10),
        11: upgradeScript(11),
        12: upgradeScript(12),
      };
      // 升级 9→11 应只含 V10、V11；V9（下界本身）和 V12（超出）被排除
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 9,
        toVersion: 11,
      );
      expect(plan.map((s) => s.version).toList(), [10, 11]);
    });
  });
}
