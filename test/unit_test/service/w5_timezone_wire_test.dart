// W5 接线验证（R07-phase2 wire + R01-FL + R02-FL）。
//
// 覆盖：
// - R07-7（真库 ffi）：无 seq 消息依次收 archive → 重复 archive → 晚 ACK：
//   行数不变、权威字段补齐且稳定、created_at/正文/密文不受损、重启后
//   按 ConversationOrder 排序正确。
// - R07-2/R07-3（真库 ffi）：同毫秒两行按 conv_seq 稳定排序（分页游标依据）。
// - R02-1/R02-5（真库 ffi + 决策纯函数）：1 缺失→2 已同步→1 补齐后集合完整；
//   过冲游标（seq > safe_head）决策为不回退 + 有界补扫。
// - R01（纯函数）：blocked=true 等待不推进；gaps 触发 backfill 区间；
//   safe_head 钳制；c2g cursor v1/v2 版本解析；parseServerOrderFacts 时间归一。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_order.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/offline_message_writer.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _uk3 = 'synthetic-w5-001';
const _createdAt = 1750000000000;

Map<String, Object?> _row({
  required String msgId,
  int? convSeq,
  int? acceptedAt,
  int? createdAt,
}) => {
  'id': msgId,
  'msg_type': 'text',
  'from_id': 990001,
  'to_id': 990002,
  'conversation_uk3': _uk3,
  'payload': '{"ciphertext":"c-$msgId","attachment":"att://$msgId"}',
  'e2ee': '{"v":3,"session_id":"s-$msgId"}',
  'created_at': createdAt ?? _createdAt,
  'conv_seq': ?convSeq,
  'accepted_at': ?acceptedAt,
  'topic_id': 0,
  'status': 1,
  'is_author': 0,
  'type': 'C2C',
};

Map<String, dynamic> _archiveShape({
  required String msgId,
  required int convSeq,
  required int acceptedAt,
}) => {
  'msg_id': msgId,
  'type': 'C2C',
  'from': '990001',
  'to': '990002',
  'msg_type': 'text',
  'created_at': _createdAt,
  'conv_seq': convSeq,
  'accepted_at': acceptedAt,
  'payload': {'ciphertext': 'c-$msgId'},
  'e2ee': {'v': 3, 'session_id': 's-$msgId'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openFixtureDatabaseAtVersion(version: 35);
    SqliteService.setDbForTest(db);
    // _syncOfflineConversationsAndNotify 依赖注入的应用级容器（全量插入路径）
    MessageRepo.setProviderContainer(ProviderContainer());
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  Future<int> countRows() async {
    final r = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM msg_c2c WHERE conversation_uk3 = ?",
      [_uk3],
    );
    return (r.first['n'] as num).toInt();
  }

  Future<Map<String, Object?>> rowById(String msgId) async {
    final r = await db.rawQuery('SELECT * FROM msg_c2c WHERE id = ?', [msgId]);
    return r.isEmpty ? <String, Object?>{} : r.first;
  }

  test('R07-7 archive→重复archive→晚ACK：行数不变、权威字段稳定、原值不覆盖', () async {
    // 本地已有无 seq 消息（晚历史前的旧落库）
    const mid = '910000000011';
    await db.insert('msg_c2c', _row(msgId: mid));
    expect(await countRows(), 1);
    final before = await rowById(mid);

    // 1) archive 带权威字段到达（经 offline writer 同一列映射）
    final repo = MessageRepo(tableName: MessageRepo.c2cTable);
    await repo.batchInsertOfflineMessages([
      _archiveShape(msgId: mid, convSeq: 42, acceptedAt: _createdAt + 7),
    ], trustedArchive: true);
    expect(await countRows(), 1, reason: 'archive 重复行不得新增');
    var after = await rowById(mid);
    expect(after['conv_seq'], 42, reason: '缺失 conv_seq 应被补齐');
    expect(after['accepted_at'], _createdAt + 7, reason: '缺失 accepted_at 应被补齐');
    expect(after['created_at'], before['created_at'], reason: 'created_at 不覆盖');
    expect(after['payload'], contains('c-$mid'), reason: '正文不覆盖');
    expect(after['e2ee'], contains('s-$mid'), reason: 'E2EE 元数据不覆盖');

    // 2) 重复 archive（不同 conv_seq 的错乱值）：已有可信值不得被改
    await repo.batchInsertOfflineMessages([
      _archiveShape(msgId: mid, convSeq: 999, acceptedAt: _createdAt + 99),
    ], trustedArchive: true);
    after = await rowById(mid);
    expect(after['conv_seq'], 42, reason: '重复 archive 不得改写已有 conv_seq');
    expect(after['accepted_at'], _createdAt + 7);
    expect(await countRows(), 1);

    // 3) 晚 ACK（SERVER_ACK 标准化为 C2C）只补缺失，不动 created_at
    final ack = _archiveShape(
      msgId: mid,
      convSeq: 42,
      acceptedAt: _createdAt + 7,
    );
    ack['type'] = 'C2C_SERVER_ACK';
    ack['created_at'] = 1999999999999; // 收到时刻，必须不覆盖
    await repo.batchInsertOfflineMessages([ack], trustedArchive: true);
    after = await rowById(mid);
    expect(after['conv_seq'], 42);
    expect(after['created_at'], _createdAt, reason: 'ACK 不得用收到时刻覆盖原始创建时间');
    expect(await countRows(), 1);
    expect(after['status'], 1, reason: '状态不受损');
  });

  test('R07-7 重启后顺序：无 seq 排前、有 seq 段按 conv_seq；同毫秒 R07-2 稳定', () async {
    await db.insert('msg_c2c', _row(msgId: '910000000021')); // 无 seq 历史段
    final repo = MessageRepo(tableName: MessageRepo.c2cTable);
    await repo.batchInsertOfflineMessages([
      // 同 created_at 毫秒、不同 conv_seq（R07-2 同毫秒不乱序）
      _archiveShape(msgId: '910000000023', convSeq: 12, acceptedAt: _createdAt),
      _archiveShape(msgId: '910000000022', convSeq: 11, acceptedAt: _createdAt),
    ], trustedArchive: true);

    // 注：writer 按 from/to 推导 conversation_uk3（C2C__990001），
    // 与手插行的 synthetic uk3 不同会话；排序断言按 msg_id 集合取行。
    final rows = await db.rawQuery(
      'SELECT id, conv_seq FROM msg_c2c WHERE id IN (?, ?, ?) '
      'ORDER BY ${ConversationOrder.orderByAsc}',
      ['910000000021', '910000000022', '910000000023'],
    );
    expect(rows.map((r) => r['id'].toString()).toList(), [
      '910000000021',
      '910000000022',
      '910000000023',
    ], reason: '无 seq 历史段排前，有 seq 段按 conv_seq 升序（同毫秒不乱序）');
    expect(rows.map((r) => r['conv_seq']).toList(), [
      null,
      11,
      12,
    ], reason: '同毫秒两行按 conv_seq 稳定排序（R07-2 / R07-3 游标依据）');
  });

  test('R02-1/R02-5 集合完整：2 已同步→1 缺失补齐→集合 [1,2] 完整且有序', () async {
    const gap1 = '910000000031', seq2 = '910000000032';
    // 已同步：只有 seq=2
    await db.insert(
      'msg_c2c',
      _row(msgId: seq2, convSeq: 2, acceptedAt: _createdAt + 2),
    );
    // 补齐缺失 seq=1（backfill 语义：带权威字段落库）
    await db.insert(
      'msg_c2c',
      _row(msgId: gap1, convSeq: 1, acceptedAt: _createdAt + 1),
    );
    final rows = await db.rawQuery(
      'SELECT id, conv_seq FROM msg_c2c WHERE conversation_uk3 = ? '
      'ORDER BY ${ConversationOrder.orderByAsc}',
      [_uk3],
    );
    expect(rows.length, 2, reason: '补齐后集合完整');
    expect(rows.map((r) => r['conv_seq']).toList(), [1, 2]);
  });

  test('R01/R02 决策：blocked 等待；gaps 触发补扫；safe_head 钳制；过冲不回退', () {
    // blocked=true：等待，游标不动，不产生补扫
    final p1 = ChatArchiveService.planHistorySync(
      currentSeq: 10,
      nextSeq: 20,
      safeHead: 12,
      blocked: true,
      gaps: const [],
    );
    expect(p1.blocked, isTrue);
    expect(p1.advanceTo, 10);
    expect(p1.backfillRanges, isEmpty, reason: 'blocked 时不自行推断 gap');

    // gaps + safe_head：推进钳制在 safe_head 内（R02-1），gap 段触发补扫
    final p2 = ChatArchiveService.planHistorySync(
      currentSeq: 10,
      nextSeq: 30,
      safeHead: 25,
      blocked: false,
      gaps: const [(fromSeq: 15, toSeq: 17, reason: 'terminal_failure')],
    );
    expect(p2.advanceTo, 25, reason: '持久化游标不得越过 safe_head');
    expect(p2.backfillRanges, [
      (fromSeq: 14, toSeq: 17),
    ], reason: 'gaps → backfill(afterSeq=from-1, target=to)');

    // R02-5 过冲：存量游标 40 > 新 safe_head 20 → 不回退游标 + 从 0 有界补扫
    final p3 = ChatArchiveService.planHistorySync(
      currentSeq: 40,
      nextSeq: 40,
      safeHead: 20,
      blocked: false,
      gaps: const [],
    );
    expect(p3.advanceTo, 40, reason: '过冲不回退游标');
    expect(p3.backfillRanges, [
      (fromSeq: 0, toSeq: 20),
    ], reason: '过冲恢复：从 0 补扫至 safe_head');
  });

  test('R01 gaps 解析：字段名 from_seq/to_seq/reason（BE 合同）与容错', () {
    final gaps = ChatArchiveService.parseGaps([
      {'from_seq': 3, 'to_seq': 5, 'reason': 'terminal_failure'},
      {'from_seq': 1, 'to_seq': 1, 'reason': 'authorization'},
      'garbage',
      {'from_seq': null, 'to_seq': 2, 'reason': 'x'},
    ]);
    expect(gaps.length, 2);
    expect(gaps.first.reason, 'terminal_failure');
    expect(ChatArchiveService.parseGaps(null), isEmpty);
    expect(ChatArchiveService.parseGaps('not-a-list'), isEmpty);
  });

  test('R01 c2g cursor：v2 marks 与 v1 token 版本解析（迁移兼容透传）', () {
    String enc(Object o) => base64.encode(utf8.encode(jsonEncode(o)));
    final v2 = enc({
      'v': 2,
      'marks': [
        {'g': 7001, 's': 42},
      ],
    });
    final v1 = enc({'v': 1, 'at': '2026-10-01T00:00:00Z', 'id': 'abc'});
    expect(MessageOfflineService.c2gCursorVersion(v2), 2);
    expect(
      MessageOfflineService.c2gCursorVersion(v1),
      1,
      reason: '读到 v1 token 可解析（迁移不丢失）',
    );
    expect(MessageOfflineService.c2gCursorVersion(''), isNull);
    expect(MessageOfflineService.c2gCursorVersion('!!!not-base64'), isNull);
  });

  test('R07 parseServerOrderFacts：毫秒/RFC3339 归一、非正 seq 拒绝', () {
    final f1 = OfflineMessageWriter.parseServerOrderFacts({
      'conv_seq': 42,
      'accepted_at': 1750000000123,
    });
    expect(f1.convSeq, 42);
    expect(f1.acceptedAt, 1750000000123);

    final f2 = OfflineMessageWriter.parseServerOrderFacts({
      'conv_seq': '43',
      'accepted_at': '2026-10-01T00:00:00.123Z',
    });
    expect(f2.convSeq, 43);
    expect(f2.acceptedAt, isNotNull, reason: 'RFC3339 归一为毫秒');

    final f3 = OfflineMessageWriter.parseServerOrderFacts({
      'conv_seq': 0,
      'accepted_at': 'bad-time',
    });
    expect(f3.convSeq, isNull, reason: '非正 seq 不落列（不伪造序号）');
    expect(f3.acceptedAt, isNull);
  });
}
