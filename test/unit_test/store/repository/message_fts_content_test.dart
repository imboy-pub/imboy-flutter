import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// Hold the update's completion after the real SQLite write. This exposes the
/// production window before MessageRepo can enqueue its deferred FTS work.
class _HeldUpdateDatabase implements Database {
  _HeldUpdateDatabase(this.inner, this.table, {required this.hold});
  final Database inner;
  final String table;
  bool hold;
  final committed = Completer<void>();
  final release = Completer<void>();

  @override
  bool get isOpen => inner.isOpen;

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final count = await inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    if (hold && table == this.table && values.containsKey('payload')) {
      hold = false;
      committed.complete();
      await release.future;
    }
    return count;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) => inner.transaction(action, exclusive: exclusive);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      inner.rawUpdate(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => inner.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessageModel _message(
  String type,
  String id,
  Map<String, dynamic> payload, {
  String msgType = 'text',
}) => MessageModel(
  id,
  autoId: 0,
  type: type,
  fromId: '200',
  toId: '100',
  payload: payload,
  msgType: msgType,
  status: 20,
  isAuthor: 0,
  createdAt: 1700000000000,
  conversationUk3: 'synthetic',
);

Future<List<FtsSearchResult>> _search(String type, String query) =>
    type == 'C2C'
    ? MessageFtsRepo().searchC2c(query: query, throwOnError: true)
    : MessageFtsRepo().searchC2g(query: query, throwOnError: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
  });

  for (final type in ['C2C', 'C2G']) {
    for (final pending in [false, true]) {
      test('$type repaired index survives edit/delete; pending=$pending', () async {
        final inner = await openFixtureDatabaseAtVersion(version: 39);
        addTearDown(() async {
          SqliteService.setDbForTest(null);
          if (inner.isOpen) await inner.close();
        });
        final table = MessageRepo.getTableName(type);
        final rowid = await inner.insert(table, {
          'id': 'synthetic-original',
          'type': type,
          'from_id': 200,
          'to_id': 100,
          'payload': '{"text":"currentword"}',
          'msg_type': 'text',
          'conversation_uk3': 'synthetic',
          'status': 20,
          'is_author': 0,
          'created_at': 1700000000000,
        });
        for (final text in ['oldword', 'currentword']) {
          await inner.insert('${table}_fts', {
            'rowid': rowid,
            'id': 'synthetic-original',
            'conversation_uk3': 'synthetic',
            'text_content': text,
          });
        }
        await inner.transaction((txn) async {
          final result = await MigrationService.to.migrate(
            db: txn,
            fromVersion: 39,
            toVersion: 40,
          );
          expect(result.success, isTrue, reason: result.error);
        });
        final proxy = _HeldUpdateDatabase(inner, table, hold: pending);
        SqliteService.setDbForTest(proxy);
        final repo = MessageRepo(tableName: table);
        Future<int>? update;
        Future<int>? deletion;
        Future<List<Map<String, Object?>>> matches(String text) =>
            inner.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              [text],
            );
        try {
          expect(await matches('oldword'), isEmpty);
          expect(
            (await _search(type, 'currentword')).single.id,
            'synthetic-original',
          );
          update = repo.update({
            'id': 'synthetic-original',
            'payload': {'text': 'editedword'},
          });
          if (pending) {
            await Future.any([
              proxy.committed.future,
              update.then((_) => expect(proxy.committed.isCompleted, isTrue)),
            ]);
            expect(await matches('currentword'), hasLength(1));
            expect(await matches('editedword'), isEmpty);
            expect(
              await _search(type, 'currentword'),
              isEmpty,
              reason: 'A committed edit must not expose the old stored snippet',
            );
            // Queue deletion while the update still holds the database lock.
            // Deletion owns the FTS lock before deferred reindex is scheduled.
            deletion = repo.delete('synthetic-original');
            proxy.release.complete();
            expect(await update, 1);
          } else {
            expect(await update, 1);
            await repo.waitForFtsReindexForTest();
            expect(await matches('currentword'), isEmpty);
            expect(
              (await _search(type, 'editedword')).single.id,
              'synthetic-original',
            );
            deletion = repo.delete('synthetic-original');
          }
          expect(await deletion, 1);
          await repo.waitForFtsReindexForTest();
          for (final text in ['oldword', 'currentword', 'editedword']) {
            expect(await matches(text), isEmpty);
          }
          await repo.insert(
            _message(type, 'synthetic-replacement', {
              'text': 'replacementword',
            }),
          );
          await repo.waitForFtsReindexForTest();
          expect((await repo.find('synthetic-replacement'))!.autoId, rowid);
          expect(
            (await _search(type, 'replacementword')).single.id,
            'synthetic-replacement',
          );
          for (final text in ['oldword', 'currentword', 'editedword']) {
            expect(await matches(text), isEmpty);
            expect(await _search(type, text), isEmpty);
          }
        } finally {
          if (!proxy.release.isCompleted) proxy.release.complete();
          try {
            if (update != null) await update;
            if (deletion != null) await deletion;
            await repo.waitForFtsReindexForTest();
          } finally {
            SqliteService.setDbForTest(null);
            await inner.close();
          }
        }
      });
    }

    for (final version in [38, 39, 40]) {
      test(
        '$type v$version preserves Unicode text/quote/location searches',
        () async {
          final db = await openFixtureDatabaseAtVersion(
            version: version == 38 ? 37 : version,
          );
          addTearDown(() async {
            SqliteService.setDbForTest(null);
            if (db.isOpen) await db.close();
          });
          if (version == 38) {
            await db.transaction((txn) async {
              for (final statement in upgradeV38Fts.sqlStatements) {
                await txn.execute(statement);
              }
            });
          }
          SqliteService.setDbForTest(db);
          final repo = MessageRepo(tableName: MessageRepo.getTableName(type));
          try {
            final cases = <(String, Map<String, dynamic>)>[
              ('text', {'text': '\n\u00a0needle\ufeff\u3000'}),
              ('quote', {'quote_text': '\ufeffneedle\n'}),
              (
                'location',
                {'title': '\u3000needle\u3000', 'address': '\u00a0road\u00a0'},
              ),
            ];
            for (var index = 0; index < cases.length; index++) {
              final (msgType, payload) = cases[index];
              await repo.insert(
                _message(type, 'unicode-$index', payload, msgType: msgType),
              );
            }
            await repo.waitForFtsReindexForTest();
            expect(
              (await _search(type, 'needle')).map((row) => row.id),
              unorderedEquals(['unicode-0', 'unicode-1', 'unicode-2']),
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
}
