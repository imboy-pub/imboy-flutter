import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/channel_inbox_preferences.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/channel_inbox_actions.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_inbox_preference_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _Session extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (uid: 'a', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope value) =>
      value == current && !current.transitioning && current.uid.isNotEmpty;
  void rotate(String uid) {
    current = (
      uid: uid,
      generation: current.generation + 1,
      transitioning: false,
    );
    notifyListeners();
  }
}

class _UnusedApi extends Fake implements ChannelApi {}

Future<Database> _database() async {
  final db = await openFixtureDatabaseAtVersion(version: 39);
  await db.insert('channel', {
    'id': 1,
    'scope': 'personal',
    'name': 'fixture',
    'creator_id': 1,
    'created_at': 1,
    'updated_at': 1,
    'is_subscribed': 1,
  });
  await db.insert('channel_subscription', {
    'channel_id': 1,
    'subscribed_at': 1,
    'unread_count': 9,
    'is_pinned': 1,
    'is_muted': 1,
    'notifications_enabled': 0,
  });
  addTearDown(db.close);
  return db;
}

class _PausedDatabase implements Database {
  _PausedDatabase(this.inner);
  final Database inner;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => inner.transaction(
    (txn) => action(_PausedTransaction(txn, entered, release)),
    exclusive: exclusive,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PausedTransaction implements Transaction {
  _PausedTransaction(this.inner, this.entered, this.release);
  final Transaction inner;
  final Completer<void> entered, release;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final result = await inner.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'pin writes only the subscription pin fact and rechecks personal source',
    () async {
      final db = await _database();
      final session = _Session();
      final owner = session.current;
      final service = ChannelService.forTest(
        api: _UnusedApi(),
        repo: ChannelRepo(),
        bindPublishDatabase: true,
      );
      final before = (await db.query('channel_subscription')).single;
      Future<bool> pin(bool value) => setPersonalInboxChannelPinned(
        service: service,
        channelId: '1',
        pinned: value,
        isCurrent: () => session.isCurrent(owner),
        database: () async => db,
      );
      expect(await pin(false), isTrue);
      expect((await db.query('channel_subscription')).single, {
        ...before,
        'is_pinned': 0,
      });
      await db.update(
        'channel',
        {'scope': 'workspace', 'workspace_id': '7'},
        where: 'id = ?',
        whereArgs: [1],
      );
      expect(await pin(true), isFalse);
      expect((await db.query('channel_subscription')).single, {
        ...before,
        'is_pinned': 0,
      });
    },
  );
  test(
    'hide/restore persist only presentation; subscription facts stay unchanged',
    () async {
      final db = await _database();
      final session = _Session();
      ChannelInboxPreferenceRepo repo() => ChannelInboxPreferenceRepo(
        session: session,
        database: () async => db,
        environment: () => 'fixture',
        endpoint: () => 'https://one.invalid',
      );
      final store = repo();
      final scope = store.captureScope();
      final container = ProviderContainer(
        overrides: [
          channelInboxPreferenceRepoProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(channelInboxHiddenIdsProvider.future);
      final notifier = container.read(channelInboxHiddenIdsProvider.notifier);
      final before = await db.query('channel_subscription');
      expect(await notifier.setHidden(scope, '1', true), isTrue);
      expect(container.read(channelInboxHiddenIdsProvider).value, {'1'});
      expect(await repo().hiddenIds(scope), {'1'});
      expect(await db.query('channel_subscription'), before);
      expect(await notifier.setHidden(scope, '1', false), isTrue);
      expect(container.read(channelInboxHiddenIdsProvider).value, isEmpty);
      expect(await repo().hiddenIds(scope), isEmpty);
      expect(await db.query('channel_subscription'), before);
    },
  );
  test(
    'account databases and endpoints isolate identical channel ids',
    () async {
      final first = await _database(), second = await _database();
      final session = _Session();
      var endpoint = 'https://one.invalid';
      var environment = 'one';
      final store = ChannelInboxPreferenceRepo(
        session: session,
        database: () async =>
            session.current.uid == 'a' && environment == 'one' ? first : second,
        environment: () => environment,
        endpoint: () => endpoint,
      );
      final original = store.captureScope();
      expect(await store.setHidden(original, '1', true), isTrue);
      endpoint = 'https://two.invalid';
      expect(await store.hiddenIds(store.captureScope()), isEmpty);
      expect(await store.setHidden(original, '1', false), isFalse);
      endpoint = 'https://one.invalid';
      session.rotate('b');
      expect(await store.hiddenIds(store.captureScope()), isEmpty);
      session.rotate('a');
      environment = 'two';
      expect(await store.hiddenIds(store.captureScope()), isEmpty);
      environment = 'one';
      expect(await store.hiddenIds(store.captureScope()), {'1'});
    },
  );
  test('unknown and workspace sources cannot be hidden by stale UI', () async {
    final db = await _database();
    final session = _Session();
    final store = ChannelInboxPreferenceRepo(
      session: session,
      database: () async => db,
      endpoint: () => 'https://one.invalid',
    );
    for (final row in [
      {'scope': null},
      {'scope': 'workspace', 'workspace_id': '5'},
      {'scope': 'personal', 'workspace_id': '5'},
      {'scope': 'personal', 'workspace_id': null, 'is_subscribed': 0},
    ]) {
      await db.update('channel', row, where: 'id = ?', whereArgs: [1]);
      expect(await store.setHidden(store.captureScope(), '1', true), isFalse);
    }
    expect(await db.query('channel_inbox_preference'), isEmpty);
  });
  test(
    'same uid reauthentication during insert rolls back real SQLite write',
    () async {
      final db = await _database();
      final paused = _PausedDatabase(db);
      final session = _Session();
      final store = ChannelInboxPreferenceRepo(
        session: session,
        database: () async => paused,
        endpoint: () => 'https://one.invalid',
      );
      final write = store.setHidden(store.captureScope(), '1', true);
      await paused.entered.future;
      session.rotate('a');
      paused.release.complete();
      expect(await write, isFalse);
      expect(await db.query('channel_inbox_preference'), isEmpty);
    },
  );
  test(
    'preference read failure is an error instead of revealing hidden rows',
    () async {
      final session = _Session();
      final store = ChannelInboxPreferenceRepo(
        session: session,
        database: () async => null,
        endpoint: () => 'https://one.invalid',
      );
      await expectLater(
        store.hiddenIds(store.captureScope()),
        throwsStateError,
      );
      expect(await store.setHidden(store.captureScope(), '1', true), isFalse);
    },
  );
}
