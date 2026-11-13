import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

import 'package:test/test.dart';

import '../../../integration_test/demo_flow/group_pro_readonly_contract_test.dart'
    show ReadOnlyContractClient;

import 'api_test_client.dart';

Future<List<Map<String, dynamic>>> _loginRequests(
  Future<void> Function(Uri base) exercise, {
  bool rejectMd5 = false,
}) async {
  final requests = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    final body = await utf8.decoder.bind(request).join();
    requests.add({
      'method': request.method,
      'path': request.uri.path,
      'body': body.isEmpty ? null : jsonDecode(body),
      'headers': {
        for (final name in [
          'did',
          'vsn',
          'cos',
          'pkg',
          'sign',
          'authorization',
        ])
          name: request.headers.value(name),
      },
    });
    final fail = rejectMd5 && requests.length == 1;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'code': fail ? 1 : 0,
        'msg': fail ? 'errorPassword' : 'ok',
        'payload': {'token': 'synthetic-token', 'uid': '1001'},
      }),
    );
    await request.response.close();
  });
  await exercise(Uri.parse('http://127.0.0.1:${server.port}'));
  for (final request in requests) {
    final headers = request['headers'] as Map;
    final raw =
        '${headers['did']}|${headers['vsn']}|${headers['cos']}|${headers['pkg']}';
    expect(
      headers['sign'],
      base64.encode(
        crypto.Hmac(
          crypto.sha512,
          utf8.encode('synthetic-sign-key'),
        ).convert(utf8.encode(raw)).bytes,
      ),
    );
  }
  expect(requests.last['method'], 'GET');
  expect(requests.last['path'], '/api/v1/group/page');
  expect(
    (requests.last['headers'] as Map)['authorization'],
    'Bearer synthetic-token',
  );
  return requests;
}

Future<List<Map<String, dynamic>>> _readOnlyLogin({
  required String account,
  String? type,
  bool rejectMd5 = false,
}) => _loginRequests((base) async {
  final client = ReadOnlyContractClient(base, 'synthetic-sign-key');
  final result = await client.loginCompat(
    account,
    'synthetic-password',
    type: type,
  );
  expect(result['ok'], isTrue);
  expect(result['md5Rejected'], rejectMd5);
  expect(result['plainRetryOk'], rejectMd5);
  expect(client.currentUid, '1001');
  expect(
    (await client.get(
      '/api/v1/group/page',
      query: {'page': '1', 'size': '10'},
    ))['code'],
    0,
  );
}, rejectMd5: rejectMd5);

void main() {
  test('readonly explicit account alias reaches login POST', () async {
    final requests = await _readOnlyLogin(
      account: 'synthetic-account-alias',
      type: 'account',
    );
    expect(requests.first['method'], 'POST');
    expect(requests.first['path'], '/api/v1/passport/login');
    expect((requests.first['body'] as Map)['type'], 'account');
  });

  test('readonly optional environment type reaches login POST', () async {
    final configured = Platform.environment['TEST_LOGIN_TYPE'] ?? '';
    final requests = await _readOnlyLogin(account: 'synthetic-account-alias');
    expect(
      (requests.first['body'] as Map)['type'],
      configured.isEmpty ? 'mobile' : configured,
    );
  });

  for (final (account, expectedType) in [
    ('synthetic@example.invalid', 'email'),
    ('synthetic-mobile-key', 'mobile'),
  ]) {
    test('readonly empty login type keeps default $expectedType', () async {
      final requests = await _readOnlyLogin(account: account, type: '');
      expect(requests.length, 2);
      expect((requests.first['body'] as Map)['type'], expectedType);
      expect(
        (requests.first['body'] as Map)['pwd'],
        crypto.md5.convert(utf8.encode('synthetic-password')).toString(),
      );
    });
  }

  test('readonly password fallback keeps configured account type', () async {
    final requests = await _readOnlyLogin(
      account: 'synthetic-account-alias',
      type: 'account',
      rejectMd5: true,
    );
    expect(requests.length, 3);
    final bodies = requests.take(2).map((r) => r['body'] as Map).toList();
    expect(bodies.map((body) => body['type']), ['account', 'account']);
    expect(bodies.map((body) => body['account']), [
      'synthetic-account-alias',
      'synthetic-account-alias',
    ]);
    expect(bodies.map((body) => body['pwd']), [
      crypto.md5.convert(utf8.encode('synthetic-password')).toString(),
      'synthetic-password',
    ]);
    expect(bodies.map((body) => body['rsa_encrypt']), ['0', '0']);
  });

  test('explicit readonly mobile type reaches login POST', () async {
    final requests = await _readOnlyLogin(
      account: 'synthetic-mobile-key',
      type: 'mobile',
    );
    expect((requests.first['body'] as Map)['type'], 'mobile');
  });

  test(
    'shared login uses explicit account type for both password attempts',
    () async {
      final requests = await _loginRequests((base) async {
        final client = ApiTestClient(
          baseUrl: base.toString(),
          signingKey: 'synthetic-sign-key',
        );
        addTearDown(client.close);
        final result = await client.login(
          account: 'synthetic-account-alias',
          password: 'synthetic-password',
          type: 'account',
        );
        expect(result['code'], 0);
        expect(client.currentUid, '1001');
        expect((await client.get('/api/v1/group/page'))['code'], 0);
      }, rejectMd5: true);
      expect(requests.length, 3);
      expect(requests.take(2).map((r) => (r['body'] as Map)['type']), [
        'account',
        'account',
      ]);
    },
  );

  test('握手签名复用相同 DID，header 快照修改不影响 client', () {
    final client = ApiTestClient(
      baseUrl: 'http://127.0.0.1',
      deviceId: 'synthetic-ws-did',
      accessToken: 'synthetic-token',
      signingKey: 'synthetic-sign-key',
    );
    addTearDown(client.close);
    final headers = client.authenticatedHeaders;
    expect(headers['did'], 'synthetic-ws-did');
    final raw =
        '${headers['did']}|${headers['vsn']}|${headers['cos']}|${headers['pkg']}';
    expect(
      headers['sign'],
      base64.encode(
        crypto.Hmac(
          crypto.sha512,
          utf8.encode('synthetic-sign-key'),
        ).convert(utf8.encode(raw)).bytes,
      ),
    );
    headers.remove('authorization');
    headers['did'] = 'modified-snapshot';
    expect(
      client.authenticatedHeaders['authorization'],
      'Bearer synthetic-token',
    );
    expect(client.authenticatedHeaders['did'], 'synthetic-ws-did');
  });

  test('业务 POST 按 client 实际目标地址判断，不能被环境变量误导', () async {
    final client = ApiTestClient(baseUrl: 'https://pro.imboy.pub');
    addTearDown(client.close);

    await expectLater(
      client.post('/api/v1/group/task/create'),
      throwsA(isA<StateError>()),
    );
  });

  test('注入 Dio 目标不一致在构造时拒绝，不发请求', () {
    final dio = Dio(BaseOptions(baseUrl: 'https://pro.imboy.pub'));
    addTearDown(() => dio.close(force: true));
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (_, handler) {
          requests++;
          handler.reject(DioException(requestOptions: RequestOptions()));
        },
      ),
    );
    expect(
      () => ApiTestClient(baseUrl: 'http://127.0.0.1', dio: dio),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  for (final status in [200, 302, 503]) {
    test('GET expectedStatusCode 保留 HTTP 语义：$status', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.followRedirects, isFalse);
            expect(options.baseUrl, 'http://127.0.0.1');
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: status,
                data: <String, dynamic>{'code': 0},
                headers: Headers.fromMap({
                  'location': ['https://example.invalid'],
                }),
              ),
            );
          },
        ),
      );
      final client = ApiTestClient(
        baseUrl: 'http://127.0.0.1',
        dio: dio,
        signingKey: 'synthetic-test-key',
      );
      addTearDown(client.close);
      final request = client.get('/synthetic', expectedStatusCode: 200);
      if (status == 200) {
        expect(await request, {'code': 0});
      } else {
        await expectLater(
          request,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('expected HTTP 200, got $status'),
            ),
          ),
        );
      }
    });
  }

  Response<dynamic> reply(int status, {String? retryAfter}) =>
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/synthetic'),
        statusCode: status,
        headers: Headers.fromMap({
          if (retryAfter != null) 'retry-after': [retryAfter],
        }),
      );

  test('登录 429 按一分钟 IP 窗口等待后重试，不吞登录结果', () async {
    var calls = 0;
    final waits = <Duration>[];
    final result = await requestWithRateLimitRetry(
      () async => reply(++calls == 1 ? 429 : 200),
      login: true,
      wait: (delay) async => waits.add(delay),
    );
    expect(calls, 2);
    expect(waits, [const Duration(seconds: 60)]);
    expect(result.statusCode, 200);
  });

  test('429 尊重 Retry-After，持续限流最多重试三次', () async {
    var calls = 0;
    final waits = <Duration>[];
    final result = await requestWithRateLimitRetry(
      () async {
        calls++;
        return reply(429, retryAfter: '12');
      },
      login: true,
      wait: (delay) async => waits.add(delay),
    );
    expect(calls, 4);
    expect(waits, List.filled(3, const Duration(seconds: 12)));
    expect(result.statusCode, 429);
  });

  test('畸形 HTTP 日期 Retry-After 回退有界登录等待', () async {
    var calls = 0;
    final waits = <Duration>[];
    final result = await requestWithRateLimitRetry(
      () async =>
          reply(++calls == 1 ? 429 : 200, retryAfter: 'not-a-valid-http-date'),
      login: true,
      wait: (delay) async => waits.add(delay),
    );
    expect(calls, 2);
    expect(waits, [const Duration(seconds: 60)]);
    expect(result.statusCode, 200);
  });

  test('超出有界预算的 Retry-After 不提前重试', () async {
    var calls = 0;
    final result = await requestWithRateLimitRetry(
      () async {
        calls++;
        return reply(429, retryAfter: '120');
      },
      login: true,
      wait: (_) async => fail('不得抢先重试'),
    );
    expect(calls, 1);
    expect(result.statusCode, 429);
  });

  test('业务写入遇 429 不重放', () async {
    var calls = 0;
    final result = await requestWithRateLimitRetry(
      () async {
        calls++;
        return reply(429);
      },
      retryable: false,
      wait: (_) async => fail('业务写入不得重放'),
    );
    expect(calls, 1);
    expect(result.statusCode, 429);
  });
}
