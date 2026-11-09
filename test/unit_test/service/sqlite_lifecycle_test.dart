import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/db_encryption_key_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _OwnedLifecyclePaths extends PathProviderPlatform {
  _OwnedLifecyclePaths(this.directory);
  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
  @override
  Future<String?> getApplicationCachePath() async => directory;
  @override
  Future<String?> getTemporaryPath() async => directory;
}

class _LifecycleDatabase implements Database {
  _LifecycleDatabase(this.events, {this.closeGate});
  final List<String> events;
  final Completer<void>? closeGate;
  final closeEntered = Completer<void>();
  bool failClose = false;
  bool _open = true;
  int closeCalls = 0;

  @override
  bool get isOpen => _open;

  @override
  Future<void> close() async {
    if (!_open) return;
    closeCalls++;
    events.add('database-close-start');
    if (!closeEntered.isCompleted) closeEntered.complete();
    if (failClose) throw StateError('synthetic-close-unavailable');
    await closeGate?.future;
    _open = false;
    events.add('database-close-end');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeChannel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const uid = 'synthetic-lifecycle-a';
  const keyName = 'db_cipher_key_$uid';
  final repo = UserRepoLocal.to;
  final secure = <String, String>{};
  final events = <String>[];
  final databases = <_LifecycleDatabase>[];
  final nativeCalls = <MethodCall>[];
  Future<void> Function(String key)? beforeWrite;
  Future<String> Function()? getDatabaseDirectory;
  String? refuseDelete;
  late Directory directory;
  late PathProviderPlatform previousPaths;
  late String previousEnvironment;

  Map<String, dynamic> loginPayload() => {
    'uid': uid,
    'token': 'synthetic-access-token',
    'refreshtoken': 'synthetic-refresh-token',
  };

  _LifecycleDatabase database({bool blockClose = false}) {
    final result = _LifecycleDatabase(
      events,
      closeGate: blockClose ? Completer<void>() : null,
    );
    databases.add(result);
    return result;
  }

  setUp(() async {
    previousEnvironment = currentEnv;
    currentEnv = 'local';
    previousPaths = PathProviderPlatform.instance;
    directory = await Directory.systemTemp.createTemp('imboy-db-lifecycle-');
    PathProviderPlatform.instance = _OwnedLifecyclePaths(directory.path);
    SharedPreferences.setMockInitialValues({Keys.currentUid: uid});
    await StorageService.init();
    repo.clearAuthTransitionFailureForTest();
    SqliteService.setDbForTest(null);
    SqliteService.setInitializerForTest(null);
    secure.clear();
    events.clear();
    databases.clear();
    nativeCalls.clear();
    beforeWrite = null;
    getDatabaseDirectory = null;
    refuseDelete = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'getDatabasesPath') {
            return await getDatabaseDirectory?.call() ?? directory.path;
          }
          throw StateError('Unexpected native call: ${call.method}');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'readAll':
              events.add('secure-read-all');
              return Map<String, String>.from(secure);
            case 'write':
              await beforeWrite?.call(key!);
              secure[key!] = args['value'] as String;
              events.add('secure-write:$key');
              return null;
            case 'delete':
              events.add('secure-delete:$key');
              if (refuseDelete == key) {
                throw PlatformException(code: 'synthetic-delete-unavailable');
              }
              secure.remove(key);
              return null;
            case 'deleteAll':
              secure.clear();
              return null;
          }
          throw StateError('Unexpected storage call: ${call.method}');
        });
  });

  tearDown(() async {
    for (final db in databases) {
      db.failClose = false;
      final gate = db.closeGate;
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    await SqliteService.to.close();
    for (final db in databases) {
      if (db.isOpen) await db.close();
    }
    SqliteService.setDbForTest(null);
    SqliteService.setInitializerForTest(null);
    PersistentMessageQueue.to.dispose();
    PathProviderPlatform.instance = previousPaths;
    currentEnv = previousEnvironment;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    await directory.delete(recursive: true);
  });

  test('account change while resolving database directory stops before keys or open', () async {
    final resolvingDirectory = Completer<void>();
    final finishDirectory = Completer<String>();
    getDatabaseDirectory = () {
      resolvingDirectory.complete();
      return finishDirectory.future;
    };
    final opening = SqliteService.to.db;
    await resolvingDirectory.future;
    await StorageService.to.setString(Keys.currentUid, 'synthetic-lifecycle-b');
    currentEnv = 'dev';
    finishDirectory.complete(directory.path);

    expect(await opening, isNull);
    expect(secure, isEmpty);
    expect(
      nativeCalls.map((call) => call.method),
      isNot(contains('openDatabase')),
    );
    expect(directory.listSync(), isEmpty);
    final next = database();
    SqliteService.setInitializerForTest((uid, env, generation) async => next);
    expect(await SqliteService.to.db, same(next));
  });

  test('concurrent requests initialize once and reuse one handle', () async {
    final entered = Completer<void>();
    final release = Completer<Database?>();
    final opened = database();
    var calls = 0;
    SqliteService.setInitializerForTest((account, environment, generation) {
      calls++;
      expect(account, uid);
      expect(environment, 'local');
      expect(generation, repo.sessionGeneration);
      entered.complete();
      return release.future;
    });
    final first = SqliteService.to.db;
    await entered.future;
    final second = SqliteService.to.db;
    release.complete(opened);
    expect(await first, same(opened));
    expect(await second, same(opened));
    expect(await SqliteService.to.db, same(opened));
    expect(calls, 1);
  });

  test('stale result is closed and the next account has no cooldown', () async {
    final entered = Completer<void>();
    final release = Completer<Database?>();
    final old = database(), next = database();
    final accounts = <String>[];
    SqliteService.setInitializerForTest((account, environment, generation) {
      accounts.add(account);
      if (accounts.length == 1) {
        entered.complete();
        return release.future;
      }
      return Future.value(next);
    });
    final opening = SqliteService.to.db;
    await entered.future;
    await StorageService.to.setString(Keys.currentUid, 'synthetic-lifecycle-b');
    release.complete(old);
    expect(await opening, isNull);
    expect(old.isOpen, isFalse);
    expect(await SqliteService.to.db, same(next));
    expect(accounts, [uid, 'synthetic-lifecycle-b']);
  });

  test(
    'a stale handle whose close fails remains available for close retry',
    () async {
      final entered = Completer<void>();
      final release = Completer<Database?>();
      final old = database()..failClose = true;
      final next = database();
      var calls = 0;
      SqliteService.setInitializerForTest((account, environment, generation) {
        if (++calls == 1) {
          entered.complete();
          return release.future;
        }
        return Future.value(next);
      });
      final opening = SqliteService.to.db;
      await entered.future;
      final rejected = expectLater(opening, throwsStateError);
      await StorageService.to.setString(
        Keys.currentUid,
        'synthetic-lifecycle-b',
      );
      release.complete(old);
      await rejected;
      await expectLater(SqliteService.to.close(), throwsStateError);
      expect(old.closeCalls, 2);
      old.failClose = false;
      await SqliteService.to.close();
      expect(old.isOpen, isFalse);
      expect(await SqliteService.to.db, same(next));
    },
  );

  test(
    'same UID with a new session generation rejects an earlier open',
    () async {
      final entered = Completer<void>();
      final release = Completer<Database?>();
      final old = database(), next = database();
      final generations = <int>[];
      SqliteService.setInitializerForTest((account, environment, generation) {
        generations.add(generation);
        if (generations.length == 1) {
          entered.complete();
          return release.future;
        }
        return Future.value(next);
      });
      final opening = SqliteService.to.db;
      await entered.future;
      beforeWrite = (_) async =>
          throw PlatformException(code: 'synthetic-login-interrupted');
      await expectLater(
        repo.loginAfter('synthetic', loginPayload()),
        throwsA(isA<PlatformException>()),
      );
      repo.clearAuthTransitionFailureForTest();
      expect(repo.currentUid, uid);
      release.complete(old);

      expect(await opening, isNull);
      expect(old.isOpen, isFalse);
      expect(await SqliteService.to.db, same(next));
      expect(generations.last, greaterThan(generations.first));
    },
  );

  test(
    'an auth transition rejects opens without starting a cooldown',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      beforeWrite = (_) async {
        entered.complete();
        await release.future;
        throw PlatformException(code: 'synthetic-login-interrupted');
      };
      final failed = expectLater(
        repo.loginAfter('synthetic', loginPayload()),
        throwsA(isA<PlatformException>()),
      );
      await entered.future;
      final opened = database();
      var calls = 0;
      SqliteService.setInitializerForTest((
        account,
        environment,
        generation,
      ) async {
        calls++;
        return opened;
      });
      expect(await SqliteService.to.db, isNull);
      expect(calls, 0);
      release.complete();
      await failed;
      repo.clearAuthTransitionFailureForTest();
      expect(await SqliteService.to.db, same(opened));
      expect(calls, 1);
    },
  );

  test(
    'anonymous injected handles remain usable outside auth transitions',
    () async {
      await StorageService.to.remove(Keys.currentUid);
      final injected = database();
      SqliteService.setDbForTest(injected);
      expect(await SqliteService.to.db, same(injected));
      SqliteService.setDbForTest(null);
      var calls = 0;
      SqliteService.setInitializerForTest((
        account,
        environment,
        generation,
      ) async {
        calls++;
        return database();
      });
      expect(await SqliteService.to.db, isNull);
      expect(
        calls,
        0,
        reason: 'empty UID must never initialize a production DB',
      );
    },
  );

  test(
    'close drains initialization including a pending secure-storage write',
    () async {
      final writeEntered = Completer<void>(), finishWrite = Completer<void>();
      beforeWrite = (key) async {
        if (key == keyName) {
          writeEntered.complete();
          await finishWrite.future;
        }
      };
      final opened = database();
      SqliteService.setInitializerForTest((
        account,
        environment,
        generation,
      ) async {
        await DbEncryptionKeyService.getOrCreateKey(account);
        return opened;
      });
      final opening = SqliteService.to.db;
      await writeEntered.future;
      await StorageService.to.remove(Keys.currentUid);
      var closed = false;
      final closing = SqliteService.to.close().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      finishWrite.complete();

      expect(await opening, isNull);
      await closing;
      expect(opened.isOpen, isFalse);
      expect(
        events,
        containsAllInOrder(['secure-write:$keyName', 'database-close-end']),
      );
    },
  );

  test(
    'login warms a settled session and contains background open failure',
    () async {
      final attempted = Completer<void>();
      SqliteService.setInitializerForTest((
        account,
        environment,
        generation,
      ) async {
        expect(repo.isAuthTransitioning, isFalse);
        expect(account, uid);
        expect(generation, repo.sessionGeneration);
        attempted.complete();
        throw StateError('synthetic-initialization-failure');
      });

      expect(await repo.loginAfter('synthetic', loginPayload()), isTrue);
      await attempted.future;
      await Future<void>.delayed(Duration.zero);
      expect(repo.isAuthTransitioning, isFalse);
      expect(secure.containsKey(keyName), isFalse);
      expect(
        nativeCalls.map((call) => call.method),
        isNot(contains('openDatabase')),
      );
    },
  );

  test('logout closes the database before production key purge', () async {
    secure[keyName] = 'synthetic-existing-key';
    final opened = database(blockClose: true);
    SqliteService.setDbForTest(opened);
    final logout = repo.quitLogin();
    await opened.closeEntered.future;
    expect(secure[keyName], 'synthetic-existing-key');
    expect(events, isNot(contains('secure-read-all')));
    opened.closeGate!.complete();

    expect(await logout, isTrue);
    expect(secure.containsKey(keyName), isFalse);
    expect(
      events,
      containsAllInOrder(['database-close-end', 'secure-delete:$keyName']),
    );
  });

  test(
    'close failure preserves keys, clears tokens, and blocks recovery purge',
    () async {
      secure[keyName] = 'synthetic-existing-key';
      secure['secure_token'] = 'synthetic-token';
      final opened = database()..failClose = true;
      SqliteService.setDbForTest(opened);

      expect(await repo.quitLogin(), isFalse);
      expect(opened.isOpen, isTrue);
      expect(secure[keyName], 'synthetic-existing-key');
      expect(secure.containsKey('secure_token'), isFalse);
      expect(StorageService.to.getBool(Keys.e2eePurgePending), isTrue);
      expect(events, isNot(contains('secure-read-all')));
      await expectLater(
        repo.loginAfter('synthetic', loginPayload()),
        throwsStateError,
      );
      expect(opened.closeCalls, 2);
      expect(secure[keyName], 'synthetic-existing-key');
      expect(events, isNot(contains('secure-read-all')));
    },
  );

  test(
    'purge failure still leaves the database closed and clears tokens',
    () async {
      secure[keyName] = 'synthetic-existing-key';
      secure['secure_token'] = 'synthetic-token';
      refuseDelete = keyName;
      final opened = database();
      SqliteService.setDbForTest(opened);

      expect(await repo.quitLogin(), isFalse);
      expect(opened.isOpen, isFalse);
      expect(secure.containsKey('secure_token'), isFalse);
      expect(StorageService.to.getBool(Keys.e2eePurgePending), isTrue);
      expect(
        events,
        containsAllInOrder(['database-close-end', 'secure-delete:$keyName']),
      );
    },
  );
}
