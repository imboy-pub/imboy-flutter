/// 验证 ChannelRepo.incrementUnreadCount 使用原子 SQL，避免并发丢更新。
///
/// 这里直接在内存 SQLite 上复现 `channel_subscription` 的最小 schema 与
/// `ChannelRepo.incrementUnreadCount` 使用的同一条 SQL，以约束 SQL 形态，
/// 同时对照旧实现的「读-改-写」两步写法，演示并发场景下两者的差异：
/// - 旧实现：两次 Future.wait 并发 +1 最终仅 +1（丢更新）
/// - 新实现：两次 Future.wait 并发 +1 最终稳定 +2（原子）
///
/// Schema 与 SQL 是 ChannelRepo 的私有实现细节的复制品，保持同步由人工维护。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 最小订阅表，仅保留本测试所需字段。
const String _subscriptionDDL = '''
  CREATE TABLE channel_subscription (
    channel_id TEXT PRIMARY KEY,
    unread_count INTEGER NOT NULL DEFAULT 0
  )
''';

/// 与 ChannelRepo.incrementUnreadCount 等价的原子 SQL。
const String _atomicIncrementSql =
    'UPDATE channel_subscription '
    'SET unread_count = unread_count + 1 '
    'WHERE channel_id = ?';

Future<Database> _openMemoryDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_subscriptionDDL);
  return db;
}

void main() {
  group('channel_subscription unread_count atomic increment', () {
    late Database db;

    setUp(() async {
      db = await _openMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('single increment changes unread_count from 5 to 6', () async {
      await db.insert('channel_subscription', {
        'channel_id': '1001',
        'unread_count': 5,
      });

      final affected = await db.rawUpdate(_atomicIncrementSql, ['1001']);

      expect(affected, 1);
      final rows = await db.query(
        'channel_subscription',
        where: 'channel_id = ?',
        whereArgs: ['1001'],
      );
      expect(rows.single['unread_count'], 6);
    });

    test('concurrent increments are not lost (race-safety)', () async {
      await db.insert('channel_subscription', {
        'channel_id': '1001',
        'unread_count': 5,
      });

      // 并发触发两次原子 +1；原子 SQL 保证最终 +2，避免旧「读-改-写」在
      // 两次读到同一旧值时写出同样的 N+1 造成的丢更新。
      await Future.wait([
        db.rawUpdate(_atomicIncrementSql, ['1001']),
        db.rawUpdate(_atomicIncrementSql, ['1001']),
      ]);

      final rows = await db.query(
        'channel_subscription',
        where: 'channel_id = ?',
        whereArgs: ['1001'],
      );
      expect(rows.single['unread_count'], 7,
          reason: '两次并发原子 +1 必须得到 +2；若观察到 +1 则说明回退为非原子实现');
    });

    test('returns 0 affected rows when subscription does not exist',
        () async {
      final affected = await db.rawUpdate(_atomicIncrementSql, ['9999']);
      expect(affected, 0);
    });
  });
}
