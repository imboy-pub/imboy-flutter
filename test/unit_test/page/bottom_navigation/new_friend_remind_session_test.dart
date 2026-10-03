import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel(uid: '100', account: 'synthetic');
  void select(String uid) => state = UserModel(uid: uid, account: 'synthetic');
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _Database implements Database {
  final entered = Completer<void>();
  final release = Completer<List<Map<String, Object?>>>();
  final secondEntered = Completer<void>();
  final secondRelease = Completer<List<Map<String, Object?>>>();
  int queries = 0;
  @override
  bool get isOpen => true;
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
  }) {
    expect(whereArgs, [0, '100', '100']);
    queries++;
    if (queries == 1) {
      entered.complete();
      return release.future;
    }
    secondEntered.complete();
    return secondRelease.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stale in [false, true]) {
    test('friend reminders account changed=$stale', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _Database();
      SqliteService.setDbForTest(db);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        ],
      );
      final subscription = container.listen(newFriendRemindProvider, (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
        SqliteService.setDbForTest(null);
      });
      final pending = container
          .read(newFriendRemindProvider.notifier)
          .countReminders();
      await db.entered.future;
      if (stale) {
        await StorageService.to.setString(Keys.currentUid, '101');
        container.read(_account.notifier).select('101');
        await container.pump();
      }
      db.release.complete([
        {NewFriendRepo.from: '200'},
        {NewFriendRepo.from: '200'},
        {NewFriendRepo.from: null},
      ]);
      await pending;
      expect(
        container.read(newFriendRemindProvider),
        stale ? <String>{} : {'200'},
      );
      if (!stale) {
        container.read(_account.notifier).select('100');
        await container.pump();
        expect(container.read(newFriendRemindProvider), {'200'});
        await StorageService.to.setString(Keys.currentUid, '101');
        container.read(_account.notifier).select('101');
        await container.pump();
        expect(container.read(newFriendRemindProvider), isEmpty);
      }
    });
  }
  for (final boundary in ['concurrent', 'session', 'dispose']) {
    test('friend reminders reject old result at $boundary', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _Database();
      SqliteService.setDbForTest(db);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        ],
      );
      final observed = <Set<String>>[];
      final subscription = container.listen(
        newFriendRemindProvider,
        (_, next) => observed.add(Set.of(next)),
      );
      final dispose = _registerCleanup(container, subscription, db);
      final notifier = container.read(newFriendRemindProvider.notifier);
      final pending = notifier.countReminders();
      await db.entered.future;
      if (boundary == 'concurrent') {
        final newer = notifier.countReminders();
        await db.secondEntered.future;
        db.secondRelease.complete([
          {NewFriendRepo.from: '300'},
        ]);
        await newer;
        expect(container.read(newFriendRemindProvider), {'300'});
      } else if (boundary == 'session') {
        await _changeSession();
      } else {
        dispose();
      }
      db.release.complete([
        {NewFriendRepo.from: '200'},
      ]);
      await pending;
      expect(observed.any((value) => value.contains('200')), isFalse);
      if (boundary != 'dispose') {
        expect(
          container.read(newFriendRemindProvider),
          boundary == 'concurrent' ? {'300'} : <String>{},
        );
        dispose();
      }
    });
  }
}

Future<void> _changeSession() async {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'write' &&
        (call.arguments as Map)['key'] == 'secure_token') {
      throw PlatformException(code: 'synthetic-login-stop');
    }
    return null;
  });
  final generation = UserRepoLocal.to.sessionGeneration;
  try {
    await expectLater(
      UserRepoLocal.to.loginAfter('synthetic', {
        'uid': '100',
        'token': 'synthetic-token',
        'refreshtoken': 'synthetic-refresh',
      }),
      throwsA(isA<PlatformException>()),
    );
    expect(UserRepoLocal.to.sessionGeneration, generation + 1);
    expect(UserRepoLocal.to.currentUid, '100');
  } finally {
    messenger.setMockMethodCallHandler(channel, null);
  }
}

void Function() _registerCleanup(
  ProviderContainer container,
  ProviderSubscription<Set<String>> subscription,
  _Database db,
) {
  bool disposed = false;
  void dispose() {
    if (disposed) return;
    disposed = true;
    subscription.close();
    container.dispose();
  }

  addTearDown(() async {
    if (!db.release.isCompleted) db.release.complete([]);
    if (!db.secondRelease.isCompleted) db.secondRelease.complete([]);
    await pumpEventQueue();
    dispose();
    SqliteService.setDbForTest(null);
  });
  return dispose;
}
