import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('v38 searches observe direct writes and deletion immediately', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    try {
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      final repo = MessageFtsRepo();
      for (final type in ['C2C', 'C2G']) {
        final table = type == 'C2C' ? 'msg_c2c' : 'msg_c2g';
        Future<List<FtsSearchResult>> search() => type == 'C2C'
            ? repo.searchC2c(query: 'freshword', conversationUk3: 'synthetic')
            : repo.searchC2g(query: 'freshword', conversationUk3: 'synthetic');
        expect(await search(), isEmpty);
        await db.insert(table, {
          'id': 'cache-$table',
          'conversation_uk3': 'synthetic',
          'msg_type': 'text',
          'payload': '{"text":"freshword"}',
          'status': 20,
        });
        expect((await search()).single.id, 'cache-$table');
        await db.delete(table, where: 'id = ?', whereArgs: ['cache-$table']);
        expect(await search(), isEmpty);
      }
    } finally {
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });

  test('v38 works with message repository writes', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    final repo = MessageRepo(tableName: MessageRepo.c2cTable);
    try {
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      await repo.insert(
        MessageModel(
          '116837000000000106',
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.delivered,
          fromId: 200,
          toId: 100,
          payload: {'text': 'repositoryword'},
          createdAt: 1700000000000,
          isAuthor: 0,
          conversationUk3: 'synthetic',
          msgType: 'text',
        ),
      );
      await repo.waitForFtsReindexForTest();
      await db.insert('msg_c2c', {
        'id': '116837000000000107',
        'msg_type': 'text',
        'conversation_uk3': 'synthetic',
        'payload': '{"text":"secondword"}',
        'status': 20,
      });
      await MessageFtsRepo().indexC2cMessage(
        id: '116837000000000106',
        conversationUk3: 'synthetic',
        textContent: 'repositoryword',
      );
      await MessageFtsRepo().deleteFromIndex(
        type: 'C2C',
        id: '116837000000000106',
        conversationUk3: 'synthetic',
        textContent: 'repositoryword',
      );
      final results = await MessageFtsRepo().searchC2c(
        query: 'repositoryword',
        conversationUk3: 'synthetic',
      );
      expect(results, hasLength(1));
      expect(results.single.id, '116837000000000106');
      await db.insert('msg_c2g', {
        'id': '116837000000000108',
        'msg_type': 'text',
        'conversation_uk3': 'group',
        'payload': '{"text":"groupword"}',
        'status': 20,
      });
      await db.insert('msg_c2g', {
        'id': '116837000000000109',
        'msg_type': 'text',
        'conversation_uk3': 'group',
        'payload': '{"text":"othergroupword"}',
        'status': 20,
      });
      await MessageFtsRepo().indexC2gMessage(
        id: '116837000000000108',
        conversationUk3: 'group',
        textContent: 'groupword',
      );
      await MessageFtsRepo().deleteFromIndex(
        type: 'C2G',
        id: '116837000000000108',
        conversationUk3: 'group',
        textContent: 'groupword',
      );
      final groupResults = await MessageFtsRepo().searchC2g(
        query: 'groupword',
        conversationUk3: 'group',
      );
      expect(groupResults, hasLength(1));
      expect(groupResults.single.id, '116837000000000108');
    } finally {
      await repo.waitForFtsReindexForTest();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
  test('v38 repository updates revoke empty payload and delete indexes', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    final repos = <MessageRepo>[];
    try {
      await db.execute('PRAGMA recursive_triggers = ON');
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final type in ['C2C', 'C2G']) {
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final repo = MessageRepo(tableName: table);
        repos.add(repo);
        final id = type == 'C2C' ? '116837000000000111' : '116837000000000112';
        Future<List<Map<String, Object?>>> search(String word) => db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        );
        await repo.insert(
          MessageModel(
            id,
            autoId: 1,
            type: type,
            status: IMBoyMessageStatus.delivered,
            fromId: 200,
            toId: 100,
            payload: {'text': 'originalword'},
            createdAt: 1700000000000,
            isAuthor: 0,
            conversationUk3: 'synthetic',
            msgType: 'text',
          ),
        );
        await repo.waitForFtsReindexForTest();
        expect((await search('originalword')).single['id'], id);
        expect(
          await repo.update({'id': id, 'payload': <String, dynamic>{}}),
          1,
        );
        await repo.waitForFtsReindexForTest();
        expect(await search('originalword'), isEmpty);
        expect(
          await repo.update({
            'id': id,
            'payload': {'text': 'restoredword'},
          }),
          1,
        );
        await repo.waitForFtsReindexForTest();
        expect((await search('restoredword')).single['id'], id);
        expect(
          await repo.update({
            'id': id,
            'status': IMBoyMessageStatus.peerRevoked,
          }),
          1,
        );
        await repo.waitForFtsReindexForTest();
        expect(await search('restoredword'), isEmpty);
        expect(
          await repo.update({'id': id, 'status': IMBoyMessageStatus.delivered}),
          1,
        );
        expect((await search('restoredword')).single['id'], id);
        expect(await repo.delete(id), 1);
        await repo.waitForFtsReindexForTest();
        expect(await search('restoredword'), isEmpty);
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      for (final repo in repos) {
        await repo.waitForFtsReindexForTest();
      }
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });

  test('v38 FTS rebuild and triggers follow message transactions', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      await db.execute('PRAGMA recursive_triggers = ON');
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.insert(table, {
          'id': 'old-$table',
          'msg_type': 'text',
          'conversation_uk3': 'synthetic',
          'payload': '{"text":"historicalword"}',
          'status': 20,
        });
        await db.insert(table, {
          'id': 'invalid-$table',
          'msg_type': 'text',
          'payload': 'not-json',
          'status': 20,
        });
        await db.insert(table, {
          'id': 'failed-$table',
          'msg_type': 'text',
          'payload': '{"text":"placeholderword","_e2ee_failed":true}',
          'status': 20,
        });
      }
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        Future<List<Map<String, Object?>>> search(String word) => db.rawQuery(
          'SELECT id, conversation_uk3, snippet(${table}_fts, 2, "<b>", "</b>", "...", 32) AS snippet FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        );
        final historical = await search('historicalword');
        expect(historical.single['id'], 'old-$table');
        expect(historical.single['conversation_uk3'], 'synthetic');
        expect(historical.single['snippet'], contains('historicalword'));
        expect(await search('placeholderword'), isEmpty);
        await expectLater(
          db.transaction((txn) async {
            await txn.update(
              table,
              {'payload': '{"text":"rollbackword"}'},
              where: 'id = ?',
              whereArgs: ['old-$table'],
            );
            expect(
              await txn.rawQuery(
                'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
                ['rollbackword'],
              ),
              hasLength(1),
            );
            throw StateError('rollback');
          }),
          throwsStateError,
        );
        expect(await search('historicalword'), hasLength(1));
        expect(await search('rollbackword'), isEmpty);
        await db.insert(table, {
          'id': 'new-$table',
          'msg_type': 'quote',
          'conversation_uk3': 'another',
          'payload': '{"quote_text":"quoteword"}',
          'status': 20,
        });
        expect((await search('quoteword')).single['id'], 'new-$table');
        await db.update(
          table,
          {
            'msg_type': 'location',
            'payload': '{"title":"locationword","address":"addressword"}',
          },
          where: 'id = ?',
          whereArgs: ['new-$table'],
        );
        expect(await search('quoteword'), isEmpty);
        expect((await search('locationword')).single['id'], 'new-$table');
        expect((await search('addressword')).single['id'], 'new-$table');
        await db.delete(table, where: 'id = ?', whereArgs: ['new-$table']);
        expect(await search('locationword'), isEmpty);
        expect(await search('addressword'), isEmpty);
        for (final payload in [
          '"ciphertextword"',
          '{"text":{"ciphertext":"ciphertextword"}}',
          '{"text":"placeholderword","_e2ee_failed":true}',
          'malformed ciphertextword',
        ]) {
          await db.insert(table, {
            'id': 'excluded-$table-${payload.length}',
            'msg_type': 'text',
            'payload': payload,
            'status': 20,
          });
        }
        expect(await search('ciphertextword'), isEmpty);
        expect(await search('placeholderword'), isEmpty);
        await db.insert(table, {
          'id': 'old-$table',
          'conversation_uk3': 'synthetic',
          'msg_type': 'text',
          'payload': '{"text":"replacementword"}',
          'status': 20,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        expect(await search('historicalword'), isEmpty);
        expect((await search('replacementword')).single['id'], 'old-$table');
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
        await db.update(
          table,
          {'status': 30},
          where: 'id = ?',
          whereArgs: ['old-$table'],
        );
        expect(await search('replacementword'), isEmpty);
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
    }
  });

  test('v38 indexes recovered plaintext without indexing E2EE envelopes', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.insert(table, {
          'id': 'decrypted-$table',
          'msg_type': 'text',
          'payload': '{"text":"decryptedword"}',
          'e2ee': '{"protocol":"megolm","ciphertext":"envelopeword"}',
          'status': 20,
        });
        await db.insert(table, {
          'id': 'failed-$table',
          'msg_type': 'text',
          'payload':
              '{"_e2ee_failed":true,"text":"placeholderword",'
              '"_e2ee_raw":{"payload":"cipherword"}}',
          'e2ee': '{"protocol":"megolm"}',
          'status': 20,
        });
      }
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        Future<List<Map<String, Object?>>> search(String word) => db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        );
        expect(
          (await search('decryptedword')).single['id'],
          'decrypted-$table',
        );
        for (final word in ['envelopeword', 'placeholderword', 'cipherword']) {
          expect(await search(word), isEmpty);
        }
        await db.update(
          table,
          {'payload': '{"text":"recoveredword"}'},
          where: 'id = ?',
          whereArgs: ['failed-$table'],
        );
        expect((await search('recoveredword')).single['id'], 'failed-$table');
        await db.update(
          table,
          {'payload': '{"_e2ee_failed":true,"text":"placeholderword"}'},
          where: 'id = ?',
          whereArgs: ['decrypted-$table'],
        );
        expect(await search('decryptedword'), isEmpty);
        expect(await search('placeholderword'), isEmpty);
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
    }
  });

  test('v38 excludes the entire revoked status range', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      for (final table in ['msg_c2c', 'msg_c2g']) {
        for (final status in [29, 30, 31, 32, 39, 40]) {
          await db.insert(table, {
            'id': '$table-$status',
            'msg_type': 'text',
            'payload': '{"text":"boundaryword"}',
            'status': status,
          });
        }
      }
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        Future<Set<Object?>> matches() async => (await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['boundaryword'],
        )).map((row) => row['id']).toSet();
        expect(await matches(), {'$table-29', '$table-40'});
        await db.update(
          table,
          {'status': 39},
          where: 'id = ?',
          whereArgs: ['$table-29'],
        );
        await db.update(
          table,
          {'status': 20},
          where: 'id = ?',
          whereArgs: ['$table-32'],
        );
        expect(await matches(), {'$table-32', '$table-40'});
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
    }
  });

  test('v38 interrupted migration restores the v37 schema', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      await expectLater(
        db.transaction((txn) async {
          for (final sql in upgradeV38Fts.sqlStatements.take(4)) {
            await txn.execute(sql);
          }
          throw StateError('injected migration failure');
        }),
        throwsStateError,
      );
      expect(await db.getVersion(), 37);
      final original = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE name = 'msg_c2c_fts'",
      );
      expect(original.single['sql'], contains("content=''"));
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'msg_c2c_fts_content'",
        ),
        isEmpty,
      );
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      expect(await db.getVersion(), 38);
    } finally {
      await db.close();
    }
  });

  test('v38 interrupted migration can retry after database reopen', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('imboy_fts_retry_');
    final databasePath = '${directory.path}/synthetic.db';
    var db = await openFixtureDatabaseAtVersion(
      version: 37,
      path: databasePath,
    );
    try {
      await db.insert('msg_c2c', {
        'id': 'before-retry',
        'conversation_uk3': 'synthetic',
        'msg_type': 'text',
        'payload': '{"text":"retryword"}',
        'status': 20,
      });
      await expectLater(
        db.transaction((txn) async {
          for (final sql in upgradeV38Fts.sqlStatements.take(4)) {
            await txn.execute(sql);
          }
          throw StateError('injected failure');
        }),
        throwsStateError,
      );
      await db.close();
      db = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      expect(await db.getVersion(), 37);
      expect((await db.query('msg_c2c')).single['id'], 'before-retry');
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      await db.close();
      db = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      expect(await db.getVersion(), 38);
      expect(
        (await db.rawQuery(
          'SELECT id FROM msg_c2c_fts WHERE msg_c2c_fts MATCH ?',
          ['retryword'],
        )).single['id'],
        'before-retry',
      );
      await db.execute(
        "INSERT INTO msg_c2c_fts(msg_c2c_fts, rank) VALUES('integrity-check', 1)",
      );
    } finally {
      if (db.isOpen) await db.close();
      await directory.delete(recursive: true);
    }
  });

  test('v38 replace and upsert with recursive triggers', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      await db.execute('PRAGMA recursive_triggers = ON');
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.insert(table, {
          'id': 'replace-$table',
          'msg_type': 'text',
          'payload': '{"text":"firstword"}',
          'status': 20,
        });
        await db.insert(table, {
          'id': 'replace-$table',
          'msg_type': 'text',
          'payload': '{"text":"secondword"}',
          'status': 20,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['firstword'],
          ),
          isEmpty,
        );
        await db.rawInsert(
          'INSERT INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET payload = excluded.payload',
          ['replace-$table', 'text', '{"text":"thirdword"}', 20],
        );
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['secondword'],
          ),
          isEmpty,
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['thirdword'],
          ),
          hasLength(1),
        );
        await db.insert(table, {
          'id': 'collision-$table',
          'msg_type': 'text',
          'payload': '{"text":"collisionword"}',
          'status': 20,
        });
        expect(
          await db.rawUpdate(
            'UPDATE OR REPLACE $table SET id = ? WHERE id = ?',
            ['collision-$table', 'replace-$table'],
          ),
          1,
        );
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['collisionword'],
          ),
          isEmpty,
        );
        expect(
          (await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['thirdword'],
          )).single['id'],
          'collision-$table',
        );
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
    }
  });

  test('v38 ignored conflicting updates preserve the original index', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    for (final recursive in [false, true]) {
      final db = await openFixtureDatabaseAtVersion(version: 37);
      try {
        await db.execute(
          'PRAGMA recursive_triggers = ${recursive ? 'ON' : 'OFF'}',
        );
        await db.transaction((txn) async {
          for (final sql in upgradeV38Fts.sqlStatements) {
            await txn.execute(sql);
          }
        });
        for (final table in ['msg_c2c', 'msg_c2g']) {
          await db.insert(table, {
            'id': 'first-$table',
            'msg_type': 'text',
            'payload': '{"text":"firstword"}',
            'status': 20,
          });
          await db.insert(table, {
            'id': 'second-$table',
            'msg_type': 'text',
            'payload': '{"text":"secondword"}',
            'status': 20,
          });
          final update = db.rawUpdate(
            'UPDATE OR IGNORE $table SET id = ? WHERE id = ?',
            ['second-$table', 'first-$table'],
          );
          if (recursive) {
            expect(await update, 0);
          } else {
            await expectLater(update, throwsA(isA<DatabaseException>()));
          }
          expect(
            await db.rawQuery(
              'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['firstword'],
            ),
            hasLength(1),
          );
          expect(
            await db.rawQuery(
              'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['secondword'],
            ),
            hasLength(1),
          );
          await db.execute(
            "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
          );
        }
      } finally {
        await db.close();
      }
    }
  });

  test('v38 rejects conflicting updates without recursive triggers', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      await db.execute('PRAGMA recursive_triggers = OFF');
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.insert(table, {
          'auto_id': 101,
          'id': 'first-$table',
          'msg_type': 'text',
          'payload': '{"text":"firstword"}',
          'status': 20,
        });
        await db.insert(table, {
          'auto_id': 102,
          'id': 'second-$table',
          'msg_type': 'text',
          'payload': '{"text":"secondword"}',
          'status': 20,
        });
        await expectLater(
          db.rawUpdate(
            'UPDATE OR REPLACE $table SET id = ? WHERE auto_id = ?',
            ['second-$table', 101],
          ),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          db.rawUpdate(
            'UPDATE OR REPLACE $table SET auto_id = ? WHERE id = ?',
            [102, 'first-$table'],
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db.query(table), hasLength(2));
        for (final word in ['firstword', 'secondword']) {
          expect(
            await db.rawQuery(
              'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              [word],
            ),
            hasLength(1),
          );
        }
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
    }
  });

  test('v38 rejects conflicting inserts without recursive triggers', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    try {
      await db.execute('PRAGMA recursive_triggers = OFF');
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.insert(table, {
          'auto_id': 42,
          'id': 'original-$table',
          'msg_type': 'text',
          'payload': '{"text":"originalword"}',
          'status': 20,
        });
        for (final statement in [
          "INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES ('original-$table', 'text', '{\"text\":\"replacementword\"}', 20)",
          "INSERT OR REPLACE INTO $table(auto_id, id, msg_type, payload, status) VALUES (42, 'other-$table', 'text', '{\"text\":\"replacementword\"}', 20)",
          "INSERT INTO $table(id, msg_type, payload, status) VALUES ('original-$table', 'text', '{\"text\":\"replacementword\"}', 20) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload",
        ]) {
          await expectLater(
            db.execute(statement),
            throwsA(isA<DatabaseException>()),
          );
        }
        expect(
          (await db.query(
            table,
            where: 'auto_id = ?',
            whereArgs: [42],
          )).single['id'],
          'original-$table',
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['originalword'],
          ),
          hasLength(1),
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['replacementword'],
          ),
          isEmpty,
        );
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
        await db.insert(table, {
          'auto_id': -1,
          'id': 'negative-$table',
          'msg_type': 'text',
          'payload': '{"text":"negativeword"}',
          'status': 20,
        });
        await expectLater(
          db.rawInsert(
            'INSERT OR REPLACE INTO $table(auto_id, id, msg_type, payload, status) VALUES (?, ?, ?, ?, ?)',
            [-1, 'different-$table', 'text', '{"text":"replacementword"}', 20],
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['negativeword'],
          ),
          hasLength(1),
        );
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
    }
  });
}
