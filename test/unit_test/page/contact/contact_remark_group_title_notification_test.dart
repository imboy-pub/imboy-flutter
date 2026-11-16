import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/ui_events.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/api/contact_api.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_provider.dart';
import 'package:imboy/page/conversation/widget/web_conversation_group_title.dart';

class _Endpoint implements Env {
  @override
  String get apiBaseUrl => 'http://127.0.0.1:19801';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends ContactApi {
  _Api(this.result);
  final Future<bool> result;
  @override
  Future<bool> changeRemark(String uid, String remark) => result;
}

// The wrapper delays only completion: SQLite executes the real write inside
// its real transaction before the production ownership check runs.
class _HeldRemarkDatabase implements Database {
  _HeldRemarkDatabase(this.real);
  final Database real;
  final entered = Completer<int>();
  final release = Completer<void>();
  @override
  bool get isOpen => real.isOpen;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) => real.transaction(
    (txn) => action(_HeldRemarkTransaction(txn, entered, release)),
    exclusive: exclusive,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeldRemarkTransaction implements Transaction {
  _HeldRemarkTransaction(this.real, this.entered, this.release);
  final Transaction real;
  final Completer<int> entered;
  final Completer<void> release;
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final count = await real.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    entered.complete(count);
    await release.future;
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Database> _remarkDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openFixtureDatabaseAtVersion(version: 39);
  for (final row in [
    (owner: '1', peer: '2'),
    (owner: '9', peer: '2'),
    (owner: '1', peer: '3'),
  ]) {
    await db.insert('contact', {
      'user_id': row.owner,
      'peer_id': row.peer,
      'nickname': 'SYNTHETIC',
      'remark': 'BEFORE',
    });
  }
  return db;
}

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Future<void> _replaceSameUidSession() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
        if (call.method == 'write' &&
            (call.arguments as Map)['key'] == 'secure_token') {
          throw PlatformException(code: 'synthetic-login-stop');
        }
        return null;
      });
  final previous = UserRepoLocal.to.sessionGeneration;
  final login = UserRepoLocal.to.loginAfter('', {
    'uid': '1',
    'token': 'synthetic-token',
    'refreshtoken': 'synthetic-refresh',
  });
  final rejected = expectLater(login, throwsA(isA<PlatformException>()));
  expect(UserRepoLocal.to.sessionGeneration, previous + 1);
  expect(UserRepoLocal.to.currentUid, '1');
  await rejected;
  UserRepoLocal.to.clearAuthTransitionFailureForTest();
  expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
  expect(UserRepoLocal.to.currentUid, '1');
  expect(UserRepoLocal.to.sessionGeneration, previous + 1);
}

void main() {
  late String previousEnvironment;
  setUp(() async {
    previousEnvironment = currentEnv;
    currentEnv = 'remark-title-fixture';
    envMap[currentEnv] = _Endpoint();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    UserRepoLocal.to.clearAuthTransitionFailureForTest();
  });
  tearDown(() {
    envMap.remove('remark-title-fixture');
    currentEnv = previousEnvironment;
  });

  for (final mode in ['commit', 'owner', 'same-uid-generation']) {
    final switchOwner = mode != 'commit';
    test('Real SQLite remark transaction $mode', () async {
      final db = await _remarkDatabase();
      final held = _HeldRemarkDatabase(db);
      SqliteService.setDbForTest(held);
      final notifier = ContactSettingTagNotifier(
        contactApi: _Api(Future.value(true)),
      );
      final container = ProviderContainer(
        overrides: [contactSettingTagProvider.overrideWith(() => notifier)],
      );
      final keep = container.listen(contactSettingTagProvider, (_, _) {});
      final events = <ContactUpdatedEvent>[];
      final eventSub = AppEventBus.on<ContactUpdatedEvent>().listen(events.add);
      final remark = '合成长备注 ' * 100;
      // Attach error handling before releasing the transaction, including cleanup.
      final outcome = notifier
          .changeRemark('2', remark)
          .then<Object>((value) => value, onError: (Object error) => error);
      try {
        expect(
          await held.entered.future.timeout(const Duration(seconds: 5)),
          1,
        );
        expect(events, isEmpty);
        if (mode == 'owner')
          await StorageService.to.setString(Keys.currentUid, '9');
        if (mode == 'same-uid-generation') await _replaceSameUidSession();
        held.release.complete();
        expect(await outcome, switchOwner ? isA<StateError>() : isTrue);
        await Future<void>.delayed(Duration.zero);
        final rows = await db.query('contact', orderBy: 'user_id, peer_id');
        expect(rows, hasLength(3));
        for (final row in rows) {
          final target =
              row['user_id'].toString() == '1' &&
              row['peer_id'].toString() == '2';
          expect(row['remark'], target && !switchOwner ? remark : 'BEFORE');
        }
        expect(events, hasLength(switchOwner ? 0 : 1));
        if (!switchOwner) {
          expect(events.single.userId, '2');
          expect(events.single.updateType, ContactUpdateType.remarkUpdated);
        }
      } finally {
        keep.close();
        container.dispose();
        if (!held.release.isCompleted) held.release.complete();
        await outcome;
        await eventSub.cancel();
        SqliteService.setDbForTest(null);
        await db.close();
        if (mode == 'same-uid-generation') {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_secureStorageChannel, null);
          UserRepoLocal.to.clearAuthTransitionFailureForTest();
        }
      }
    });
  }

  test(
    'Real changeRemark success publishes only after local persistence',
    () async {
      var stored = 'BEFORE';
      var calls = 0;
      final titles = WebConversationGroupTitles(
        loader: (_, _, _) async {
          calls++;
          return stored;
        },
      );
      addTearDown(titles.dispose);
      titles.title('100');
      await Future<void>.delayed(Duration.zero);
      final persisted = Completer<int>();
      final notifier = ContactSettingTagNotifier(
        contactApi: _Api(Future.value(true)),
        persistRemark: (_, remark, account, current) async {
          expect(account, '1');
          expect(current(), isTrue);
          final changed = await persisted.future;
          stored = remark;
          return changed;
        },
      );
      final container = ProviderContainer(
        overrides: [contactSettingTagProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(contactSettingTagProvider, (_, _) {});
      addTearDown(sub.close);
      final result = notifier.changeRemark('2', 'AFTER');
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), 'BEFORE');
      expect(calls, 1);
      persisted.complete(1);
      expect(await result, isTrue);
      await Future<void>.delayed(Duration.zero);
      titles.title('100');
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), 'AFTER');
      expect(calls, 2);
    },
  );

  test(
    'Late network result cannot persist or notify another account',
    () async {
      final response = Completer<bool>();
      var writes = 0;
      final notifier = ContactSettingTagNotifier(
        contactApi: _Api(response.future),
        persistRemark: (_, _, _, _) async {
          writes++;
          return 1;
        },
      );
      final container = ProviderContainer(
        overrides: [contactSettingTagProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(contactSettingTagProvider, (_, _) {});
      addTearDown(sub.close);
      final result = notifier.changeRemark('2', 'AFTER');
      await StorageService.to.setString(Keys.currentUid, '9');
      response.complete(true);
      expect(await result, isFalse);
      expect(writes, 0);
    },
  );
}
