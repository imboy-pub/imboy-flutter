// R07 phase1 迁移演练测试（sqflite_common_ffi 真库执行，非 mock）：
//   - v34→v35 单步升级：新列/索引/版本号 + 既有数据原样保留；
//   - v32→v35 逐级升级（补齐 golden 空档后的完整路径）；
//   - v9→v35 旧版本跨级升级，数据保留（R07-4）；
//   - v35→v34 降级：列/索引移除、业务行不丢；
//   - v35 invariant + 升级后 SQL 排序与 Dart 比较器同构（混排数据）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migrations/manifest_all.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/model/message_order.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _uk3 = 'synthetic-r07-conv-001';
const _now = 1750000000000;

/// 向 msg 表写入混排形状：同毫秒多条、无 seq 旧消息、有 seq 新消息。
Future<void> _seedMixedRows(Database db, String table) async {
  // 无 seq 旧消息两条（同毫秒，msg_id 定序）
  await db.insert(table, {
    'id': 900000000001,
    'msg_type': 'text',
    'from_id': 990001,
    'to_id': 990002,
    'conversation_uk3': _uk3,
    'payload': '{"legacy":1}',
    'created_at': _now - 10000,
    'topic_id': 0,
    'status': 1,
    'is_author': 0,
    'type': 'C2C',
  });
  await db.insert(table, {
    'id': 900000000002,
    'msg_type': 'text',
    'from_id': 990001,
    'to_id': 990002,
    'conversation_uk3': _uk3,
    'payload': '{"legacy":2}',
    'created_at': _now - 10000, // 同毫秒
    'topic_id': 0,
    'status': 1,
    'is_author': 1,
    'type': 'C2C',
  });
  // 有 seq 新消息（离线乱序：auto_id 序 != seq 序，模拟 3 后到）
  await db.insert(table, {
    'id': 900000000004,
    'msg_type': 'text',
    'from_id': 990001,
    'to_id': 990002,
    'conversation_uk3': _uk3,
    'payload': '{"seq":4}',
    'created_at': _now,
    'topic_id': 0,
    'status': 1,
    'is_author': 1,
    'type': 'C2C',
  });
}

/// 升级后回填 seq（模拟 phase2 wire 前置数据准备，直接写列）。
Future<void> _applySeq(Database db, String table, int msgId, int seq) async {
  await db.rawUpdate(
    'UPDATE $table SET conv_seq = ?, accepted_at = ? WHERE id = ?',
    [seq, _now + seq, msgId],
  );
}

Future<Set<String>> _columns(Database db, String table) async =>
    (await db.rawQuery('PRAGMA table_info($table)'))
        .map((r) => r['name'] as String)
        .toSet();

Future<Set<String>> _indexes(Database db, String table) async =>
    (await db.rawQuery('PRAGMA index_list($table)'))
        .map((r) => r['name'] as String)
        .toSet();

Future<int> _version(Database db) async =>
    (await db.rawQuery('PRAGMA user_version')).first.values.first as int;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('v35 迁移边（manifest 声明）', () {
    test('manifest 最新版本为 35 且边存在', () {
      expect(kMigrationManifest.latestVersion, 35);
      final edge = kMigrationManifest.edge(34, 35);
      expect(edge, isNotNull);
      expect(edge!.reversible, isTrue);
      expect(edge.dataLoss, isFalse);
      expect(edge.affectedObjects, containsAll(['msg_c2c', 'msg_c2g']));
      expect(kMigrationManifest.edge(35, 34), isNotNull); // down 边存在
    });
  });

  group('v34→v35 单步升级', () {
    test('四表加可空列 + 排序索引 + user_version=35', () async {
      final db = await openFixtureDatabaseAtVersion(version: 34);
      await _seedMixedRows(db, 'msg_c2c');
      final before = await db.rawQuery(
        'SELECT id, payload, created_at FROM msg_c2c ORDER BY auto_id',
      );

      await upgradeFixtureToVersion(db, 34, 35);

      expect(await _version(db), 35);
      for (final t in ['msg_c2c', 'msg_c2g', 'msg_c2s', 'msg_s2c']) {
        final cols = await _columns(db, t);
        expect(
          cols,
          containsAll(['conv_seq', 'accepted_at']),
          reason: '$t 缺新列',
        );
        expect(
          await _indexes(db, t),
          contains('idx_${t}_conversation_conv_seq'),
          reason: '$t 缺排序索引',
        );
      }
      // 新列可空：既有行值为 NULL
      final nulls = await db.rawQuery(
        'SELECT count(*) AS c FROM msg_c2c '
        'WHERE conv_seq IS NOT NULL OR accepted_at IS NOT NULL',
      );
      expect((nulls.first['c'] as int), 0, reason: '存量行不得被伪造序号');

      // 既有数据原样保留（列值逐行对比）
      final after = await db.rawQuery(
        'SELECT id, payload, created_at FROM msg_c2c ORDER BY auto_id',
      );
      expect(after, before);
      await db.close();
    });

    test('降级 v35→v34：列/索引移除，业务行保留', () async {
      final db = await openFixtureDatabaseAtVersion(version: 35);
      await _seedMixedRows(db, 'msg_c2c');
      await _applySeq(db, 'msg_c2c', 900000000004, 4);

      final down = kMigrationManifest.edge(35, 34)!;
      for (final stmt in down.sqlStatements) {
        await db.execute(stmt);
      }

      expect(await _version(db), 34);
      final cols = await _columns(db, 'msg_c2c');
      expect(cols, isNot(contains('conv_seq')));
      expect(cols, isNot(contains('accepted_at')));
      expect(
        await _indexes(db, 'msg_c2c'),
        isNot(contains('idx_msg_c2c_conversation_conv_seq')),
      );
      final rows = await db.rawQuery('SELECT count(*) AS c FROM msg_c2c');
      expect(rows.first['c'], 3, reason: '降级不丢业务行');
      await db.close();
    });
  });

  group('v32→v35 逐级升级（golden 空档补齐后的完整路径）', () {
    test('seed 行保留且到 v35 形态', () async {
      final db = await openFixtureDatabaseAtVersion(
        version: 32,
        withSyntheticRows: true,
      );
      await upgradeFixtureToVersion(db, 32, 35);

      expect(await _version(db), 35);
      final rows = await db.rawQuery(
        "SELECT id, payload, conversation_uk3 FROM msg_c2c "
        "WHERE conversation_uk3 = 'synthetic-conv-001'",
      );
      expect(rows, hasLength(1));
      expect(rows.first['payload'], '{"synthetic":true}');
      expect(
        await _columns(db, 'msg_c2c'),
        containsAll(['conv_seq', 'accepted_at']),
      );
      await db.close();
    });
  });

  group('v9→v35 旧版本跨级升级（R07-4 数据保留）', () {
    test('legacy 起点升到 v35 后消息与会话数据保留', () async {
      final db = await openFixtureDatabaseAtVersion(
        version: 9,
        withSyntheticRows: false,
      );
      // v9 legacy：message 旧表名 + 旧形态 conversation；种入旧消息
      await db.insert('message', {
        'id': 880000000001,
        'from_id': '990001',
        'to_id': '990002',
        'payload': '{"legacy-v9":true}',
        'status': 1,
        'is_author': 0,
        'created_at': _now - 20000,
        'conversation_uk3': _uk3,
        'topic_id': 0,
      });

      await upgradeFixtureToVersion(db, 9, 35);

      expect(await _version(db), 35);
      // v10 块将 message RENAME 为 msg_c2c——旧行随表迁移
      final rows = await db.rawQuery(
        "SELECT id, payload FROM msg_c2c WHERE id = 880000000001",
      );
      expect(rows, hasLength(1), reason: 'v9 旧消息跨级升级后必须保留');
      expect(rows.first['payload'], '{"legacy-v9":true}');
      expect(
        await _columns(db, 'msg_c2s'),
        containsAll(['conv_seq', 'accepted_at']),
      );
      await db.close();
    });
  });

  group('v35 invariant 与排序同构', () {
    test('verifyInvariants(v35) 无违规', () async {
      final db = await openFixtureDatabaseAtVersion(version: 35);
      final violations = await SchemaContract.verifyInvariants(db, version: 35);
      expect(violations, isEmpty);
      await db.close();
    });

    test('升级后真实库上 SQL orderByAsc 与 Dart compareAsc 同序（混排数据）', () async {
      final db = await openFixtureDatabaseAtVersion(version: 35);
      await _seedMixedRows(db, 'msg_c2c');
      // 补齐权威 seq：msg_id ...004 得 seq 4；再插两条有 seq
      await _applySeq(db, 'msg_c2c', 900000000004, 4);
      await db.insert('msg_c2c', {
        'id': 900000000005,
        'msg_type': 'text',
        'from_id': 990001,
        'to_id': 990002,
        'conversation_uk3': _uk3,
        'payload': '{"seq":5}',
        'created_at': _now,
        'topic_id': 0,
        'status': 1,
        'is_author': 1,
        'type': 'C2C',
        'conv_seq': 5,
        'accepted_at': _now + 5,
      });

      final rows = await db.rawQuery(
        'SELECT id, conv_seq, accepted_at, created_at, auto_id '
        'FROM msg_c2c WHERE conversation_uk3 = ? '
        'ORDER BY ${ConversationOrder.orderByAsc}',
        [_uk3],
      );
      final sqlOrder = rows.map((r) => r['id']).toList();

      final dartRows =
          rows
              .map(
                (r) => (
                  convSeq: r['conv_seq'] as int?,
                  acceptedAt: r['accepted_at'] as int?,
                  createdAt: r['created_at'] as int,
                  id: r['id'] as int,
                  autoId: r['auto_id'] as int,
                ),
              )
              .toList()
            ..sort(ConversationOrder.compareAsc);
      final dartOrder = dartRows.map((k) => k.id).toList();

      // 无 seq 旧消息（id 1,2 同毫秒按 id 升序）在前；有 seq 组按 seq
      expect(sqlOrder, [
        900000000001,
        900000000002,
        900000000004,
        900000000005,
      ]);
      expect(dartOrder, sqlOrder, reason: 'SQL 与 Dart 比较器必须同构');
      await db.close();
    });

    test('MessageColumns 常量与真实列名一致', () async {
      expect(MessageColumns.convSeq, 'conv_seq');
      expect(MessageColumns.acceptedAt, 'accepted_at');
      final db = await openFixtureDatabaseAtVersion(version: 35);
      expect(
        await _columns(db, 'msg_c2c'),
        containsAll([MessageColumns.convSeq, MessageColumns.acceptedAt]),
      );
      await db.close();
    });
  });
}
