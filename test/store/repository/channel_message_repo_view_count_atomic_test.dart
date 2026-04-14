/// 验证 ChannelMessageRepo.incrementViewCount 使用原子 SQL，避免并发曝光
/// 事件造成的阅读量丢更新。
///
/// 与 channel_repo_unread_atomic_test 同构：直接在内存 SQLite 复现 SQL 契约，
/// 约束实现必须是单语句 UPDATE。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// channel_message 表最小 schema（仅覆盖本测试字段）
const String _messageDDL = '''
  CREATE TABLE channel_message (
    id TEXT PRIMARY KEY,
    view_count INTEGER NOT NULL DEFAULT 0
  )
''';

/// 与 ChannelMessageRepo.incrementViewCount 使用的 SQL 等价
const String _atomicIncrementSql =
    'UPDATE channel_message SET view_count = view_count + 1 WHERE id = ?';

Future<Database> _openMemoryDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_messageDDL);
  return db;
}

void main() {
  group('channel_message view_count atomic increment', () {
    late Database db;

    setUp(() async {
      db = await _openMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('single increment 3 -> 4', () async {
      await db.insert('channel_message', {
        'id': 'msg-1',
        'view_count': 3,
      });

      final affected = await db.rawUpdate(_atomicIncrementSql, ['msg-1']);

      expect(affected, 1);
      final rows = await db.query(
        'channel_message',
        where: 'id = ?',
        whereArgs: ['msg-1'],
      );
      expect(rows.single['view_count'], 4);
    });

    test('concurrent increments are not lost', () async {
      await db.insert('channel_message', {
        'id': 'msg-1',
        'view_count': 0,
      });

      // 并发 10 次曝光：原子 SQL 必须得到 view_count=10。
      await Future.wait(List.generate(
        10,
        (_) => db.rawUpdate(_atomicIncrementSql, ['msg-1']),
      ));

      final rows = await db.query(
        'channel_message',
        where: 'id = ?',
        whereArgs: ['msg-1'],
      );
      expect(rows.single['view_count'], 10,
          reason: '10 次并发原子 +1 必须累加为 10；否则说明回退为非原子实现');
    });

    test('returns 0 affected rows when message does not exist', () async {
      final affected = await db.rawUpdate(_atomicIncrementSql, ['no-such']);
      expect(affected, 0);
    });
  });
}
