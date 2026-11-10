import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sql_cipher;

import 'package:imboy/app_core/feature_flags/runtime_feature_recovery.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/account_local_data_service.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _QrPaths extends PathProviderPlatform {
  _QrPaths(this.root);
  final Directory root;
  Future<void> Function()? beforeSupportRead;

  @override
  Future<String?> getApplicationSupportPath() async {
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

class _QrPreferences extends InMemorySharedPreferencesStore {
  _QrPreferences() : super.withData({});
  bool failRegistry = false;
  Future<void> Function()? beforeRegistryWrite;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${LoginAccountHistoryService.storageKey}') {
      await beforeRegistryWrite?.call();
      if (failRegistry) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _SyntheticHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":503,"msg":"synthetic unavailable"}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
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
  const uid = 'qr-synthetic-owner';
  const token = 'synthetic-qr-access-token';
  final repo = UserRepoLocal.to;
  final history = LoginAccountHistoryService();
  late Directory root;
  late PathProviderPlatform previousPaths;
  late _QrPaths paths;
  late _QrPreferences preferences;
  late Map<String, String> secure;
  late List<String> secretMutations;

  LoginAccountIdentity identity({String endpoint = ''}) => LoginAccountIdentity(
    uid: uid,
    environment: currentEnv,
    endpoint: endpoint.isEmpty ? Env().apiBaseUrl : endpoint,
    aliases: const {},
  );

  List<LoginAccountIdentity> registered() {
    final raw = jsonDecode(
      StorageService.to.getString(LoginAccountHistoryService.storageKey),
    ) as Map<String, dynamic>;
    return [
      for (final entry in raw['accounts'] as List)
        LoginAccountIdentity.fromJson(entry)!,
    ];
  }

  Future<void> capture() => AccountLocalDataService.captureInitialOwnership(
    inventoryService: AccountLocalDataService(),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('imboy-qr-persistence-');
    for (final directory in [
      'databases',
      'support',
      'cache',
      'documents',
      'temporary',
    ]) {
      await Directory(p.join(root.path, directory)).create(recursive: true);
    }
    previousPaths = PathProviderPlatform.instance;
    paths = _QrPaths(root);
    PathProviderPlatform.instance = paths;
    await sql_cipher.databaseFactory.setDatabasesPath(
      p.join(root.path, 'databases'),
    );
    SharedPreferences.setMockInitialValues({});
    preferences = _QrPreferences();
    SharedPreferencesStorePlatform.instance = preferences;
    await StorageService.init();
    repo.clearAuthTransitionFailureForTest();
    SqliteService.setDbUnavailableForTest();
    PushNotificationService.instance.resetForTest();
    HttpClient.adapterForTest = _SyntheticHttpAdapter();
    secure = {};
    secretMutations = [];
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(databaseChannel, (call) async {
      if (call.method == 'getDatabasesPath') {
        return p.join(root.path, 'databases');
      }
      if (call.method == 'deleteDatabase') return null;
      throw StateError('Unexpected database operation: ${call.method}');
    });
    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'getActiveNotifications') return <dynamic>[];
      throw StateError('Unexpected notification operation: ${call.method}');
    });
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return secure[key];
        case 'readAll':
          return Map<String, String>.from(secure);
        case 'write':
          secretMutations.add('write:$key');
          secure[key!] = args['value'] as String;
          return null;
        case 'delete':
          secretMutations.add('delete:$key');
          secure.remove(key);
          return null;
      }
      throw StateError('Unexpected secure operation: ${call.method}');
    });
    AccountLocalDataService.resetInitialOwnershipForTest();
    await capture();
  });

  tearDown(() async {
    RuntimeFeatureRecovery.dispose();
    WebSocketService.to.dispose();
    PersistentMessageQueue.to.dispose();
    HttpClient.adapterForTest = null;
    AccountLocalDataService.resetInitialOwnershipForTest();
    SqliteService.setDbForTest(null);
    PathProviderPlatform.instance = previousPaths;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      secureChannel,
      databaseChannel,
      notificationsChannel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    await root.delete(recursive: true);
  });

  test(
    'QR waits for durable ownership before publishing any session data',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      preferences.beforeRegistryWrite = () async {
        entered.complete();
        await release.future;
      };
      final generation = repo.sessionGeneration;
      final login = repo.loginAfterQr(uid: uid, token: token);
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        expect(repo.isAuthTransitioning, isTrue);
        expect(repo.sessionGeneration, generation + 1);
        expect(secretMutations, isEmpty);
        expect(repo.currentUid, isEmpty);
        expect(StorageService.getMap(Keys.currentUser), isEmpty);
      } finally {
        release.complete();
      }
      expect(await login, isTrue);
      expect(repo.currentUid, uid);
      expect(secure['secure_token'], token);
      expect(registered().single.storageOwnershipVerified, isTrue);
      expect(registered().single.aliases, isEmpty);
      expect(history.readHistory(Keys.loginHistory), isEmpty);
      expect(StorageService.to.getString(Keys.lastLoginAccount), isEmpty);
      expect(history.ownsLastSession(identity()), isTrue);
    },
  );

  test(
    'failed QR owner persistence publishes no credentials, UID or profile',
    () async {
      preferences.failRegistry = true;
      await expectLater(
        repo.loginAfterQr(uid: uid, token: token),
        throwsStateError,
      );
      expect(secretMutations, isEmpty);
      expect(repo.currentUid, isEmpty);
      expect(StorageService.getMap(Keys.currentUser), isEmpty);
      expect(
        StorageService.to.containsKey(LoginAccountHistoryService.storageKey),
        isFalse,
      );
    },
  );

  for (final invalidUid in <String?>[null, '', '   ']) {
    test('QR missing authoritative UID ($invalidUid) performs zero writes', () {
      final generation = repo.sessionGeneration;
      expect(
        () => repo.loginAfterQr(uid: invalidUid, token: token),
        throwsArgumentError,
      );
      expect(repo.sessionGeneration, generation);
      expect(StorageService.to.getKeys(), isEmpty);
      expect(secretMutations, isEmpty);
    });
  }

  test(
    'QR rejects an empty token without weakening ordinary login validation',
    () {
      expect(() => repo.loginAfterQr(uid: uid, token: ''), throwsArgumentError);
      expect(
        () => repo.loginAfter('ordinary', {'uid': uid, 'token': token}),
        throwsArgumentError,
      );
      expect(StorageService.to.getKeys(), isEmpty);
      expect(secretMutations, isEmpty);
    },
  );

  test(
    'QR clears previous refresh token and preserves display history',
    () async {
      secure['secure_refresh_token'] = 'synthetic-previous-refresh-token';
      await StorageService.to.setList(Keys.loginHistory, ['previous-alias']);
      await StorageService.to.setString(
        Keys.lastLoginAccount,
        'previous-alias',
      );
      expect(await repo.loginAfterQr(uid: uid, token: token), isTrue);
      expect(secure.containsKey('secure_refresh_token'), isFalse);
      expect(secretMutations, contains('delete:secure_refresh_token'));
      expect(history.readHistory(Keys.loginHistory), ['previous-alias']);
      expect(
        StorageService.to.getString(Keys.lastLoginAccount),
        'previous-alias',
      );
    },
  );

  test(
    'QR does not inherit a same-UID profile from another endpoint',
    () async {
      final other = await history.rememberLogin(
        account: 'other-endpoint-alias',
        profile: {'uid': uid},
        environment: currentEnv,
        endpoint: 'http://127.0.0.1:9802',
        storageWasUnusedAtStartup: true,
      );
      await StorageService.setMap(Keys.currentUser, {
        'uid': uid,
        'nickname': 'other endpoint profile',
        LoginAccountHistoryService.localProfileKey: other.toJson(),
      });
      expect(await repo.loginAfterQr(uid: uid, token: token), isTrue);
      final profile = StorageService.getMap(Keys.currentUser);
      expect(profile.containsKey('nickname'), isFalse);
      expect(history.ownsLastSession(identity()), isTrue);
      expect(registered(), hasLength(2));
      expect(
        () => history.requireIndependentStorage(identity()),
        throwsA(isA<LoginAccountSharedDataException>()),
      );
    },
  );

  test(
    'QR cannot publish while historical cleanup holds the session boundary',
    () async {
      await history.rememberLogin(
        account: 'cleanup-alias',
        profile: {'uid': uid},
        environment: currentEnv,
        endpoint: Env().apiBaseUrl,
        storageWasUnusedAtStartup:
            AccountLocalDataService.wasStorageUnusedAtStartup(identity()),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      paths.beforeSupportRead = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        throw StateError('synthetic read-only preflight stop');
      };
      final cleanup = expectLater(
        repo.clearHistoricalAccountData('cleanup-alias'),
        throwsStateError,
      );
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        final generation = repo.sessionGeneration;
        expect(
          () => repo.loginAfterQr(uid: 'another-qr-owner', token: token),
          throwsA(isA<LoginAccountCleanupBusyException>()),
        );
        expect(repo.sessionGeneration, generation);
        expect(repo.currentUid, isEmpty);
        expect(secretMutations, isEmpty);
      } finally {
        release.complete();
        await cleanup;
      }
    },
  );

  test(
    'QR provenance survives restart and later password-login cleanup',
    () async {
      expect(await repo.loginAfterQr(uid: uid, token: token), isTrue);
      const draftKey = 'draft_v2:$uid:C2C:synthetic-peer';
      await StorageService.to.setString(draftKey, 'synthetic QR draft');
      expect(await repo.quitLogin(), isTrue);
      RuntimeFeatureRecovery.dispose();
      AccountLocalDataService.resetInitialOwnershipForTest();
      await StorageService.init();
      await capture();
      expect(
        AccountLocalDataService.wasStorageUnusedAtStartup(identity()),
        isFalse,
      );
      expect(
        await repo.loginAfter('confirmed-password-alias', {
          'uid': uid,
          'token': token,
          'refreshtoken': 'synthetic-new-refresh-token',
        }),
        isTrue,
      );
      expect(registered().single.storageOwnershipVerified, isTrue);
      expect(await repo.quitLogin(), isTrue);
      await repo.clearHistoricalAccountData('confirmed-password-alias');
      expect(StorageService.to.containsKey(draftKey), isFalse);
      expect(registered(), isEmpty);
    },
  );
}
