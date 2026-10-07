import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('background offline batch survives provider disposal and replay', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final container = ProviderContainer();
    SqliteService.setDbForTest(db);
    MessageRepo.setProviderContainer(container);
    try {
      await applyBaselineSchema(db);
      await db.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      final message = <String, dynamic>{
        'msg_id': '116834000000000001',
        'type': 'C2C',
        'from': '995012',
        'to': '995011',
        'msg_type': 'text',
        'payload': {'text': ''},
        'created_at': 1750000000000,
      };
      expect(await repo.batchInsertOfflineMessages([message]), [
        message['msg_id'],
      ]);
      await container.pump();
      expect(container.exists(conversationProvider), isFalse);
      expect(await repo.batchInsertOfflineMessages([message]), [
        message['msg_id'],
      ]);
      final rows = await db.query('conversation');
      expect(rows.single['unread_num'], 1);
      await repo.batchInsertOfflineMessages([
        {...message, 'msg_id': '116834000000000002'},
      ]);
      expect((await db.query('conversation')).single['unread_num'], 2);
      expect((await db.query('msg_c2c')).length, 2);
    } finally {
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
