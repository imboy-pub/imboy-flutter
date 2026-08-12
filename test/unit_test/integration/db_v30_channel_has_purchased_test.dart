/// Schema migration v29 → v30：channel 新增 `has_purchased` 购买权益列。
///
/// 付费频道购买态必须能写入本地缓存并在重启后恢复；否则已成功付款的
/// 用户会因 SQLite 写入失败或状态丢失重新看到 paywall。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _v29ChannelDdl = '''
  CREATE TABLE channel (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    avatar TEXT,
    type INTEGER DEFAULT 0,
    custom_id TEXT UNIQUE,
    creator_id INTEGER NOT NULL,
    subscriber_count INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 0,
    tags TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    user_role INTEGER DEFAULT 0,
    is_subscribed INTEGER DEFAULT 0
  )
''';

const String _v30Upgrade =
    'ALTER TABLE channel ADD COLUMN has_purchased INTEGER DEFAULT 0';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('v29 → v30 channel.has_purchased migration', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(_v29ChannelDdl);
      await db.insert('channel', {
        'id': 1,
        'name': '旧付费频道',
        'creator_id': 2,
        'type': 2,
        'created_at': 1,
        'updated_at': 1,
      });
    });

    tearDown(() async => db.close());

    test('迁移后旧行默认为未购买且购买态可写回', () async {
      await db.execute(_v30Upgrade);

      final columns = await db.rawQuery('PRAGMA table_info(channel)');
      expect(columns.map((row) => row['name']), contains('has_purchased'));

      final before = await db.query('channel', where: 'id = 1');
      expect(before.single['has_purchased'], 0);

      await db.update(
        'channel',
        {'has_purchased': 1},
        where: 'id = ?',
        whereArgs: [1],
      );
      final after = await db.query('channel', where: 'id = 1');
      expect(after.single['has_purchased'], 1);
    });
  });
}
