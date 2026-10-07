import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  final repo = MessageRepo(tableName: MessageRepo.s2cTable);
  final messages = <Map<String, dynamic>>[
    {'msg_id': 'offline_system_probe', 'type': 'S2C'},
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  test(
    'failed system handler propagates; successful retry alone returns ACK IDs',
    () async {
      final failure = StateError('synthetic system handler failure');
      var calls = 0;
      await expectLater(
        repo.batchInsertOfflineMessages(
          messages,
          onS2CMessage: (_) async {
            calls++;
            throw failure;
          },
        ),
        throwsA(same(failure)),
      );
      expect(calls, 1);
      expect(
        await repo.batchInsertOfflineMessages(
          messages,
          onS2CMessage: (_) async {
            calls++;
          },
        ),
        ['offline_system_probe'],
      );
      expect(calls, 2);
    },
  );

  test('system events without a handler cannot be acknowledged', () async {
    await expectLater(
      repo.batchInsertOfflineMessages(messages),
      throwsStateError,
    );
  });
}
