import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sql_cipher;

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _AccountCleanupPaths extends PathProviderPlatform {
  _AccountCleanupPaths(this.root);

  final Directory root;
  Future<void> Function()? beforeSupportRead;
  int supportReads = 0;

  @override
  Future<String?> getApplicationSupportPath() async {
    supportReads++;
    await beforeSupportRead?.call();
    return p.join(root.path, 'support');
  }

  @override
  Future<String?> getApplicationCachePath() async => p.join(root.path, 'cache');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root.path, 'documents');

  @override
  Future<String?> getTemporaryPath() async => p.join(root.path, 'temporary');
}

class _FailingLoginPreferences extends InMemorySharedPreferencesStore {
  _FailingLoginPreferences(super.data, this.failKey) : super.withData();
  final String failKey;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$failKey') return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const databaseChannel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const selectedAccount = 'selected-synthetic';
  const selectedUid = 'history-selected';
  const otherAccount = 'retained-synthetic';
  const otherUid = 'history-retained';
  final repo = UserRepoLocal.to;
  final history = LoginAccountHistoryService();
  late Directory root;
  late PathProviderPlatform previousPaths;
  late _AccountCleanupPaths paths;
  late Map<String, String> secure;
  late List<String> secureCalls;
  late int databaseCalls;
  String? failingSecretKey;

  Map<String, dynamic> syntheticLogin() => {
    'uid': 'synthetic-new-login',
    'token': 'synthetic-access-token',
    'refreshtoken': 'synthetic-refresh-token',
    'nickname': 'Synthetic',
  };

  Future<File> createFile(String relative) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString('synthetic account data');
    return file;
  }

  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    previousPaths = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('imboy-account-session-');
    // SQLCipher caches its database path across tests in this isolate.
    await sql_cipher.databaseFactory.setDatabasesPath(
      p.join(root.path, 'databases'),
    );
    paths = _AccountCleanupPaths(root);
    PathProviderPlatform.instance = paths;
    SharedPreferences.setMockInitialValues({
      Keys.loginHistoryAccount: [selectedAccount, otherAccount],
      'draft_v2:$selectedUid:C2C:peer': 'selected draft',
      'draft_v2:$otherUid:C2C:peer': 'retained draft',
    });
    await StorageService.init();
    repo.clearAuthTransitionFailureForTest();
    SqliteService.setDbForTest(null);
    secure = {
      'db_cipher_key_$selectedUid': 'selected synthetic key',
      'db_cipher_key_$otherUid': 'retained synthetic key',
      'secure_token': 'retained last session token',
    };
    secureCalls = [];
    databaseCalls = 0;
    failingSecretKey = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'getActiveNotifications') return <dynamic>[];
          throw StateError('Unexpected notification operation: ${call.method}');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(databaseChannel, (call) async {
          databaseCalls++;
          if (call.method == 'getDatabasesPath') {
            return p.join(root.path, 'databases');
          }
          throw StateError('Unexpected database operation: ${call.method}');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          secureCalls.add(call.method);
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'readAll':
              return Map<String, String>.from(secure);
            case 'write':
              if (key == failingSecretKey) {
                throw PlatformException(code: 'synthetic_write_failure');
              }
              secure[key!] = args['value'] as String;
              return null;
            case 'delete':
              secure.remove(key);
              return null;
            case 'deleteAll':
              throw StateError('Account cleanup must not purge every account');
          }
          return null;
        });
    await history.rememberLogin(
      account: selectedAccount,
      profile: {'user_id': selectedUid},
      environment: currentEnv,
      endpoint: Env().apiBaseUrl,
    );
    final other = await history.rememberLogin(
      account: otherAccount,
      profile: {'user_id': otherUid},
      environment: currentEnv,
      endpoint: Env().apiBaseUrl,
    );
    await StorageService.setMap(Keys.currentUser, {
      'user_id': otherUid,
      LoginAccountHistoryService.localProfileKey: other.toJson(),
    });
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    SqliteService.setDbForTest(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(databaseChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    await root.delete(recursive: true);
  });

  test(
    'cleanup waits outside the session queue for a stopped task to settle',
    () async {
      final owner = AccountLocalTaskOwner(
        uid: selectedUid,
        environment: currentEnv,
        endpoint: Env().apiBaseUrl,
      );
      final otherOwner = AccountLocalTaskOwner(
        uid: otherUid,
        environment: currentEnv,
        endpoint: Env().apiBaseUrl,
      );
      final selectedFile = File(
        p.join(
          AccountLocalFiles.folderFor(p.join(root.path, 'temporary'), owner),
          'a.tmp',
        ),
      );
      final otherFile = File(
        p.join(
          AccountLocalFiles.folderFor(
            p.join(root.path, 'temporary'),
            otherOwner,
          ),
          'b.tmp',
        ),
      );
      for (final file in [selectedFile, otherFile]) {
        await file.parent.create(recursive: true);
        await file.writeAsString('synthetic retained until cleanup');
      }
      final generation = repo.sessionGeneration;
      final stopRequested = Completer<void>();
      final writeRejected = Completer<void>();
      final settle = Completer<void>();
      var unexpectedWrite = false;
      final work = AccountLocalTaskRegistry.instance.run<void>(
        owner,
        onCancel: () => stopRequested.complete(),
        operation: (task) async {
          await stopRequested.future;
          await expectLater(
            repo.writeSessionSecret(
              uid: selectedUid,
              generation: generation,
              write: () async => unexpectedWrite = true,
              discard: () async {},
            ),
            throwsStateError,
          );
          writeRejected.complete();
          await settle.future;
          task.throwIfCancelled();
        },
      );
      final workOutcome = expectLater(
        work,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      final cleanup = repo.clearHistoricalAccountData(selectedAccount);
      try {
        await writeRejected.future.timeout(const Duration(seconds: 5));
        expect(await selectedFile.exists(), isTrue);
        expect(
          history.readHistory(Keys.loginHistoryAccount),
          contains(selectedAccount),
        );
        expect(unexpectedWrite, isFalse);
      } finally {
        settle.complete();
        await workOutcome;
        await cleanup;
      }
      expect(await selectedFile.exists(), isFalse);
      expect(await otherFile.exists(), isTrue);
      // Discard the facade/cache and hydrate only the values persisted by the plugin.
      final persisted = await SharedPreferencesStorePlatform.instance.getAll();
      SharedPreferences.setMockInitialValues({
        for (final entry in persisted.entries)
          entry.key.replaceFirst(RegExp(r'^flutter\.'), ''): entry.value,
      });
      await StorageService.init();
      expect(history.readHistory(Keys.loginHistoryAccount), [otherAccount]);
    },
  );

  test(
    'a failed task stop preserves history and files, then retries successfully',
    () async {
      final file = await createFile('databases/${currentEnv}_$selectedUid.db');
      var attempts = 0;
      late AccountLocalTask task;
      task = AccountLocalTaskRegistry.instance.register(
        AccountLocalTaskOwner(
          uid: selectedUid,
          environment: currentEnv,
          endpoint: Env().apiBaseUrl,
        ),
        onCancel: () async {
          attempts++;
          if (attempts == 1) throw StateError('synthetic stop failed');
          task.finish();
        },
      );
      await expectLater(
        repo.clearHistoricalAccountData(selectedAccount),
        throwsStateError,
      );
      expect(await file.exists(), isTrue);
      expect(
        history.readHistory(Keys.loginHistoryAccount),
        contains(selectedAccount),
      );
      expect(repo.isAuthTransitioning, isFalse);
      await repo.clearHistoricalAccountData(selectedAccount);
      expect(attempts, 2);
      expect(await file.exists(), isFalse);
      expect(history.readHistory(Keys.loginHistoryAccount), [otherAccount]);
    },
  );

  test('partial database removal retains history for retry without changing B data', () async {
    final selectedDatabase = await createFile(
      'databases/${currentEnv}_$selectedUid.db',
    );
    // A non-empty directory at the journal path makes the real filesystem
    // deletion fail after A's key and main database have already been removed.
    final obstruction = await createFile(
      'databases/${currentEnv}_$selectedUid.db-journal/obstruction',
    );
    AccountLocalTaskOwner owner(String uid) => AccountLocalTaskOwner(
      uid: uid,
      environment: currentEnv,
      endpoint: Env().apiBaseUrl,
    );
    String attachmentPath(String uid) => p.join(
      AccountLocalFiles.folderFor('temporary', owner(uid)),
      'attachment.bin',
    );
    final selectedAttachment = await createFile(attachmentPath(selectedUid));
    final preserved = <File, String>{};
    for (final relative in [
      'databases/${currentEnv}_$otherUid.db',
      'databases/${currentEnv}_$otherUid.db-wal',
      attachmentPath(otherUid),
    ]) {
      final file = await createFile(relative);
      final contents = 'retained B data: $relative';
      await file.writeAsString(contents);
      preserved[file] = contents;
    }
    final retainedProfile = StorageService.getMap(Keys.currentUser);
    final retainedSecrets = Map<String, String>.of(secure)
      ..remove('db_cipher_key_$selectedUid');
    Future<void> expectOtherAccountIntact() async {
      expect(secure, retainedSecrets);
      for (final entry in preserved.entries) {
        expect(await entry.key.readAsString(), entry.value);
      }
      expect(StorageService.getMap(Keys.currentUser), retainedProfile);
      expect(
        StorageService.to.getString('draft_v2:$otherUid:C2C:peer'),
        'retained draft',
      );
    }

    await expectLater(
      repo.clearHistoricalAccountData(selectedAccount),
      throwsA(isA<FileSystemException>()),
    );
    expect(await selectedDatabase.exists(), isFalse);
    expect(await selectedAttachment.exists(), isTrue);
    expect(await obstruction.exists(), isTrue);
    expect(repo.isAuthTransitioning, isFalse);
    expect(history.readHistory(Keys.loginHistoryAccount), [
      selectedAccount,
      otherAccount,
    ]);
    await expectOtherAccountIntact();

    // Reload persisted preferences and resolve the same identity afresh; retry
    // must continue past the already-removed key and database.
    await (await SharedPreferences.getInstance()).reload();
    final restartedHistory = LoginAccountHistoryService();
    expect(
      restartedHistory
          .resolve(
            value: selectedAccount,
            environment: currentEnv,
            endpoint: Env().apiBaseUrl,
          )
          .uid,
      selectedUid,
    );
    await obstruction.delete();
    await repo.clearHistoricalAccountData(selectedAccount);
    expect(await obstruction.parent.exists(), isFalse);
    expect(await selectedAttachment.exists(), isFalse);
    expect(restartedHistory.readHistory(Keys.loginHistoryAccount), [
      otherAccount,
    ]);
    expect(
      StorageService.to.getString('draft_v2:$selectedUid:C2C:peer'),
      isEmpty,
    );
    await expectOtherAccountIntact();
  });

  for (final stage in ['token', 'refresh', 'profile', 'uid']) {
    test('a failed $stage commit does not publish login history', () async {
      await StorageService.to.setList(Keys.loginHistory, [otherAccount]);
      await StorageService.to.setString(Keys.lastLoginAccount, otherAccount);
      if (stage == 'token' || stage == 'refresh') {
        failingSecretKey = stage == 'token'
            ? 'secure_token'
            : 'secure_refresh_token';
      } else {
        final persisted = await SharedPreferencesStorePlatform.instance
            .getAll();
        SharedPreferences.setMockInitialValues({});
        SharedPreferencesStorePlatform.instance = _FailingLoginPreferences(
          persisted,
          stage == 'profile' ? Keys.currentUser : Keys.currentUid,
        );
        await StorageService.init();
      }
      await expectLater(
        repo.loginAfter('synthetic-new-account', syntheticLogin()),
        throwsA(anyOf(isA<PlatformException>(), isA<StateError>())),
      );
      expect(repo.currentUid, isEmpty);
      expect(history.readHistory(Keys.loginHistory), [otherAccount]);
      expect(StorageService.to.getString(Keys.lastLoginAccount), otherAccount);
      expect(history.readHistory(Keys.loginHistoryAccount), [
        selectedAccount,
        otherAccount,
      ]);
    });
  }

  test(
    'account cleanup rejects login and a second cleanup until it completes',
    () async {
      final selectedDatabase = await createFile(
        'databases/${currentEnv}_$selectedUid.db',
      );
      final otherDatabase = await createFile(
        'databases/${currentEnv}_$otherUid.db',
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      paths.beforeSupportRead = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final generation = repo.sessionGeneration;
      final retainedProfile = StorageService.getMap(Keys.currentUser);
      final cleanup = repo.clearHistoricalAccountData(selectedAccount);
      final completed = expectLater(cleanup, completes);
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        expect(repo.currentUid, isEmpty);
        expect(repo.isAuthTransitioning, isTrue);
        expect(await selectedDatabase.exists(), isTrue);
        expect(
          secureCalls,
          isNot(contains(anyOf('write', 'delete', 'deleteAll'))),
        );
        repo.validateLoginPayload(syntheticLogin());
        expect(
          () => repo.loginAfter('synthetic-new-account', syntheticLogin()),
          throwsA(isA<LoginAccountCleanupBusyException>()),
        );
        expect(
          () => repo.clearHistoricalAccountData(otherAccount),
          throwsA(isA<LoginAccountCleanupBusyException>()),
        );
        expect(
          await repo.changeInfo({'user_id': selectedUid, 'nickname': 'late'}),
          isFalse,
        );
        expect(
          await repo.changeSetting(
            UserSettingModel(allowSearch: false, peopleNearbyVisible: false),
          ),
          isFalse,
        );
        expect(StorageService.getMap(Keys.currentUser), retainedProfile);
        expect(repo.sessionGeneration, generation + 1);
        expect(repo.currentUid, isEmpty);
        expect(history.readHistory(Keys.loginHistoryAccount), [
          selectedAccount,
          otherAccount,
        ]);
      } finally {
        release.complete();
        await completed;
      }

      expect(repo.isAuthTransitioning, isFalse);
      expect(repo.sessionGeneration, generation + 1);
      expect(repo.currentUid, isEmpty);
      expect(await selectedDatabase.exists(), isFalse);
      expect(await otherDatabase.exists(), isTrue);
      expect(secure.containsKey('db_cipher_key_$selectedUid'), isFalse);
      expect(secure['db_cipher_key_$otherUid'], 'retained synthetic key');
      expect(secure['secure_token'], 'retained last session token');
      expect(
        await repo.saveAccessTokenForSession(
          generation,
          'synthetic-stale-refresh-token',
        ),
        isFalse,
      );
      expect(
        await repo.saveAccessTokenForSession(
          repo.sessionGeneration,
          'synthetic-signed-out-token',
        ),
        isFalse,
      );
      expect(secure['secure_token'], 'retained last session token');
      expect(secureCalls, isNot(contains('write')));
      expect(history.readHistory(Keys.loginHistoryAccount), [otherAccount]);
      expect(
        () => history.resolve(
          value: selectedAccount,
          environment: currentEnv,
          endpoint: Env().apiBaseUrl,
        ),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      expect(
        history
            .resolve(
              value: otherAccount,
              environment: currentEnv,
              endpoint: Env().apiBaseUrl,
            )
            .uid,
        otherUid,
      );
      expect(StorageService.getMap(Keys.currentUser)['user_id'], otherUid);
      expect(
        await repo.changeInfo({'user_id': selectedUid, 'nickname': 'late'}),
        isFalse,
      );
      expect(StorageService.getMap(Keys.currentUser), retainedProfile);
      expect(
        StorageService.to.getString('draft_v2:$selectedUid:C2C:peer'),
        isEmpty,
      );
      expect(
        StorageService.to.getString('draft_v2:$otherUid:C2C:peer'),
        'retained draft',
      );
    },
  );

  test('active profile edits retain verified local data ownership', () async {
    await StorageService.to.setString(Keys.currentUid, otherUid);
    final localIdentity = StorageService.getMap(
      Keys.currentUser,
    )[LoginAccountHistoryService.localProfileKey];

    expect(
      await repo.changeInfo({'user_id': otherUid, 'nickname': 'Updated'}),
      isTrue,
    );
    expect(
      await repo.changeSetting(
        UserSettingModel(allowSearch: false, peopleNearbyVisible: false),
      ),
      isTrue,
    );

    final saved = StorageService.getMap(Keys.currentUser);
    expect(saved['nickname'], 'Updated');
    expect(saved[LoginAccountHistoryService.localProfileKey], localIdentity);
    expect((saved['setting'] as Map)['allow_search'], isFalse);
    expect(paths.supportReads, 0);
    expect(secureCalls, isEmpty);
  });

  test(
    'a signed-in account rejects historical cleanup before any storage access',
    () async {
      final selectedDatabase = await createFile(
        'databases/${currentEnv}_$selectedUid.db',
      );
      await StorageService.to.setString(Keys.currentUid, otherUid);
      final savedHistory = StorageService.to.getString(
        LoginAccountHistoryService.storageKey,
      );
      final savedSecrets = Map<String, String>.from(secure);
      final generation = repo.sessionGeneration;

      expect(
        () => repo.clearHistoricalAccountData(selectedAccount),
        throwsA(isA<LoginAccountCleanupBusyException>()),
      );

      expect(paths.supportReads, 0);
      expect(databaseCalls, 0);
      expect(secureCalls, isEmpty);
      expect(secure, savedSecrets);
      expect(await selectedDatabase.exists(), isTrue);
      expect(
        StorageService.to.getString(LoginAccountHistoryService.storageKey),
        savedHistory,
      );
      expect(history.readHistory(Keys.loginHistoryAccount), [
        selectedAccount,
        otherAccount,
      ]);
      expect(repo.currentUid, otherUid);
      expect(repo.sessionGeneration, generation);
      expect(repo.isAuthTransitioning, isFalse);
    },
  );

  for (final scenario in ['alias reassignment', 'registry recovery']) {
    test('cleanup rejects $scenario before touching shared account data', () async {
      const remoteEndpoint = 'https://retained.example.test/api';
      expect(remoteEndpoint, isNot(Env().apiBaseUrl));
      await history.rememberLogin(
        account: 'remote-only-alias',
        profile: {'user_id': selectedUid},
        environment: currentEnv,
        endpoint: remoteEndpoint,
      );
      final selectedIdentity = history.resolve(
        value: selectedAccount,
        environment: currentEnv,
        endpoint: Env().apiBaseUrl,
      );
      expect(
        () => history.requireIndependentStorage(selectedIdentity),
        throwsA(isA<LoginAccountSharedDataException>()),
      );
      final uploadDigest = sha256
          .convert(utf8.encode('$currentEnv:$selectedUid'))
          .toString();
      final preserved = <File, List<int>>{};
      for (final relative in [
        for (final suffix in ['', '-wal', '-shm', '-journal'])
          'databases/${currentEnv}_$selectedUid.db$suffix',
        'databases/${currentEnv}_$otherUid.db',
        'databases/${currentEnv}_$otherUid.db-wal',
        'cache/attachment_uploads/$uploadDigest/shared.bin',
        for (final owner in [
          AccountLocalTaskOwner(
            uid: selectedUid,
            environment: currentEnv,
            endpoint: Env().apiBaseUrl,
          ),
          AccountLocalTaskOwner(
            uid: selectedUid,
            environment: currentEnv,
            endpoint: remoteEndpoint,
          ),
          AccountLocalTaskOwner(
            uid: otherUid,
            environment: currentEnv,
            endpoint: Env().apiBaseUrl,
          ),
        ])
          p.join(AccountLocalFiles.folderFor('temporary', owner), 'file.bin'),
      ]) {
        final file = await createFile(relative);
        final bytes = utf8.encode('synthetic preserved data: $relative');
        await file.writeAsBytes(bytes);
        preserved[file] = bytes;
      }
      for (final uid in [selectedUid, otherUid]) {
        secure['utk_${Uri.encodeComponent(currentEnv)}:${Uri.encodeComponent(uid)}:synthetic'] =
            'synthetic upload key for $uid';
      }
      final savedSecrets = Map<String, String>.of(secure);
      final generation = repo.sessionGeneration;
      if (scenario == 'alias reassignment') {
        await history.rememberLogin(
          account: 'remote-only-alias',
          profile: {'user_id': 'history-reassigned'},
          environment: currentEnv,
          endpoint: remoteEndpoint,
        );
      } else {
        await StorageService.to.setString(
          LoginAccountHistoryService.storageKey,
          '{',
        );
        await history.rememberLogin(
          account: selectedAccount,
          profile: {'user_id': selectedUid},
          environment: currentEnv,
          endpoint: Env().apiBaseUrl,
        );
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt == 1) {
          await history.rememberLogin(
            account: 'unrelated-later',
            profile: {'user_id': 'history-later'},
            environment: currentEnv,
            endpoint: Env().apiBaseUrl,
          );
        }
        // Recreate preferences from the plugin store before each attempt.
        // This is persisted-state hydration, not a native process restart.
        final persisted = await SharedPreferencesStorePlatform.instance
            .getAll();
        SharedPreferences.setMockInitialValues({
          for (final entry in persisted.entries)
            entry.key.replaceFirst(RegExp(r'^flutter\.'), ''): entry.value,
        });
        await StorageService.init();
        final savedPreferences = await SharedPreferencesStorePlatform.instance
            .getAll();
        final rejection = scenario == 'alias reassignment'
            ? isA<LoginAccountSharedDataException>()
            : isA<AccountLocalDataOwnershipException>();
        await expectLater(
          Future<void>.sync(
            () => repo.clearHistoricalAccountData(selectedAccount),
          ),
          throwsA(rejection),
        );
        expect(paths.supportReads, 0);
        expect(databaseCalls, 0);
        expect(secureCalls, isEmpty);
        expect(secure, savedSecrets);
        expect(
          await SharedPreferencesStorePlatform.instance.getAll(),
          savedPreferences,
        );
        for (final entry in preserved.entries) {
          expect(await entry.key.readAsBytes(), entry.value);
        }
        expect(repo.currentUid, isEmpty);
        expect(repo.sessionGeneration, generation);
        expect(repo.isAuthTransitioning, isFalse);
      }
    });
  }
}
