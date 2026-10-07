import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  final queries = <String, Future<Object?> Function()>{
    'older page': () => repo.pageForConversation('synthetic', 1, 20),
    'newer page': () => repo.pageNewerForConversation('synthetic', 1, 20),
    'history search': () => repo.page(page: 1, size: 20),
    'merged history': () => MessageRepo.getMessages(),
    'message count': () => repo.countMessagesWithUser('995012'),
  };
  for (final entry in queries.entries) {
    test('${entry.key} exposes SQL failure and permits recovery', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      try {
        await applyBaselineSchema(db);
        final schema =
            (await db.rawQuery(
                  "SELECT sql FROM sqlite_master WHERE type='table' AND name='msg_c2c'",
                )).single['sql']
                as String;
        await db.execute('DROP TABLE msg_c2c');
        await expectLater(entry.value(), throwsA(isA<DatabaseException>()));
        await db.execute(schema);
        final recovered = await entry.value();
        if (entry.key == 'message count') {
          expect(recovered, 0);
        } else {
          expect(recovered, isEmpty);
        }
      } finally {
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
  }
}
