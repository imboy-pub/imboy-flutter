import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

Future<void> _insert(Database db, String type, int index, int time) async {
  await db.insert(
    MessageRepo.getTableName(type),
    MessageModel(
      '$type-$index',
      autoId: index + 1,
      type: type,
      fromId: 995012,
      toId: 995011,
      payload: {'text': 'probe'},
      createdAt: time,
      isAuthor: 0,
      conversationUk3: 'paging-$type',
      msgType: 'text',
      status: IMBoyMessageStatus.delivered,
    ).toJson(),
  );
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
  });
  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  test(
    'offset belongs to merged history; all pages have no gaps or repeats',
    () async {
      for (var index = 0; index < 6; index++) {
        await _insert(
          db,
          index.isEven ? 'C2C' : 'C2G',
          index,
          1750000000000 + index,
        );
      }
      final seen = <int>[];
      for (var offset = 0; offset < 6; offset += 2) {
        seen.addAll(
          (await MessageRepo.getMessages(
            limit: 2,
            offset: offset,
          )).map((m) => m.createdAt),
        );
      }
      expect(seen, List.generate(6, (i) => 1750000000005 - i));
      expect(await MessageRepo.getMessages(limit: 2, offset: 6), isEmpty);
    },
  );

  test(
    'merged history applies conversation and inclusive millisecond filters',
    () async {
      for (var index = 0; index < 6; index++) {
        await _insert(
          db,
          index.isEven ? 'C2C' : 'C2G',
          index,
          1750000000000 + index,
        );
      }
      final rows = await MessageRepo.getMessages(
        conversationUk3: 'paging-C2G',
        startTime: 1750000000001,
        endTime: 1750000000003,
      );
      expect(rows.map((m) => m.createdAt), [1750000000003, 1750000000001]);
      expect(rows.every((m) => m.type == 'C2G'), isTrue);
      expect(await MessageRepo.getMessages(limit: 0), isEmpty);
    },
  );

  test('equal timestamps have stable ordering across page sizes', () async {
    for (final type in ['C2C', 'C2G']) {
      for (var index = 0; index < 2; index++) {
        await _insert(db, type, index, 1750000000000);
      }
    }
    final whole = await MessageRepo.getMessages(limit: 4);
    final split = <String>[];
    for (var offset = 0; offset < 4; offset++) {
      split.add(
        (await MessageRepo.getMessages(
          limit: 1,
          offset: offset,
        )).single.id.toString(),
      );
    }
    expect(split, whole.map((m) => m.id.toString()));
    expect(split.toSet().length, 4);
  });
}
