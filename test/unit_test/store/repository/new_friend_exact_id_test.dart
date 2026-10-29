import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('adjacent friend request IDs remain separate through SQLite', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.execute('''CREATE TABLE new_friend (
      auto_id INTEGER PRIMARY KEY, uid INTEGER NOT NULL,
      from_id INTEGER NOT NULL, to_id INTEGER NOT NULL,
      nickname TEXT DEFAULT '', avatar TEXT DEFAULT '', msg TEXT DEFAULT '',
      status INTEGER DEFAULT 0, payload TEXT DEFAULT '',
      updated_at INTEGER DEFAULT 0, created_at INTEGER DEFAULT 0)''');
    const owner = '9007199254740995';
    for (final sender in ['9007199254740992', '9007199254740993']) {
      await db.insert('new_friend', {
        'uid': owner,
        'from_id': sender,
        'to_id': owner,
      });
    }
    final repo = NewFriendRepo();
    final rows = await repo.listNewFriend(owner, 10);
    expect(rows.map((row) => row.from).toSet(), {
      '9007199254740992',
      '9007199254740993',
    });
    expect(
      (await repo.findByFromTo('9007199254740993', owner, account: owner))?.to,
      owner,
    );
    expect(await repo.delete('9007199254740993', owner, account: owner), 1);
    expect(
      (await repo.listNewFriend(owner, 10)).single.from,
      '9007199254740992',
    );
  });

  test('lookups and updates are scoped to the captured account', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.execute(
      '''CREATE TABLE new_friend (
      auto_id INTEGER PRIMARY KEY, uid INTEGER NOT NULL,
      from_id INTEGER NOT NULL, to_id INTEGER NOT NULL, nickname TEXT DEFAULT '',
      avatar TEXT DEFAULT '', msg TEXT DEFAULT '', status INTEGER DEFAULT 0,
      payload TEXT DEFAULT '', updated_at INTEGER DEFAULT 0, created_at INTEGER DEFAULT 0)''',
    );
    for (final owner in ['1', '2']) {
      await db.insert('new_friend', {
        'uid': owner,
        'from_id': '8',
        'to_id': '9',
      });
    }
    final repo = NewFriendRepo();
    expect(
      await repo.update({'from': '8', 'to': '9', 'status': 1}, account: '1'),
      1,
    );
    expect((await repo.findByFromTo('8', '9', account: '1'))?.status, 1);
    expect((await repo.findByFromTo('8', '9', account: '2'))?.status, 0);
    expect(await repo.delete('8', '9', account: '1'), 1);
    expect(await repo.findByFromTo('8', '9', account: '2'), isNotNull);
  });
}
