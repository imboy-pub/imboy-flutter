// Real Native QR acceptance helpers. No fake transport, profile repair, or
// explicit socket connection: every check observes the application's session.
import 'dart:convert';
import 'dart:io' show InternetAddress, Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jose/jose.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/component/helper/func.dart' show getOperatingSystem;
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart'
    show currentEnv, deviceId, serviceContainer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/passport/qr_login_response_rules.dart';
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/api_test_client.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

class NativeQrFixture {
  NativeQrFixture._();

  static String get account => FlowConfig.testPhone;
  static String get password => FlowConfig.testPassword;
  static const expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
  static const expectedNickname = String.fromEnvironment(
    'TEST_EXPECTED_NICKNAME',
  );
  static const expectedAvatar = String.fromEnvironment('TEST_EXPECTED_AVATAR');
  static const runTag = String.fromEnvironment('NQR_RUN_TAG');
}

class NativeQrBlocked implements Exception {
  const NativeQrBlocked(this.reason);
  final String reason;
}

/// A blocked checkpoint must not return a successful test or a phase receipt.
/// The outer test maps this exception to an unexpected skip (runner BLOCKED).
class NativeQrEvidence {
  NativeQrEvidence(this.scenario);
  final String scenario;
  final Map<String, String> _results = {};

  void check(String id, bool passed, String detail) =>
      _record(id, passed ? 'PASS' : 'FAIL', detail);

  void blocked(String id, String reason) => _record(id, 'BLOCKED', reason);

  void _record(String id, String status, String detail) {
    _results[id] = '$status: $detail';
    flowLog('NATIVE_QR $scenario/$id ${_results[id]}');
  }

  Future<void> capture(
    String id,
    Future<bool> Function() action,
    String detail,
  ) async {
    try {
      check(id, await action(), detail);
    } on NativeQrBlocked catch (error) {
      blocked(id, error.reason);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        blocked(id, 'Backend connection unavailable (${error.type.name})');
      } else {
        check(id, false, '$detail (${error.type.name})');
      }
    } catch (error) {
      // Exception text can contain RequestOptions and bearer credentials.
      check(id, false, '$detail (${error.runtimeType})');
    }
  }

  void finish() {
    if (_results.isEmpty) {
      throw const NativeQrBlocked('No checkpoints executed');
    }
    final failures = _results.entries.where((e) => e.value.startsWith('FAIL:'));
    if (failures.isNotEmpty) {
      throw TestFailure(
        '$scenario\n${failures.map((e) => '${e.key}: ${e.value}').join('\n')}',
      );
    }
    final blocked = _results.entries.where(
      (e) => e.value.startsWith('BLOCKED:'),
    );
    if (blocked.isNotEmpty) {
      throw NativeQrBlocked(
        blocked.map((e) => '${e.key}: ${e.value}').join('\n'),
      );
    }
  }
}

bool _localUrl(String value, Set<String> schemes) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      schemes.contains(uri.scheme) &&
      uri.userInfo.isEmpty &&
      (InternetAddress.tryParse(uri.host)?.isLoopback ?? false);
}

String _normalizedUrl(String value) => value.replaceFirst(RegExp(r'/$'), '');

/// Run before app initialization, including when bypassing the unified runner.
void requireNativeQrFixture() {
  const apiOverride = String.fromEnvironment('API_BASE_URL_OVERRIDE');
  const wsOverride = String.fromEnvironment('WS_URL_OVERRIDE');
  final missing = <String>[
    if (!Platform.isMacOS) 'macOS (this acceptance contract)',
    if (FlowConfig.appEnv != 'local') 'APP_ENV=local',
    if (const String.fromEnvironment('IMBOY_TEST_ISOLATED') != 'true')
      'IMBOY_TEST_ISOLATED=true',
    if (!FlowConfig.allowBusinessWrites) 'TEST_ALLOW_BUSINESS_WRITES=true',
    if (!_localUrl(FlowConfig.apiBaseUrl, {'http', 'https'}) ||
        _normalizedUrl(apiOverride) != _normalizedUrl(FlowConfig.apiBaseUrl))
      'matching explicit loopback API_BASE_URL/API_BASE_URL_OVERRIDE',
    if (!_localUrl(wsOverride, {'ws', 'wss'}))
      'explicit loopback WS_URL_OVERRIDE',
    if (const String.fromEnvironment('SOLIDIFIED_KEY_OVERRIDE').isEmpty ||
        const String.fromEnvironment('SOLIDIFIED_KEY_IV_OVERRIDE').isEmpty)
      'SOLIDIFIED_KEY_OVERRIDE/SOLIDIFIED_KEY_IV_OVERRIDE',
    if (NativeQrFixture.account.isEmpty || NativeQrFixture.password.isEmpty)
      'TEST_PHONE/TEST_PASSWORD (account fixture)',
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(NativeQrFixture.expectedUid))
      'TEST_EXPECTED_UID',
    if (NativeQrFixture.expectedNickname.trim().isEmpty ||
        NativeQrFixture.expectedAvatar.trim().isEmpty)
      'nonempty TEST_EXPECTED_NICKNAME/TEST_EXPECTED_AVATAR',
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$')
        .hasMatch(NativeQrFixture.runTag))
      'NQR_RUN_TAG',
  ];
  if (missing.isNotEmpty) {
    throw NativeQrBlocked(missing.join(', '));
  }
}

bool _booted = false;
bool _qrSignatureRejected = false;
final _createdQrDevices = <String, ({String did, String platform})>{};

/// Storage isolation belongs to the caller, so restore never creates a scope.
Future<void> bootNativeQrApp(WidgetTester tester) async {
  requireNativeQrFixture();
  if (_booted) {
    throw const NativeQrBlocked('Run each AT-WL case in its own process');
  }
  _booted = true;
  if (!await ensureBackendAvailable(forceRecheck: true)) {
    throw const NativeQrBlocked('Isolated backend is unavailable');
  }
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await ensureAppLaunched(
    tester,
    launch: (_) async {
      final testFlutterError = FlutterError.onError;
      final testPlatformError = PlatformDispatcher.instance.onError;
      try {
        await app.bootstrap();
      } finally {
        // run.dart installs production loggers; retain test failure reporting.
        FlutterError.onError = testFlutterError;
        PlatformDispatcher.instance.onError = testPlatformError;
      }
      // bootstrap schedules the first frame. Observe before pumping it, so a
      // failing automatic create is distinguishable from a product regression.
      if (serviceContainer.isRegistered<app_http.HttpClient>()) {
        final dio = app_http.HttpClient.client.dio;
        final observer = InterceptorsWrapper(
          onResponse: (response, handler) {
            if (response.requestOptions.uri.path.startsWith(
              '/api/v1/passport/qr_login/',
            )) {
              try {
                final body = _body(response.data);
                _qrSignatureRejected =
                    _qrSignatureRejected || body['code'] == 902;
                if (response.requestOptions.uri.path ==
                        '/api/v1/passport/qr_login/create' &&
                    body['code'] == 0) {
                  final payload = body['payload'];
                  final request = response.requestOptions.data;
                  if (payload is Map &&
                      request is Map &&
                      payload['session_token'] is String) {
                    _createdQrDevices[payload['session_token'] as String] = (
                      did: '${request['device_id'] ?? ''}',
                      platform: '${request['platform'] ?? ''}',
                    );
                  }
                }
              } on Object {
                // Observation must not change the application's response handling.
              }
            }
            handler.next(response);
          },
        );
        dio.interceptors.add(observer);
        addTearDown(() => dio.interceptors.remove(observer));
      }
    },
    maxSeconds: 2,
  );
  expect(
    await waitForNativeQr(tester, () => tester.any(find.byType(Navigator))),
    isTrue,
    reason: 'Native app bootstrap must mount its router',
  );
  if (currentEnv != 'local' ||
      _normalizedUrl(Env().apiBaseUrl) !=
          _normalizedUrl(FlowConfig.apiBaseUrl)) {
    throw const NativeQrBlocked(
      'App and scanner resolved different environments',
    );
  }
}

Future<bool> waitForNativeQr(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final clock = Stopwatch()..start();
  while (!ready() && clock.elapsed < timeout) {
    if (_qrSignatureRejected) {
      throw const NativeQrBlocked('Native QR signature rejected (902)');
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (_qrSignatureRejected) {
    throw const NativeQrBlocked('Native QR signature rejected (902)');
  }
  return ready();
}

class NativeQrSession {
  const NativeQrSession({
    required this.uid,
    required this.token,
    required this.did,
    required this.cos,
  });
  final String uid;
  final String token;
  final String did;
  final String cos;
}

Future<NativeQrSession> readNativeQrSession() async => NativeQrSession(
  uid: UserRepoLocal.to.currentUid,
  token: await SecureTokenStorageService.getToken(),
  did: deviceId,
  cos: getOperatingSystem(),
);

Map<String, dynamic> _body(dynamic data) {
  final decoded = data is String ? jsonDecode(data) : data;
  return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
}

bool _successful(Map<String, dynamic> body) {
  if (body['code'] == 902) {
    throw const NativeQrBlocked('Device signature rejected (902)');
  }
  return body['code'] == 0;
}

/// Observe the App's single-consumer status response; never poll it separately.
Future<NativeQrSession?> completeNativeQrLogin(
  WidgetTester tester,
  NativeQrEvidence evidence,
) async {
  final repo = UserRepoLocal.to;
  final anonymous =
      repo.currentUid.isEmpty &&
      (await repo.accessToken).isEmpty &&
      WebSocketService.to.status != SocketStatus.connected;
  evidence.check('anonymous', anonymous, 'Fresh isolated anonymous session');
  if (!anonymous) {
    return null;
  }
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  if (!tester.any(find.byType(WebLoginPage))) {
    router.go('/sign_in');
  }
  if (!await waitForNativeQr(
    tester,
    () => tester.any(find.byType(WebLoginPage)),
  )) {
    evidence.check('qr.entry', false, 'Native wide QR page must mount');
    return null;
  }
  final container = ProviderScope.containerOf(
    tester.element(find.byType(WebLoginPage)),
  );
  final ready = await waitForNativeQr(tester, () {
    final state = container.read(qRLoginProvider);
    return (state.qrData?.isNotEmpty ?? false) &&
        (state.sessionToken?.isNotEmpty ?? false);
  });
  evidence.check(
    'qr.auto_create',
    ready,
    'Page automatically creates a real QR session',
  );
  if (!ready) {
    return null;
  }
  final qr = container.read(qRLoginProvider);
  final creation = _createdQrDevices[qr.sessionToken];
  evidence.check(
    'qr.device',
    deviceId.isNotEmpty &&
        creation?.did == deviceId &&
        creation?.platform == getOperatingSystem() &&
        creation?.platform != 'web',
    'Observed automatic create carries the real Native DID and OS',
  );
  QrStatusConfirmed? confirmed;
  var signatureRejected = false;
  final observer = InterceptorsWrapper(
    onResponse: (response, handler) {
      if (response.requestOptions.uri.path ==
              '/api/v1/passport/qr_login/status' &&
          response.requestOptions.queryParameters['session_token'] ==
              qr.sessionToken) {
        try {
          final body = _body(response.data);
          signatureRejected = signatureRejected || body['code'] == 902;
          final result = parseQrStatusResponse(
            ok: body['code'] == 0,
            code: body['code'] is int ? body['code'] as int : -1,
            payload: body['payload'],
          );
          if (result is QrStatusConfirmed) {
            confirmed = result;
          }
        } on Object {
          // Leave malformed-response handling to the application; never change it.
        }
      }
      handler.next(response);
    },
  );
  final dio = app_http.HttpClient.client.dio;
  dio.interceptors.add(observer);
  final scannerDid = 'nqr-scanner-${NativeQrFixture.runTag}';
  evidence.check(
    'scanner.device',
    scannerDid.isNotEmpty && scannerDid != deviceId,
    'API scanner uses a separate device identity',
  );
  final scanner = FlowApiClient(
    baseUrl: FlowConfig.apiBaseUrl,
    deviceId: scannerDid,
    deviceType: 'android',
  );
  try {
    var scannerReady = false;
    await evidence.capture('scanner.login', () async {
      final response = await scanner.login(
        account: NativeQrFixture.account,
        password: NativeQrFixture.password,
        type: 'account',
        plainPassword: true,
      );
      scannerReady =
          _successful(response) &&
          scanner.currentUid == NativeQrFixture.expectedUid;
      if (!scannerReady) {
        final code = response['code'];
        throw NativeQrBlocked(
          'Scanner fixture authentication/owner mismatch '
          '(code=${code is int ? code : 'invalid'})',
        );
      }
      return scannerReady;
    }, 'API scanner authenticates as the fixture owner');
    if (!scannerReady) {
      return null;
    }
    var scanned = false;
    await evidence.capture('qr.scan', () async {
      scanned = _successful(
        await scanner.post(
          '/api/v1/passport/qr_login/scan',
          data: {'qr_token': qr.qrData},
        ),
      );
      return scanned;
    }, 'Backend accepts scanning this QR');
    if (!scanned) {
      return null;
    }
    evidence.check(
      'qr.scanned_ui',
      await waitForNativeQr(
        tester,
        () => tester.any(find.text(t.discovery.webQRScanned)),
      ),
      'Scanned, awaiting confirmation UI',
    );
    var accepted = false;
    await evidence.capture('qr.confirm', () async {
      accepted = _successful(
        await scanner.post(
          '/api/v1/passport/qr_login/confirm',
          data: {'qr_token': qr.qrData},
        ),
      );
      return accepted;
    }, 'Backend accepts scanner confirmation');
    if (!accepted) {
      return null;
    }
    final consumed = await waitForNativeQr(
      tester,
      () =>
          confirmed != null &&
          repo.currentUid.isNotEmpty &&
          !repo.isAuthTransitioning,
    );
    if (signatureRejected) {
      evidence.blocked('qr.consume', 'App polling signature rejected (902)');
      return null;
    }
    evidence.check(
      'qr.consume',
      consumed,
      'App polling consumes the real confirmed token',
    );
    if (!consumed) {
      return null;
    }
    final result = confirmed!;
    evidence.check(
      'qr.owner',
      result.uid == NativeQrFixture.expectedUid,
      'Status response identifies the expected UID without numeric rounding',
    );
    await evidence.capture(
      'qr.token_device',
      () async =>
          JsonWebToken.unverified(result.token).claims['did'] == deviceId,
      'Issued QR token binds the Native DID; protected HTTP verifies acceptance',
    );
    return NativeQrSession(
      uid: result.uid ?? '',
      token: result.token,
      did: deviceId,
      cos: getOperatingSystem(),
    );
  } finally {
    dio.interceptors.remove(observer);
    scanner.close();
  }
}

/// Independent checkpoints: missing profile must not hide HTTP or socket results.
Future<void> assertNativeQrSession(
  WidgetTester tester,
  NativeQrEvidence evidence, {
  NativeQrSession? expected,
}) async {
  final session = expected ?? await readNativeQrSession();
  final repo = UserRepoLocal.to;
  var persisted = false;
  await evidence.capture(
    'credentials',
    () async {
      final profile = StorageService.getMap(Keys.currentUser);
      persisted =
          session.token.isNotEmpty &&
          session.uid == NativeQrFixture.expectedUid &&
          repo.currentUid == session.uid &&
          await repo.accessToken == session.token &&
          await SecureTokenStorageService.getToken() == session.token &&
          (await SecureTokenStorageService.getRefreshToken()).isEmpty &&
          !profile.containsKey('token') &&
          !profile.containsKey('refreshtoken');
      return persisted;
    },
    'Same QR credential in real secure storage; no refresh token or plaintext profile secret',
  );
  if (!persisted) {
    for (final id in ['profile', 'http.protected', 'ws.automatic_ready']) {
      evidence.blocked(id, 'QR credentials were not committed');
    }
    return;
  }
  await evidence.capture(
    'navigation',
    () => waitForNativeQr(
      tester,
      () =>
          GoRouter.of(tester.element(find.byType(Navigator).first))
              .routeInformationProvider
              .value
              .uri
              .path ==
          '/bottom_navigation',
    ),
    'Native login route is /bottom_navigation',
  );
  await evidence.capture(
    'profile',
    () => waitForNativeQr(tester, () {
      final user = repo.currentUser;
      return user?.uid == session.uid &&
          user?.account == NativeQrFixture.account &&
          user?.nickname == NativeQrFixture.expectedNickname &&
          user?.avatar == NativeQrFixture.expectedAvatar;
    }),
    'App restores the nonempty fixture profile without test hydration',
  );
  await evidence.capture(
    'ws.automatic_ready',
    () async {
      final connected = await waitForNativeQr(
        tester,
        () => WebSocketService.to.status == SocketStatus.connected,
      );
      return connected &&
          repo.currentUid == session.uid &&
          await repo.accessToken == session.token &&
          deviceId == session.did;
    },
    'App socket reaches real ready automatically (handshake only, not message roundtrip)',
  );
  await evidence.capture('http.protected', () async {
    Map<String, dynamic>? sent;
    int? status;
    final observer = InterceptorsWrapper(
      onResponse: (response, handler) {
        if (response.requestOptions.uri.path == API.userDevicePage) {
          sent = Map.of(response.requestOptions.headers);
          status = response.statusCode;
        }
        handler.next(response);
      },
    );
    final client = app_http.HttpClient.client;
    client.dio.interceptors.add(observer);
    try {
      final response = await client.get(
        API.userDevicePage,
        queryParameters: {'page': 1, 'size': 10},
      );
      if (response.code == 902) {
        throw const NativeQrBlocked('App signature rejected (902)');
      }
      final payload = response.payload;
      final devices = payload is Map ? payload['list'] : null;
      final registered =
          devices is List &&
          devices.any(
            (row) =>
                row is Map &&
                row['device_id'] == session.did &&
                row['device_type'] == session.cos,
          );
      return response.code == 0 &&
          status == 200 &&
          registered &&
          sent?[Keys.tokenKey] == session.token &&
          sent?['did'] == session.did &&
          sent?['cos'] == session.cos &&
          session.cos != 'web' &&
          await repo.accessToken == session.token;
    } finally {
      client.dio.interceptors.remove(observer);
    }
  }, 'Production HTTP sends this QR token with the Native DID/OS');
}

/// Use independent Dio: production auth-expired handling would log out the App.
Future<void> assertNativeQrAuthNegatives(NativeQrEvidence evidence) async {
  final before = await readNativeQrSession();
  final generation = UserRepoLocal.to.sessionGeneration;
  final dio = Dio(
    BaseOptions(
      baseUrl: FlowConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status != null,
    ),
  );
  try {
    for (final invalid in [false, true]) {
      await evidence.capture(
        invalid ? 'http.invalid_token' : 'http.no_token',
        () async {
          final headers = await app_http.defaultHeaders();
          if (invalid) {
            headers[Keys.tokenKey] = 'not-a-jwt';
          }
          final response = await dio.get<dynamic>(
            API.userDevicePage,
            queryParameters: {'page': 1, 'size': 10},
            options: Options(headers: headers),
          );
          final body = _body(response.data);
          if (body['code'] == 902) {
            throw const NativeQrBlocked(
              'Negative probe signature rejected (902)',
            );
          }
          return response.statusCode == 401 &&
              body['code'] == (invalid ? 706 : 401) &&
              body['msg'] == (invalid ? 'Invalid token' : '未登录，请先登录');
        },
        'Real protected endpoint rejects ${invalid ? 'malformed' : 'absent'} credentials',
      );
    }
    final after = await readNativeQrSession();
    evidence.check(
      'http.negative_isolation',
      before.uid == after.uid &&
          before.token == after.token &&
          UserRepoLocal.to.sessionGeneration == generation,
      'Negative probes do not alter or log out the App session',
    );
  } finally {
    dio.close(force: true);
  }
}
