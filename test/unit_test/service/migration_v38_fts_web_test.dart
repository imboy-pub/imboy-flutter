@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('v38 draft maintains FTS using the Web SQLite driver', (
    tester,
  ) async {
    const wasmUrl = String.fromEnvironment('SQLITE_WASM_URL');
    expect(
      wasmUrl,
      isNotEmpty,
      reason: 'Web test requires the project SQLite WASM',
    );
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final factory = createDatabaseFactoryFfiWeb(
        noWebWorker: true,
        options: SqfliteFfiWebOptions(sqlite3WasmUri: Uri.parse(wasmUrl)),
      );
      final db = await factory.openDatabase(':memory:');
      SqliteService.setDbForTest(db);
      try {
        for (final table in ['msg_c2c', 'msg_c2g']) {
          await db.execute(
            'CREATE TABLE $table (auto_id INTEGER PRIMARY KEY, '
            'id TEXT UNIQUE, conversation_uk3 TEXT, msg_type TEXT, payload TEXT, status INTEGER)',
          );
          await db.execute(
            'CREATE VIRTUAL TABLE ${table}_fts USING fts5('
            "id, conversation_uk3, text_content, content='')",
          );
          await db.insert(table, {
            'id': 'synthetic-$table',
            'conversation_uk3': 'synthetic',
            'msg_type': 'text',
            'payload': '{"text":"originalword"}',
            'status': 20,
          });
        }
        await db.execute('PRAGMA user_version = 37');
        await db.transaction((txn) async {
          for (final sql in upgradeV38Fts.sqlStatements) {
            await txn.execute(sql);
          }
        });
        for (final table in ['msg_c2c', 'msg_c2g']) {
          final repo = MessageFtsRepo();
          Future<List<FtsSearchResult>> appSearch() => table == 'msg_c2c'
              ? repo.searchC2c(
                  query: 'originalword',
                  conversationUk3: 'synthetic',
                )
              : repo.searchC2g(
                  query: 'originalword',
                  conversationUk3: 'synthetic',
                );
          Future<List<Map<String, Object?>>> search(String word) => db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            [word],
          );
          expect(
            (await search('originalword')).single['id'],
            'synthetic-$table',
          );
          expect((await appSearch()).single.id, 'synthetic-$table');
          await db.update(
            table,
            {'payload': '{"text":"updatedword"}'},
            where: 'id = ?',
            whereArgs: ['synthetic-$table'],
          );
          expect(await search('originalword'), isEmpty);
          expect(await appSearch(), isEmpty);
          expect(
            (await search('updatedword')).single['id'],
            'synthetic-$table',
          );
          await db.execute('PRAGMA recursive_triggers = OFF');
          await expectLater(
            db.rawInsert(
              'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
              ['synthetic-$table', 'text', '{"text":"rejectedword"}', 20],
            ),
            throwsA(
              predicate<Object>(
                (error) => error.toString().contains(
                  'message FTS requires recursive triggers for conflicting inserts',
                ),
              ),
            ),
          );
          expect(await search('updatedword'), hasLength(1));
          await db.execute('PRAGMA recursive_triggers = ON');
          await db.rawInsert(
            'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
            ['synthetic-$table', 'text', '{"text":"replacementword"}', 20],
          );
          expect(await search('updatedword'), isEmpty);
          expect(
            (await search('replacementword')).single['id'],
            'synthetic-$table',
          );
          await db.execute(
            "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
          );
        }
        expect(
          (await db.rawQuery('PRAGMA user_version')).single.values.single,
          38,
        );
      } finally {
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
  });
}
