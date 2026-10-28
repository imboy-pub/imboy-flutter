import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _PausedDatabase implements Database {
  _PausedDatabase(this.real);
  final Database real;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  bool get isOpen => real.isOpen;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => real.transaction(
    (txn) => action(_PausedTransaction(txn, entered, release)),
    exclusive: exclusive,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PausedTransaction implements Transaction {
  _PausedTransaction(this.real, this.entered, this.release);
  final Transaction real;
  final Completer<void> entered;
  final Completer<void> release;
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
  }) => real.query(
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
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final result = await real.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    entered.complete();
    await release.future;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'same UID new session during write rolls back actual SQLite transaction',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openFixtureDatabaseAtVersion(version: 32);
      await db.insert('conversation', {
        'user_id': '995011',
        'peer_id': 8006,
        'type': 'C2C',
        'is_muted': 0,
        'is_show': 1,
        'last_time': 1,
        'last_msg_id': '',
        'last_msg_status': 11,
        'unread_num': 0,
        'mention_unread': 0,
        'msg_type': 'text',
        'payload': '{}',
      });
      final wrapped = _PausedDatabase(db);
      SqliteService.setDbForTest(wrapped);
      const secure = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, (call) async {
            if (call.method == 'write' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              throw PlatformException(code: 'synthetic-login-stop');
            }
            return null;
          });
      try {
        final pending = ConversationRepo().setMutedForPeer('C2C', '8006', true);
        final rejected = expectLater(pending, throwsStateError);
        await wrapped.entered.future;
        final previous = UserRepoLocal.to.sessionGeneration;
        final login = UserRepoLocal.to.loginAfter('synthetic', {
          'uid': '995011',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        });
        final loginRejected = expectLater(
          login,
          throwsA(isA<PlatformException>()),
        );
        expect(UserRepoLocal.to.sessionGeneration, previous + 1);
        expect(UserRepoLocal.to.currentUid, '995011');
        wrapped.release.complete();
        await rejected;
        await loginRejected;
        final rows = await db.query(
          'conversation',
          where: 'peer_id = ?',
          whereArgs: [8006],
        );
        expect(rows.single['is_muted'], 0);
      } finally {
        SqliteService.setDbForTest(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secure, null);
        await db.close();
      }
    },
  );
}
