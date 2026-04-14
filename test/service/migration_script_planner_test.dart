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
    test(
      '升级 V9→V11 应升序返回 [V10, V11] / ascending order',
      () {
        final scripts = {
          10: upgradeScript(10),
          11: upgradeScript(11),
        };
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 11,
        );
        expect(plan.map((s) => s.version).toList(), [10, 11]);
      },
    );

    test(
      '升级 V9→V10 只含 V10 / single hop',
      () {
        final scripts = {
          10: upgradeScript(10),
          11: upgradeScript(11),
        };
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 10,
        );
        expect(plan.map((s) => s.version).toList(), [10]);
      },
    );

    test(
      '升级 V9→V12 跳过不存在的 V12 脚本 / skips missing scripts',
      () {
        // 只有 V10 / V11 脚本，无 V12
        final scripts = {
          10: upgradeScript(10),
          11: upgradeScript(11),
        };
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 12,
        );
        // 已有的都应执行
        expect(plan.map((s) => s.version).toList(), [10, 11]);
      },
    );
  });

  group('MigrationScriptPlanner.plan — 降级 / downgrade', () {
    test(
      '降级 V11→V9 应降序返回 [V11, V10] '
      '(防止在 V11 schema 执行 V10→V9 的 SQL)',
      () {
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
          reason: '降级必须降序：先 11→10，再 10→9；否则 V10→V9 的 SQL '
              '会在 V11 schema 上执行而失败',
        );
      },
    );

    test(
      '降级 V10→V9 只含 V10 / single hop descending',
      () {
        final scripts = {
          10: downgradeScript(10),
          11: downgradeScript(11),
        };
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 10,
          toVersion: 9,
        );
        expect(plan.map((s) => s.version).toList(), [10]);
      },
    );

    test(
      '降级跨 3 版本 V12→V9 应 [V12, V11, V10] / three-hop descending',
      () {
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
      },
    );
  });

  group('MigrationScriptPlanner.plan — 边界 / edge cases', () {
    test(
      'from == to 返回空列表 / no-op when versions equal',
      () {
        final scripts = {10: upgradeScript(10)};
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 10,
          toVersion: 10,
        );
        expect(plan, isEmpty);
      },
    );

    test(
      '空 scripts map 返回空列表 / empty map returns empty',
      () {
        final plan = MigrationScriptPlanner.plan(
          scripts: <int, MigrationScript>{},
          fromVersion: 9,
          toVersion: 11,
        );
        expect(plan, isEmpty);
      },
    );

    test(
      '选择区间为 (min, max]（开下界、闭上界） / half-open interval',
      () {
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
      },
    );
  });
}
