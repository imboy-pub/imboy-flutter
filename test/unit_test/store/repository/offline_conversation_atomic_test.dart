import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _PausedMessageReadDatabase implements Database {
  _PausedMessageReadDatabase(
    this.inner, {
    this.pauseAfterCommit = false,
    this.pauseInTransaction = false,
    this.pauseContactAfterCommit = false,
  });
  final Database inner;
  final bool pauseAfterCommit;
  final bool pauseInTransaction;
  final bool pauseContactAfterCommit;
  bool committed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool paused = false;

  @override
  bool get isOpen => inner.isOpen;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) async {
    final result = await inner.transaction(
      (txn) => action(pauseInTransaction ? _PausedTransaction(txn, this) : txn),
      exclusive: exclusive,
    );
    committed = true;
    if (pauseAfterCommit && !paused) {
      paused = true;
      entered.complete();
      await release.future;
    }
    return result;
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
  }) async {
    final rows = await inner.query(
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
    if (!paused &&
        ((!pauseAfterCommit &&
                !pauseContactAfterCommit &&
                table == MessageRepo.c2cTable) ||
            (pauseContactAfterCommit && committed && table == 'contact'))) {
      paused = true;
      entered.complete();
      await release.future;
    }
    return rows;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => inner.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      inner.rawUpdate(sql, arguments);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PausedTransaction implements Transaction {
  _PausedTransaction(this.inner, this.owner);
  final Transaction inner;
  final _PausedMessageReadDatabase owner;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final result = await inner.rawQuery(sql, arguments);
    if (!owner.paused && sql.contains('FROM msg_c2c WHERE id')) {
      owner.paused = true;
      owner.entered.complete();
      await owner.release.future;
    }
    return result;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => inner.insert(
    table,
    values,
    nullColumnHack: nullColumnHack,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => inner.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );

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

const _messages = <Map<String, dynamic>>[
  {
    'msg_id': '116837000000000001',
    'type': 'C2C',
    'from': '995012',
    'to': '995011',
    'msg_type': 'text',
    'payload': {'text': ''},
    'created_at': 1750000000000,
  },
];

Future<void> _expectUpdateRecovery(Database db, MessageRepo repo) async {
  final second = [
    {..._messages.single, 'msg_id': '116837000000000002'},
  ];
  await db.execute(
    "CREATE TRIGGER fail_update BEFORE UPDATE ON conversation BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
  );
  await expectLater(repo.batchInsertOfflineMessages(second), throwsA(anything));
  expect((await db.query('msg_c2c')).length, 1);
  expect((await db.query('conversation')).single['unread_num'], 1);
  await db.execute('DROP TRIGGER fail_update');
  for (var attempt = 0; attempt < 2; attempt++) {
    expect(await repo.batchInsertOfflineMessages(second), [
      '116837000000000002',
    ]);
    expect((await db.query('msg_c2c')).length, 2);
    expect((await db.query('conversation')).single['unread_num'], 2);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => UserRepoLocal.to.clearAuthTransitionFailureForTest());
  test('offline message is not published after session changes during mapping', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final inner = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final db = _PausedMessageReadDatabase(inner, pauseContactAfterCommit: true);
    final container = ProviderContainer();
    final events = <DataWrapperEvent<dynamic>>[];
    final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
      events.add,
    );
    final repo = MessageRepo(tableName: MessageRepo.c2cTable);
    try {
      await applyBaselineSchema(inner);
      await inner.execute(
        'ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0',
      );
      await inner.insert('contact', {'user_id': 995011, 'peer_id': 995012});
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      SqliteService.setDbForTest(db);
      MessageRepo.setProviderContainer(container);
      MessageRepo.setCurrentActiveConversationUk3('C2C_995011_995012');
      final pending = repo.batchInsertOfflineMessages(_messages);
      final outcome = pending.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await db.entered.future.timeout(const Duration(seconds: 5));
      await StorageService.to.setString(Keys.currentUid, '995013');
      db.release.complete();
      expect(await outcome, isA<StateError>());
      await Future<void>.delayed(Duration.zero);
      expect(events.where((event) => event.dataType == 'Message'), isEmpty);
      expect(await inner.query('msg_c2c'), hasLength(1));
    } finally {
      if (!db.release.isCompleted) db.release.complete();
      await repo.waitForFtsReindexForTest();
      await subscription.cancel();
      MessageRepo.setCurrentActiveConversationUk3(null);
      container.dispose();
      SqliteService.setDbForTest(null);
      await inner.close();
    }
  });
  test('offline S2C stops after session changes during callback', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final entered = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'write' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            throw PlatformException(code: 'synthetic-login-stop');
          }
          return null;
        });
    try {
      await applyBaselineSchema(db);
      SqliteService.setDbForTest(db);
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      final pending = repo.batchInsertOfflineMessages(
        [
          {'msg_id': 'first', 'type': 'S2C'},
          {'msg_id': 'second', 'type': 'S2C'},
        ],
        onS2CMessage: (_) async {
          calls++;
          entered.complete();
          await release.future;
        },
      );
      final outcome = pending.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await entered.future.timeout(const Duration(seconds: 5));
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '995013',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      release.complete();
      expect(await outcome, isA<StateError>());
      expect(calls, 1);
    } finally {
      if (!release.isCompleted) release.complete();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
  test('offline transaction rolls back when session changes', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final inner = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final container = ProviderContainer();
    final db = _PausedMessageReadDatabase(inner, pauseInTransaction: true);
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'write' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            throw PlatformException(code: 'synthetic-login-stop');
          }
          return null;
        });
    try {
      await applyBaselineSchema(inner);
      await inner.execute(
        'ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      SqliteService.setDbForTest(db);
      MessageRepo.setProviderContainer(container);
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      final pending = repo.batchInsertOfflineMessages(_messages);
      final outcome = pending.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await db.entered.future.timeout(const Duration(seconds: 5));
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '995013',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      db.release.complete();
      expect(await outcome, isA<StateError>());
      expect(await inner.query('msg_c2c'), isEmpty);
      expect(await inner.query('conversation'), isEmpty);
      await repo.waitForFtsReindexForTest();
    } finally {
      if (!db.release.isCompleted) db.release.complete();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      container.dispose();
      SqliteService.setDbForTest(null);
      await inner.close();
    }
  });
  test('offline index callback retains the original session', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final inner = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final container = ProviderContainer();
    final db = _PausedMessageReadDatabase(inner, pauseAfterCommit: true);
    final repo = MessageRepo(tableName: MessageRepo.c2cTable);
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'write' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            throw PlatformException(code: 'synthetic-login-stop');
          }
          return null;
        });
    try {
      await applyBaselineSchema(inner);
      await inner.execute(
        'ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      await inner.execute('DROP TABLE msg_c2c_fts');
      await inner.execute(
        'CREATE VIRTUAL TABLE msg_c2c_fts USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content)',
      );
      SqliteService.setDbForTest(db);
      MessageRepo.setProviderContainer(container);
      final pending = repo.batchInsertOfflineMessages([
        {
          ..._messages.single,
          'payload': {'text': 'oldaccountword'},
        },
      ]);
      final outcome = pending.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await db.entered.future.timeout(const Duration(seconds: 5));
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '995013',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      db.release.complete();
      expect(await outcome, isA<StateError>());
      expect(await inner.query('msg_c2c'), hasLength(1));
      await repo.waitForFtsReindexForTest();
      expect(await inner.query('msg_c2c_fts'), isEmpty);
    } finally {
      if (!db.release.isCompleted) db.release.complete();
      await repo.waitForFtsReindexForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      container.dispose();
      SqliteService.setDbForTest(null);
      await inner.close();
    }
  });
  test('offline indexing cannot overwrite a later edit', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final inner = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final container = ProviderContainer();
    final db = _PausedMessageReadDatabase(inner);
    final offlineRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    final editRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    try {
      await applyBaselineSchema(inner);
      await inner.execute(
        'ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await inner.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      await inner.execute('DROP TABLE msg_c2c_fts');
      await inner.execute(
        'CREATE VIRTUAL TABLE msg_c2c_fts USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content)',
      );
      SqliteService.setDbForTest(db);
      MessageRepo.setProviderContainer(container);
      final inserted = await offlineRepo.batchInsertOfflineMessages([
        {
          ..._messages.single,
          'payload': {'text': 'oldword'},
        },
      ]);
      expect(inserted, ['116837000000000001']);
      await db.entered.future.timeout(const Duration(seconds: 5));
      expect(
        await editRepo.update({
          'id': '116837000000000001',
          'payload': {'text': 'newword'},
        }),
        1,
      );
      db.release.complete();
      await offlineRepo.waitForFtsReindexForTest();
      await editRepo.waitForFtsReindexForTest();
      expect(
        (await inner.query('msg_c2c_fts')).single['text_content'],
        'newword',
      );
    } finally {
      if (!db.release.isCompleted) db.release.complete();
      await offlineRepo.waitForFtsReindexForTest();
      await editRepo.waitForFtsReindexForTest();
      container.dispose();
      SqliteService.setDbForTest(null);
      await inner.close();
    }
  });
  test('conversation failure rolls back message; retry rebuilds both exactly once', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final container = ProviderContainer();
    SqliteService.setDbForTest(db);
    MessageRepo.setProviderContainer(container);
    try {
      await applyBaselineSchema(db);
      await db.execute(
        'ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0',
      );
      await db.insert('contact', {'user_id': 995011, 'peer_id': 995012});
      await db.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      await db.execute(
        "CREATE TRIGGER fail_conversation BEFORE INSERT ON conversation BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await expectLater(
        repo.batchInsertOfflineMessages(_messages),
        throwsA(anything),
      );
      expect(await db.query('msg_c2c'), isEmpty);
      expect(await db.query('conversation'), isEmpty);
      await db.execute('DROP TRIGGER fail_conversation');
      for (var attempt = 0; attempt < 2; attempt++) {
        expect(await repo.batchInsertOfflineMessages(_messages), [
          '116837000000000001',
        ]);
        expect((await db.query('msg_c2c')).length, 1);
        expect((await db.query('conversation')).single['unread_num'], 1);
      }
      await _expectUpdateRecovery(db, repo);
    } finally {
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
