import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('subscription round trips exact channel and message IDs', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.execute('''CREATE TABLE channel_subscription (
      channel_id INTEGER PRIMARY KEY, subscribed_at INTEGER NOT NULL,
      last_read_at INTEGER, last_message_id INTEGER, unread_count INTEGER,
      notifications_enabled INTEGER, is_pinned INTEGER, is_muted INTEGER)''');
    const id = '9007199254740993';
    const messageId = '9007199254740995';
    await db.insert('channel_subscription', {
      'channel_id': id,
      'subscribed_at': 1,
      'unread_count': 2,
    });
    final repo = ChannelRepo();
    expect(await repo.updateLastMessageId(id, messageId), 1);
    final subscription = await repo.getSubscription(id);
    expect(subscription?.channelId, id);
    expect(subscription?.lastMessageId, messageId);
    expect(await repo.markAsRead(id, 'not-a-number'), 1);
    expect((await repo.getSubscription(id))?.lastMessageId, isNull);
  });
}
