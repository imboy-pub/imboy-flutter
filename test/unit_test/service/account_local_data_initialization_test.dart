import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/account_local_data_service.dart';
import 'package:imboy/service/db_encryption_key_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

class _ClosingDatabase implements Database {
  _ClosingDatabase({required this.failClose, this.closeGate});

  bool failClose;
  final Completer<void>? closeGate;
  final closeStarted = Completer<void>();
  int closeCalls = 0;
  bool _open = true;

  @override
  bool get isOpen => _open;

  @override
  Future<void> close() async {
    closeCalls++;
    if (!closeStarted.isCompleted) closeStarted.complete();
    if (closeGate != null) await closeGate!.future;
    if (failClose) throw StateError('synthetic native close failure');
    _open = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cleanup drains held key initialization before reading or deleting data',
    () async {
      const uid = 'initializing-account';
      const selectedKey = 'db_cipher_key_$uid';
      const otherKey = 'db_cipher_key_retained-account';
      const secureChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      const databaseChannel = MethodChannel(
        'com.davidmartos96.sqflite_sqlcipher',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final root = await Directory.systemTemp.createTemp('imboy-init-cleanup-');
      final secure = <String, String>{otherKey: 'retained key'};
      final keyWriteEntered = Completer<void>();
      final releaseKeyWrite = Completer<void>();
      var secureReads = 0;
      var ownershipReads = 0;
      var databaseDeletes = 0;
      Future<void>? cleanup;

      SharedPreferences.setMockInitialValues({Keys.currentUid: uid});
      await StorageService.init();
      SqliteService.setDbForTest(null);
      messenger.setMockMethodCallHandler(secureChannel, (call) async {
        final arguments = Map<String, dynamic>.from(call.arguments as Map);
        final key = arguments['key'] as String;
        switch (call.method) {
          case 'read':
            return secure[key];
          case 'write':
            expect(key, selectedKey);
            keyWriteEntered.complete();
            await releaseKeyWrite.future;
            secure[key] = arguments['value'] as String;
            return null;
          default:
            throw StateError('Unexpected secure operation: ${call.method}');
        }
      });
      messenger.setMockMethodCallHandler(databaseChannel, (call) async {
        if (call.method != 'getDatabasesPath') {
          throw StateError('Unexpected database operation: ${call.method}');
        }
        // Linux SQLite is unencrypted. Run the real mobile key creation step at
        // a platform await inside the production initialization lock instead.
        await DbEncryptionKeyService.getOrCreateKey(uid);
        throw PlatformException(code: 'synthetic_initialization_finished');
      });
      final opening = SqliteService.to.db.then<void>(
        (_) =>
            fail('Synthetic initialization must stop after creating its key'),
        onError: (Object error, StackTrace _) {
          expect(error, isA<PlatformException>());
        },
      );

      try {
        await keyWriteEntered.future.timeout(const Duration(seconds: 5));
        await StorageService.to.remove(Keys.currentUid);
        final cleaner = AccountLocalDataService(
          databaseDirectory: () async => Directory(p.join(root.path, 'db')),
          supportDirectory: () async {
            ownershipReads++;
            return Directory(p.join(root.path, 'support'));
          },
          cacheDirectory: () async => Directory(p.join(root.path, 'cache')),
          documentsDirectory: () async =>
              Directory(p.join(root.path, 'documents')),
          temporaryDirectory: () async => Directory(p.join(root.path, 'temp')),
          systemTemporaryDirectory: () async => root,
          readSecure: () async {
            secureReads++;
            expect(releaseKeyWrite.isCompleted, isTrue);
            return Map.of(secure);
          },
          deleteSecure: (key) async {
            secure.remove(key);
          },
          deleteDatabase: (owner, environment) async {
            expect(owner, uid);
            expect(secure, isNot(contains(selectedKey)));
            databaseDeletes++;
          },
          validateNotifications: () async {},
          clearNotifications: (_) async {},
          clearMediaCache: (_) async {},
          clearQueuedMessages: (_) async {},
        );
        cleanup = cleaner.clear(
          uid: uid,
          environment: currentEnv.isEmpty ? 'pro' : currentEnv,
          endpoint: 'https://cleanup.example.invalid',
          clearLastSessionData: false,
        );
        await Future<void>.delayed(Duration.zero);
        expect(secureReads, 0);
        expect(ownershipReads, 0);
        expect(databaseDeletes, 0);
        releaseKeyWrite.complete();
        await opening;
        await cleanup;
        expect(secureReads, 2);
        expect(databaseDeletes, 1);
        expect(secure, {otherKey: 'retained key'});
      } finally {
        if (!releaseKeyWrite.isCompleted) releaseKeyWrite.complete();
        await opening;
        await cleanup;
        messenger.setMockMethodCallHandler(secureChannel, null);
        messenger.setMockMethodCallHandler(databaseChannel, null);
        SqliteService.setDbForTest(null);
        await root.delete(recursive: true);
      }
    },
  );

  for (final failsFirst in [false, true]) {
    test(
      failsFirst
          ? 'failed account close preserves keys and files for a successful retry'
          : 'cleanup waits for selected native close before deleting any secrets',
      () async {
        const uid = 'closing-account';
        const otherUid = 'retained-account';
        const environment = 'local';
        const selectedKey = 'db_cipher_key_$uid';
        const otherKey = 'db_cipher_key_$otherUid';
        final previousEnvironment = currentEnv;
        currentEnv = environment;
        final root = await Directory.systemTemp.createTemp(
          'imboy-close-cleanup-',
        );
        final databases = Directory(p.join(root.path, 'db'));
        await databases.create();
        final selectedFile = File(
          p.join(databases.path, '${environment}_$uid.db'),
        );
        final otherFile = File(
          p.join(databases.path, '${environment}_$otherUid.db'),
        );
        await selectedFile.writeAsString('selected database');
        await otherFile.writeAsString('retained database');
        final secure = {selectedKey: 'selected key', otherKey: 'retained key'};
        final gate = failsFirst ? null : Completer<void>();
        final database = _ClosingDatabase(
          failClose: failsFirst,
          closeGate: gate,
        );
        var keyDeletes = 0;
        var databaseDeletes = 0;
        Future<void>? cleanup;

        SharedPreferences.setMockInitialValues({
          Keys.currentUid: uid,
          Keys.loginHistoryAccount: ['selected', 'retained'],
        });
        await StorageService.init();
        SqliteService.setDbForTest(database);
        await StorageService.to.remove(Keys.currentUid);
        final cleaner = AccountLocalDataService(
          databaseDirectory: () async => databases,
          supportDirectory: () async => Directory(p.join(root.path, 'support')),
          cacheDirectory: () async => Directory(p.join(root.path, 'cache')),
          documentsDirectory: () async =>
              Directory(p.join(root.path, 'documents')),
          temporaryDirectory: () async => Directory(p.join(root.path, 'temp')),
          systemTemporaryDirectory: () async => root,
          readSecure: () async => Map.of(secure),
          deleteSecure: (key) async {
            expect(
              database.isOpen,
              isFalse,
              reason: 'close must precede key deletion',
            );
            keyDeletes++;
            secure.remove(key);
          },
          deleteDatabase: (owner, env) async {
            expect((owner, env), (uid, environment));
            expect(database.isOpen, isFalse);
            databaseDeletes++;
            await selectedFile.delete();
          },
          validateNotifications: () async {},
          clearNotifications: (_) async {},
          clearMediaCache: (_) async {},
          clearQueuedMessages: (_) async {},
        );
        Future<void> clear() => cleaner.clear(
          uid: uid,
          environment: environment,
          endpoint: 'https://cleanup.example.invalid',
          clearLastSessionData: false,
        );
        try {
          cleanup = clear();
          final completion = expectLater(
            cleanup,
            failsFirst ? throwsStateError : completes,
          );
          await database.closeStarted.future.timeout(
            const Duration(seconds: 5),
          );
          expect(secure[selectedKey], 'selected key');
          expect(keyDeletes, 0);
          expect(databaseDeletes, 0);
          expect(await selectedFile.exists(), isTrue);
          expect(StorageService.to.getStringList(Keys.loginHistoryAccount), [
            'selected',
            'retained',
          ]);
          if (failsFirst) {
            await completion;
            expect(database.isOpen, isTrue);
            database.failClose = false;
            cleanup = clear();
            await cleanup.timeout(const Duration(seconds: 5));
            expect(
              database.closeCalls,
              2,
              reason: 'failed handle is retained for retry',
            );
          } else {
            gate!.complete();
            await completion.timeout(const Duration(seconds: 5));
            expect(database.closeCalls, 1);
          }
          expect(keyDeletes, 1);
          expect(databaseDeletes, 1);
          expect(database.isOpen, isFalse);
          expect(await selectedFile.exists(), isFalse);
          expect(await otherFile.readAsString(), 'retained database');
          expect(secure, {otherKey: 'retained key'});
        } finally {
          if (gate != null && !gate.isCompleted) gate.complete();
          try {
            await cleanup;
          } on Object {
            // The failing first attempt is asserted above; always release fixtures.
          }
          SqliteService.setDbForTest(null);
          database.failClose = false;
          if (database.isOpen) await database.close();
          currentEnv = previousEnvironment;
          SharedPreferences.setMockInitialValues({});
          await StorageService.init();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
