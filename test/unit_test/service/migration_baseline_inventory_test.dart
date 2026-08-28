// WP0 迁移基线清单测试：版本边事实与运行时真源双向对照
// WP0 migration baseline inventory test: two-way check between the frozen
// inventory and the runtime sources of truth.
//
// 守护三件事：
//   1. embedded 脚本的实际 VERSION 块集合 == 清单声明（无漂移、无未登记块）。
//   2. 缺失降级边以"已知缺口"显式登记，且与动态计算结果一致——
//      WP1 将把这些缺口转为 fail-fast 断言，本测试是缺口清单的真源。
//   3. fixture 生成器能从生产脚本真实构建全部受支持起点
//      （v9/v16/v18/v25/v29/v30/v31），合成种子行为无 PII 固定值。
//
// 本测试全部为本地/静态证据（sqflite_common_ffi in-memory），
// 不构成真机 SQLCipher 或生产验收证明。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('清单 ↔ 脚本 双向对照 / inventory ↔ embedded scripts', () {
    test('upgrade VERSION 块集合与清单一致 / upgrade block set matches', () {
      final blocks = parseMigrationVersionBlocks(
        kUpgradeScriptSql,
      ).keys.toSet();
      expect(
        blocks,
        equals(kInventoryExpectedUpgradeBlocks),
        reason:
            'upgrade 块集合漂移：若新增/删除版本块，必须先更新 '
            'migration_inventory.dart 并在计划中登记',
      );
    });

    test('downgrade VERSION 块集合与清单一致 / downgrade block set matches', () {
      final blocks = parseMigrationVersionBlocks(
        kDowngradeScriptSql,
      ).keys.toSet();
      expect(
        blocks,
        equals(kInventoryExpectedDowngradeBlocks),
        reason:
            'downgrade 块集合漂移：若新增/删除版本块，必须先更新 '
            'migration_inventory.dart 并在计划中登记',
      );
    });

    test('已知缺失降级边与动态计算一致 / known missing downgrade edges', () {
      // 降级块宇宙 = upgrade 块（去掉起点 9 与跳号 15）：每个升级可达的
      // 版本理论上都该有一条回退边。
      final downgradeUniverse = kInventoryExpectedUpgradeBlocks
          .where((v) => v > kInventoryLegacyBaselineVersion)
          .where((v) => !kInventorySkippedVersions.contains(v))
          .toSet();
      final actualDowngrade = kInventoryExpectedDowngradeBlocks
          .where((v) => v > kInventoryLegacyBaselineVersion)
          .toSet();

      final dynamicallyMissing = downgradeUniverse.difference(actualDowngrade);

      expect(
        dynamicallyMissing,
        equals(kInventoryKnownMissingDowngradeBlocks),
        reason:
            '缺失降级边清单与脚本事实不一致；缺口边（块 N = N→N-1）：'
            '$dynamicallyMissing。WP1 依赖此清单做 fail-fast。',
      );
    });

    test('upgrade 最大 PRAGMA user_version == 权威版本 / max target version', () {
      final targets = RegExp(
        r'PRAGMA user_version\s*=\s*(\d+)',
      ).allMatches(kUpgradeScriptSql).map((m) => int.parse(m.group(1)!));
      expect(targets, isNotEmpty);
      expect(
        targets.reduce((a, b) => a > b ? a : b),
        equals(kInventoryCurrentDbVersion),
        reason:
            'upgrade 脚本最大目标版本必须等于权威版本 '
            '$kInventoryCurrentDbVersion（SqliteService._dbVersion）',
      );
    });
  });

  group('权威版本守护 / authoritative version guard', () {
    test('SqliteService._dbVersion 源码扫描 == 清单 / source scan matches', () {
      final file = File('lib/service/sqlite.dart');
      expect(file.existsSync(), isTrue, reason: 'test CWD 必须是项目根');
      final source = file.readAsStringSync();
      final match = RegExp(
        r'static\s+const\s+_dbVersion\s*=\s*(\d+)',
      ).firstMatch(source);
      expect(match, isNotNull, reason: 'sqlite.dart 必须声明 _dbVersion 常量');
      expect(
        int.parse(match!.group(1)!),
        equals(kInventoryCurrentDbVersion),
        reason:
            'SqliteService._dbVersion 与基线清单不一致；改版本号必须同步 '
            'migration_inventory.dart',
      );
    });
  });

  group('fixture 生成器 / fixture builder smoke', () {
    for (final version in [9, 16, 18, 25, 29, 30, 31]) {
      test('v$version 能从生产脚本构建且 user_version 归位 / builds', () async {
        final db = await openFixtureDatabaseAtVersion(version: version);
        addTearDown(db.close);

        final uv = await db.rawQuery('PRAGMA user_version');
        expect(uv.first.values.first, equals(version));

        if (version >= 10) {
          final msgTable = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='msg_c2c'",
          );
          expect(msgTable, isNotEmpty, reason: 'v$version 必须有 msg_c2c 表');
        }
        if (version >= 13) {
          final channel = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='channel'",
          );
          expect(channel, isNotEmpty, reason: 'v$version 必须有 channel 表');
        }
        if (version == 9) {
          final legacy = await db.rawQuery(
            "SELECT count(*) AS c FROM sqlite_master WHERE type='table' "
            "AND name IN ('message','group_message','c2s_message','s2c_message')",
          );
          expect(legacy.first['c'], equals(4), reason: 'v9 必须是旧表名形态');
        }
      });
    }

    test('合成种子行可插入且全部为合成值 / synthetic seed rows', () async {
      final db = await openFixtureDatabaseAtVersion(
        version: 31,
        withSyntheticRows: true,
      );
      addTearDown(db.close);

      final msgs = await db.query(
        'msg_c2c',
        where: 'conversation_uk3 = ?',
        whereArgs: ['synthetic-conv-001'],
      );
      expect(msgs, isNotEmpty);
      expect(msgs.first['payload'], equals('{"synthetic":true}'));

      final channels = await db.query(
        'channel',
        where: 'name = ?',
        whereArgs: ['synthetic-channel-001'],
      );
      expect(channels, isNotEmpty);
      // v31 访问模型三字段必须可写（channel-access-model 重构后）
      expect(channels.first['visibility'], equals('public'));
      expect(channels.first['access_type'], equals(0));
      expect(channels.first['join_policy'], equals('open'));
    });

    test('v31 频道访问模型三字段存在 / v31 access model columns', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final cols = await db.rawQuery('PRAGMA table_info(channel)');
      final names = cols.map((r) => r['name'] as String).toSet();
      expect(names, containsAll(['visibility', 'access_type', 'join_policy']));
      expect(names, contains('type'), reason: 'v31 保留旧 type 列（expand 设计）');
      expect(names, contains('has_purchased'));
    });
  });
}
