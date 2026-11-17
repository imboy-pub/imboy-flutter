import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final type in ['C2C', 'C2G']) {
    test(
      'concurrent $type redelivery inserts one row and preserves backfilled metadata',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = MessageRepo.getTableName(type);
        final repo = MessageRepo(tableName: table);
        try {
          await db.execute('CREATE TABLE insertion_audit(auto_id INTEGER)');
          await db.execute(
            'CREATE TRIGGER audit_insert AFTER INSERT ON $table '
            'BEGIN INSERT INTO insertion_audit VALUES(NEW.auto_id); END',
          );
          MessageModel incoming() => MessageModel(
            'synthetic-redelivery',
            autoId: 0,
            type: type,
            status: IMBoyMessageStatus.delivered,
            fromId: '200',
            toId: '100',
            payload: {'text': 'originaltext'},
            createdAt: 1700000000000,
            isAuthor: 0,
            conversationUk3: 'synthetic-conversation',
            msgType: 'text',
          );
          expect(await SqliteService.to.count(table), 0);
          await Future.wait(List.generate(8, (_) => repo.insert(incoming())));
          await repo.waitForFtsReindexForTest();
          expect(await SqliteService.to.count(table), 1);
          final original = (await db.query(table)).single;
          expect(await db.query('insertion_audit'), hasLength(1));
          await db.update(
            table,
            {
              'conv_seq': 42,
              'accepted_at': 1700000001000,
              'status': IMBoyMessageStatus.seen,
            },
            where: 'id = ?',
            whereArgs: ['synthetic-redelivery'],
          );
          await Future.wait(List.generate(4, (_) => repo.insert(incoming())));
          await repo.waitForFtsReindexForTest();
          final retained = (await db.query(table)).single;
          expect(retained['auto_id'], original['auto_id']);
          expect(retained['conv_seq'], 42);
          expect(retained['accepted_at'], 1700000001000);
          expect(retained['status'], IMBoyMessageStatus.seen);
          expect(await db.query('insertion_audit'), hasLength(1));
          expect(
            await db.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['originaltext'],
            ),
            hasLength(1),
          );
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );
  }
}
