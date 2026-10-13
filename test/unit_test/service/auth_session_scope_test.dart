import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class SyntheticAuthDatabase implements Database {
  @override
  bool get isOpen => true;
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = UserRepoLocal.to;
  final reader = authSessionReader;
  final secure = <String, String>{};
  Future<void> Function()? beforeWrite;
  bool refuseDelete = false;
  final credentialEvents = <String>[];
  Map<String, dynamic> payload() => {
    'uid': '1001',
    'token': 'synthetic-access-token',
    'refreshtoken': 'synthetic-refresh-token',
  };
  Future<bool> login() {
    SqliteService.setDbForTest(SyntheticAuthDatabase());
    return repo.loginAfter('synthetic', payload());
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    secure.clear();
    beforeWrite = null;
    refuseDelete = false;
    credentialEvents.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secure[key];
              case 'readAll':
                return Map<String, String>.from(secure);
              case 'write':
                credentialEvents.add('write');
                await beforeWrite?.call();
                secure[key!] = args['value'] as String;
                return null;
              case 'delete':
                credentialEvents.add('delete');
                if (refuseDelete) {
                  throw PlatformException(code: 'synthetic-delete-refused');
                }
                secure.remove(key);
                return null;
              case 'deleteAll':
                secure.clear();
                return null;
            }
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
          (call) async => call.method == 'getDatabasesPath'
              ? '/nonexistent-synthetic-auth-scope'
              : null,
        );
    expect(await login(), isTrue);
    expect(reader.isCurrent(reader.current), isTrue);
  });
  tearDown(() {
    SqliteService.setDbForTest(null);
    PersistentMessageQueue.to.dispose();
  });
  test('login begin revokes immediately and failed login remains latched until successful login', () async {
    final captured = reader.current,
        entered = Completer<void>(),
        release = Completer<void>();
    beforeWrite = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
      throw PlatformException(code: 'synthetic-write-refused');
    };
    final pending = login();
    final failed = expectLater(pending, throwsA(isA<PlatformException>()));
    expect(reader.current.transitioning, isTrue);
    expect(reader.isCurrent(captured), isFalse);
    await entered.future;
    release.complete();
    await failed;
    expect(reader.current.transitioning, isTrue);
    final changes = <AuthSessionScope>[];
    void listener() => changes.add(reader.current);
    reader.addListener(listener);
    await repo.changeInfo({'nickname': 'synthetic'});
    expect(changes, isEmpty);
    reader.removeListener(listener);
    expect(
      await repo.quitLogin(expectedGeneration: captured.generation),
      isFalse,
    );
    expect(reader.current.transitioning, isTrue);
    beforeWrite = null;
    expect(await login(), isTrue);
    expect(reader.current.transitioning, isFalse);
    expect(reader.isCurrent(reader.current), isTrue);
  });
  test(
    'queued stale logout balances without erasing prior failed login latch',
    () async {
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-first-failure');
      await expectLater(login(), throwsA(isA<PlatformException>()));
      final generation = repo.sessionGeneration;
      final entered = Completer<void>(), release = Completer<void>();
      beforeWrite = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final write = repo.saveAccessTokenForSession(
        generation,
        'synthetic-pending-token',
      );
      await entered.future;
      final logout = repo.quitLogin(expectedGeneration: generation);
      expect(reader.current.transitioning, isTrue);
      expect(repo.isClearingSession, isFalse);
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-next-failure');
      final failed = expectLater(login(), throwsA(isA<PlatformException>()));
      release.complete();
      await write;
      expect(await logout, isFalse);
      await failed;
      expect(reader.current.transitioning, isTrue);
      beforeWrite = null;
      expect(await login(), isTrue);
      expect(reader.current.transitioning, isFalse);
    },
  );
  test('all queued authentication work must finish before a successful scope can be read', () async {
    final first = Completer<void>(), second = Completer<void>();
    var calls = 0;
    beforeWrite = () async {
      calls++;
      if (calls == 1) await first.future;
      if (calls == 3) await second.future;
    };
    final a = login(), b = login();
    expect(reader.current.transitioning, isTrue);
    first.complete();
    expect(await a, isTrue);
    expect(reader.current.transitioning, isTrue);
    expect(reader.isCurrent(reader.current), isFalse);
    second.complete();
    expect(await b, isTrue);
    expect(reader.current.transitioning, isFalse);
    expect(reader.isCurrent(reader.current), isTrue);
  });
  test('failed logout cannot restore authority and later stale logout cannot clear its latch', () async {
    final captured = reader.current;
    refuseDelete = true;
    expect(
      await repo.quitLogin(expectedGeneration: captured.generation),
      isFalse,
    );
    expect(reader.current.transitioning, isTrue);
    expect(reader.isCurrent(captured), isFalse);
    expect(
      await repo.quitLogin(expectedGeneration: captured.generation),
      isFalse,
    );
    expect(reader.current.transitioning, isTrue);
    refuseDelete = false;
    await StorageService.to.setString(Keys.currentUid, '1001');
    await StorageService.to.remove(Keys.e2eePurgePending);
    expect(await login(), isTrue);
    expect(reader.current.transitioning, isFalse);
  });
  test(
    'reentrant logout from login listener stays after the accepted outer login',
    () async {
      credentialEvents.clear();
      var fired = false;
      late Future<bool> inner;
      void listener() {
        if (fired || !reader.current.transitioning) return;
        fired = true;
        inner = repo.quitLogin();
      }

      reader.addListener(listener);
      beforeWrite = () async =>
          throw PlatformException(code: 'synthetic-outer-failure');
      await expectLater(login(), throwsA(isA<PlatformException>()));
      await inner;
      reader.removeListener(listener);
      expect(credentialEvents.first, 'write');
      expect(reader.current.uid, isEmpty);
      beforeWrite = null;
      await StorageService.to.setString(Keys.currentUid, '1001');
      await StorageService.to.remove(Keys.e2eePurgePending);
      expect(await login(), isTrue);
      expect(reader.current.transitioning, isFalse);
    },
  );
  test('reentrant login from logout listener stays after the accepted outer logout', () async {
    credentialEvents.clear();
    var fired = false;
    late Future<void> failed;
    beforeWrite = () async =>
        throw PlatformException(code: 'synthetic-inner-failure');
    void listener() {
      if (fired || !reader.current.transitioning) return;
      fired = true;
      failed = expectLater(login(), throwsA(isA<PlatformException>()));
    }

    reader.addListener(listener);
    await repo.quitLogin();
    await failed;
    reader.removeListener(listener);
    expect(credentialEvents.first, 'delete');
    expect(reader.current.transitioning, isTrue);
    beforeWrite = null;
    await StorageService.to.setString(Keys.currentUid, '1001');
    await StorageService.to.remove(Keys.e2eePurgePending);
    expect(await login(), isTrue);
    expect(reader.current.transitioning, isFalse);
  });
}
