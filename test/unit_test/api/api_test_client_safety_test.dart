import 'package:dio/dio.dart';

import 'package:test/test.dart';

import 'api_test_client.dart';

void main() {
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
