import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:imboy/config/init.dart' show currentEnv, serviceContainer;
import 'package:imboy/page/passport/sse_client.dart';
import 'package:imboy/page/passport/web_login_page.dart';
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
  Map<String, dynamic>? qrStatusResponse;
  String qrSessionToken = 'synthetic-session';
  Future<void> Function()? beforeCreateResponse;
  void Function(RequestOptions)? beforeQrStatus;
  Future<void> Function()? beforeStatusResponse;
  int statusRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic> response = {
      'code': 503,
      'msg': 'synthetic unavailable',
    };
    if (options.path == '/api/v1/passport/qr_login/create') {
      await beforeCreateResponse?.call();
      response = {
        'code': 0,
        'payload': {
          'qr_token': 'synthetic-qr-code',
          'session_token': qrSessionToken,
          'expires_in': 60,
        },
      };
    } else if (options.path == '/api/v1/passport/qr_login/status') {
      statusRequests++;
      beforeQrStatus?.call(options);
      await beforeStatusResponse?.call();
      response = qrStatusResponse ?? response;
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SyntheticSseClient implements SseClient {
  final _frames = StreamController<String>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  bool closed = false;

  @override
  bool get isOpen => !closed;
  @override
  Stream<String> get frames => _frames.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Future<void> connect(String url) async {}
  @override
  Future<void> close() async => closed = true;

  void confirmed(Map<String, dynamic> payload) =>
      _frames.add('data: ${jsonEncode(payload)}');
  void disconnect() => _errors.add(StateError('synthetic disconnect'));
}

class _ReadyQrLogin extends QRLogin {
  @override
  QRLoginState build() => const QRLoginState(sessionToken: 'synthetic-session');
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
  const uid = '9007199254740993';
  const token = 'synthetic-qr-access-token';
  final repo = UserRepoLocal.to;
  final history = LoginAccountHistoryService();
  late Directory root;
  late PathProviderPlatform previousPaths;
  late _QrPaths paths;
  late _QrPreferences preferences;
  late Map<String, String> secure;
  late List<String> secretMutations;
  late ProviderContainer container;
  late QRLogin notifier;
  late _SyntheticSseClient sse;
  late _SyntheticHttpAdapter adapter;

  const confirmed = {
    'status': 'confirmed',
    'token': token,
    // Simulate the legacy JSON number after browser rounding.
    'uid': 9007199254740992,
    'uid_str': uid,
  };

  Future<void> waitForStatus(QRLoginStatus status) async {
    final reached = Completer<void>();
    final subscription = container.listen(qRLoginProvider, (_, state) {
      if (state.status == status && !reached.isCompleted) reached.complete();
    }, fireImmediately: true);
    try {
      await reached.future.timeout(const Duration(seconds: 8));
    } finally {
      subscription.close();
    }
  }

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
    adapter = _SyntheticHttpAdapter();
    HttpClient.adapterForTest = adapter;
    serviceContainer.put(
      HttpClient(options: BaseOptions(baseUrl: Env().apiBaseUrl)),
    );
    container = ProviderContainer(
      overrides: [qRLoginProvider.overrideWith(_ReadyQrLogin.new)],
    );
    container.listen(qRLoginProvider, (_, _) {});
    notifier = container.read(qRLoginProvider.notifier);
    sse = _SyntheticSseClient();
    notifier.sseClientBuilderForTesting = () => sse;
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
    notifier.dispose();
    container.dispose();
    serviceContainer.clear();
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
    'SSE preserves exact UID, persists owner first, and publishes only once',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      preferences.beforeRegistryWrite = () async {
        entered.complete();
        await release.future;
      };
      final generation = repo.sessionGeneration;
      notifier.startSseSession('synthetic-session');
      final success = waitForStatus(QRLoginStatus.success);
      sse.confirmed(confirmed);
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        expect(
          container.read(qRLoginProvider).status,
          QRLoginStatus.confirming,
        );
        expect(repo.currentUid, isEmpty);
        expect(secretMutations, isEmpty);
        expect(repo.sessionGeneration, generation + 1);
        sse.confirmed(confirmed);
        sse.disconnect();
        await Future<void>.delayed(Duration.zero);
        expect(repo.sessionGeneration, generation + 1);
        expect(sse.closed, isTrue);
        expect(adapter.statusRequests, 0);
      } finally {
        release.complete();
      }
      await success;
      sse.confirmed(confirmed);
      sse.confirmed(const {'status': 'expired'});
      await Future<void>.delayed(Duration.zero);
      expect(repo.currentUid, uid);
      expect(secure['secure_token'], token);
      expect(registered().single.uid, uid);
      expect(registered().single.storageOwnershipVerified, isTrue);
      expect(repo.sessionGeneration, generation + 1);
      expect(
        secretMutations.where((item) => item == 'write:secure_token'),
        hasLength(1),
      );
      expect(container.read(qRLoginProvider).status, QRLoginStatus.success);
    },
  );

  for (final uidFields in <Map<String, dynamic>>[
    {},
    {'uid': 9007199254740992},
    {'uid': 42, 'uid_str': ''},
    {'uid': 42, 'uid_str': '43'},
  ]) {
    test('SSE invalid authority $uidFields publishes no session', () async {
      final generation = repo.sessionGeneration;
      notifier.startSseSession('synthetic-session');
      final failed = waitForStatus(QRLoginStatus.failed);
      sse.confirmed({'status': 'confirmed', 'token': token, ...uidFields});
      await failed;
      expect(repo.sessionGeneration, generation);
      expect(repo.currentUid, isEmpty);
      expect(secretMutations, isEmpty);
      expect(StorageService.to.getKeys(), isEmpty);
    });
  }

  test('polling confirmed uses the same exact owner and token', () async {
    adapter.qrStatusResponse = {'code': 0, 'payload': confirmed};
    final success = waitForStatus(QRLoginStatus.success);
    await notifier.generateQRCode();
    await success;
    expect(adapter.statusRequests, 1);
    expect(repo.currentUid, uid);
    expect(secure['secure_token'], token);
    expect(registered().single.uid, uid);
  });

  test(
    'refresh invalidates old in-flight polling before new create returns',
    () async {
      final oldPollEntered = Completer<void>();
      final releaseOldPoll = Completer<void>();
      final newCreateEntered = Completer<void>();
      final releaseNewCreate = Completer<void>();
      adapter.qrStatusResponse = {'code': 0, 'payload': confirmed};
      adapter.beforeQrStatus = (_) => oldPollEntered.complete();
      adapter.beforeStatusResponse = () => releaseOldPoll.future;
      final generation = repo.sessionGeneration;
      await notifier.generateQRCode();
      await oldPollEntered.future.timeout(const Duration(seconds: 8));
      adapter.beforeCreateResponse = () async {
        newCreateEntered.complete();
        await releaseNewCreate.future;
      };
      adapter.qrSessionToken = 'synthetic-refreshed-session';
      final refreshing = notifier.refresh();
      try {
        await newCreateEntered.future.timeout(const Duration(seconds: 5));
        expect(container.read(qRLoginProvider).sessionToken, isNull);
        releaseOldPoll.complete();
        await Future<void>.delayed(Duration.zero);
        expect(repo.sessionGeneration, generation);
        expect(repo.currentUid, isEmpty);
        expect(secretMutations, isEmpty);
      } finally {
        if (!releaseOldPoll.isCompleted) releaseOldPoll.complete();
        releaseNewCreate.complete();
        await refreshing;
      }
      expect(
        container.read(qRLoginProvider).sessionToken,
        'synthetic-refreshed-session',
      );
      expect(repo.sessionGeneration, generation);
      expect(repo.currentUid, isEmpty);
    },
  );

  test(
    'disconnect before claim closes SSE and completes via polling',
    () async {
      adapter.qrStatusResponse = {'code': 0, 'payload': confirmed};
      adapter.beforeQrStatus = (options) {
        expect(sse.closed, isTrue);
        expect(options.queryParameters['session_token'], 'synthetic-session');
      };
      final generation = repo.sessionGeneration;
      notifier.startSseSession('synthetic-session');
      final success = waitForStatus(QRLoginStatus.success);
      sse.disconnect();
      await success;
      expect(adapter.statusRequests, 1);
      expect(repo.sessionGeneration, generation + 1);
      expect(repo.currentUid, uid);
      expect(secure['secure_token'], token);
      expect(registered().single.uid, uid);
    },
  );

  test(
    'disconnect after server claim cannot reuse an already-consumed token',
    () async {
      adapter.qrStatusResponse = {'code': 5203, 'msg': 'already claimed'};
      final polled = Completer<void>();
      adapter.beforeQrStatus = (_) => polled.complete();
      final generation = repo.sessionGeneration;
      notifier.startSseSession('synthetic-session');
      sse.disconnect();
      await polled.future.timeout(const Duration(seconds: 8));
      await Future<void>.delayed(Duration.zero);
      expect(sse.closed, isTrue);
      expect(repo.sessionGeneration, generation);
      expect(repo.currentUid, isEmpty);
      expect(secretMutations, isEmpty);
      expect(StorageService.to.getKeys(), isEmpty);
    },
  );

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
