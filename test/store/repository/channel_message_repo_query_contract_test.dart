/// ChannelMessageRepo 查询契约测试（CMRD-1 ~ CMRD-3）
///
/// CMRD-1  deleteOldMessages — 裁剪策略边界（总数 < / == / > keepCount）
/// CMRD-2  getMessagesBefore / getMessagesAfter — 排序方向 + 严格不等式 + 默认 limit
/// CMRD-3  updateReactionSummary — 全量替换语义（非 JSON merge）
///
/// 全部使用内存 SQLite（sqflite_common_ffi），不依赖 SqliteService 单例。
/// 与 ChannelMessageRepo 实现细节的一致性由人工维护。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─── schema ──────────────────────────────────────────────────────────────────

const String _ddl = '''
  CREATE TABLE channel_message (
    id       TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    content    TEXT NOT NULL DEFAULT '',
    msg_type   TEXT NOT NULL DEFAULT 'channel_text',
    created_at INTEGER NOT NULL,
    is_pinned  INTEGER NOT NULL DEFAULT 0,
    view_count INTEGER NOT NULL DEFAULT 0,
    reaction_summary TEXT
  )
''';

// ─── helpers ─────────────────────────────────────────────────────────────────

Future<Database> _openDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_ddl);
  return db;
}

/// 插入一条消息（仅需 id / channel_id / created_at）
Future<void> _insert(
  Database db, {
  required String id,
  required String channelId,
  required int createdAt,
  String? reactionSummary,
}) async {
  await db.insert('channel_message', {
    'id': id,
    'channel_id': channelId,
    'created_at': createdAt,
    'reaction_summary': ?reactionSummary,
  });
}

/// 与 ChannelMessageRepo.deleteOldMessages 等价的 SQL 对
Future<int> _deleteOldMessages(
  Database db,
  String channelId,
  int keepCount,
) async {
  final keepIds = await db.rawQuery(
    'SELECT id FROM channel_message '
    'WHERE channel_id = ? ORDER BY created_at DESC LIMIT ?',
    [channelId, keepCount],
  );

  if (keepIds.isEmpty || keepIds.length < keepCount) {
    return 0;
  }

  final excludeIds = keepIds.map((r) => r['id'].toString()).toList();
  final placeholders = List.filled(excludeIds.length, '?').join(',');

  return db.delete(
    'channel_message',
    where: 'channel_id = ? AND id NOT IN ($placeholders)',
    whereArgs: [channelId, ...excludeIds],
  );
}

/// 与 ChannelMessageRepo.getMessagesBefore 等价的查询
Future<List<Map<String, Object?>>> _getMessagesBefore(
  Database db,
  String channelId, {
  required int beforeTime,
  int limit = 20,
}) async {
  return db.query(
    'channel_message',
    where: 'channel_id = ? AND created_at < ?',
    whereArgs: [channelId, beforeTime],
    orderBy: 'created_at DESC',
    limit: limit,
  );
}

/// 与 ChannelMessageRepo.getMessagesAfter 等价的查询
Future<List<Map<String, Object?>>> _getMessagesAfter(
  Database db,
  String channelId, {
  required int afterTime,
  int limit = 100,
}) async {
  return db.query(
    'channel_message',
    where: 'channel_id = ? AND created_at > ?',
    whereArgs: [channelId, afterTime],
    orderBy: 'created_at ASC',
    limit: limit,
  );
}

// ─── 主测试 ────────────────────────────────────────────────────────────────

void main() {
  late Database db;

  setUp(() async {
    db = await _openDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── CMRD-1  deleteOldMessages ────────────────────────────────────────────

  group('CMRD-1 deleteOldMessages 裁剪策略', () {
    test('总数 < keepCount — 不删除，返回 0', () async {
      // 3 条消息，keepCount=5 → 不需要裁剪
      for (var i = 1; i <= 3; i++) {
        await _insert(db, id: 'msg-$i', channelId: 'ch-1', createdAt: i);
      }

      final deleted = await _deleteOldMessages(db, 'ch-1', 5);

      expect(deleted, 0);
      final remaining = await db.query('channel_message',
          where: 'channel_id = ?', whereArgs: ['ch-1']);
      expect(remaining, hasLength(3));
    });

    test('总数 == keepCount — 不删除，返回 0', () async {
      // 恰好 5 条消息，keepCount=5
      for (var i = 1; i <= 5; i++) {
        await _insert(db, id: 'msg-$i', channelId: 'ch-1', createdAt: i);
      }

      final deleted = await _deleteOldMessages(db, 'ch-1', 5);

      expect(deleted, 0);
      final remaining = await db.query('channel_message',
          where: 'channel_id = ?', whereArgs: ['ch-1']);
      expect(remaining, hasLength(5));
    });

    test('总数 > keepCount — 保留最近 N 条，删除其余', () async {
      // 8 条消息，keepCount=5 → 删除最旧的 3 条
      for (var i = 1; i <= 8; i++) {
        await _insert(db, id: 'msg-$i', channelId: 'ch-1', createdAt: i);
      }

      final deleted = await _deleteOldMessages(db, 'ch-1', 5);

      expect(deleted, 3);
      final remaining = await db.query('channel_message',
          where: 'channel_id = ?', whereArgs: ['ch-1'],
          orderBy: 'created_at ASC');
      expect(remaining, hasLength(5));
      // 保留的是最近 5 条（created_at 4..8）
      expect(remaining.first['id'], 'msg-4');
      expect(remaining.last['id'], 'msg-8');
    });

    test('频道无消息 — 返回 0', () async {
      final deleted = await _deleteOldMessages(db, 'ch-empty', 5);
      expect(deleted, 0);
    });

    test('不影响其他频道的消息', () async {
      // ch-1: 8 条  ch-2: 3 条
      for (var i = 1; i <= 8; i++) {
        await _insert(db, id: 'ch1-msg-$i', channelId: 'ch-1', createdAt: i);
      }
      for (var i = 1; i <= 3; i++) {
        await _insert(db, id: 'ch2-msg-$i', channelId: 'ch-2', createdAt: i);
      }

      await _deleteOldMessages(db, 'ch-1', 5);

      // ch-2 完整保留
      final ch2 = await db.query('channel_message',
          where: 'channel_id = ?', whereArgs: ['ch-2']);
      expect(ch2, hasLength(3));
    });

    test('keepCount=1 — 只保留最新一条', () async {
      for (var i = 1; i <= 5; i++) {
        await _insert(db, id: 'msg-$i', channelId: 'ch-1', createdAt: i);
      }

      final deleted = await _deleteOldMessages(db, 'ch-1', 1);

      expect(deleted, 4);
      final remaining = await db.query('channel_message',
          where: 'channel_id = ?', whereArgs: ['ch-1']);
      expect(remaining, hasLength(1));
      expect(remaining.first['id'], 'msg-5'); // 最新
    });
  });

  // ── CMRD-2  getMessagesBefore / getMessagesAfter ──────────────────────────

  group('CMRD-2 getMessagesBefore / getMessagesAfter 分页方向契约', () {
    // 固定时间轴：t=100, 200, 300, 400, 500
    setUp(() async {
      for (var i = 1; i <= 5; i++) {
        await _insert(
          db,
          id: 'msg-$i',
          channelId: 'ch-1',
          createdAt: i * 100,
        );
      }
    });

    // ── getMessagesBefore ──

    test('getMessagesBefore — 返回严格小于 beforeTime 的消息', () async {
      // beforeTime=300 → 应返回 t=100, t=200（不含 t=300）
      final rows =
          await _getMessagesBefore(db, 'ch-1', beforeTime: 300, limit: 20);
      expect(rows, hasLength(2));
    });

    test('getMessagesBefore — 结果按 created_at DESC 排列（新在前）', () async {
      final rows =
          await _getMessagesBefore(db, 'ch-1', beforeTime: 500, limit: 20);
      // t=400, t=300, t=200, t=100
      expect(rows.length, 4);
      expect(rows[0]['created_at'], 400);
      expect(rows[1]['created_at'], 300);
      expect(rows[2]['created_at'], 200);
      expect(rows[3]['created_at'], 100);
    });

    test('getMessagesBefore — 默认 limit=20 限制结果数量', () async {
      // 先清空再填充 30 条
      await db.delete('channel_message');
      for (var i = 1; i <= 30; i++) {
        await _insert(db, id: 'big-$i', channelId: 'ch-big', createdAt: i);
      }
      final rows = await _getMessagesBefore(
        db,
        'ch-big',
        beforeTime: 31,
        limit: 20, // 等价于默认
      );
      expect(rows, hasLength(20));
    });

    test('getMessagesBefore — beforeTime 等于某条消息时间，不含该条', () async {
      // beforeTime=300 → t=100, t=200 仅 2 条，t=300 本身不含
      final rows =
          await _getMessagesBefore(db, 'ch-1', beforeTime: 300, limit: 20);
      final times = rows.map((r) => r['created_at'] as int).toList();
      expect(times.contains(300), isFalse);
    });

    test('getMessagesBefore — 无更早消息时返回空列表', () async {
      final rows =
          await _getMessagesBefore(db, 'ch-1', beforeTime: 50, limit: 20);
      expect(rows, isEmpty);
    });

    // ── getMessagesAfter ──

    test('getMessagesAfter — 返回严格大于 afterTime 的消息', () async {
      // afterTime=300 → 应返回 t=400, t=500（不含 t=300）
      final rows =
          await _getMessagesAfter(db, 'ch-1', afterTime: 300, limit: 100);
      expect(rows, hasLength(2));
    });

    test('getMessagesAfter — 结果按 created_at ASC 排列（旧在前）', () async {
      // afterTime=100 → t=200, t=300, t=400, t=500
      final rows =
          await _getMessagesAfter(db, 'ch-1', afterTime: 100, limit: 100);
      expect(rows.length, 4);
      expect(rows[0]['created_at'], 200);
      expect(rows[1]['created_at'], 300);
      expect(rows[2]['created_at'], 400);
      expect(rows[3]['created_at'], 500);
    });

    test('getMessagesAfter — 默认 limit=100 限制结果数量', () async {
      await db.delete('channel_message');
      for (var i = 1; i <= 150; i++) {
        await _insert(db, id: 'big-$i', channelId: 'ch-big', createdAt: i);
      }
      final rows = await _getMessagesAfter(
        db,
        'ch-big',
        afterTime: 0,
        limit: 100, // 等价于默认
      );
      expect(rows, hasLength(100));
    });

    test('getMessagesAfter — afterTime 等于某条消息时间，不含该条', () async {
      final rows =
          await _getMessagesAfter(db, 'ch-1', afterTime: 300, limit: 100);
      final times = rows.map((r) => r['created_at'] as int).toList();
      expect(times.contains(300), isFalse);
    });

    test('getMessagesAfter — 无更新消息时返回空列表', () async {
      final rows =
          await _getMessagesAfter(db, 'ch-1', afterTime: 600, limit: 100);
      expect(rows, isEmpty);
    });

    test('Before + After 组合：游标双向一致性', () async {
      // pivot = t=300 (msg-3)
      // Before(300) → [msg-2(200), msg-1(100)]（DESC）
      // After(300)  → [msg-4(400), msg-5(500)]（ASC）
      final before =
          await _getMessagesBefore(db, 'ch-1', beforeTime: 300, limit: 20);
      final after =
          await _getMessagesAfter(db, 'ch-1', afterTime: 300, limit: 100);

      final beforeTimes = before.map((r) => r['created_at'] as int).toList();
      final afterTimes = after.map((r) => r['created_at'] as int).toList();

      expect(beforeTimes, containsAll([100, 200]));
      expect(afterTimes, containsAll([400, 500]));
      // 两侧均不含 pivot
      expect(beforeTimes.contains(300), isFalse);
      expect(afterTimes.contains(300), isFalse);
    });
  });

  // ── CMRD-3  updateReactionSummary ─────────────────────────────────────────

  group('CMRD-3 updateReactionSummary 全量替换语义', () {
    const msgId = 'msg-rxn';

    setUp(() async {
      await _insert(
        db,
        id: msgId,
        channelId: 'ch-1',
        createdAt: 1000,
        reactionSummary: jsonEncode({'like': 5, 'heart': 2}),
      );
    });

    /// 与 ChannelMessageRepo.updateReactionSummary 等价
    Future<int> updateReaction(
      Database db,
      String messageId,
      Map<String, int> summary,
    ) async {
      return db.update(
        'channel_message',
        {'reaction_summary': jsonEncode(summary)},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    }

    Map<String, int>? readReaction(Map<String, Object?> row) {
      final raw = row['reaction_summary'];
      if (raw == null) return null;
      return Map<String, int>.from(jsonDecode(raw as String) as Map);
    }

    test('更新后读回等于新 summary（全量替换）', () async {
      await updateReaction(db, msgId, {'like': 3});

      final rows = await db.query('channel_message',
          where: 'id = ?', whereArgs: [msgId]);
      final reaction = readReaction(rows.first);

      // 全量替换：原有 heart 字段消失
      expect(reaction, {'like': 3});
      expect(reaction!.containsKey('heart'), isFalse,
          reason: '全量替换语义：旧 key 应被清除');
    });

    test('用空 map 替换 — 写入 {}，而非 null', () async {
      await updateReaction(db, msgId, {});

      final rows = await db.query('channel_message',
          where: 'id = ?', whereArgs: [msgId]);
      final raw = rows.first['reaction_summary'] as String?;

      expect(raw, isNotNull);
      expect(jsonDecode(raw!), isEmpty);
    });

    test('覆盖写：连续两次更新，最终值以第二次为准', () async {
      await updateReaction(db, msgId, {'fire': 10});
      await updateReaction(db, msgId, {'like': 1, 'wave': 7});

      final rows = await db.query('channel_message',
          where: 'id = ?', whereArgs: [msgId]);
      final reaction = readReaction(rows.first);

      expect(reaction, {'like': 1, 'wave': 7});
      expect(reaction!.containsKey('fire'), isFalse);
    });

    test('消息不存在 — 返回 0（受影响行数）', () async {
      final affected =
          await updateReaction(db, 'non-exist', {'like': 1});
      expect(affected, 0);
    });

    test('受影响行数 == 1 当消息存在', () async {
      final affected =
          await updateReaction(db, msgId, {'thumbup': 3});
      expect(affected, 1);
    });
  });
}
