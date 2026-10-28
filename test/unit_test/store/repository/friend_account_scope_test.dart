import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'contact save stays with captured account after current account changes',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
      await StorageService.init();
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      addTearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });
      await db.execute('''CREATE TABLE contact (
      user_id INTEGER, peer_id INTEGER, nickname TEXT, avatar TEXT,
      account TEXT, status INTEGER, remark TEXT, tag TEXT, region TEXT,
      sign TEXT, source TEXT, gender INTEGER, is_friend INTEGER,
      is_from INTEGER, category_id INTEGER, account_type INTEGER,
      last_seen_at INTEGER, updated_at INTEGER)''');
      for (final owner in ['1', '2']) {
        await db.insert('contact', {
          'user_id': owner,
          'peer_id': '9',
          'nickname': 'before',
          'is_friend': 0,
        });
      }
      final entered = Completer<void>();
      final release = Completer<void>();
      final holding = db.transaction((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final captured = UserRepoLocal.to.currentUid;
      final pending = ContactRepo().save({
        'id': '9',
        'nickname': 'after',
        'is_friend': 1,
      }, account: captured);
      await StorageService.to.setString(Keys.currentUid, '2');
      release.complete();
      await holding;
      final saved = await pending;
      expect(saved, isNotNull);
      final rows = await db.query('contact', orderBy: 'user_id');
      expect(rows[0]['nickname'], 'after');
      expect(rows[0]['is_friend'], 1);
      expect(rows[1]['nickname'], 'before');
      expect(rows[1]['is_friend'], 0);
    },
  );
}
