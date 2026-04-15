/// 验证 channel_subscription.last_message_id 写入类型安全：
/// - 数字字符串 → INTEGER 存储
/// - 非数字字符串 → NULL（避免污染整数列读回解析）
///
/// 与 ChannelRepo.updateLastMessageId / markAsRead 的 SQL 形态等价。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _ddl = '''
  CREATE TABLE channel_subscription (
    channel_id TEXT PRIMARY KEY,
    unread_count INTEGER NOT NULL DEFAULT 0,
    last_read_at INTEGER,
    last_message_id INTEGER
  )
''';

Future<Database> _open() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_ddl);
  await db.insert('channel_subscription', {
    'channel_id': '1001',
    'unread_count': 3,
  });
  return db;
}

Future<void> _updateLastMessageId(
  Database db,
  String channelId,
  String messageId,
) async {
  await db.update(
    'channel_subscription',
    {'last_message_id': parseModelNullableInt(messageId)},
    where: 'channel_id = ?',
    whereArgs: [channelId],
  );
}

void main() {
  group('updateLastMessageId type safety', () {
    late Database db;

    setUp(() async {
      db = await _open();
    });

    tearDown(() async {
      await db.close();
    });

    test('numeric string is stored as int', () async {
      await _updateLastMessageId(db, '1001', '1838294017982464');

      final row = (await db.query(
        'channel_subscription',
        where: 'channel_id = ?',
        whereArgs: ['1001'],
      ))
          .single;
      expect(row['last_message_id'], 1838294017982464,
          reason: '数字字符串必须归一化为 int 存储');
      expect(row['last_message_id'], isA<int>());
    });

    test('non-numeric string becomes NULL', () async {
      await _updateLastMessageId(db, '1001', 'not-a-number');

      final row = (await db.query(
        'channel_subscription',
        where: 'channel_id = ?',
        whereArgs: ['1001'],
      ))
          .single;
      expect(row['last_message_id'], isNull,
          reason: '非法字符串不得写入整数列，落为 NULL');
    });

    test('empty string becomes NULL', () async {
      await _updateLastMessageId(db, '1001', '');

      final row = (await db.query(
        'channel_subscription',
        where: 'channel_id = ?',
        whereArgs: ['1001'],
      ))
          .single;
      expect(row['last_message_id'], isNull);
    });
  });
}
