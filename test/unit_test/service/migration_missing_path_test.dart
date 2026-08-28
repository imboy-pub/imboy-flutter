// WP1 缺失迁移路径 fail-fast 测试
// WP1 missing-migration-path fail-fast tests.
//
// 复现的缺陷（研究文档 §2.2 / §2.3 P0）：planner 只对升级目标块校验，
// 降级方向缺块时静默返回部分/空计划 → migrate() 返回 success →
// sqflite 推进 user_version → schema 与版本号静默错配。
// v30→v29（has_purchased 回退缺失）是最危险的实例。
//
// 修复后契约：
//   - 升降级任一方向的所需块缺失 → 抛 MissingMigrationPathException
//     （升级仅缺目标块保留旧 MissingMigrationScriptException 语义）。
//   - 异常报告：第一条缺边（按执行顺序）+ 全部缺失块 + 完整请求 from/to。
//   - 空脚本 map 的升降级均失败；from == to 仍为合法 no-op。
//   - 历史跳号（v15）必须在 planner 显式声明，不得隐式容忍一切跳号。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_script.dart';
import 'package:imboy/service/migration_script_planner.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

MigrationScript up(int v) => MigrationScript(
  version: v,
  targetVersion: v,
  description: 'up v$v',
  sqlStatements: const [],
);

MigrationScript down(int v) => MigrationScript(
  version: v,
  targetVersion: v - 1,
  description: 'down from v$v',
  sqlStatements: const [],
);

/// 真实 embedded 脚本构造的块 map（升级/降级），与 MigrationService.init
/// 的解析产物同构。
Map<int, MigrationScript> realUpgradeScripts() => parseMigrationVersionBlocks(
  kUpgradeScriptSql,
).map((v, sql) => MapEntry(v, up(v)));
Map<int, MigrationScript> realDowngradeScripts() => parseMigrationVersionBlocks(
  kDowngradeScriptSql,
).map((v, sql) => MapEntry(v, down(v)));

void main() {
  group('WP1 降级缺边必须 fail-fast / missing downgrade edges throw', () {
    test('30→29（has_purchased 回退）缺块必须抛', () {
      // 真实 downgrade 块没有 VERSION: 30
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: realDowngradeScripts(),
          fromVersion: 30,
          toVersion: 29,
        ),
        throwsA(isA<MissingMigrationPathException>()),
      );
    });

    test('27→26（user_role/is_subscribed 回退）缺块必须抛', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: realDowngradeScripts(),
          fromVersion: 27,
          toVersion: 26,
        ),
        throwsA(isA<MissingMigrationPathException>()),
      );
    });

    test('26→25（last_seen_at 回退）缺块必须抛', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: realDowngradeScripts(),
          fromVersion: 26,
          toVersion: 25,
        ),
        throwsA(isA<MissingMigrationPathException>()),
      );
    });

    test('31→25 跨边：缺 {30,27,26}，第一条按执行序是 30→29', () {
      try {
        MigrationScriptPlanner.plan(
          scripts: realDowngradeScripts(),
          fromVersion: 31,
          toVersion: 25,
        );
        fail('必须抛 MissingMigrationPathException');
      } on MissingMigrationPathException catch (e) {
        // 第一条缺边：降级执行序 [31,30,29,...]，块 30 先于 27/26 缺失
        expect(e.firstMissingBlock, equals(30));
        expect(e.missingBlocks, equals([30, 27, 26]));
        expect(e.requestFromVersion, equals(31));
        expect(e.requestToVersion, equals(25));
        // 错误信息包含准确的缺边表述与完整请求
        expect(e.toString(), contains('v30 → v29'));
        expect(e.toString(), contains('v31 → v25'));
      }
    });

    test('合成脚本：11→9 只有块 11 时必须抛（旧预期"按原样返回"已反转）', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: {11: down(11)},
          fromVersion: 11,
          toVersion: 9,
        ),
        throwsA(isA<MissingMigrationPathException>()),
      );
    });
  });

  group('WP1 升级中间缺块必须 fail-fast / missing intermediate blocks', () {
    test('升级 13→17 缺 16 块必须抛（跳号合法≠中间块可缺）', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: {14: up(14), 17: up(17)}, // 缺 16
          fromVersion: 13,
          toVersion: 17,
        ),
        throwsA(isA<MissingMigrationPathException>()),
      );
    });

    test('升级缺目标块保留旧异常语义 / target-missing keeps legacy type', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: {10: up(10), 11: up(11)},
          fromVersion: 9,
          toVersion: 12,
        ),
        throwsA(isA<MissingMigrationScriptException>()),
      );
    });
  });

  group('WP1 空脚本与 no-op / empty map and no-op', () {
    test('空 map 降级必须抛（不得空计划 success）', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: <int, MigrationScript>{},
          fromVersion: 10,
          toVersion: 9,
        ),
        throwsA(isA<MissingMigrationPathException>()),
      );
    });

    test('空 map 升级必须抛', () {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: <int, MigrationScript>{},
          fromVersion: 9,
          toVersion: 10,
        ),
        throwsA(isA<MissingMigrationScriptException>()),
      );
    });

    test('from == to 仍为合法 no-op（空计划不抛）', () {
      expect(
        MigrationScriptPlanner.plan(
          scripts: <int, MigrationScript>{},
          fromVersion: 31,
          toVersion: 31,
        ),
        isEmpty,
      );
    });
  });

  group('WP1 真实脚本全链回归 / real-script regression', () {
    test('真实 upgrade：v9 → v31 全链完整，正常返回', () {
      final plan = MigrationScriptPlanner.plan(
        scripts: realUpgradeScripts(),
        fromVersion: 9,
        toVersion: 31,
      );
      expect(plan.first.version, equals(10));
      expect(plan.last.version, equals(31));
    });

    test('真实 downgrade：v25 → v18 已有链继续 PASS', () {
      final plan = MigrationScriptPlanner.plan(
        scripts: realDowngradeScripts(),
        fromVersion: 25,
        toVersion: 18,
      );
      // 块 N = 边 N→(N-1)：[25..19] 覆盖 25→24 … 19→18
      expect(
        plan.map((s) => s.version).toList(),
        equals([25, 24, 23, 22, 21, 20, 19]),
      );
    });

    test('真实 downgrade：v31 → v30 单边（唯一受支持窗口）继续 PASS', () {
      final plan = MigrationScriptPlanner.plan(
        scripts: realDowngradeScripts(),
        fromVersion: 31,
        toVersion: 30,
      );
      expect(plan.map((s) => s.version).toList(), equals([31]));
    });
  });
}
