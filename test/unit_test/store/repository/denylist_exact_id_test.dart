import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('unblocking one adjacent large ID leaves the other blocked', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.execute(
      '''CREATE TABLE user_denylist (user_id INTEGER, denied_user_id INTEGER, nickname TEXT, avatar TEXT, account TEXT, remark TEXT, region TEXT, sign TEXT, source TEXT, gender INTEGER, created_at INTEGER)''',
    );
    await db.insert('user_denylist', {
      'user_id': '1001',
      'denied_user_id': '9007199254740992',
    });
    await db.insert('user_denylist', {
      'user_id': '1001',
      'denied_user_id': '9007199254740993',
    });
    final repo = UserDenylistRepo();
    expect((await repo.page()).map((e) => e.deniedUid).toSet(), {
      '9007199254740992',
      '9007199254740993',
    });
    expect(await repo.delete('9007199254740993'), 1);
    expect((await repo.page()).single.deniedUid, '9007199254740992');
  });
}
