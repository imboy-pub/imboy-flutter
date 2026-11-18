@TestOn('chrome')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../env_test_pin.dart';

const _input = String.fromEnvironment('WEB_CONTROL_TEST_ORIGIN');
late Uri _origin;

class _FixtureEnv implements Env {
  @override
  String get apiBaseUrl => _origin.origin;
  @override
  String get solidifiedKey => '';
  @override
  dynamic noSuchMethod(Invocation x) => super.noSuchMethod(x);
}

Future<List<Object?>> _stats(String id) async {
  final r = await web.window
      .fetch(
        '${_origin.origin}/stats?case=$id'.toJS,
        web.RequestInit(credentials: 'omit'),
      )
      .toDart;
  expect(r.status, 200);
  return jsonDecode((await r.text().toDart).toDart) as List<Object?>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    expect(_input, isNotEmpty, reason: 'existing controlled fixture required');
    _origin = Uri.parse(_input);
    expect(_origin.scheme, 'http');
    expect({'127.0.0.1', 'localhost'}, contains(_origin.host));
    expect(_origin.userInfo, isEmpty);
    expect(_origin.path, anyOf('', '/'));
    expect(_origin.hasQuery || _origin.hasFragment, isFalse);
    pinLoopbackTestEnv();
    envMap['dev'] = _FixtureEnv();
    await prepareWebWriter();
    SharedPreferences.setMockInitialValues({Keys.currentUid: ''});
    await StorageService.init();
  });
  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, '');
  });
  test(
    'real public init wrapper admits empty owner and strips stale auth',
    () async {
      expect(authSessionReader.current.uid, isEmpty);
      expect(authSessionReader.current.transitioning, isFalse);
      final client = HttpClient(
        conf: HttpConfig(baseUrl: _origin.origin),
        retryEnabled: false,
      );
      client.dio.options.headers[Keys.tokenKey] = 'synthetic-stale-token';
      client.dio.options.headers.addAll({
        'sk': 'native',
        'sign': 'native',
        'cos': 'ios',
        'method': 'sha512',
      });
      client.dio.options.headers[Keys.refreshTokenKey] =
          'synthetic-stale-refresh';
      try {
        final response = await client.get(
          API.initConfig,
          queryParameters: {'case': 'wrapper-public'},
        );
        expect(response.ok, isTrue);
        expect(response.code, 0);
        final rows = await _stats('wrapper-public');
        expect(rows, hasLength(1));
        final row = rows.single as Map;
        expect(row['method'], 'GET');
        expect(row['path'], '/api/v1/web/bootstrap');
        expect(row['complete'], isTrue);
        expect(row['authorization'], isFalse);
        expect(
          client.dio.options.headers.containsKey(Keys.refreshTokenKey),
          isFalse,
        );
      } finally {
        client.dio.close(force: true);
      }
    },
  );
  test(
    'absolute public manifest direct Dio clears inherited credentials',
    () async {
      final client = HttpClient(
        conf: HttpConfig(baseUrl: _origin.origin),
        retryEnabled: false,
      );
      client.dio.options.headers.addAll({
        Keys.tokenKey: 'synthetic-stale-token',
        Keys.refreshTokenKey: 'synthetic-stale-refresh',
        'if-none-match': 'native-etag',
        'sign': 'native-sign',
      });
      try {
        final seenHeaders = <String, dynamic>{};
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, handler) {
              seenHeaders.addAll(o.headers);
              handler.next(o);
            },
          ),
        );
        await client.dio.get<dynamic>(
          '${_origin.origin}${API.appManifest}?case=wrapper-manifest',
          queryParameters: {'business': 'synthetic'},
        );
        final rows = await _stats('wrapper-manifest');
        expect(rows, hasLength(1));
        final row = rows.single as Map;
        expect(row['path'], API.appManifest);
        expect(row['authorization'], isFalse);
        expect(
          seenHeaders.keys.map((k) => k.toLowerCase()),
          isNot(
            anyElement(
              anyOf(
                'authorization',
                'imboy-refreshtoken',
                'if-none-match',
                'sk',
                'sign',
                'cos',
                'method',
              ),
            ),
          ),
        );
        expect(seenHeaders['dname'], 'Web Browser');
      } finally {
        client.dio.close(force: true);
      }
    },
  );

  test('public policy uses the real wrapper without credentials', () async {
    expect(authSessionReader.current.uid, isEmpty);
    expect(authSessionReader.current.transitioning, isFalse);
    final client = HttpClient(
      conf: HttpConfig(baseUrl: _origin.origin),
      retryEnabled: false,
    );
    client.dio.options.headers.addAll({
      Keys.tokenKey: 'synthetic-stale-token',
      Keys.refreshTokenKey: 'synthetic-stale-refresh',
      'sign': 'synthetic-native-signature',
    });
    try {
      final seenHeaders = <String, dynamic>{};
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            seenHeaders.addAll(o.headers);
            handler.next(o);
          },
        ),
      );
      final response = await client.get(
        API.appPolicy,
        queryParameters: {'case': 'wrapper-policy'},
      );
      expect(response.ok, isTrue);
      final rows = await _stats('wrapper-policy');
      expect(rows, hasLength(1));
      final row = rows.single as Map;
      expect(row['method'], 'GET');
      expect(row['path'], '/api/v1/app/policy');
      expect(row['complete'], isTrue);
      expect(row['authorization'], isFalse);
      expect(
        seenHeaders.keys.map((k) => k.toLowerCase()),
        isNot(
          anyElement(
            anyOf(
              'authorization',
              'imboy-refreshtoken',
              'sk',
              'sign',
              'cos',
              'method',
            ),
          ),
        ),
      );
      expect(seenHeaders['dname'], 'Web Browser');
    } finally {
      client.dio.close(force: true);
    }
  });

  test(
    'unknown methods, raw path normalization and foreign origin never dispatch',
    () async {
      final client = HttpClient(
        conf: HttpConfig(baseUrl: _origin.origin),
        retryEnabled: false,
      );
      try {
        for (final path in [
          '/api/v1/friend/delete',
          '/api/v1/attachment/content',
          '/api/v1/friend/../friend/list',
          '/api/v1//friend/list',
          '/api/v1/friend/%6cist',
          'https://other.invalid/api/v1/friend/list',
        ]) {
          await expectLater(
            client.dio.get<dynamic>(
              path,
              queryParameters: {'case': 'wrapper-rejected'},
            ),
            throwsA(isA<DioException>()),
          );
        }
        await expectLater(
          client.dio.post<dynamic>(
            '/api/v1/friend/list',
            queryParameters: {'case': 'wrapper-rejected'},
          ),
          throwsA(isA<DioException>()),
        );
        expect(await _stats('wrapper-rejected'), isEmpty);
      } finally {
        client.dio.close(force: true);
      }
    },
  );

  test(
    'real public login wrapper rejects changed owner after last body chunk',
    () async {
      final client = HttpClient(
        conf: HttpConfig(baseUrl: _origin.origin),
        retryEnabled: false,
      );
      Stream<List<int>> body() async* {
        yield utf8.encode('{"account":"synthetic","password":"synthetic"}');
        await StorageService.to.setString(Keys.currentUid, '910000000002');
      }

      try {
        final response = await client.post(
          API.login,
          queryParameters: {'case': 'wrapper-login-owner'},
          data: body(),
        );
        expect(StorageService.to.getString(Keys.currentUid), '910000000002');
        expect(response.ok, isFalse);
        expect(response.code, 409);
        expect(await _stats('wrapper-login-owner'), isEmpty);
      } finally {
        client.dio.close(force: true);
        await StorageService.to.setString(Keys.currentUid, '');
      }
    },
  );
}
