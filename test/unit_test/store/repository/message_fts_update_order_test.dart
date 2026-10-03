import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedUpdateDatabase implements Database {
  _DelayedUpdateDatabase(this.inner);
  final Database inner;
  final entered = Completer<void>();
  final release = Completer<int>();
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
    entered.complete();
    final result = await release.future;
    if (result == 0) return 0;
    return inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

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
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      inner.rawUpdate(sql, arguments);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  for (final type in ['C2C', 'C2G']) {
    for (final outcome in [
      'success',
      'missing',
      'failure',
      'stale',
      'mutated_input',
    ]) {
      test('FTS update order $type $outcome', () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        final inner = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
        );
        final db = _DelayedUpdateDatabase(inner);
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final row = MessageModel(
          'synthetic-order',
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
        await inner.execute(
          'CREATE TABLE $table (${{...row.keys, ...MessageRepo.c2cColumns}.map((k) => '"$k"').join(', ')})',
        );
        await inner.insert(table, row);
        await inner.execute(
          'CREATE VIRTUAL TABLE ${table}_fts USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content)',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'write' &&
                  (call.arguments as Map)['key'] == 'secure_token') {
                throw PlatformException(code: 'synthetic-login-stop');
              }
              return null;
            });
        final repo = MessageRepo(tableName: table);
        try {
          final input = <String, dynamic>{
            'id': 'synthetic-order',
            'payload': {'text': 'newword'},
          };
          final result = repo
              .update(input)
              .then<Object>((value) => value, onError: (Object error) => error);
          await db.entered.future;
          // Drain the real connection read queue without waiting on the SQL lock.
          await inner.query(table);
          expect(await inner.query('${table}_fts'), isEmpty);
          if (outcome == 'mutated_input') input['id'] = 'synthetic-other';
          if (outcome == 'stale') {
            await expectLater(
              UserRepoLocal.to.loginAfter('synthetic-session', {
                'uid': '101',
                'token': 'synthetic-token',
                'refreshtoken': 'synthetic-refresh',
              }),
              throwsA(isA<PlatformException>()),
            );
          }
          if (outcome == 'failure') {
            db.release.completeError(StateError('synthetic-update-failure'));
          } else {
            db.release.complete(outcome == 'missing' ? 0 : 1);
          }
          final actual = await result;
          await repo.waitForFtsReindexForTest();
          final indexed = await inner.query('${table}_fts');
          if (outcome == 'success' || outcome == 'mutated_input') {
            expect(actual, 1);
            expect(indexed.single['text_content'], 'newword');
            expect(
              await inner.rawQuery(
                'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
                ['oldword'],
              ),
              isEmpty,
            );
            expect(
              (await inner.rawQuery(
                'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
                ['newword'],
              )).single['id'],
              'synthetic-order',
            );
          } else {
            expect(indexed, isEmpty);
            if (outcome == 'failure') expect(actual, isA<StateError>());
            if (outcome == 'missing') expect(actual, 0);
            if (outcome == 'stale') expect(actual, 1);
          }
          expect(input['payload'], {'text': 'newword'});
        } finally {
          if (!db.release.isCompleted) db.release.complete(0);
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await inner.close();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        }
      });
    }
  }
}
