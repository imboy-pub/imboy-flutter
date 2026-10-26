// R07-7 库层验证：MessageRepo.backfillServerOrderFacts 幂等补齐。
//
// 合同：仅补 NULL；不覆盖正文/密文/附件引用/原始发送时间/已有可信接受值；
// 不重复增加未读（不触碰 conversation）；行数不变；重复调用幂等。
// 真库执行：sqflite_common_ffi + fixture v35 schema（非 mock）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _uk3 = 'synthetic-backfill-001';
const _msgId = 910000000001;
const _createdAt = 1750000000000;

Map<String, Object?> _row() => {
  'id': _msgId,
  'msg_type': 'text',
  'from_id': 990001,
  'to_id': 990002,
  'conversation_uk3': _uk3,
  'payload': '{"ciphertext":"fake","attachment":"att://x"}',
  'e2ee': '{"v":3}',
  'created_at': _createdAt,
  'topic_id': 0,
  'status': 1,
  'is_author': 0,
  'type': 'C2C',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late MessageRepo repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openFixtureDatabaseAtVersion(version: 35);
    SqliteService.setDbForTest(db);
    repo = MessageRepo(tableName: MessageRepo.c2cTable);
    await db.insert('msg_c2c', _row());
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  Future<Map<String, Object?>> fetchRow() async =>
      (await db.rawQuery('SELECT * FROM msg_c2c WHERE id = ?', [_msgId])).first;

  test('缺失双列：补齐 conv_seq 与 accepted_at，其余列逐字段不变', () async {
    final before = await fetchRow();

    final r = await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 42,
      acceptedAt: _createdAt + 7,
    );

    expect(r.rowExists, isTrue);
    expect(r.convSeqApplied, isTrue);
    expect(r.acceptedAtApplied, isTrue);

    final after = await fetchRow();
    expect(after['conv_seq'], 42);
    expect(after['accepted_at'], _createdAt + 7);
    // 其余列一律不动（逐字段对比，conv_seq/accepted_at 除外）
    for (final e in before.entries) {
      if (e.key == 'conv_seq' || e.key == 'accepted_at') continue;
      expect(after[e.key], e.value, reason: '列 ${e.key} 不得被补齐触碰');
    }
  });

  test('已有 conv_seq 不覆盖；缺失 accepted_at 仍补齐', () async {
    await db.rawUpdate('UPDATE msg_c2c SET conv_seq = 7 WHERE id = ?', [
      _msgId,
    ]);

    final r = await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 999, // 恶意/错乱值：必须被拒
      acceptedAt: _createdAt + 9,
    );

    expect(r.convSeqApplied, isFalse);
    expect(r.acceptedAtApplied, isTrue);
    final after = await fetchRow();
    expect(after['conv_seq'], 7, reason: '已有可信 seq 不得覆盖');
    expect(after['accepted_at'], _createdAt + 9);
  });

  test('已有 accepted_at 不覆盖（首次接受事实不可变）', () async {
    await db.rawUpdate('UPDATE msg_c2c SET accepted_at = 111 WHERE id = ?', [
      _msgId,
    ]);

    final r = await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      acceptedAt: 222,
    );

    expect(r.acceptedAtApplied, isFalse);
    expect((await fetchRow())['accepted_at'], 111);
  });

  test('重复调用幂等：第二次零写入，行数不变', () async {
    await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 42,
      acceptedAt: _createdAt + 7,
    );
    final count1 = await db.rawQuery('SELECT count(*) AS c FROM msg_c2c');

    final r2 = await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 42,
      acceptedAt: _createdAt + 7,
    );

    expect(r2.convSeqApplied, isFalse);
    expect(r2.acceptedAtApplied, isFalse);
    final count2 = await db.rawQuery('SELECT count(*) AS c FROM msg_c2c');
    expect(count2.first['c'], count1.first['c']);
    final after = await fetchRow();
    expect(after['conv_seq'], 42);
    expect(after['accepted_at'], _createdAt + 7);
  });

  test('行不存在：rowExists=false，不插行', () async {
    final r = await repo.backfillServerOrderFacts(
      msgId: '910000999999',
      convSeq: 1,
      acceptedAt: 1,
    );
    expect(r.rowExists, isFalse);
    final count = await db.rawQuery('SELECT count(*) AS c FROM msg_c2c');
    expect(count.first['c'], 1, reason: '行数不变');
  });

  test('只传单字段：另一列不动', () async {
    final r = await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 11,
    );
    expect(r.convSeqApplied, isTrue);
    expect(r.acceptedAtApplied, isFalse);
    final after = await fetchRow();
    expect(after['conv_seq'], 11);
    expect(after['accepted_at'], isNull);
  });

  test('双参数皆空：ArgumentError（拒绝空操作误用）', () async {
    expect(
      () => repo.backfillServerOrderFacts(msgId: _msgId.toString()),
      throwsArgumentError,
    );
  });

  test('不触碰 conversation（不重复增加未读）', () async {
    await db.insert('conversation', {
      'type': 'C2C',
      'user_id': 990001,
      'peer_id': 990002,
      'is_show': 1,
      'last_time': _createdAt,
      'unread_num': 3,
    });
    final convBefore = await db.rawQuery('SELECT * FROM conversation');

    await repo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 42,
      acceptedAt: _createdAt + 7,
    );

    final convAfter = await db.rawQuery('SELECT * FROM conversation');
    expect(convAfter, convBefore, reason: '补齐不得触碰会话表（含未读）');
  });

  test('其他消息表同样可用（msg_s2c 形态一致性抽查）', () async {
    final s2cRepo = MessageRepo(tableName: MessageRepo.s2cTable);
    await db.insert('msg_s2c', _row());
    final r = await s2cRepo.backfillServerOrderFacts(
      msgId: _msgId.toString(),
      convSeq: 5,
      acceptedAt: _createdAt + 5,
    );
    expect(r.convSeqApplied, isTrue);
    final row = (await db.rawQuery(
      'SELECT conv_seq FROM msg_s2c WHERE id = ?',
      [_msgId],
    )).first;
    expect(row['conv_seq'], 5);
  });
}
