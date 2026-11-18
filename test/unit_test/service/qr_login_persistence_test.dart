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
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/helper/func.dart' show getOperatingSystem;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart'
    show currentEnv, deviceId, serviceContainer;
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

final class _QrIsolatedEnv implements Env {
  const _QrIsolatedEnv();
  @override
  String get apiBaseUrl => 'http://127.0.0.1:0';
  @override
  String get solidifiedKey => 'synthetic-qr-signing-key';
  @override
  String? get wsUrl => 'ws://127.0.0.1:0/ws';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  bool failHydratedProfile = false;
  Future<void> Function()? beforeRegistryWrite;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failHydratedProfile &&
        key == 'flutter.${Keys.currentUser}' &&
        value is String &&
        (jsonDecode(value) as Map).containsKey('nickname')) {
      return false;
    }
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
  int createRequests = 0;
  Map<String, dynamic>? lastCreateBody;
  int profileRequests = 0;
  int profileStatusCode = 200;
  int? lastProfileStatusCode;
  Future<void> Function()? beforeProfileResponse;
  Map<String, dynamic> profileResponse = {
    'code': 0,
    'payload': {
      'uid': '9007199254740993',
      'nickname': 'Hydrated synthetic',
      'account': 'hydrated-account',
      'email': '',
      'avatar': '',
      'gender': 3,
      'region': 'Hydrated region',
      'sign': 'Hydrated sign',
      'setting': {
        'allow_search': 2,
        'enable_visibility_read': 'false',
        'visibility_read_fraction': '0.83',
        'visibility_read_delay_ms': '1350',
        'font_size': 'huge',
      },
    },
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var responseStatus = 200;
    Map<String, dynamic> response = {
      'code': 503,
      'msg': 'synthetic unavailable',
    };
    if (options.path == '/api/v1/passport/qr_login/create') {
      createRequests++;
      lastCreateBody = Map<String, dynamic>.from(options.data as Map);
      final sessionToken = qrSessionToken;
      await beforeCreateResponse?.call();
      response = {
        'code': 0,
        'payload': {
          'qr_token': 'synthetic-qr-code',
          'session_token': sessionToken,
          'expires_in': 60,
        },
      };
    } else if (options.path == '/api/v1/user/me') {
      profileRequests++;
      responseStatus = profileStatusCode;
      lastProfileStatusCode = responseStatus;
      await beforeProfileResponse?.call();
      response = profileResponse;
    } else if (options.path == '/api/v1/passport/qr_login/status') {
      statusRequests++;
      beforeQrStatus?.call(options);
      await beforeStatusResponse?.call();
      response = qrStatusResponse ?? response;
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      responseStatus,
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
  // Existing persistence tests model browser hydration using a VM runner.
  @override
  bool get shouldHydrateWebProfile => true;

  @override
  QRLoginState build() => const QRLoginState(sessionToken: 'synthetic-session');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Keep the test isolate on an unreachable endpoint, including late callbacks.
  envMap['dev'] = const _QrIsolatedEnv();
  currentEnv = 'dev';
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
  late String previousDeviceId;
  late String previousEnv;
  late Map<String, Env> previousEnvMap;
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
    const wsOverride = String.fromEnvironment('WS_URL_OVERRIDE');
    expect(
      wsOverride,
      isEmpty,
      reason: 'QR tests require isolated WS configuration',
    );
    previousEnv = currentEnv;
    previousEnvMap = Map<String, Env>.of(envMap);
    addTearDown(() {
      envMap
        ..clear()
        ..addAll(previousEnvMap);
      currentEnv = previousEnv;
    });
    currentEnv = 'qr-isolated';
    envMap[currentEnv] = const _QrIsolatedEnv();
    expect(Env().apiBaseUrl, 'http://127.0.0.1:0');
    expect(Env.effectiveWsUrl, 'ws://127.0.0.1:0/ws');
    previousDeviceId = deviceId;
    deviceId = 'synthetic-qr-device';
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
      HttpClient(conf: HttpConfig(baseUrl: Env().apiBaseUrl)),
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
    deviceId = previousDeviceId;
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

  test('Native QR create uses the actual device platform, not web', () async {
    await notifier.generateQRCode();
    expect(adapter.createRequests, 1);
    expect(adapter.lastCreateBody, containsPair('device_id', deviceId));
    expect(
      adapter.lastCreateBody,
      containsPair('platform', getOperatingSystem()),
    );
    expect(adapter.lastCreateBody, containsPair('purpose', 'human'));
    expect(adapter.lastCreateBody?['platform'], isNot('web'));
  });

  test(
    'create response after anonymous generation changes cannot publish failure',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      adapter.beforeCreateResponse = () async {
        entered.complete();
        await release.future;
      };
      final creating = notifier.generateQRCode();
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        expect(await repo.quitLogin(), isTrue);
      } finally {
        release.complete();
        await creating;
      }
      expect(container.read(qRLoginProvider).status, QRLoginStatus.waiting);
      expect(container.read(qRLoginProvider).sessionToken, isNull);
      expect(container.read(qRLoginProvider).errorMessage, isNull);
      expect(adapter.createRequests, 1);
    },
  );

  test(
    'QR success waits for current owner profile, then replaces fields safely',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      adapter.beforeProfileResponse = () async {
        entered.complete();
        await release.future;
      };
      notifier.startSseSession('synthetic-session');
      final success = waitForStatus(QRLoginStatus.success);
      sse.confirmed(confirmed);
      try {
        await entered.future.timeout(const Duration(seconds: 8));
        expect(repo.currentUid, uid);
        expect(
          container.read(qRLoginProvider).status,
          QRLoginStatus.confirming,
        );
        expect(repo.current.nickname, isEmpty);
      } finally {
        release.complete();
      }
      await success;
      expect(repo.current.nickname, 'Hydrated synthetic');
      expect(repo.setting.allowSearch, isFalse);
      expect(repo.setting.enableVisibilityRead, isFalse);
      expect(repo.setting.visibilityReadFraction, .83);
      expect(repo.setting.visibilityReadDelayMs, 1350);
      expect(repo.setting.fontSize, 'huge');
      expect(repo.current.account, 'hydrated-account');
      expect(repo.current.region, 'Hydrated region');
      expect(repo.current.gender, 3);
      expect(adapter.profileRequests, 1);
      expect(secure['secure_token'], token);
    },
  );

  test(
    'profile failure retains active session and retries only the profile read',
    () async {
      adapter.profileResponse = {
        'code': 503,
        'msg': 'synthetic profile unavailable',
      };
      notifier.startSseSession('synthetic-session');
      final failed = waitForStatus(QRLoginStatus.failed);
      sse.confirmed(confirmed);
      await failed;
      expect(repo.currentUid, uid);
      expect(secure['secure_token'], token);
      expect(
        container.read(qRLoginProvider).errorMessage,
        'synthetic profile unavailable',
      );
      expect(notifier.canRetryProfile, isTrue);
      final generation = repo.sessionGeneration;
      final mutations = List<String>.of(secretMutations);
      adapter.profileResponse = {
        'code': 0,
        'payload': {
          'uid': uid,
          'nickname': 'Recovered',
          'setting': {'allow_search': false},
          'account': 'recovered',
          'email': '',
          'avatar': '',
          'gender': 3,
          'region': '',
          'sign': '',
        },
      };
      await notifier.refresh();
      expect(container.read(qRLoginProvider).status, QRLoginStatus.success);
      expect(repo.current.nickname, 'Recovered');
      expect(adapter.profileRequests, 2);
      expect(adapter.createRequests, 0);
      expect(repo.sessionGeneration, generation);
      expect(secretMutations, mutations);
    },
  );

  test(
    'profile mismatched UID fails without overwriting the committed owner',
    () async {
      adapter.profileResponse = {
        'code': 0,
        'payload': {'uid': 'another-owner', 'nickname': 'Forbidden'},
      };
      notifier.startSseSession('synthetic-session');
      final failed = waitForStatus(QRLoginStatus.failed);
      sse.confirmed(confirmed);
      await failed;
      expect(repo.currentUid, uid);
      expect(repo.current.uid, uid);
      expect(repo.current.nickname, isEmpty);
      expect(secure['secure_token'], token);
    },
  );

  test(
    'late profile after account replacement never writes into the new account',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      adapter.beforeProfileResponse = () async {
        entered.complete();
        await release.future;
      };
      notifier.startSseSession('synthetic-session');
      sse.confirmed(confirmed);
      try {
        await entered.future.timeout(const Duration(seconds: 8));
        expect(await repo.quitLogin(), isTrue);
        expect(
          await repo.loginAfterQr(uid: 'another-qr-owner', token: token),
          isTrue,
        );
      } finally {
        release.complete();
      }
      await Future<void>.delayed(Duration.zero);
      expect(repo.currentUid, 'another-qr-owner');
      expect(repo.current.uid, 'another-qr-owner');
      expect(repo.current.nickname, isEmpty);
      expect(
        container.read(qRLoginProvider).status,
        isNot(QRLoginStatus.success),
      );
    },
  );

  test(
    'profile persistence failure never publishes success and can retry',
    () async {
      preferences.failHydratedProfile = true;
      notifier.startSseSession('synthetic-session');
      final failed = waitForStatus(QRLoginStatus.failed);
      sse.confirmed(confirmed);
      await failed;
      expect(repo.currentUid, uid);
      expect(secure['secure_token'], token);
      expect(container.read(qRLoginProvider).status, QRLoginStatus.failed);
      preferences.failHydratedProfile = false;
      await notifier.refresh();
      expect(container.read(qRLoginProvider).status, QRLoginStatus.success);
      expect(repo.current.nickname, 'Hydrated synthetic');
      expect(repo.setting.allowSearch, isFalse);
      expect(repo.setting.enableVisibilityRead, isFalse);
      expect(repo.setting.visibilityReadFraction, .83);
      expect(repo.setting.visibilityReadDelayMs, 1350);
      expect(repo.setting.fontSize, 'huge');
    },
  );

  test(
    'profile result from the previous environment cannot publish success',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      adapter.beforeProfileResponse = () async {
        entered.complete();
        await release.future;
      };
      notifier.startSseSession('synthetic-session');
      sse.confirmed(confirmed);
      try {
        await entered.future.timeout(const Duration(seconds: 8));
        currentEnv = 'qr-other';
        envMap[currentEnv] = const _QrIsolatedEnv();
      } finally {
        release.complete();
      }
      await Future<void>.delayed(Duration.zero);
      expect(repo.currentUid, uid);
      expect(repo.current.nickname, isEmpty);
      expect(
        container.read(qRLoginProvider).status,
        isNot(QRLoginStatus.success),
      );
      expect(notifier.canRetryProfile, isFalse);
    },
  );

  test(
    'real profile HTTP401 invokes owned logout without bypassing auth handling',
    () async {
      adapter.profileStatusCode = 401;
      late Map<String, dynamic> retainedProfile;
      adapter.beforeProfileResponse = () async {
        retainedProfile = StorageService.getMap(Keys.currentUser);
      };
      adapter.profileResponse = {
        'code': 401,
        'msg': 'synthetic session expired',
      };
      final expired = Completer<void>();
      final previous = HttpClient.onAuthExpired;
      var notifications = 0;
      HttpClient.onAuthExpired = () {
        notifications++;
        if (!expired.isCompleted) expired.complete();
      };
      addTearDown(() => HttpClient.onAuthExpired = previous);
      notifier.startSseSession('synthetic-session');
      sse.confirmed(confirmed);
      await expired.future.timeout(const Duration(seconds: 8));
      expect(adapter.profileRequests, 1);
      expect(adapter.lastProfileStatusCode, 401);
      expect(repo.currentUid, isEmpty);
      expect(repo.isLoggedIn, isFalse);
      // SEC02（属主裁决 2026-11-16，user_repo_local.quitLogin）：登出保留
      // _login_account_identity_v1 所有权证明（uid/env/endpoint，历史账号
      // 清理授权链 ownsLastSession→clearLastSessionData 依赖它），但清除
      // 顶层 uid 与展示性 PII；sanitized 形状已由 DEF-LOGOUT-RELOAD-INIT-
      // POISON 读侧适配（8b271618d）固化为分支约定。
      expect(StorageService.getMap(Keys.currentUser), {
        LoginAccountHistoryService.localProfileKey:
            retainedProfile[LoginAccountHistoryService.localProfileKey],
      });
      expect(secure.containsKey('secure_token'), isFalse);
      expect(secure.containsKey('secure_refresh_token'), isFalse);
      expect(notifications, 1);
      expect(notifier.canRetryProfile, isFalse);
      // Chrome separately exercises Page cancellation; this host fixture has no Web Page.
    },
  );

  test(
    'password session commits original typed settings without QR-only parsing',
    () async {
      final setting = <String, dynamic>{
        'enable_visibility_read': 'garbage',
        'manual_pending': {'nested': true},
        'font_size': 'huge',
      };
      expect(
        await repo.loginAfter('synthetic-password-account', {
          'uid': uid,
          'token': token,
          'refreshtoken': 'synthetic-password-refresh',
          'account': 'synthetic-password-account',
          'nickname': 'Password owner',
          'setting': setting,
        }),
        isTrue,
      );
      expect(repo.currentUid, uid);
      expect(StorageService.getMap(Keys.currentUser)['setting'], setting);
      expect(secure['secure_token'], token);
      // Actual panel's malformed-setting case independently proves no read side effect.
    },
  );

  test('missing device identity rejects QR creation before request', () async {
    deviceId = '';
    await notifier.generateQRCode();
    expect(container.read(qRLoginProvider).status, QRLoginStatus.failed);
    expect(adapter.createRequests, 0);
  });

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
    'older create response cannot replace the refreshed QR session',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      adapter.qrSessionToken = 'synthetic-old-session';
      adapter.beforeCreateResponse = () async {
        entered.complete();
        await release.future;
      };
      final oldCreate = notifier.generateQRCode();
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        adapter.beforeCreateResponse = null;
        adapter.qrSessionToken = 'synthetic-current-session';
        await notifier.refresh();
        expect(
          container.read(qRLoginProvider).sessionToken,
          'synthetic-current-session',
        );
      } finally {
        release.complete();
        await oldCreate;
      }
      expect(
        container.read(qRLoginProvider).sessionToken,
        'synthetic-current-session',
      );
      expect(secretMutations, isEmpty);
    },
  );

  for (final disposeInstead in [false, true]) {
    test(
      'retiring QR during create ignores its response (dispose=$disposeInstead)',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        adapter.beforeCreateResponse = () async {
          entered.complete();
          await release.future;
        };
        final creating = notifier.generateQRCode();
        try {
          await entered.future.timeout(const Duration(seconds: 5));
          if (disposeInstead) {
            notifier.dispose();
          } else {
            notifier.cancelQRCode();
          }
        } finally {
          release.complete();
          await creating;
        }
        expect(container.read(qRLoginProvider).sessionToken, isNull);
        expect(container.read(qRLoginProvider).qrData, isNull);
        expect(adapter.statusRequests, 0);
        expect(secretMutations, isEmpty);
      },
    );
  }

  test(
    'switching to password closes SSE and ignores late confirmed frames',
    () async {
      final generation = repo.sessionGeneration;
      notifier.startSseSession('synthetic-session');
      notifier.cancelQRCode();
      sse.confirmed(confirmed);
      await Future<void>.delayed(Duration.zero);
      expect(sse.closed, isTrue);
      expect(container.read(qRLoginProvider).sessionToken, isNull);
      expect(repo.sessionGeneration, generation);
      expect(repo.currentUid, isEmpty);
      expect(secretMutations, isEmpty);
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
        endpoint: 'http://127.0.0.2:0',
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
