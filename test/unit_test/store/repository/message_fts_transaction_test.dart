import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final type in ['C2C', 'C2G']) {
    for (final rollback in [false, true]) {
      for (final writes in [1, 2]) {
        test('FTS transaction $type rollback=$rollback writes=$writes', () async {
          SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
          await StorageService.init();
          sqfliteFfiInit();
          final db = await databaseFactoryFfi.openDatabase(
            inMemoryDatabasePath,
          );
          SqliteService.setDbForTest(db);
          final table = type == 'C2C'
              ? MessageRepo.c2cTable
              : MessageRepo.c2gTable;
          final row = MessageModel(
            'synthetic-transaction',
            autoId: 1,
            type: type,
            status: IMBoyMessageStatus.delivered,
            fromId: 200,
            toId: 100,
            payload: {'text': 'oldword'},
            isAuthor: 0,
            conversationUk3: 'synthetic',
            msgType: 'text',
          ).toJson();
          final repo = MessageRepo(tableName: table);
          try {
            await db.execute(
              'CREATE TABLE $table (${{...row.keys, ...MessageRepo.c2cColumns}.map((k) => '"$k"').join(', ')})',
            );
            await db.insert(table, row);
            await db.execute(
              'CREATE VIRTUAL TABLE ${table}_fts USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content)',
            );
            await db.rawInsert('INSERT INTO ${table}_fts VALUES(?, ?, ?)', [
              'synthetic-transaction',
              'synthetic',
              'oldword',
            ]);
            final outcome = await db
                .transaction((txn) async {
                  for (var index = 0; index < writes; index++) {
                    expect(
                      await repo.update({
                        'id': 'synthetic-transaction',
                        'payload': {'text': 'newword$index'},
                      }, txn: txn),
                      1,
                    );
                  }
                  expect(
                    (await txn.query('${table}_fts')).single['text_content'],
                    'oldword',
                  );
                  if (rollback) throw StateError('synthetic-rollback');
                })
                .then<Object?>((_) => null, onError: (Object error) => error);
            if (rollback) {
              expect(outcome, isA<StateError>());
            } else {
              expect(outcome, isNull);
            }
            await repo.waitForFtsReindexForTest();
            final indexed = await db.query('${table}_fts');
            expect(indexed, hasLength(1));
            expect(
              indexed.single['text_content'],
              rollback ? 'oldword' : 'newword${writes - 1}',
            );
            final matches = await db.rawQuery(
              'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              [rollback ? 'oldword' : 'newword${writes - 1}'],
            );
            expect(matches, hasLength(1));
            expect(
              await db.rawQuery(
                'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
                [rollback ? 'newword0' : 'oldword'],
              ),
              isEmpty,
            );
          } finally {
            await repo.waitForFtsReindexForTest();
            SqliteService.setDbForTest(null);
            await db.close();
          }
        });
      }
    }
  }
  for (final type in ['C2C', 'C2G']) {
    test('FTS $type concurrent separate repository instances', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      final table = type == 'C2C' ? 'msg_c2c_fts' : 'msg_c2g_fts';
      try {
        await db.execute(
          'CREATE VIRTUAL TABLE $table USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content)',
        );
        await Future.wait(
          List.generate(
            6,
            (index) => MessageFtsRepo().indexMessage(
              type: type,
              id: 'synthetic-concurrent',
              conversationUk3: 'synthetic',
              textContent: 'newword$index',
            ),
          ),
        );
        final rows = await db.query(table);
        expect(rows, hasLength(1));
        expect(rows.single['text_content'], 'newword5');
        expect(
          await db.rawQuery('SELECT id FROM $table WHERE $table MATCH ?', [
            'newword5',
          ]),
          hasLength(1),
        );
        expect(
          await db.rawQuery('SELECT id FROM $table WHERE $table MATCH ?', [
            'newword0',
          ]),
          isEmpty,
        );
      } finally {
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
  }
}
