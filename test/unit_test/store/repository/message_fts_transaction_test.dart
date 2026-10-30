import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final type in ['C2C', 'C2G']) {
    test(
      'FTS $type follows direct SQL writes and rollback',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        Future<List<Map<String, Object?>>> matches(String word) => db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        );

        try {
          await db.insert(table, {
            'id': '116837000000000105',
            'type': type,
            'status': IMBoyMessageStatus.delivered,
            'conversation_uk3': 'synthetic',
            'msg_type': 'text',
            'payload': '{"text":"directoriginalword"}',
          });
          expect(await matches('directoriginalword'), hasLength(1));
          await expectLater(
            db.transaction((txn) async {
              await txn.update(
                table,
                {'payload': '{"text":"rolledbackreplacementword"}'},
                where: 'id = ?',
                whereArgs: ['116837000000000105'],
              );
              expect(
                await txn.rawQuery(
                  'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
                  ['rolledbackreplacementword'],
                ),
                hasLength(1),
              );
              throw StateError('synthetic rollback');
            }),
            throwsStateError,
          );
          expect(await matches('directoriginalword'), hasLength(1));
          expect(await matches('rolledbackreplacementword'), isEmpty);
        } finally {
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
      // 裸 SQL 写入绕过 repo，只有 v38 的 FTS 同步触发器能跟随；v38 草稿
      // 有意未注册（plan-v2.2 §11.1 记两项注册前阻断）。注册后移除本 skip。
      skip: 'v38 FTS 触发器未注册：直写 SQL 的索引跟随待 v38 注册后转绿',
    );
    test('FTS $type removes terms when the message is revoked', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(db);
      final table = type == 'C2C' ? MessageRepo.c2cTable : MessageRepo.c2gTable;
      final repo = MessageRepo(tableName: table);
      try {
        await repo.insert(
          MessageModel(
            '116837000000000104',
            autoId: 1,
            type: type,
            status: IMBoyMessageStatus.delivered,
            fromId: 200,
            toId: 100,
            payload: {'text': 'revokeduniqueword'},
            createdAt: 1700000000000,
            isAuthor: 0,
            conversationUk3: 'synthetic',
            msgType: 'text',
          ),
        );
        await repo.waitForFtsReindexForTest();
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['revokeduniqueword'],
          ),
          hasLength(1),
        );
        expect(
          await repo.update({
            'id': '116837000000000104',
            'status': IMBoyMessageStatus.peerRevoked,
          }),
          1,
        );
        await repo.waitForFtsReindexForTest();
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['revokeduniqueword'],
          ),
          isEmpty,
        );
      } finally {
        await repo.waitForFtsReindexForTest();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
    test('FTS $type removes terms when the message is deleted', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(db);
      final table = type == 'C2C' ? MessageRepo.c2cTable : MessageRepo.c2gTable;
      final repo = MessageRepo(tableName: table);
      try {
        await repo.insert(
          MessageModel(
            '116837000000000103',
            autoId: 1,
            type: type,
            status: IMBoyMessageStatus.delivered,
            fromId: 200,
            toId: 100,
            payload: {'text': 'deleteduniqueword'},
            createdAt: 1700000000000,
            isAuthor: 0,
            conversationUk3: 'synthetic',
            msgType: 'text',
          ),
        );
        await repo.waitForFtsReindexForTest();
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['deleteduniqueword'],
          ),
          hasLength(1),
        );
        expect(await repo.delete('116837000000000103'), 1);
        await repo.waitForFtsReindexForTest();
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['deleteduniqueword'],
          ),
          isEmpty,
        );
      } finally {
        await repo.waitForFtsReindexForTest();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
    test(
      'FTS $type production schema returns searchable message identity',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final message = MessageModel(
          '116837000000000101',
          autoId: 1,
          type: type,
          status: IMBoyMessageStatus.delivered,
          fromId: 200,
          toId: 100,
          payload: {'text': 'searchableword'},
          createdAt: 1700000000000,
          isAuthor: 0,
          conversationUk3: 'synthetic',
          msgType: 'text',
        );
        final repo = MessageRepo(tableName: table);
        try {
          await repo.insert(message);
          await repo.waitForFtsReindexForTest();
          final fts = MessageFtsRepo();
          final results = type == 'C2C'
              ? await fts.searchC2c(
                  query: 'searchableword',
                  conversationUk3: 'synthetic',
                )
              : await fts.searchC2g(
                  query: 'searchableword',
                  conversationUk3: 'synthetic',
                );
          expect(results, hasLength(1));
          expect(results.single.id, '116837000000000101');
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );
    test('FTS $type removes stale text after empty payload', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(db);
      final table = type == 'C2C' ? MessageRepo.c2cTable : MessageRepo.c2gTable;
      final row = MessageModel(
        '116837000000000102',
        autoId: 1,
        type: type,
        status: IMBoyMessageStatus.delivered,
        fromId: 200,
        toId: 100,
        payload: {'text': 'oldsecret'},
        isAuthor: 0,
        conversationUk3: 'synthetic',
        msgType: 'text',
      ).toJson();
      final repo = MessageRepo(tableName: table);
      try {
        await db.insert(table, row);
        await db.rawInsert('INSERT INTO ${table}_fts VALUES(?, ?, ?)', [
          '116837000000000102',
          'synthetic',
          'oldsecret',
        ]);
        expect(
          await repo.update({
            'id': '116837000000000102',
            'payload': <String, dynamic>{},
          }),
          1,
        );
        await repo.waitForFtsReindexForTest();
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['oldsecret'],
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
  // ===== 阅后即焚到期销毁（chat_burn_service 同路径）=====
  //
  // 风险线：到期阅后即焚消息仍可经本地 FTS 返回正文。
  // ChatBurnService.expireBurnMessage 的库层动作就是 repo.find + repo.delete
  // （lib/page/chat/chat/services/chat_burn_service.dart:298 与 :317），
  // MessageRepo.delete 在删行前经 _ftsRemoveStaleIndexEntry 清 FTS。
  // 本组测试复刻同一调用序列并断言销毁后 FTS 搜索不再命中。
  for (final type in ['C2C', 'C2G']) {
    test('burn_expiry $type removes FTS terms on chat_burn_service delete path', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(db);
      final table = type == 'C2C' ? MessageRepo.c2cTable : MessageRepo.c2gTable;
      final repo = MessageRepo(tableName: table);
      final fts = MessageFtsRepo();
      const msgId = '116837000000000106';
      try {
        // 存活期：带阅后即焚元数据的消息与普通文本一致入索引
        // （payload 键与 ChatBurnService.isBurnPayload / burnAfterMsFromPayload /
        //  burnReadAtMsFromPayload 读取的现网形态一致）
        await repo.insert(
          MessageModel(
            msgId,
            autoId: 1,
            type: type,
            status: IMBoyMessageStatus.seen,
            fromId: 200,
            toId: 100,
            payload: {
              'text': 'burnsecretword',
              'burn': true,
              'burn_after_ms': 60000,
              'burn_read_at': 1700000001000,
            },
            createdAt: 1700000000000,
            isAuthor: 0,
            conversationUk3: 'synthetic',
            msgType: 'text',
          ),
        );
        await repo.waitForFtsReindexForTest();
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['burnsecretword'],
          ),
          hasLength(1),
        );

        // 复刻 ChatBurnService.expireBurnMessage：
        // find(messageId) 非空后调用同一 repo.delete(messageId)
        final MessageModel? m = await repo.find(msgId);
        expect(m, isNotNull, reason: '到期销毁前消息行必须仍在库中');
        expect(m!.payloadMap['burn'], isTrue);
        await repo.delete(msgId);
        await repo.waitForFtsReindexForTest();

        // 行已出库
        expect(await repo.find(msgId), isNull);
        // FTS 词条已清：裸 MATCH 无命中
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['burnsecretword'],
          ),
          isEmpty,
        );
        // 搜索 API 层不再返回正文
        final results = type == 'C2C'
            ? await fts.searchC2c(
                query: 'burnsecretword',
                conversationUk3: 'synthetic',
              )
            : await fts.searchC2g(
                query: 'burnsecretword',
                conversationUk3: 'synthetic',
              );
        expect(results, isEmpty);
      } finally {
        await repo.waitForFtsReindexForTest();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
    test(
      'burn_expiry $type removes FTS terms after burn_read_at update then expiry',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final repo = MessageRepo(tableName: table);
        final fts = MessageFtsRepo();
        const msgId = '116837000000000107';
        try {
          // 已送达但未读：payload 尚无 burn_read_at
          await repo.insert(
            MessageModel(
              msgId,
              autoId: 1,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: 200,
              toId: 100,
              payload: {
                'text': 'burnreadsecret',
                'burn': true,
                'burn_after_ms': 60000,
              },
              createdAt: 1700000000000,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          await repo.waitForFtsReindexForTest();
          expect(
            await db.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['burnreadsecret'],
            ),
            hasLength(1),
          );

          // 复刻 ChatBurnService.markBurnReadAt 的落库动作
          // （chat_burn_service.dart:254-262：repo.update 写入 burn_read_at）
          final MessageModel? m = await repo.find(msgId);
          expect(m, isNotNull);
          final payload = Map<String, dynamic>.from(m!.payloadMap);
          payload['burn_read_at'] = 1700000001000;
          await repo.update({
            MessageRepo.id: msgId,
            MessageRepo.payload: payload,
          });
          await repo.waitForFtsReindexForTest();
          // 仍存活：正文保持可搜（倒计时中）
          expect(
            await db.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['burnreadsecret'],
            ),
            hasLength(1),
          );

          // 到期：与 expireBurnMessage 相同的 repo.delete
          await repo.delete(msgId);
          await repo.waitForFtsReindexForTest();

          expect(await repo.find(msgId), isNull);
          expect(
            await db.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['burnreadsecret'],
            ),
            isEmpty,
          );
          final results = type == 'C2C'
              ? await fts.searchC2c(
                  query: 'burnreadsecret',
                  conversationUk3: 'synthetic',
                )
              : await fts.searchC2g(
                  query: 'burnreadsecret',
                  conversationUk3: 'synthetic',
                );
          expect(results, isEmpty);
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );
  }
  for (final type in ['C2C', 'C2G']) {
    for (final rollback in [false, true]) {
      test('FTS $type transactional insert rollback=$rollback', () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final message = MessageModel(
          'synthetic-rollback-insert',
          autoId: 1,
          type: type,
          status: IMBoyMessageStatus.delivered,
          fromId: 200,
          toId: 100,
          payload: {'text': 'rolledbackword'},
          createdAt: 1700000000000,
          isAuthor: 0,
          conversationUk3: 'synthetic',
          msgType: 'text',
        );
        final repo = MessageRepo(tableName: table);
        try {
          await db.execute(
            'CREATE TABLE $table (${{...message.toJson().keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
          );
          await db.execute(
            'CREATE VIRTUAL TABLE ${table}_fts USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content)',
          );
          final outcome = await db
              .transaction((txn) async {
                await repo.insert(message, txn: txn);
                if (rollback) throw StateError('synthetic rollback');
              })
              .then<Object?>((_) => null, onError: (Object error) => error);
          if (rollback) {
            expect(outcome, isA<StateError>());
          } else {
            expect(outcome, isNull);
          }
          await repo.waitForFtsReindexForTest();
          final rows = await db.query(table);
          final indexed = await db.query('${table}_fts');
          if (rollback) {
            expect(rows, isEmpty);
            expect(indexed, isEmpty);
          } else {
            expect(rows, hasLength(1));
            expect(indexed.single['text_content'], 'rolledbackword');
          }
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      });
    }
  }
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
