// WP3 类型化 Migration Manifest 契约测试
// Contract tests for the typed migration manifest (single source of truth).
//
// 守护（计划 Step 4 验收）：
//   1. 边集合与 WP0 基线清单一致（无漂移、无未登记块）。
//   2. 生成等价：manifest 重组的 upgrade/downgrade SQL 与仓库
//      assets/migrations/*.sql 字节级一致（.sql 是生成物，不是真源）。
//   3. 生成确定性：两次运行输出完全相同。
//   4. ID/from/to 唯一：注入重复值必须在构造期抛 MigrationManifestException。
//   5. 不可逆 upgrade 边不得存在配对 downgrade 边。
//   6. 每边 sqlStatements 以 `PRAGMA user_version = to` 收尾（框架推进
//      版本的单一出口）。
//   7. latestVersion == SqliteService._dbVersion == MigrationService.targetVersion。
//   8. v31→v30 唯一受支持降级窗口在 manifest 中且声明 dataLoss/requiresResync。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_manifest.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migrations/manifest_all.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';

void main() {
  group('清单 ↔ WP0 基线 / manifest ↔ frozen inventory', () {
    test('upgrade 边块集合与清单一致（去掉 v9 起点占位）', () {
      final blocks = kMigrationManifest.upgradesByTo.keys.toSet();
      final expected = kInventoryExpectedUpgradeBlocks.difference({9});
      expect(blocks, equals(expected));
    });

    test('downgrade 边块集合与清单一致（去掉 v9 空占位）', () {
      final blocks = kMigrationManifest.downgradesByFrom.keys.toSet();
      final expected = kInventoryExpectedDowngradeBlocks.difference({9});
      expect(blocks, equals(expected));
    });

    test('已知缺失降级边与动态计算一致', () {
      final universe = kInventoryExpectedUpgradeBlocks
          .where((v) => v > kInventoryLegacyBaselineVersion)
          .where((v) => !kInventorySkippedVersions.contains(v))
          .toSet();
      final actual = kMigrationManifest.downgradesByFrom.keys.toSet();
      expect(
        universe.difference(actual),
        equals(kInventoryKnownMissingDowngradeBlocks),
      );
    });

    test('latestVersion == 31 == SqliteService._dbVersion（源码扫描）', () async {
      expect(kMigrationManifest.latestVersion, equals(31));
      final src = File('lib/service/sqlite.dart').readAsStringSync();
      final m = RegExp(
        r'static\s+const\s+_dbVersion\s*=\s*(\d+)',
      ).firstMatch(src);
      expect(m, isNotNull);
      expect(int.parse(m!.group(1)!), equals(kMigrationManifest.latestVersion));
    });

    test('MigrationService.targetVersion == manifest.latestVersion', () async {
      await MigrationService.to.init();
      expect(
        MigrationService.to.targetVersion,
        equals(kMigrationManifest.latestVersion),
        reason: '契约：服务目标版本必须来自 manifest（单一真源）',
      );
    });
  });

  group('生成等价与确定性 / generation equivalence & determinism', () {
    test(
      'buildUpgradeSqlFromManifest == assets/migrations/upgrade.sql（字节级）',
      () {
        final repo = File('assets/migrations/upgrade.sql').readAsStringSync();
        expect(buildUpgradeSqlFromManifest(), equals(repo));
      },
    );

    test(
      'buildDowngradeSqlFromManifest == assets/migrations/downgrade.sql（字节级）',
      () {
        final repo = File('assets/migrations/downgrade.sql').readAsStringSync();
        expect(buildDowngradeSqlFromManifest(), equals(repo));
      },
    );

    test('生成确定性：两次运行输出相同', () {
      expect(
        buildUpgradeSqlFromManifest(),
        equals(buildUpgradeSqlFromManifest()),
      );
      expect(
        buildDowngradeSqlFromManifest(),
        equals(buildDowngradeSqlFromManifest()),
      );
    });

    test('embedded 常量与 manifest 一致（kUpgradeScriptSql 为生成物）', () {
      expect(kUpgradeScriptSql, equals(buildUpgradeSqlFromManifest()));
      expect(kDowngradeScriptSql, equals(buildDowngradeSqlFromManifest()));
    });
  });

  group('构造期校验 / construction-time validation', () {
    test('重复边 id 抛 MigrationManifestException', () {
      const edge = MigrationEdge(
        id: 'dup_id',
        fromVersion: 1,
        toVersion: 2,
        description: 'x',
        reversible: false,
        dataLoss: false,
        requiresResync: false,
        preconditions: [],
        postconditions: [],
        affectedObjects: [],
        headerComment: '-- VERSION: 2\n',
        sql: 'PRAGMA user_version = 2;\n',
      );
      expect(
        () => MigrationManifest([edge, edge]),
        throwsA(isA<MigrationManifestException>()),
      );
    });

    test('重复 upgrade 目标版本抛 MigrationManifestException', () {
      MigrationEdge edge(int from, String id) => MigrationEdge(
        id: id,
        fromVersion: from,
        toVersion: 2,
        description: 'x',
        reversible: false,
        dataLoss: false,
        requiresResync: false,
        preconditions: [],
        postconditions: [],
        affectedObjects: [],
        headerComment: '-- VERSION: 2\n',
        sql: 'PRAGMA user_version = 2;\n',
      );
      expect(
        () => MigrationManifest([edge(1, 'a'), edge(0, 'b')]),
        throwsA(isA<MigrationManifestException>()),
      );
    });

    test('from == to 自环抛 MigrationManifestException', () {
      expect(
        () => MigrationManifest([
          const MigrationEdge(
            id: 'loop',
            fromVersion: 3,
            toVersion: 3,
            description: 'x',
            reversible: false,
            dataLoss: false,
            requiresResync: false,
            preconditions: [],
            postconditions: [],
            affectedObjects: [],
            headerComment: '-- VERSION: 3\n',
            sql: 'PRAGMA user_version = 3;\n',
          ),
        ]),
        throwsA(isA<MigrationManifestException>()),
      );
    });

    test('不可逆 upgrade 边存在配对 downgrade 时 validatePairing 抛', () {
      final manifest = MigrationManifest(const [
        MigrationEdge(
          id: 'up_1_2',
          fromVersion: 1,
          toVersion: 2,
          description: 'x',
          reversible: false,
          dataLoss: false,
          requiresResync: false,
          preconditions: [],
          postconditions: [],
          affectedObjects: [],
          headerComment: '-- VERSION: 2\n',
          sql: 'PRAGMA user_version = 2;\n',
        ),
        MigrationEdge(
          id: 'down_2_1',
          fromVersion: 2,
          toVersion: 1,
          description: 'x',
          reversible: false,
          dataLoss: true,
          requiresResync: true,
          preconditions: [],
          postconditions: [],
          affectedObjects: [],
          headerComment: '-- VERSION: 2\n',
          sql: 'PRAGMA user_version = 1;\n',
        ),
      ]);
      expect(
        manifest.validatePairing,
        throwsA(isA<MigrationManifestException>()),
      );
    });

    test('全局清单每条 downgrade 边的配对 upgrade 均 reversible', () {
      for (final e in kMigrationManifest.downgradesByFrom.values) {
        final up = kMigrationManifest.upgradesByTo[e.fromVersion];
        if (up == null) continue;
        expect(
          up.reversible,
          isTrue,
          reason: 'downgrade ${e.id} 配对的 upgrade ${up.id} 必须 reversible',
        );
      }
    });
  });

  group('边内容契约 / edge content contract', () {
    test('每条边 sqlStatements 以 PRAGMA user_version = to 收尾', () {
      for (final e in kMigrationManifest.edges) {
        final stmts = e.sqlStatements;
        expect(stmts, isNotEmpty, reason: '${e.id} 不得为空 SQL 边');
        expect(
          stmts.last,
          matches(RegExp('PRAGMA user_version = ${e.toVersion};?')),
          reason: '${e.id} 最后一条语句必须是 PRAGMA user_version = ${e.toVersion}',
        );
      }
    });

    test('每条边声明 affectedObjects（影响面可审计）', () {
      for (final e in kMigrationManifest.edges) {
        expect(e.affectedObjects, isNotEmpty, reason: '${e.id} 必须声明受影响对象');
      }
    });

    test('v31→v30 唯一受支持降级窗口：存在且声明 dataLoss/requiresResync', () {
      final e = kMigrationManifest.edge(31, 30);
      expect(e, isNotNull, reason: '受支持的降级窗口 v31→v30 必须在 manifest');
      expect(e!.dataLoss, isTrue);
      expect(
        e.requiresResync,
        isFalse,
        reason: 'v31→v30 回退 type 权威列，旧版仍可读写（expand 设计）',
      );
    });

    test('v22 upgrade 边声明 dataLoss（user_collect 重建丢弃非法行）', () {
      final e = kMigrationManifest.upgradesByTo[22];
      expect(e, isNotNull);
      expect(
        e!.dataLoss,
        isTrue,
        reason: 'v22 重建 user_collect 丢弃 kind_id IN (0,\'\') 行',
      );
    });
  });

  group('planner 与 manifest 单一真源 / planner consumes manifest', () {
    test('MigrationService 脚本块集合 == manifest 块集合', () async {
      await MigrationService.to.init();
      expect(
        MigrationService.to.debugUpgradeScripts.keys.toSet(),
        equals(kMigrationManifest.upgradesByTo.keys.toSet()),
      );
      expect(
        MigrationService.to.debugDowngradeScripts.keys.toSet(),
        equals(kMigrationManifest.downgradesByFrom.keys.toSet()),
      );
    });
  });
}
