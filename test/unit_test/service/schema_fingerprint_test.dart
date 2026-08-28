// WP4 Schema 指纹测试
// Fingerprint tests: three build paths converge, tampering detected,
// business data does not affect the hash.
//
// 验收（计划 Step 5）：
//   - fresh v31（baseline+增量）、逐级 v9→31、跨级 v16→31 三条路径 hash 相同。
//   - 篡改一列 / 一个索引 → hash 必变。
//   - 业务数据行变化 → hash 不变（只含结构）。
//   - application_id 契约值固定非零，可写入可读回。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/schema_fingerprint.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WP4 三条建库路径收敛 / three build paths converge', () {
    test('fresh v31 == 逐级 v9→31 == 跨级 v16→31', () async {
      final fresh = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(fresh.close);
      final hFresh = await SchemaFingerprint.compute(fresh);

      // v9 逐级（每版本一个检查点）到 31
      final stepwise = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(stepwise.close);
      await applyV9LegacySchema(stepwise);
      for (var v = 10; v <= 31; v++) {
        await upgradeFixtureToVersion(stepwise, v - 1, v);
      }
      final hStep = await SchemaFingerprint.compute(stepwise);

      // v16 baseline → 31（跨级单段）
      final cross = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(cross.close);
      await applyBaselineSchema(cross);
      await cross.execute('PRAGMA user_version = 16');
      await upgradeFixtureToVersion(cross, 16, 31);
      final hCross = await SchemaFingerprint.compute(cross);

      expect(hFresh, equals(hStep), reason: 'fresh 与 v9 逐级路径必须等价');
      expect(hFresh, equals(hCross), reason: 'fresh 与 v16 跨级路径必须等价');
      expect(hFresh.length, equals(64), reason: 'SHA-256 hex');
    });

    test('同一库重复计算 hash 稳定', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final a = await SchemaFingerprint.compute(db);
      final b = await SchemaFingerprint.compute(db);
      expect(a, equals(b));
    });
  });

  group('WP4 篡改必检 / tampering detected', () {
    test('新增一列 → hash 变', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final before = await SchemaFingerprint.compute(db);
      await db.execute(
        'ALTER TABLE contact ADD COLUMN tamper_probe INTEGER DEFAULT 0',
      );
      final after = await SchemaFingerprint.compute(db);
      expect(after, isNot(equals(before)));
    });

    test('删除并重建索引（改列集）→ hash 变', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final before = await SchemaFingerprint.compute(db);
      await db.execute('DROP INDEX i_Nickname');
      await db.execute('CREATE INDEX i_Nickname ON contact (nickname, remark)');
      final after = await SchemaFingerprint.compute(db);
      expect(after, isNot(equals(before)));
    });

    test('同名同列索引仅改名 → hash 变（索引名属于契约）', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final before = await SchemaFingerprint.compute(db);
      await db.execute('DROP INDEX i_Nickname');
      await db.execute('CREATE INDEX i_Renamed ON contact (nickname)');
      final after = await SchemaFingerprint.compute(db);
      expect(after, isNot(equals(before)));
    });
  });

  group('WP4 hash 不含业务数据 / data independence', () {
    test('插入/删除行 → hash 不变', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      final before = await SchemaFingerprint.compute(db);
      await db.insert('msg_c2c', {
        'id': 990000000099,
        'msg_type': 'text',
        'from_id': 990001,
        'to_id': 990002,
        'conversation_uk3': 'synthetic-conv-002',
        'payload': '{"synthetic":true}',
        'created_at': 1700000000000,
        'status': 1,
        'is_author': 1,
        'type': 'C2C',
      });
      final mid = await SchemaFingerprint.compute(db);
      expect(mid, equals(before));
      await db.delete('msg_c2c', where: 'id = ?', whereArgs: [990000000099]);
      final after = await SchemaFingerprint.compute(db);
      expect(after, equals(before));
    });
  });

  group('WP4 application_id 契约 / application id contract', () {
    test('固定非零（IMBO ASCII）', () {
      expect(kImboyApplicationId, equals(0x494D424F));
      expect(kImboyApplicationId, isNot(equals(0)));
    });

    test('可写入并可读回（拒绝非 IMBoy 文件的契约基础）', () async {
      final db = await openFixtureDatabaseAtVersion(version: 31);
      addTearDown(db.close);
      await db.execute('PRAGMA application_id = $kImboyApplicationId');
      final rows = await db.rawQuery('PRAGMA application_id');
      expect(rows.first.values.first, equals(kImboyApplicationId));
    });
  });
}
