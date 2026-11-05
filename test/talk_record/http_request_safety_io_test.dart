import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_retry_interceptor.dart';

void main() {
  test(
    'diagnostic URI removes credentials, every query value and fragment',
    () {
      final safe = safeHttpUri(
        'https://user:secret@host/path?capability=private&x=hidden#fragment',
      );
      for (final secret in [
        'user',
        'secret',
        'private',
        'hidden',
        'fragment',
      ]) {
        expect(safe, isNot(contains(secret)));
      }
      expect(safe, contains('/path'));
    },
  );

  test('real IO retains normal retry but noAutoRetry sends exactly once', () async {
    io.HttpOverrides.global = null;
    final retryLogs = <String>[];
    await runZoned(
      () async {
        for (final noRetry in [false, true]) {
          final server = await io.HttpServer.bind(
            io.InternetAddress.loopbackIPv4,
            0,
          );
          var requests = 0;
          final task = () async {
            await for (final r in server) {
              requests++;
              if (requests == 1) {
                // Leave the response open to force a real receive timeout.
              } else {
                r.response.write('ok');
                await r.response.close();
              }
            }
          }();
          final dio = Dio(
            BaseOptions(receiveTimeout: const Duration(milliseconds: 100)),
          );
          final retry = HttpRetryInterceptor(
            maxRetries: 1,
            retryInterval: Duration.zero,
            exponentialBackoff: false,
          );
          retry.bindDio(dio);
          dio.interceptors.add(retry);
          try {
            final future = dio.get<dynamic>(
              'http://127.0.0.1:${server.port}/plain?capability=retry-private#fragment-private',
              options: Options(extra: {httpNoAutoRetry: noRetry}),
            );
            if (noRetry) {
              await expectLater(future, throwsA(isA<DioException>()));
            } else {
              expect((await future).data, 'ok');
            }
            expect(requests, noRetry ? 1 : 2);
          } finally {
            dio.close(force: true);
            await server.close(force: true);
            await task;
          }
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          retryLogs.add(line);
        },
      ),
    );
    expect(retryLogs.join(), contains('retrying'));
    expect(retryLogs.join(), isNot(contains('retry-private')));
    expect(retryLogs.join(), isNot(contains('fragment-private')));
  });
}
