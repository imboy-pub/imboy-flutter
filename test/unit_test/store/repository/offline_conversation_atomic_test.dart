import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _messages = <Map<String, dynamic>>[
  {
    'msg_id': '116837000000000001',
    'type': 'C2C',
    'from': '995012',
    'to': '995011',
    'msg_type': 'text',
    'payload': {'text': ''},
    'created_at': 1750000000000,
  },
];

Future<void> _expectUpdateRecovery(Database db, MessageRepo repo) async {
  final second = [
    {..._messages.single, 'msg_id': '116837000000000002'},
  ];
  await db.execute(
    "CREATE TRIGGER fail_update BEFORE UPDATE ON conversation BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
  );
  await expectLater(repo.batchInsertOfflineMessages(second), throwsA(anything));
  expect((await db.query('msg_c2c')).length, 1);
  expect((await db.query('conversation')).single['unread_num'], 1);
  await db.execute('DROP TRIGGER fail_update');
  for (var attempt = 0; attempt < 2; attempt++) {
    expect(await repo.batchInsertOfflineMessages(second), [
      '116837000000000002',
    ]);
    expect((await db.query('msg_c2c')).length, 2);
    expect((await db.query('conversation')).single['unread_num'], 2);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('conversation failure rolls back message; retry rebuilds both exactly once', () async {
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
      await db.execute(
        "CREATE TRIGGER fail_conversation BEFORE INSERT ON conversation BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await expectLater(
        repo.batchInsertOfflineMessages(_messages),
        throwsA(anything),
      );
      expect(await db.query('msg_c2c'), isEmpty);
      expect(await db.query('conversation'), isEmpty);
      await db.execute('DROP TRIGGER fail_conversation');
      for (var attempt = 0; attempt < 2; attempt++) {
        expect(await repo.batchInsertOfflineMessages(_messages), [
          '116837000000000001',
        ]);
        expect((await db.query('msg_c2c')).length, 1);
        expect((await db.query('conversation')).single['unread_num'], 1);
      }
      await _expectUpdateRecovery(db, repo);
    } finally {
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
