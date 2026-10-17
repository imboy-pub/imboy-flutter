import 'dart:io' show Directory;
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_login_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_login_api.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_login_attempt.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _SessionDatabase extends Fake implements Database {
  @override
  bool get isOpen => true;
  @override
  Future<void> close() async {}
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  int statusCode;
  dynamic body;

  /// 每次请求的 (method, path, data)。
  final List<(String, String, Object?)> requests = [];
  final List<String> wireBodies = [];
  final List<String> queries = [];
  bool failTransport = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.method, options.uri.path, options.data));
    queries.add(options.uri.query);
    if (failTransport) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      wireBodies.add(utf8.decode(bytes));
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ChangedEndpoint extends Fake implements Env {
  @override
  String get apiBaseUrl => 'http://127.0.0.1:9801';
}

Future<void> _pumpSessionWidget(WidgetTester tester, Widget widget) async {
  await tester.runAsync(() => tester.pumpWidget(widget));
}

Future<void> _settleSessionWrites(WidgetTester tester) async {
  for (var turn = 0; turn < 100; turn++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await tester.pump(const Duration(milliseconds: 10));
    if (find.byType(CupertinoActivityIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sessionRepo = UserRepoLocal.to;
  test('PKCE challenge matches RFC7636 S256 vector', () {
    final attempt = OaLoginAttempt(
      state: 'local-state',
      verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      intent: 'login',
      createdAt: DateTime.now(),
    );
    expect(attempt.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    final launch = attempt.launchUri(
      Uri.parse('https://oa.example/login?source=im'),
    );
    expect(launch.queryParameters['code_verifier'], isNull);
    expect(launch.queryParameters['state'], 'local-state');
    expect(
      launch.queryParameters['redirect_uri'],
      'imboy://imboy.pub/oa/login',
    );
  });
  test('generated attempts use different state and verifier and survive secure serialization', () {
    final a = OaLoginAttempt.create('login'), b = OaLoginAttempt.create('link');
    expect(a.state, isNot(b.state));
    expect(a.verifier, isNot(b.verifier));
    expect(a.state, isNot(a.verifier));
    final restored = OaLoginAttempt.fromJson(
      jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
    );
    expect(restored.challenge, a.challenge);
  });
  for (final scenario in [('login', false), ('link', true)]) {
    testWidgets(
      'pending ${scenario.$1} requires explicit user choice without committing session',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        if (scenario.$2) {
          await StorageService.to.setString(Keys.currentUid, 'synthetic');
        }
        final attempt =
            OaLoginAttempt.create(
                scenario.$1,
                backend: Env().apiBaseUrl,
                deviceId: 'device',
                applicationKey: 'oa-source-key',
              )
              ..pendingToken = 'p' * 43
              ..expiresAt = DateTime.now().add(const Duration(minutes: 5));
        FlutterSecureStorage.setMockInitialValues({
          'oa_inbound_login_attempt': jsonEncode({
            'backend': Env().apiBaseUrl,
            'bound_uid': scenario.$2 ? 'synthetic' : '',
            'application_key': 'oa-source-key',
            'attempt': attempt.toJson(),
          }),
        });
        await _pumpSessionWidget(
          tester,
          TranslationProvider(
            child: CupertinoApp(
              home: OaLoginPage(callback: Uri.parse('/oa/link')),
            ),
          ),
        );
        await _settleSessionWrites(tester);
        expect(
          find.byType(CupertinoButton),
          findsNWidgets(scenario.$2 ? 1 : 2),
        );
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        await _pumpSessionWidget(tester, const SizedBox.shrink());
      },
    );
  }

  for (final change in ['backend', 'device']) {
    testWidgets(
      'pending $change change sends no HTTP and cannot rewrite proof ownership',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        await StorageService.to.setString(Keys.currentUid, 'synthetic');
        final originalEnv = currentEnv;
        addTearDown(() {
          currentEnv = originalEnv;
          envMap.remove('oa_changed');
        });
        final attempt =
            OaLoginAttempt.create(
                'link',
                backend: Env().apiBaseUrl,
                deviceId: 'device',
                applicationKey: 'oa-source-key',
              )
              ..pendingToken = 'p' * 43
              ..expiresAt = DateTime.now().add(const Duration(minutes: 5));
        final raw = jsonEncode({
          'backend': attempt.backend,
          'bound_uid': 'synthetic',
          'attempt': attempt.toJson(),
        });
        FlutterSecureStorage.setMockInitialValues({
          'oa_inbound_login_attempt': raw,
        });
        final adapter = _RecordingAdapter(200, {
          'code': 0,
          'payload': <String, dynamic>{},
        });
        HttpClient.adapterForTest = adapter;
        addTearDown(() => HttpClient.adapterForTest = null);
        var did = 'device';
        await _pumpSessionWidget(
          tester,
          TranslationProvider(
            child: CupertinoApp(
              home: OaLoginPage(
                callback: Uri.parse('/oa/link'),
                deviceInfo: () async => {'did': did},
              ),
            ),
          ),
        );
        await _settleSessionWrites(tester);
        if (change == 'backend') {
          envMap['oa_changed'] = _ChangedEndpoint();
          currentEnv = 'oa_changed';
        } else {
          did = 'another-device';
        }
        await tester.runAsync(
          () => tester.tap(find.byType(CupertinoButton).first),
        );
        await _settleSessionWrites(tester);
        expect(adapter.requests, isEmpty);
        expect(
          await StorageSecureService.to.read(key: 'oa_inbound_login_attempt'),
          raw,
        );
        await _pumpSessionWidget(tester, const SizedBox.shrink());
      },
    );
  }
  testWidgets('expired pending is deleted and user can start a fresh proof', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final attempt =
        OaLoginAttempt.create(
            'login',
            backend: Env().apiBaseUrl,
            deviceId: 'old-device',
            applicationKey: 'oa-source-key',
          )
          ..pendingToken = 'p' * 43
          ..expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
    FlutterSecureStorage.setMockInitialValues({
      'oa_inbound_login_attempt': jsonEncode({
        'backend': attempt.backend,
        'bound_uid': '',
        'attempt': attempt.toJson(),
      }),
    });
    final config = EnterpriseOaRuntimeConfig.fromMap({
      'IMBOY_WL_OA_ORIGIN': 'https://oa.example',
      'IMBOY_WL_OA_APPLICATION_KEY': 'oa-source-key',
      'IMBOY_WL_OA_LOGIN_START_URI': 'https://oa.example/login',
    });
    Uri? launched;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await _pumpSessionWidget(
      tester,
      TranslationProvider(
        child: CupertinoApp(
          home: OaLoginPage(
            callback: Uri.parse('/oa/login'),
            config: config,
            deviceInfo: () async => {'did': 'fresh-device'},
            launch: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await _settleSessionWrites(tester);
    expect(
      await StorageSecureService.to.read(key: 'oa_inbound_login_attempt'),
      isNull,
    );
    await tester.runAsync(() => tester.tap(find.byType(CupertinoButton).first));
    await _settleSessionWrites(tester);
    final raw = await StorageSecureService.to.read(
      key: 'oa_inbound_login_attempt',
    );
    final fresh = OaLoginAttempt.fromJson(
      (jsonDecode(raw!) as Map<String, dynamic>)['attempt']
          as Map<String, dynamic>,
    );
    expect(fresh.deviceId, 'fresh-device');
    expect(fresh.pendingToken, isNull);
    expect(fresh.state, isNot(attempt.state));
    expect(launched!.queryParameters['state'], fresh.state);
    await _pumpSessionWidget(tester, const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final scenario in [
    'before_send',
    'session_response',
    'pending_response',
    'retry_backoff',
    'secure_write',
    'existing_account',
  ]) {
    testWidgets(
      scenario == 'existing_account'
          ? 'anonymous OA proof survives real existing account login and links'
          : 'logout while $scenario waits rejects stale OA result',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        final repo = sessionRepo;
        final previousDid = deviceId;
        deviceId = 'device';
        addTearDown(() => deviceId = previousDid);
        if (scenario != 'existing_account') {
          await StorageService.to.setString(Keys.currentUid, '123');
        }
        final attempt = OaLoginAttempt.create(
          scenario == 'existing_account' ? 'login' : 'link',
          backend: Env().apiBaseUrl,
          deviceId: 'device',
          applicationKey: 'oa-source-key',
        );
        if (scenario != 'pending_response' && scenario != 'secure_write') {
          attempt.pendingToken = 'p' * 43;
          attempt.expiresAt = DateTime.now().add(const Duration(minutes: 5));
        }
        String b64(String s) =>
            base64UrlEncode(utf8.encode(s)).replaceAll('=', '');
        final jwt =
            '${b64('{"alg":"HS256"}')}.${b64('{"exp":9999999999}')}.${b64('test-signature')}';
        final raw = jsonEncode({
          'backend': attempt.backend,
          'bound_uid': scenario == 'existing_account' ? '' : '123',
          'attempt': attempt.toJson(),
        });
        final secure = <String, String>{
          'oa_inbound_login_attempt': raw,
          'secure_token': jwt,
          'secure_refresh_token': jwt,
        };
        var jwtWrites = 0, pendingWrites = 0;
        final writeEntered = Completer<void>();
        final releaseWrite = Completer<void>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final previousStorage = FlutterSecureStoragePlatform.instance;
        FlutterSecureStoragePlatform.instance =
            MethodChannelFlutterSecureStorage();
        addTearDown(
          () => FlutterSecureStoragePlatform.instance = previousStorage,
        );
        const secureChannel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        messenger.setMockMethodCallHandler(secureChannel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'readAll':
              return Map<String, String>.from(secure);
            case 'containsKey':
              return secure.containsKey(key);
            case 'write':
              if (key == 'secure_token' || key == 'secure_refresh_token') {
                jwtWrites++;
              }
              if (key == 'oa_inbound_login_attempt') {
                pendingWrites++;
                if (scenario == 'secure_write') {
                  writeEntered.complete();
                  await releaseWrite.future;
                }
              }
              secure[key!] = args['value'] as String;
              return null;
            case 'delete':
              secure.remove(key);
              return null;
            case 'deleteAll':
              secure.clear();
              return null;
          }
          return null;
        });
        final temp = await tester.runAsync(
          () => Directory.systemTemp.createTemp('imboy-oa-logout-test-'),
        );
        const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
        messenger.setMockMethodCallHandler(
          pathChannel,
          (_) async => temp!.path,
        );
        addTearDown(() async {
          messenger.setMockMethodCallHandler(pathChannel, null);
          await temp!.delete(recursive: true);
        });
        const dbChannel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
        messenger.setMockMethodCallHandler(dbChannel, (call) async {
          if (call.method == 'getDatabasesPath') {
            return '/nonexistent-synthetic-oa-test';
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(secureChannel, null);
          messenger.setMockMethodCallHandler(dbChannel, null);
        });
        final response =
            scenario == 'pending_response' || scenario == 'secure_write'
            ? <String, dynamic>{
                'requires_account_choice': true,
                'pending_token': 'q' * 43,
                'expires_in': 300,
              }
            : <String, dynamic>{
                'user_id': '123',
                'uid': '123',
                'token': 'synthetic-token-long',
                'refreshtoken': 'synthetic-refresh-long',
                'account': 'synthetic',
              };
        final adapter = _RecordingAdapter(200, {
          'code': 0,
          'payload': response,
        });
        adapter.failTransport = scenario == 'retry_backoff';
        HttpClient.adapterForTest = adapter;
        addTearDown(() => HttpClient.adapterForTest = null);
        final held = Completer<Map<String, dynamic>?>();
        var calls = 0;
        final callback =
            scenario == 'pending_response' || scenario == 'secure_write'
            ? Uri.parse('/oa/login?state=${attempt.state}&ticket=${'t' * 43}')
            : Uri.parse('/oa/link');
        await _pumpSessionWidget(
          tester,
          TranslationProvider(
            child: CupertinoApp(
              home: OaLoginPage(
                callback: callback,
                deviceInfo: () async {
                  calls++;
                  if (scenario != 'secure_write' &&
                      scenario != 'retry_backoff' &&
                      scenario != 'existing_account' &&
                      calls == (scenario == 'before_send' ? 1 : 2)) {
                    return held.future;
                  }
                  return {'did': 'device'};
                },
              ),
            ),
          ),
        );
        Future<void> loginExisting() async {
          void bindDatabase() {
            if (repo.currentUid == '123') {
              SqliteService.setDbForTest(_SessionDatabase());
            }
          }

          repo.addListener(bindDatabase);
          addTearDown(() {
            repo.removeListener(bindDatabase);
            SqliteService.setDbForTest(null);
          });
          expect(
            await repo.loginAfter('synthetic', {
              'uid': '123',
              'token': jwt,
              'refreshtoken': jwt,
            }),
            isTrue,
          );
        }

        if (scenario == 'existing_account') {
          await _settleSessionWrites(tester);
          expect(find.text(t.enterpriseOa.useExistingAccount), findsOneWidget);
          await _pumpSessionWidget(tester, const SizedBox.shrink());
          await tester.runAsync(loginExisting);
          expect(secure['oa_inbound_login_attempt'], raw);
          final router = GoRouter(
            initialLocation: '/oa/link',
            routes: [
              GoRoute(
                path: '/oa/link',
                builder: (_, state) => OaLoginPage(
                  callback: state.uri,
                  deviceInfo: () async => {'did': 'device'},
                ),
              ),
              GoRoute(
                path: '/bottom_navigation',
                builder: (_, _) => const Text('synthetic-ready'),
              ),
            ],
          );
          addTearDown(router.dispose);
          await _pumpSessionWidget(
            tester,
            TranslationProvider(
              child: CupertinoApp.router(routerConfig: router),
            ),
          );
          await _settleSessionWrites(tester);
          expect(find.text(t.enterpriseOa.confirmLink), findsOneWidget);
          adapter.body = {
            'code': 0,
            'payload': {'uid': '123', 'token': jwt, 'refreshtoken': jwt},
          };
          await tester.runAsync(
            () => tester.tap(find.byType(CupertinoButton).first),
          );
          await _settleSessionWrites(tester);
          expect(adapter.requests.single.$2, '/api/v1/oa/login/link');
          expect(
            jsonDecode(adapter.wireBodies.single)['pending_token'],
            attempt.pendingToken,
          );
          expect(secure['oa_inbound_login_attempt'], isNull);
          expect(secure['secure_token'], jwt);
          expect(repo.currentUid, '123');
          expect(find.text('synthetic-ready'), findsOneWidget);
          await _pumpSessionWidget(tester, const SizedBox.shrink());
          return;
        }
        if (scenario != 'pending_response' && scenario != 'secure_write') {
          await _settleSessionWrites(tester);
          await tester.runAsync(
            () => tester.tap(find.byType(CupertinoButton).first),
          );
        }
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          if (scenario == 'secure_write'
              ? writeEntered.isCompleted
              : scenario == 'retry_backoff'
              ? adapter.requests.isNotEmpty
              : calls == (scenario == 'before_send' ? 1 : 2)) {
            break;
          }
        }
        if (scenario == 'secure_write') {
          expect(writeEntered.isCompleted, isTrue);
        }
        if (scenario == 'retry_backoff') expect(adapter.requests.length, 1);
        final oldGeneration = repo.sessionGeneration;
        var logoutComplete = false;
        late Future<bool> logout;
        await tester.runAsync(() async {
          logout = repo.quitLogin().then((value) {
            logoutComplete = true;
            return value;
          });
          await Future<void>.delayed(Duration.zero);
        });
        if (scenario == 'secure_write') {
          expect(repo.isAuthTransitioning, isTrue);
          expect(logoutComplete, isFalse);
          releaseWrite.complete();
          await tester.pump();
        }
        await tester.runAsync(() async {
          expect(await logout.timeout(const Duration(seconds: 5)), true);
        });
        expect(repo.sessionGeneration, oldGeneration + 1);
        held.complete({'did': 'device'});
        if (scenario == 'retry_backoff') {
          await tester.pump(const Duration(seconds: 31));
          await tester.pump(const Duration(seconds: 31));
        }
        await _settleSessionWrites(tester);
        expect(adapter.requests.length, scenario == 'before_send' ? 0 : 1);
        expect(jwtWrites, 0);
        expect(pendingWrites, scenario == 'secure_write' ? 1 : 0);
        expect(secure['oa_inbound_login_attempt'], isNull);
        expect(secure['secure_token'], isNull);
        expect(repo.currentUid, isEmpty);
        await _pumpSessionWidget(tester, const SizedBox.shrink());
        if (scenario == 'secure_write' || scenario == 'retry_backoff') {
          for (final loggedIn in [false, true]) {
            if (loggedIn) await tester.runAsync(loginExisting);
            await _pumpSessionWidget(
              tester,
              TranslationProvider(
                child: CupertinoApp(
                  home: OaLoginPage(callback: Uri.parse('/oa/link')),
                ),
              ),
            );
            await _settleSessionWrites(tester);
            expect(find.text(t.enterpriseOa.confirmLink), findsNothing);
            expect(find.text(t.enterpriseOa.useExistingAccount), findsNothing);
            expect(secure['oa_inbound_login_attempt'], isNull);
            await _pumpSessionWidget(tester, const SizedBox.shrink());
          }
        }
      },
    );
  }
  for (final scenario in [
    ('exchange', false),
    ('exchange', true),
    ('link', true),
    ('register', true),
  ]) {
    final action = scenario.$1;
    testWidgets(
      'saved callback source for $action with injected key ${scenario.$2}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
        final boundUid = action == 'link' ? 'synthetic' : '';
        if (boundUid.isNotEmpty) {
          await StorageService.to.setString(Keys.currentUid, boundUid);
        }
        final attempt = OaLoginAttempt.create(
          action == 'link' ? 'link' : 'login',
          backend: Env().apiBaseUrl,
          deviceId: 'device',
          applicationKey: 'oa-local-source-a',
        );
        String b64(String value) =>
            base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
        // Link uses the existing authenticated client; retain its own session.
        final sessionToken = boundUid.isEmpty
            ? null
            : '${b64('{"alg":"HS256"}')}.${b64('{"exp":9999999999}')}.${b64('test-signature')}';
        FlutterSecureStorage.setMockInitialValues({
          if (sessionToken != null) 'secure_token': sessionToken,
          if (sessionToken != null) 'secure_refresh_token': sessionToken,
          'oa_inbound_login_attempt': jsonEncode({
            'backend': attempt.backend,
            'bound_uid': boundUid,
            'attempt': attempt.toJson(),
          }),
        });
        final generation = sessionRepo.sessionGeneration;
        final adapter = _RecordingAdapter(200, {
          'code': 0,
          'payload': {
            'requires_account_choice': true,
            'pending_token': 'p' * 43,
            'expires_in': 300,
          },
        });
        HttpClient.adapterForTest = adapter;
        addTearDown(() => HttpClient.adapterForTest = null);
        final callback = Uri(
          path: '/oa/login',
          queryParameters: {
            'state': attempt.state,
            'ticket': 't' * 43,
            // The callback is untrusted; this valid key must never own the proof.
            if (scenario.$2) 'application_key': 'oa-callback-source-b',
          },
        );
        await _pumpSessionWidget(
          tester,
          TranslationProvider(
            child: CupertinoApp(
              home: OaLoginPage(
                callback: callback,
                deviceInfo: () async => {'did': 'device'},
              ),
            ),
          ),
        );
        await _settleSessionWrites(tester);
        expect(adapter.requests.single.$2, '/api/v1/oa/login/exchange');
        expect(
          jsonDecode(adapter.wireBodies.single)['application_key'],
          attempt.applicationKey,
        );
        final pendingRaw = await StorageSecureService.to.read(
          key: 'oa_inbound_login_attempt',
        );
        final restored = OaLoginAttempt.fromJson(
          (jsonDecode(pendingRaw!) as Map<String, dynamic>)['attempt']
              as Map<String, dynamic>,
        );
        expect(restored.applicationKey, attempt.applicationKey);
        expect(restored.state, attempt.state);
        expect(restored.verifier, attempt.verifier);
        expect(restored.pendingToken, 'p' * 43);
        if (action != 'exchange') {
          // Preserve pending proof on rejection; never commit a synthetic session.
          adapter.body = {'code': 409, 'payload': <String, dynamic>{}};
          await tester.runAsync(
            () => tester.tap(
              find.text(
                action == 'link'
                    ? t.enterpriseOa.confirmLink
                    : t.enterpriseOa.confirmCreate,
              ),
            ),
          );
          await _settleSessionWrites(tester);
          expect(adapter.requests.length, 2);
          expect(adapter.requests.last.$2, '/api/v1/oa/login/$action');
          final body = jsonDecode(adapter.wireBodies.last);
          expect(body['application_key'], attempt.applicationKey);
          expect(body['pending_token'], restored.pendingToken);
          expect(body['code_verifier'], attempt.verifier);
          expect(
            await StorageSecureService.to.read(key: 'oa_inbound_login_attempt'),
            pendingRaw,
          );
        }
        expect(sessionRepo.currentUid, boundUid);
        expect(sessionRepo.sessionGeneration, generation);
        expect(
          await StorageSecureService.to.read(key: 'secure_token'),
          sessionToken,
        );
        expect(
          await StorageSecureService.to.read(key: 'secure_refresh_token'),
          sessionToken,
        );
        await _pumpSessionWidget(tester, const SizedBox.shrink());
      },
    );
  }

  testWidgets('callback key without local proof sends no request or session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    FlutterSecureStorage.setMockInitialValues({});
    final adapter = _RecordingAdapter(200, {'code': 0, 'payload': {}});
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    final generation = sessionRepo.sessionGeneration;
    await _pumpSessionWidget(
      tester,
      TranslationProvider(
        child: CupertinoApp(
          home: OaLoginPage(
            callback: Uri(
              path: '/oa/login',
              queryParameters: {
                'state': 'unowned-state',
                'ticket': 't' * 43,
                'application_key': 'oa-callback-source-b',
              },
            ),
          ),
        ),
      ),
    );
    await _settleSessionWrites(tester);
    expect(adapter.requests, isEmpty);
    expect(
      await StorageSecureService.to.read(key: 'oa_inbound_login_attempt'),
      isNull,
    );
    expect(await StorageSecureService.to.read(key: 'secure_token'), isNull);
    expect(
      await StorageSecureService.to.read(key: 'secure_refresh_token'),
      isNull,
    );
    expect(sessionRepo.currentUid, isEmpty);
    expect(sessionRepo.sessionGeneration, generation);
    await _pumpSessionWidget(tester, const SizedBox.shrink());
  });

  final now = DateTime.utc(2026, 10, 14);
  final ticket = 't' * 43;
  OaLoginAttempt attempt() => OaLoginAttempt(
    state: 'state',
    verifier: 'v' * 43,
    intent: 'login',
    createdAt: now,
  );
  test('only local matching state can redeem callback', () {
    expect(
      attempt().callbackTicket(
        Uri.parse('/oa/login?ticket=$ticket&state=state'),
        now,
      ),
      ticket,
    );
  });
  for (final query in [
    'ticket=$ticket&state=attacker',
    'ticket=$ticket',
    'ticket=$ticket&state=state&state=state',
    'ticket=$ticket&ticket=$ticket&state=state',
    'ticket=$ticket&state=state&code_verifier=external',
    'ticket=short&state=state',
  ]) {
    test('rejects forged/ambiguous callback $query', () {
      expect(
        () => attempt().callbackTicket(Uri.parse('/oa/login?$query'), now),
        throwsFormatException,
      );
    });
  }
  test('expired and wrong-path callback are rejected', () {
    expect(
      () => attempt().callbackTicket(
        Uri.parse('/other?ticket=$ticket&state=state'),
        now,
      ),
      throwsFormatException,
    );
    expect(
      () => attempt().callbackTicket(
        Uri.parse('/oa/login?ticket=$ticket&state=state'),
        now.add(const Duration(minutes: 10)),
      ),
      throwsFormatException,
    );
    final a = attempt()..expiresAt = now.add(const Duration(minutes: 5));
    expect(a.validAt(now.add(const Duration(minutes: 5))), false);
  });
  for (final uri in [
    '',
    'http://oa.example/login',
    'https://evil.example/login',
    'https://oa.example:444/login',
    'https://user@oa.example/login',
    'https://oa.example/login#fragment',
  ]) {
    test('hides invalid inbound config $uri', () {
      expect(
        EnterpriseOaRuntimeConfig.fromMap({
          'IMBOY_WL_OA_ORIGIN': 'https://oa.example',
          'IMBOY_WL_OA_APPLICATION_KEY': 'oa-source-key',
          'IMBOY_WL_OA_LOGIN_START_URI': uri,
        }).inboundLoginEnabled,
        false,
      );
    });
  }
  test('accepts same-origin optional inbound config', () {
    expect(
      EnterpriseOaRuntimeConfig.fromMap({
        'IMBOY_WL_OA_ORIGIN': 'https://oa.example',
        'IMBOY_WL_OA_APPLICATION_KEY': 'oa-source-key',
        'IMBOY_WL_OA_LOGIN_START_URI': 'https://oa.example/login',
      }).inboundLoginEnabled,
      true,
    );
  });
  Future<_RecordingAdapter> setup(
    Map<String, dynamic> payload, {
    int code = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    String b64(String s) => base64UrlEncode(utf8.encode(s)).replaceAll('=', '');
    final jwt =
        '${b64('{"alg":"HS256"}')}.${b64('{"exp":9999999999}')}.${b64('test-signature')}';
    FlutterSecureStorage.setMockInitialValues({
      'secure_token': jwt,
      'secure_refresh_token': jwt,
    });
    final adapter = _RecordingAdapter(200, {
      'code': code,
      'msg': code == 0 ? 'success' : 'identity_conflict',
      'payload': payload,
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    return adapter;
  }

  test(
    'exchange sends local PKCE/DID and parses pending without creating session',
    () async {
      final adapter = await setup({
        'pending_token': ticket,
        'requires_account_choice': true,
        'expires_in': 300,
      });
      FlutterSecureStorage.setMockInitialValues({});
      final result = await OaLoginApi().exchange(ticket, {
        'code_verifier': 'v' * 43,
        'application_key': 'oa-source-key',
        'did': 'device',
        'cos': 'Android',
      });
      expect(result['pending_token'], ticket);
      expect(result.containsKey('token'), false);
      expect(adapter.requests.single.$2, '/api/v1/oa/login/exchange');
      expect(adapter.wireBodies.single, contains('code_verifier'));
    },
  );
  test(
    'explicit registration includes confirm_create and pending proof',
    () async {
      final adapter = await setup({
        'user_id': '123',
        'token': 'jwt',
        'refreshtoken': 'refresh',
      });
      FlutterSecureStorage.setMockInitialValues({});
      await OaLoginApi().register(ticket, {
        'code_verifier': 'v' * 43,
        'application_key': 'oa-source-key',
        'did': 'device',
      });
      expect(adapter.requests.single.$2, '/api/v1/oa/login/register');
      expect(jsonDecode(adapter.wireBodies.single)['confirm_create'], true);
    },
  );
  test(
    'link uses authenticated client and retains conflict as failure',
    () async {
      final adapter = await setup({}, code: 409);
      await expectLater(
        OaLoginApi().link(ticket, {
          'code_verifier': 'v' * 43,
          'application_key': 'oa-source-key',
          'did': 'device',
        }),
        throwsA(anything),
      );
      expect(adapter.requests.single.$2, '/api/v1/oa/login/link');
    },
  );
  for (final action in ['exchange', 'link', 'register']) {
    test('one-shot OA $action does not replay a transport failure', () async {
      final adapter = await setup({});
      adapter.failTransport = true;
      final api = OaLoginApi();
      final request = switch (action) {
        'exchange' => api.exchange(ticket, {'did': 'device'}),
        'link' => api.link(ticket, {'did': 'device'}),
        _ => api.register(ticket, {'did': 'device'}),
      };
      await expectLater(request, throwsA(anything));
      expect(adapter.requests.length, 1);
    });
  }
}
