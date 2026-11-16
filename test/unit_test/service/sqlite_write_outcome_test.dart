import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _PendingWriteDatabase implements Database {
  final completions = <Completer<int>>[];

  @override
  bool get isOpen => true;

  Future<int> _write() {
    final completion = Completer<int>();
    completions.add(completion);
    return completion.future;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _write();

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _write();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: 'synthetic-write-owner',
    });
    await StorageService.init();
  });
  tearDown(() => SqliteService.setDbForTest(null));

  for (final insert in [true, false]) {
    Future<int> write() => insert
        ? SqliteService.to.insert('synthetic', {'id': 'one'}, timeoutMs: 5)
        : SqliteService.to.update('synthetic', {'value': 'one'}, timeoutMs: 5);

    test(
      '${insert ? 'insert' : 'update'} waits for late success and keeps the write lock',
      () {
        final db = _PendingWriteDatabase();
        SqliteService.setDbForTest(db);
        fakeAsync((clock) {
          int? firstResult;
          int? nextResult;
          unawaited(write().then((result) => firstResult = result));
          clock.flushMicrotasks();
          expect(db.completions, hasLength(1));
          clock.elapse(const Duration(milliseconds: 10));
          expect(
            firstResult,
            isNull,
            reason: 'pending SQL must not report a false failure',
          );
          unawaited(write().then((result) => nextResult = result));
          clock.flushMicrotasks();
          expect(
            db.completions,
            hasLength(1),
            reason: 'the first SQL still owns the lock',
          );
          db.completions.first.complete(7);
          clock.flushMicrotasks();
          expect(firstResult, 7);
          expect(db.completions, hasLength(2));
          db.completions.last.complete(1);
          clock.flushMicrotasks();
          expect(nextResult, 1);
        });
      },
    );

    test(
      '${insert ? 'insert' : 'update'} propagates the actual late failure without redispatch',
      () {
        final db = _PendingWriteDatabase();
        SqliteService.setDbForTest(db);
        fakeAsync((clock) {
          Object? failure;
          unawaited(
            write().then<void>(
              (_) => fail('write unexpectedly succeeded'),
              onError: (Object error) {
                failure = error;
              },
            ),
          );
          clock.flushMicrotasks();
          clock.elapse(const Duration(milliseconds: 10));
          expect(failure, isNull);
          final actual = StateError('synthetic write failure');
          db.completions.single.completeError(actual);
          clock.flushMicrotasks();
          expect(failure, same(actual));
          expect(db.completions, hasLength(1));
        });
      },
    );
  }
}
