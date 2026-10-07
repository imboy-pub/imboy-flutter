import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _start = 1750000000123;
const _end = _start + 1000;
const _times = [_start - 1, _start, _start + 1, _end, _end + 1];

Future<void> _seed(Database db, String type) async {
  for (var index = 0; index < _times.length; index++) {
    await db.insert(
      MessageRepo.getTableName(type),
      MessageModel(
        '$type-$index',
        autoId: index + 1,
        type: type,
        fromId: 995012,
        toId: 995011,
        payload: {'text': 'probe'},
        createdAt: _times[index],
        isAuthor: 0,
        conversationUk3: 'time-$type',
        msgType: 'text',
        status: IMBoyMessageStatus.delivered,
      ).toJson(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    await applyBaselineSchema(db);
    await _seed(db, 'C2C');
    await _seed(db, 'C2G');
  });
  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  for (final type in ['C2C', 'C2G']) {
    test('$type search uses inclusive millisecond boundaries', () async {
      final rows = await MessageRepo(tableName: MessageRepo.getTableName(type))
          .page(
            page: 1,
            size: 20,
            conversationUk3: 'time-$type',
            startDate: DateTime.fromMillisecondsSinceEpoch(_start),
            endDate: DateTime.fromMillisecondsSinceEpoch(_end),
          );
      expect(rows.map((row) => row.createdAt), [_end, _start + 1, _start]);
    });
  }
  test(
    'cross-table count uses the declared millisecond lower boundary',
    () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      expect(await repo.countMessagesWithUser('995012', since: _end), 4);
      expect(await repo.countMessagesWithUser('995012', since: _end + 2), 0);
      expect(await repo.countMessagesWithUser('995012'), 10);
    },
  );
}
