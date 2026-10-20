import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE channel_message (
      id INTEGER PRIMARY KEY, channel_id INTEGER NOT NULL,
      content TEXT NOT NULL, msg_type TEXT NOT NULL,
      created_at INTEGER NOT NULL)''');
    SqliteService.setDbForTest(db);
  });
  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });
  Future<void> add(int id, int channel, int time, String content) => db
      .insert('channel_message', {
        'id': id,
        'channel_id': channel,
        'created_at': time,
        'content': content,
        'msg_type': 'channel_text',
      })
      .then((_) {});

  test('latest cache uses content time, deterministic ties and only requested channels', () async {
    await add(1, 10, 3000, 'newer');
    await add(2, 10, 1000, 'late-arriving old content');
    await add(3, 20, 3000, 'tie-old');
    await add(4, 20, 3000, 'tie-new');
    await add(5, 30, 9000, 'another channel');
    final previews = await ChannelMessageRepo().getLastMessages([
      '10',
      '20',
      '10',
    ]);
    expect(previews.keys.toSet(), {10, 20});
    expect(previews[10]!.content, 'newer');
    expect(previews[20]!.content, 'tie-new');
    expect(await ChannelMessageRepo().getLastMessages([]), isEmpty);
    expect(await ChannelMessageRepo().getLastMessages(['404']), isEmpty);
  });

  test('large channel sets are chunked without losing previews', () async {
    await db.transaction((txn) async {
      for (var i = 1; i <= 420; i++) {
        await txn.insert('channel_message', {
          'id': i,
          'channel_id': i,
          'created_at': i,
          'content': 'cached-$i',
          'msg_type': 'channel_text',
        });
      }
    });
    final previews = await ChannelMessageRepo().getLastMessages([
      for (var i = 1; i <= 420; i++) '$i',
    ]);
    expect(previews, hasLength(420));
    expect(previews[420]!.content, 'cached-420');
  });
}
