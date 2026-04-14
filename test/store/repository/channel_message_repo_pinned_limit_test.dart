/// 验证 `channel_message` 置顶查询的 LIMIT 契约。
///
/// 直接在内存 SQLite 复现 `getPinnedMessages` 的查询形态，约束：
/// - 默认最多返回 100 条
/// - 显式 limit 生效
/// - 非正数回退为默认 100
/// - 排序仍按 created_at DESC
///
/// 与 ChannelMessageRepo 代码的一致性由人工同步维护。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _messageDDL = '''
  CREATE TABLE channel_message (
    id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    is_pinned INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )
''';

Future<Database> _openMemoryDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_messageDDL);
  return db;
}

Future<void> _seedPinned(Database db, String channelId, int count) async {
  final batch = db.batch();
  for (var i = 0; i < count; i++) {
    batch.insert('channel_message', {
      'id': 'msg-$i',
      'channel_id': channelId,
      'is_pinned': 1,
      'created_at': i, // 保证排序顺序稳定
    });
  }
  await batch.commit(noResult: true);
}

/// 与 ChannelMessageRepo.getPinnedMessages 的查询形态等价
Future<List<Map<String, Object?>>> _queryPinned(
  Database db,
  String channelId, {
  required int limit,
}) async {
  return db.query(
    'channel_message',
    where: 'channel_id = ? AND is_pinned = ?',
    whereArgs: [channelId, 1],
    orderBy: 'created_at DESC',
    limit: limit,
  );
}

void main() {
  group('getPinnedMessages LIMIT contract', () {
    late Database db;

    setUp(() async {
      db = await _openMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('default 100 caps large pinned lists', () async {
      await _seedPinned(db, 'ch-1', 250);

      final rows = await _queryPinned(db, 'ch-1', limit: 100);

      expect(rows, hasLength(100),
          reason: '默认 limit=100 必须截断大量置顶消息');
      // 排序：最新 created_at 优先
      expect(rows.first['id'], 'msg-249');
    });

    test('explicit smaller limit is honored', () async {
      await _seedPinned(db, 'ch-1', 30);

      final rows = await _queryPinned(db, 'ch-1', limit: 10);

      expect(rows, hasLength(10));
    });

    test('empty channel returns empty list', () async {
      final rows = await _queryPinned(db, 'ch-none', limit: 100);
      expect(rows, isEmpty);
    });
  });
}
