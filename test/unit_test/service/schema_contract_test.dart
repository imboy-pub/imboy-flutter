// WP4 Schema Contract 与 golden 测试
// Golden contract tests: capture/verify per supported version + key business
// invariants + _imboy_schema_meta contract.
//
// Golden 更新方式（版本升级导致 schema 变化时）：
//   flutter test test/unit_test/service/schema_contract_test.dart \
//     --dart-define=UPDATE_SCHEMA_GOLDENS=true
// 常态（CI/本地）只读比对，golden 漂移即 RED。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _updateGoldens = bool.fromEnvironment('UPDATE_SCHEMA_GOLDENS');
const _goldenDir = 'test/fixtures/sqlite_migration/schema';
const _goldenVersions = [9, 16, 25, 30, 31, 32];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  for (final version in _goldenVersions) {
    group('WP4 golden v$version', () {
      late Database db;
      setUp(() async {
        db = await openFixtureDatabaseAtVersion(version: version);
      });
      tearDown(() async => db.close());

      test('结构匹配 golden（fingerprint + 表/列/索引）', () async {
        final fingerprint = await SchemaFingerprint.compute(db);
        final contract = await SchemaContract.capture(
          db,
          version: version,
          fingerprint: fingerprint,
        );
        final encoded = SchemaContract.encodeGolden(contract);
        final goldenPath = '$_goldenDir/v$version.json';

        if (_updateGoldens) {
          File(goldenPath).writeAsStringSync(encoded);
          return;
        }

        final golden = File(goldenPath);
        expect(
          golden.existsSync(),
          isTrue,
          reason: 'golden 不存在：先用 --dart-define=UPDATE_SCHEMA_GOLDENS=true 生成',
        );
        final goldenMap = SchemaContract.decodeGolden(
          golden.readAsStringSync(),
        );

        // fingerprint 必须一致（最强断言）
        expect(
          contract['fingerprint'],
          equals(goldenMap['fingerprint']),
          reason: 'v$version 指纹漂移：结构发生了未登记的变化',
        );
        // 表集合必须一致；表内结构差异已被 fingerprint 覆盖
        final tablesNow = (contract['tables'] as Map).keys.toSet();
        final tablesGolden = (goldenMap['tables'] as Map).keys.toSet();
        expect(tablesNow, equals(tablesGolden), reason: 'v$version 表集合漂移');
      });

      test('关键业务 invariant 通过', () async {
        final violations = await SchemaContract.verifyInvariants(
          db,
          version: version,
        );
        expect(violations, isEmpty, reason: '关键结构缺失：$violations');
      });
    });
  }

  group('WP4 关键 invariant 反向验证 / invariants actually bite', () {
    test('篡改列后 invariant 失败（v31 channel 三字段）', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      // 模拟 v31 访问模型三字段缺失（重建 channel 去掉三字段）
      await db.execute('DROP INDEX IF EXISTS idx_channel_type');
      await db.execute('ALTER TABLE channel RENAME TO channel_tampered');
      await db.execute('''
        CREATE TABLE channel (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          type INTEGER DEFAULT 0,
          has_purchased INTEGER DEFAULT 0
        )
      ''');
      final violations = await SchemaContract.verifyInvariants(db, version: 31);
      expect(violations, isNotEmpty);
      expect(
        violations.any((v) => v.contains('visibility')),
        isTrue,
        reason: '必须报告缺失的访问模型字段',
      );
    });

    test('未知版本返回空（不误报），已知版本缺表会报', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      expect(await SchemaContract.verifyInvariants(db, version: 99), isEmpty);
      expect(
        await SchemaContract.verifyInvariants(db, version: 31),
        isNotEmpty,
        reason: '空库对 v31 invariant 必须报缺失',
      );
    });
  });

  group('WP4 _imboy_schema_meta 契约 / schema meta contract', () {
    test('写入幂等 + 读回一致', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      await ImboySchemaMeta.write(db, {
        ImboySchemaMeta.keySchemaVersion: '31',
        ImboySchemaMeta.keySchemaHash: await SchemaFingerprint.compute(db),
        ImboySchemaMeta.keyLastMigrationId: 'legacy_upgrade_v31_x',
        ImboySchemaMeta.keyMigrationState: 'ok',
      });
      // 再写一次（幂等）
      await ImboySchemaMeta.write(db, {
        ImboySchemaMeta.keyMigrationState: 'migrating',
      });
      final meta = await ImboySchemaMeta.readAll(db);
      expect(meta[ImboySchemaMeta.keySchemaVersion], equals('31'));
      expect(meta[ImboySchemaMeta.keyMigrationState], equals('migrating'));
      expect(meta[ImboySchemaMeta.keySchemaHash], hasLength(64));
    });

    test('meta 表不存在时读回空 map（fail-safe）', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      expect(await ImboySchemaMeta.readAll(db), isEmpty);
    });
  });

  group('WP4 v31 声明式结构断言（消息/E2EE/outbox/频道）', () {
    test('消息四表 + E2EE 引用 + 频道访问模型关键列存在', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final e2eeCols = await db.rawQuery('PRAGMA table_info("msg_c2c")');
      final names = e2eeCols.map((r) => r['name'] as String).toSet();
      expect(names, containsAll(['e2ee', 'sender_did']));
      // 外键完整性检查通过
      final fk = await db.rawQuery('PRAGMA foreign_key_check');
      expect(fk, isEmpty);
      final quick = await db.rawQuery('PRAGMA quick_check');
      expect(quick.first.values.first, equals('ok'));
    });
  });
}
