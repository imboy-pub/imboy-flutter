import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/attachments/personal_attachment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  final repository = PersonalAttachmentRepository();
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    for (final table in ['msg_c2c', 'msg_c2g']) {
      await db.execute(
        'CREATE TABLE $table (auto_id INTEGER PRIMARY KEY, '
        'id TEXT, type TEXT, from_id TEXT, to_id TEXT, payload TEXT, '
        'created_at INTEGER, conversation_uk3 TEXT, is_author INTEGER, '
        'topic_id TEXT, status INTEGER, msg_type TEXT)',
      );
    }
  });
  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });
  Future<void> insert(
    int id, {
    String type = 'file',
    int status = 11,
    String? payload,
    String table = 'msg_c2c',
  }) => db
      .insert(table, {
        'id': '$id',
        'type': table == 'msg_c2c' ? 'C2C' : 'C2G',
        'from_id': '995011',
        'to_id': '995012',
        'payload': payload ?? jsonEncode({'filename': 'budget_$id.pdf'}),
        'created_at': id,
        'conversation_uk3': 'C2C_995011_995012',
        'is_author': 1,
        'status': status,
        'msg_type': type,
      })
      .then((_) {});
  test(
    'only readable local attachments survive type and revoked filters',
    () async {
      await insert(1);
      await insert(2, type: 'text');
      await insert(3, status: 32);
      await insert(4, payload: 'opaque-ciphertext');
      final rows = await repository.page();
      expect(rows.map((row) => row.message.id), ['1']);
      expect(
        PersonalAttachment.fromMessage(rows.single.message)?.name,
        'budget_1.pdf',
      );
    },
  );
  test(
    'literal search and stable paging cover both local message tables',
    () async {
      for (var id = 1; id <= 45; id++) {
        await insert(id, table: id.isEven ? 'msg_c2g' : 'msg_c2c');
      }
      await insert(46, payload: jsonEncode({'filename': '100%_budget.pdf'}));
      expect((await repository.page(keyword: '%_')).single.message.id, '46');
      final first = await repository.page();
      final second = await repository.page(offset: 40);
      expect(first.length, 40);
      expect(second.length, 6);
      expect(
        {...first, ...second}.map((row) => row.message.id).toSet().length,
        46,
      );
    },
  );
  test(
    'deleted message indices stay absent and database failures propagate',
    () async {
      await insert(1);
      await db.delete('msg_c2c');
      expect(await repository.page(), isEmpty);
      await db.execute('DROP TABLE msg_c2c');
      await expectLater(repository.page(), throwsA(isA<DatabaseException>()));
    },
  );
}
