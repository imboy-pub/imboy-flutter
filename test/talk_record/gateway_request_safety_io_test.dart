import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_retry_interceptor.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/talk_record/application/talk_record_part_transport.dart';
import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

import 'support/gateway_request_host.dart';

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

  test(
    'signed scoped request logs no secret and account switch before IO blocks',
    () async {
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      final dir = await io.Directory.systemTemp.createTemp(
        'owned-request-policy-',
      );
      final bytes = [4, 8, 9];
      final hash = sha256.convert(bytes).toString();
      final file = await io.File('${dir.path}/audio.aac').writeAsBytes(bytes);
      final cfg = await _config(dir, server.port);
      final logs = <String>[];
      final saved = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };
      final host = await SignedHost.load(cfg.path);
      host.api.dio.interceptors.removeWhere((i) => i is SafeHttpLogInterceptor);
      host.api.dio.interceptors.insert(
        0,
        SafeHttpLogInterceptor(log: logs.add),
      );
      var requests = 0;
      final task = () async {
        await for (final r in server) {
          requests++;
          await r.drain<void>();
          r.response.headers.contentType = io.ContentType.json;
          r.response.write(
            jsonEncode({'pinned': true, 'sha256': hash, 'size': bytes.length}),
          );
          await r.response.close();
        }
      }();
      const secret = 'never-print-capability';
      final ticket = _ticket(secret);
      try {
        final transport = TalkRecordGatewayPartTransport();
        await transport.put(ticket, file, () {});
        expect(requests, 1);
        expect(logs, isNotEmpty);
        expect(logs.join(), isNot(contains(secret)));
        final entered = Completer<void>(), resume = Completer<void>();
        host.api.dio.interceptors.insert(
          host.api.dio.interceptors.indexWhere(
            (i) => i is HttpRequestGuardInterceptor,
          ),
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              entered.complete();
              await resume.future;
              handler.next(options);
            },
          ),
        );
        final owner = UserRepoLocal.to.currentUid;
        void guard() {
          if (UserRepoLocal.to.currentUid != owner)
            throw StateError('Account changed');
        }

        final pending = transport.put(ticket, file, guard);
        await entered.future;
        await StorageService.to.setString(Keys.currentUid, '9898003');
        resume.complete();
        await expectLater(pending, throwsStateError);
        expect(requests, 1);
        expect(logs.join(), isNot(contains(secret)));
      } finally {
        debugPrint = saved;
        host.api.dio.close(force: true);
        await server.close(force: true);
        await task;
        await dir.delete(recursive: true);
      }
    },
  );
}

Future<io.File> _config(io.Directory dir, int port) =>
    io.File('${dir.path}/host.json').writeAsString(
      jsonEncode({
        'base_url': 'http://127.0.0.1:$port',
        'sign_key': 'owned-key',
        'device_id': 'owned-device',
        'app_version': '1.0.0',
        'sign_key_version': '1',
        'package_name': 'synthetic.request',
        'actors': {
          'owner': {'uid': '9898002', 'jwt': 'synthetic-token'},
        },
      }),
    );

TalkRecordUploadRef _ticket(String secret) => TalkRecordUploadRef(
  putUrl: '/api/v1/attachment/gateway/scoped?capability=$secret',
  clientUploadId: 'scoped',
  objectKey: 'owned/audio',
  uploadCapability: secret,
  expiresAt: DateTime.now().add(const Duration(minutes: 1)),
  gateway: true,
  integrationPending: false,
);
