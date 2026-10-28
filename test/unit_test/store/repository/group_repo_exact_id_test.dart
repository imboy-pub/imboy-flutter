import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('group repository round trips precise identities', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.execute('''CREATE TABLE "group" (
      id INTEGER PRIMARY KEY, type INTEGER, join_limit INTEGER,
      content_limit INTEGER, owner_uid INTEGER, creator_uid INTEGER,
      member_max INTEGER, member_count INTEGER, introduction TEXT,
      avatar TEXT, title TEXT, status INTEGER, updated_at INTEGER,
      created_at INTEGER)''');
    final repo = GroupRepo();
    await repo.save('', {
      'id': '9007199254740993',
      'owner_uid': '9007199254740995',
      'creator_uid': '9007199254740997',
      'status': 1,
      'created_at': 1,
    });
    final found = await repo.findById('9007199254740993');
    expect(found?.groupId, '9007199254740993');
    expect(found?.ownerUid, '9007199254740995');
    expect(found?.creatorUid, '9007199254740997');
    expect((await repo.pageActive()).single.groupId, '9007199254740993');
  });

  test('member repository preserves large group and user identities', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.execute(
      '''CREATE TABLE group_member (
      id INTEGER PRIMARY KEY, group_id INTEGER, user_id INTEGER,
      nickname TEXT, avatar TEXT, sign TEXT, account TEXT, invite_code TEXT,
      alias TEXT, description TEXT, role INTEGER, is_join INTEGER, join_mode TEXT,
      status INTEGER, updated_at INTEGER, created_at INTEGER, mute_until INTEGER)''',
    );
    await db.insert('group_member', {
      'id': '9007199254740997',
      'group_id': '9007199254740993',
      'user_id': '9007199254740995',
      'status': 1,
    });
    final repo = GroupMemberRepo();
    final member = await repo.findByUserId(
      '9007199254740993',
      '9007199254740995',
    );
    expect(member?.id, '9007199254740997');
    expect(member?.groupId, '9007199254740993');
    expect(member?.userId, '9007199254740995');
    expect(await repo.groupIdsByUserId('9007199254740995'), [
      '9007199254740993',
    ]);
    await db.insert('group_member', {
      'id': '9007199254740998',
      'group_id': '9007199254740992',
      'user_id': '9007199254740994',
      'status': 1,
    });
    final selected = await repo.page(
      where: '${GroupMemberRepo.groupId} = ?',
      whereArgs: ['9007199254740993'],
    );
    expect(selected.map((member) => member.userId), ['9007199254740995']);
  });
}
