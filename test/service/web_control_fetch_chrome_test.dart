@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_retry_interceptor.dart';
import 'package:imboy/component/http/web_control_fetch_adapter.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:sqflite_common/sqflite.dart' as common;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:xid/xid.dart';

import '../env_test_pin.dart';
import '../secure_storage_test_pin.dart';

const _originInput = String.fromEnvironment('WEB_CONTROL_TEST_ORIGIN');
late Uri _origin;
const _uid = '910000000001';

class _FixtureEnv implements Env {
  @override
  String get apiBaseUrl => _origin.origin;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dio _client({bool member = false}) {
  final session = authSessionReader.current;
  final owner = AccountLocalTaskOwner.capture();
  void current() {
    requireWebWriter();
    if (authSessionReader.current != session ||
        session.transitioning ||
        AccountLocalTaskOwner.capture() != owner) {
      throw StateError('Synthetic control owner changed');
    }
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _origin.origin,
      contentType: member ? 'application/octet-stream' : 'application/json',
      followRedirects: false,
      maxRedirects: 0,
      sendTimeout: const Duration(seconds: 5),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      extra: {httpRequestGuard: current},
    ),
  );
  return member
      ? guardWebMemberDio(dio, apiOrigin: _origin)
      : guardWebControlDio(dio, apiOrigin: _origin);
}

Future<List<Object?>> _stats(String id) async {
  final response = await web.window
      .fetch(
        '${_origin.origin}/stats?case=$id'.toJS,
        web.RequestInit(credentials: 'omit'),
      )
      .toDart;
  return jsonDecode((await response.text().toDart).toDart) as List<Object?>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    expect(
      _originInput,
      isNotEmpty,
      reason: 'controlled fixture preparation required',
    );
    _origin = Uri.parse(_originInput);
    expect(_origin.scheme, 'http');
    expect({'127.0.0.1', 'localhost'}, contains(_origin.host));
    expect(_origin.userInfo, isEmpty);
    pinLoopbackTestEnv();
    envMap['dev'] = _FixtureEnv();
    await prepareWebWriter();
    SharedPreferences.setMockInitialValues({Keys.currentUid: _uid});
    await StorageService.init();
  });

  test(
    'actual Dio Fetch preserves raw response for the production ID decoder',
    () async {
      final dio = _client();
      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/api/v1/probe?case=positive',
          data: {'text': 'synthetic'},
          options: Options(
            responseDecoder: channelIdResponseDecoder(
              ChannelResponseShape.detail,
            ),
          ),
        );
        expect(response.data!['payload']['id'], '9007199254740993');
        expect(response.statusCode, 200);
        expect(response.headers.value('x-control-fixture'), 'synthetic');
        final records = await _stats('positive');
        expect(records, hasLength(1));
        expect((records.single as Map)['method'], 'POST');
      } finally {
        dio.close(force: true);
      }
    },
  );

  test(
    'group result preserves the exact large peer over browser Fetch',
    () async {
      final dio = _client();
      try {
        final response = await dio.get<Map<String, dynamic>>(
          '/api/v1/web/msg/result?case=result-large-peer',
          options: Options(
            responseDecoder: channelIdResponseDecoder(
              ChannelResponseShape.messageResult,
            ),
          ),
        );
        final payload = response.data!['payload'] as Map;
        expect(payload['message_id'], 'synthetic-id');
        expect(payload['chat_type'], 'c2g');
        expect(payload['peer_id'], '123456837222926336');
        expect(payload['state'], 'committed');
        expect(await _stats('result-large-peer'), hasLength(1));
      } finally {
        dio.close(force: true);
      }
    },
  );

  test('authenticated MsgApi binds the exact group result in Chrome', () async {
    final secure = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String?;
          if (call.method == 'read') return secure[key];
          if (call.method == 'write') secure[key!] = args['value'] as String;
          if (call.method == 'delete') secure.remove(key);
          return null;
        });
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'none', 'typ': 'JWT'})}.'
        '${encode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.';
    expect(tokenExpired(token), isFalse);
    await SecureTokenStorageService.saveToken(token);
    expect(await SecureTokenStorageService.getToken(), token);
    try {
      final api = MsgApi();
      expect(
        await api.isCommitted(
          chatType: 'c2g',
          peerId: '123456837222926336',
          messageId: 'synthetic-id',
        ),
        isTrue,
      );
      expect(
        await api.isCommitted(
          chatType: 'c2g',
          peerId: '123456837222926337',
          messageId: 'synthetic-id',
        ),
        isFalse,
      );
      expect(
        await api.isCommitted(
          chatType: 'c2g',
          peerId: '123456837222926336',
          messageId: 'other-id',
        ),
        isFalse,
      );
      final rows = await _stats('');
      expect(rows, hasLength(3));
      expect(
        rows.every((row) => (row as Map)['authorization'] == true),
        isTrue,
      );
      initSqfliteFactory();
      final path = '${currentEnv}_$_uid.db';
      expect(await common.databaseFactory.databaseExists(path), isFalse);
      final ownerScope = AccountLocalTaskOwner.capture();
      await StorageService.to.setString(
        LoginAccountHistoryService.storageKey,
        jsonEncode({
          'version': 1,
          'accounts': [
            LoginAccountIdentity(
              uid: _uid,
              environment: ownerScope.environment,
              endpoint: ownerScope.endpoint,
              aliases: {_uid},
              storageOwnershipVerified: true,
            ).toJson(),
          ],
        }),
      );
      try {
        final db = (await SqliteService.to.db)!;
        await db.insert('msg_c2g', {
          'id': 'synthetic-id',
          'type': 'C2G',
          'from_id': _uid,
          'to_id': '123456837222926336',
          'is_author': 1,
          'conversation_uk3': 'c2g-$_uid-123456837222926336',
          'status': IMBoyMessageStatus.outcomeUnknown,
        });
        await db.insert('conversation', {
          'user_id': _uid,
          'peer_id': '123456837222926336',
          'type': 'C2G',
          'last_msg_id': 'synthetic-id',
          'last_msg_status': IMBoyMessageStatus.outcomeUnknown,
        });
        final owner = AccountLocalTaskOwner.capture().storageDigest;
        final repo = AttachmentUploadTaskRepo();
        await repo.insert(
          AttachmentUploadTask(
            id: 'recovery-task',
            userId: _uid,
            scope: 'private',
            scopeRef: null,
            fileName: 'synthetic.txt',
            mime: 'text/plain',
            plainSize: 1,
            plainSha256: 'synthetic',
            objectKey: 'synthetic',
            uploadPath: BrowserUploadMaterial.pending(owner, 'recovery-task'),
            businessIntent: jsonEncode({
              'author_id': _uid,
              'peer_id': '123456837222926336',
              'chat_type': 'c2g',
              'state': 'commit_unknown',
              'message_template': <String, dynamic>{},
            }),
            stage: AttachmentUploadStage.confirmed,
            cipher: null,
            bindingHash: null,
            keyRef: null,
            ciphertextSha256: null,
            anchorMsgId: 'synthetic-id',
            lastError: null,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        await SqliteService.to.close();
        final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(
          ownerScope,
        );
        try {
          await cleanup.stopped;
          await ResumableAttachmentUploader.recoverCurrentSession();
          expect(await _stats(''), hasLength(3));
        } finally {
          cleanup.release();
        }
        await ResumableAttachmentUploader.recoverCurrentSession();
        final reopened = (await SqliteService.to.db)!;
        expect(
          (await reopened.query('msg_c2g')).single['status'],
          IMBoyMessageStatus.sent,
        );
        expect(
          (await reopened.query('conversation')).single['last_msg_status'],
          IMBoyMessageStatus.sent,
        );
        expect(
          jsonDecode(
            (await repo.find('recovery-task'))!.businessIntent!,
          )['state'],
          'committed',
        );
        expect(await _stats(''), hasLength(4));
      } finally {
        await SqliteService.to.close();
        await StorageService.to.setString(Keys.currentUid, '');
        await SqliteService.to.deleteDatabaseForUid(
          _uid,
          environment: currentEnv,
        );
        await StorageService.to.setString(Keys.currentUid, _uid);
      }
    } finally {
      await SecureTokenStorageService.clear();
      pinInertSecureStorage();
    }
  });

  test(
    'owner changes after last body chunk: no request reaches the fixture',
    () async {
      final dio = _client();
      Stream<List<int>> body() async* {
        yield utf8.encode('{"text":"retained"}');
        // Last chunk passed earlier guards; change before stream completion and
        // the adapter continuation. An entry/chunk-only guard misses this case.
        await StorageService.to.setString(Keys.currentUid, '910000000002');
      }

      try {
        await expectLater(
          dio.post<void>('/api/v1/probe?case=owner', data: body()),
          throwsA(
            isA<DioException>()
                .having((e) => e.type, 'type', DioExceptionType.cancel)
                .having(
                  (e) => e.error,
                  'pre-dispatch',
                  isA<WebControlBeforeDispatch>(),
                ),
          ),
        );
        expect(await _stats('owner'), isEmpty);
      } finally {
        await StorageService.to.setString(Keys.currentUid, _uid);
        dio.close(force: true);
      }
    },
  );

  test('cancel or close after last chunk cannot dispatch', () async {
    for (final mode in ['cancel', 'close']) {
      final dio = _client();
      final token = CancelToken();
      Stream<List<int>> body() async* {
        yield utf8.encode('{}');
        if (mode == 'cancel') {
          token.cancel('synthetic');
        } else {
          dio.close(force: true);
        }
      }

      try {
        await expectLater(
          dio.post<void>(
            '/api/v1/probe?case=$mode',
            data: body(),
            cancelToken: token,
          ),
          throwsA(isA<DioException>()),
        );
        expect(await _stats(mode), isEmpty);
      } finally {
        dio.close(force: true);
      }
    }
  });

  test('over-limit or unsupported controls never fall back to XHR', () async {
    final dio = _client();
    try {
      final payload = Stream<List<int>>.fromIterable([
        Uint8List(1024 * 1024),
        Uint8List(1),
      ]);
      await expectLater(
        dio.post<void>('/api/v1/probe?case=limit', data: payload),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.post<void>(
          '/api/v1/probe?case=no-deadline',
          data: {},
          options: Options(
            connectTimeout: Duration.zero,
            sendTimeout: Duration.zero,
            receiveTimeout: Duration.zero,
          ),
        ),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.post<void>(
          '/api/v1/probe?case=progress',
          data: {},
          onSendProgress: (_, _) {},
        ),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.post<void>(
          '/api/v1/probe?case=missing-guard',
          data: {},
          options: Options(extra: {httpRequestGuard: null}),
        ),
        throwsA(isA<DioException>()),
      );
      for (final id in ['limit', 'no-deadline', 'progress', 'missing-guard']) {
        expect(await _stats(id), isEmpty);
      }
    } finally {
      dio.close(force: true);
    }
  });

  test(
    'overall deadline before dispatch retains a typed non-cancel result',
    () async {
      final dio = _client();
      final release = Completer<void>();
      final releaseTimer = Timer(const Duration(milliseconds: 150), () {
        if (!release.isCompleted) release.complete();
      });
      Stream<List<int>> body() async* {
        yield utf8.encode('{}');
        await release.future;
      }

      try {
        await expectLater(
          dio.post<void>(
            '/api/v1/probe?case=deadline-before',
            data: body(),
            options: Options(sendTimeout: const Duration(milliseconds: 30)),
          ),
          throwsA(
            isA<DioException>()
                .having((e) => e.type, 'type', DioExceptionType.unknown)
                .having(
                  (e) => e.requestOptions.extra[httpNoAutoRetry],
                  'retry',
                  true,
                )
                .having(
                  (e) => e.error,
                  'deadline',
                  isA<WebControlDeadlineExceeded>().having(
                    (e) => e.dispatched,
                    'dispatched',
                    false,
                  ),
                ),
          ),
        );
        expect(await _stats('deadline-before'), isEmpty);
      } finally {
        if (!release.isCompleted) release.complete();
        releaseTimer.cancel();
        dio.close(force: true);
      }
    },
  );

  test(
    'overall deadline after dispatch keeps unknown and blocks retry',
    () async {
      final dio = _client();
      try {
        await expectLater(
          dio.post<void>(
            '/api/v1/slow?case=deadline-after',
            data: {},
            options: Options(sendTimeout: const Duration(milliseconds: 250)),
          ),
          throwsA(
            isA<DioException>()
                .having((e) => e.type, 'type', DioExceptionType.unknown)
                .having(
                  (e) => e.requestOptions.extra[httpNoAutoRetry],
                  'retry',
                  true,
                )
                .having(
                  (e) => e.error,
                  'deadline',
                  isA<WebControlDeadlineExceeded>().having(
                    (e) => e.dispatched,
                    'dispatched',
                    true,
                  ),
                ),
          ),
        );
        expect(await _stats('deadline-after'), hasLength(1));
      } finally {
        dio.close(force: true);
      }
    },
  );

  test('member raw PUT keeps exact body and scoped JSON response', () async {
    final dio = _client(member: true);
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    try {
      final response = await dio.put<Map<String, dynamic>>(
        '/api/v1/enterprise/organizations/123/assets/presign'
        '?workspace_id=456&upload_ref=synthetic&case=member',
        data: bytes,
        options: Options(
          headers: {'authorization': 'Bearer synthetic'},
          responseDecoder: channelIdResponseDecoder(
            ChannelResponseShape.detail,
          ),
        ),
      );
      expect(response.data!['payload']['id'], '9007199254740993');
      final records = await _stats('member');
      expect(records, hasLength(1));
      final record = records.single as Map;
      expect(record['method'], 'PUT');
      expect(record['size'], bytes.length);
      expect(record['sha256'], sha256.convert(bytes).toString());
      expect(record['cookie'], isFalse);
      expect(record['authorization'], isTrue);
    } finally {
      dio.close(force: true);
    }
  });

  test(
    'body wait cannot change frozen target headers method or guard',
    () async {
      final dio = _client();
      final authorization = ['Bearer synthetic-original'];
      late RequestOptions captured;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.next(options);
          },
        ),
      );
      Stream<List<int>> body() async* {
        yield utf8.encode('{}');
        captured.path = 'http://127.0.0.1:1/api/v1/mutated';
        captured.baseUrl = 'http://127.0.0.1:1';
        captured.queryParameters = {'case': 'mutated'};
        captured.method = 'DELETE';
        authorization[0] = 'Bearer synthetic-mutated-list';
        captured.headers['authorization'] = 'Bearer synthetic-mutated-map';
        captured.followRedirects = true;
        captured.maxRedirects = 9;
        captured.sendTimeout = const Duration(microseconds: 1);
        captured.extra['withCredentials'] = true;
        captured.extra[httpRequestGuard] = () {
          throw StateError('replacement guard must never run');
        };
      }

      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/api/v1/probe?case=frozen',
          data: body(),
          options: Options(headers: {'authorization': authorization}),
        );
        expect(response.statusCode, 200);
        final records = await _stats('frozen');
        expect(records, hasLength(1));
        final record = records.single as Map;
        expect(record['path'], '/api/v1/probe');
        expect(record['method'], 'POST');
        expect(
          record['authorizationSha256'],
          sha256.convert(utf8.encode('Bearer synthetic-original')).toString(),
        );
        expect(await _stats('mutated'), isEmpty);
      } finally {
        dio.close(force: true);
      }
    },
  );

  test('replacing mutable guard or token cannot admit the old owner', () async {
    for (final mode in ['guard', 'token']) {
      final dio = _client();
      final token = CancelToken();
      final replacement = CancelToken();
      late RequestOptions captured;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.next(options);
          },
        ),
      );
      Stream<List<int>> body() async* {
        yield utf8.encode('{}');
        if (mode == 'guard') {
          captured.extra[httpRequestGuard] = () {};
          await StorageService.to.setString(Keys.currentUid, '910000000002');
        } else {
          captured.cancelToken = replacement;
          token.cancel('original token remains authoritative');
        }
      }

      try {
        await expectLater(
          dio.post<void>(
            '/api/v1/probe?case=replaced-$mode',
            data: body(),
            cancelToken: token,
          ),
          throwsA(
            isA<DioException>()
                .having((e) => e.type, 'type', DioExceptionType.cancel)
                .having(
                  (e) => e.requestOptions.extra[httpNoAutoRetry],
                  'retry',
                  true,
                ),
          ),
        );
        expect(await _stats('replaced-$mode'), isEmpty);
        expect(replacement.isCancelled, isFalse);
      } finally {
        await StorageService.to.setString(Keys.currentUid, _uid);
        dio.close(force: true);
      }
    }
  });

  test(
    'all explicit pre-dispatch refusals defeat a true retry evaluator',
    () async {
      for (final mode in ['config', 'read-body', 'header-preparation']) {
        final dio = _client();
        var attempts = 0;
        var evaluations = 0;
        var retries = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              attempts++;
              expect(
                options.responseType,
                mode == 'config' ? ResponseType.plain : ResponseType.json,
                reason:
                    'Dio must preserve the intended adapter rejection premise',
              );
              expect(options.method, mode == 'read-body' ? 'GET' : 'POST');
              handler.next(options);
            },
          ),
        );
        final retry = HttpRetryInterceptor(
          maxRetries: 2,
          retryInterval: Duration.zero,
          retryEvaluator: (_) {
            evaluations++;
            return true;
          },
          onRetry: (_, _) {
            retries++;
          },
        )..bindDio(dio);
        dio.interceptors.add(retry);
        try {
          await expectLater(
            dio.request<dynamic>(
              '/api/v1/probe?case=no-retry-$mode',
              data: Stream<List<int>>.value(utf8.encode('{}')),
              options: Options(
                method: mode == 'read-body' ? 'GET' : 'POST',
                responseType: mode == 'config'
                    ? ResponseType.plain
                    : ResponseType.json,
                headers: mode == 'header-preparation'
                    ? {'invalid\nname': 'synthetic'}
                    : null,
              ),
            ),
            throwsA(
              isA<DioException>()
                  .having(
                    (e) => e.error,
                    'pre-dispatch',
                    isA<WebControlBeforeDispatch>(),
                  )
                  .having(
                    (e) => e.requestOptions.extra[httpNoAutoRetry],
                    'retry',
                    true,
                  ),
            ),
          );
          expect(attempts, 1);
          expect(evaluations, 0);
          expect(retries, 0);
          expect(await _stats('no-retry-$mode'), isEmpty);
        } finally {
          dio.close(force: true);
        }
      }
    },
  );

  test(
    'offline page above one MiB retains all 1000 messages and exact IDs',
    () async {
      final dio = _client();
      Response<Map<String, dynamic>>? response;
      DioException? failure;
      var receivedBytes = 0;
      try {
        try {
          response = await dio.get<Map<String, dynamic>>(
            API.msgOffline,
            queryParameters: {'case': 'offline-large'},
            onReceiveProgress: (received, _) => receivedBytes = received,
            options: Options(
              responseDecoder: channelIdResponseDecoder(
                ChannelResponseShape.offline,
              ),
              extra: {httpNoAutoRetry: true},
            ),
          );
        } on DioException catch (error) {
          failure =
              error; // Reassert below, after proving the RED size premise.
        }
        final records = await _stats('offline-large');
        expect(records, hasLength(1));
        final record = records.single as Map;
        expect(record['method'], 'GET');
        expect(record['path'], API.msgOffline);
        expect(record['complete'], isTrue);
        final wireBytes = record['response_bytes'] as int;
        expect(wireBytes, greaterThan(1024 * 1024));
        expect(record['response_items'], 1000);
        expect(
          failure,
          isNull,
          reason:
              'legal offline pages must retain the old response-size behavior',
        );
        expect(response, isNotNull);
        expect(receivedBytes, wireBytes);
        expect(response!.headers.value('content-length'), '$wireBytes');
        expect(response!.data!['code'], 0);
        final payload = response!.data!['payload'] as Map;
        expect((payload['c2c'] as Map)['list'], isEmpty);
        expect((payload['c2g'] as Map)['list'], isEmpty);
        final section = payload['s2c'] as Map;
        expect(section['total'], 1000);
        expect(section['has_more'], isFalse);
        expect(MessageOfflineService.extractNextCursor(section), 1750000000999);
        final rows = section['list'] as List;
        expect(rows, hasLength(1000));
        final padding = List.filled(1400, 'x').join();
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map;
          final mid =
              '0000000000000000${(i + 1).toRadixString(32).padLeft(3, '0')}0';
          expect(row['id'], mid);
          expect(Xid.fromString(row['id'] as String).toString(), mid);
          expect(row['action'], 'channel_message');
          expect(row['from'], '9007199254740993');
          expect(row['to'], _uid);
          expect(row['created_at'], 1750000000000 + i);
          final body = row['payload'] as Map;
          expect(
            body['id'],
            (BigInt.parse('9007199254740993') + BigInt.from(i * 2)).toString(),
          );
          expect(body['channel_id'], '9007199254740995');
          expect(body['author_id'], '9007199254740997');
          expect(body['content'], 'synthetic-$i:$padding');
        }
        expect(
          ((rows.last as Map)['payload'] as Map)['id'],
          '9007199254742991',
        );
      } finally {
        dio.close(force: true);
      }
    },
  );
}
