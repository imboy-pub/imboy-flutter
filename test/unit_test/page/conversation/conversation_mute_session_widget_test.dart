import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
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
  testWidgets('过期会话的免打扰写失败不向新会话提示', (tester) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
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
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              builder: AppLoading.init(),
              home: const ChatSettingPage('8006', type: 'C2C'),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      final toggle = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch).first,
      );
      expect(toggle.onChanged, isNotNull);
      toggle.onChanged!(true);
      await tester.runAsync(() async {
        await wrapped.entered.future;
        final login = UserRepoLocal.to.loginAfter('synthetic', {
          'uid': '995011',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        });
        final rejected = expectLater(login, throwsA(isA<PlatformException>()));
        wrapped.release.complete();
        await rejected;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      final current = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch).first,
      );
      expect(current.value, isFalse);
      expect(current.onChanged, isNull);
      expect(find.text(t.common.errorNetwork), findsNothing);
      expect(find.text(t.common.enabled), findsNothing);
      expect(
        (await db.query(
          'conversation',
          where: 'peer_id = ?',
          whereArgs: [8006],
        )).single['is_muted'],
        0,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      SqliteService.setDbForTest(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, null);
      await db.close();
    }
  });
}
