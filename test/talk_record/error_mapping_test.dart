/// T08 面聊记录（talk_record）错误映射与请求头/ETag 测试。
///
/// 覆盖：envelope code/msg/payload 失败分型（classifyTalkRecordError +
/// TalkRecordApiException）、Idempotency-Key / If-Match 头注入、响应 ETag
/// 捕获（拦截器组件 + dio fake adapter 全链路）。
///
/// 本文件是 fixture 契约测试：fake adapter 只证明客户端组件行为（头到达
/// dio 层、包络解析、ETag 捕获），不伪造与真实后端的联调成功。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

/// 记录最近一次请求（含 Options 头）的假 API——用于请求构造断言。
class _RecordingApi extends TalkRecordApi {
  String? lastUri;
  Options? lastOptions;
  dynamic lastData;
  IMBoyHttpResponse next = IMBoyHttpResponse.success(<String, dynamic>{});

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    lastUri = uri;
    lastOptions = options;
    return next;
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    lastUri = uri;
    lastOptions = options;
    lastData = data;
    return next;
  }

  @override
  Future<IMBoyHttpResponse> patch(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    lastUri = uri;
    lastOptions = options;
    lastData = data;
    return next;
  }

  @override
  Future<IMBoyHttpResponse> put(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) async {
    lastUri = uri;
    lastOptions = options;
    lastData = data;
    return next;
  }

  @override
  Future<IMBoyHttpResponse> delete(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) async {
    lastUri = uri;
    lastOptions = options;
    lastData = data;
    return next;
  }
}

/// dio 层假适配器：捕获 RequestOptions（头/路径/请求体），返回 fixture
/// envelope。不打真实网络。
class _FixtureAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  Map<String, dynamic> envelopePayload = <String, dynamic>{};
  int envelopeCode = 0;
  int httpStatus = 200;
  Map<String, List<String>> extraHeaders = <String, List<String>>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return Future.value(
      ResponseBody.fromString(
        jsonEncode({
          'code': envelopeCode,
          'msg': envelopeCode == 0 ? 'success' : 'error',
          'payload': envelopePayload,
        }),
        httpStatus,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...extraHeaders,
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('错误分型 classifyTalkRecordError（§4 错误语义映射）', () {
    test('401 系 → unauthorized', () {
      expect(classifyTalkRecordError(401), TalkRecordErrorKind.unauthorized);
      expect(
        classifyTalkRecordError(ErrorCode.TOKEN_EXPIRED),
        TalkRecordErrorKind.unauthorized,
      );
    });
    test('403 → forbidden；404 → noAccess（无权限/不存在统一）', () {
      expect(classifyTalkRecordError(403), TalkRecordErrorKind.forbidden);
      expect(classifyTalkRecordError(404), TalkRecordErrorKind.noAccess);
    });
    test('409 / 幂等键冲突 → conflict', () {
      expect(classifyTalkRecordError(409), TalkRecordErrorKind.conflict);
      expect(
        classifyTalkRecordError(ErrorCode.IDEMPOTENCY_CONFLICT),
        TalkRecordErrorKind.conflict,
      );
    });
    test('412 → revisionStale；428 → preconditionRequired', () {
      expect(
        classifyTalkRecordError(ErrorCode.PRECONDITION_FAILED),
        TalkRecordErrorKind.revisionStale,
      );
      expect(
        classifyTalkRecordError(TalkRecordErrorCode.preconditionRequired),
        TalkRecordErrorKind.preconditionRequired,
      );
    });
    test('413/415/422/429/503 分型', () {
      expect(classifyTalkRecordError(413), TalkRecordErrorKind.payloadTooLarge);
      expect(
        classifyTalkRecordError(415),
        TalkRecordErrorKind.unsupportedMedia,
      );
      expect(classifyTalkRecordError(422), TalkRecordErrorKind.invalidInput);
      expect(classifyTalkRecordError(429), TalkRecordErrorKind.rateLimited);
      expect(
        classifyTalkRecordError(503),
        TalkRecordErrorKind.processingUnavailable,
      );
    });
    test('55xx 预留段 → domain；其余 5xx → server；未知 → unknown', () {
      expect(classifyTalkRecordError(5500), TalkRecordErrorKind.domain);
      expect(classifyTalkRecordError(5599), TalkRecordErrorKind.domain);
      expect(classifyTalkRecordError(5699), isNot(TalkRecordErrorKind.domain));
      expect(classifyTalkRecordError(500), TalkRecordErrorKind.server);
      expect(classifyTalkRecordError(9999), TalkRecordErrorKind.unknown);
    });
    test('TalkRecordErrorCode.inDomain 边界', () {
      expect(TalkRecordErrorCode.inDomain(5500), isTrue);
      expect(TalkRecordErrorCode.inDomain(5599), isTrue);
      expect(TalkRecordErrorCode.inDomain(5499), isFalse);
      expect(TalkRecordErrorCode.inDomain(5600), isFalse);
    });
  });

  group('包络失败 → TalkRecordApiException 分型', () {
    Future<TalkRecordApiException> thrownBy(
      Future<void> Function() action,
    ) async {
      try {
        await action();
        fail('should throw');
      } on TalkRecordApiException catch (e) {
        return e;
      }
    }

    test('transformer：428 响应体解出 code=428 的失败信封', () {
      final resp = DefaultHttpTransformer.getInstance().parse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: API.talkRecords),
          statusCode: 428,
          data: {'code': 428, 'msg': 'precondition_required', 'payload': null},
        ),
        API.talkRecords,
      );
      expect(resp.ok, isFalse);
      expect(resp.code, 428);
      expect(resp.msg, 'precondition_required');
    });

    test('428（缺 If-Match）：isPreconditionRequired + 编程错误语义', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.failure(
          errCode: 428,
          errMsg: 'precondition_required',
        );
      final e = await thrownBy(
        () => api.patchRecord('2001', title: 'new', ifMatch: ''),
      );
      expect(e.kind, TalkRecordErrorKind.preconditionRequired);
      expect(e.isPreconditionRequired, isTrue);
    });

    test('412（版本过期）：isRevisionStale，payload 透传服务端当前 revision', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.failure(
          errCode: 412,
          errMsg: 'revision_conflict',
          payload: {'current_revision': 6},
        );
      final e = await thrownBy(
        () => api.patchRecord('2001', title: 'new', ifMatch: '"v5"'),
      );
      expect(e.isRevisionStale, isTrue);
      expect(e.payload, isA<Map<dynamic, dynamic>>());
      expect((e.payload as Map<dynamic, dynamic>)['current_revision'], 6);
    });

    test('409 missing_sequences：isConflict + payload 缺失序号清单', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.failure(
          errCode: 409,
          errMsg: 'missing_sequences',
          payload: {
            'missing_sequences': [3, 7],
          },
        );
      final e = await thrownBy(
        () => api.complete(
          '2001',
          captures: const [],
          policyVersion: 'notice-v1',
          idempotencyKey: 'idem-1',
          ifMatch: '"v5"',
        ),
      );
      expect(e.isConflict, isTrue);
      expect((e.payload as Map<dynamic, dynamic>)['missing_sequences'], [3, 7]);
    });

    test('404 统一无权限/不存在（§11.3 不披露原因）', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.failure(errCode: 404, errMsg: 'not_found');
      final e = await thrownBy(() async => api.detail('9999'));
      expect(e.isNoAccess, isTrue);
      expect(e.toString(), contains('noAccess'));
    });

    test('5460 幂等键冲突归入 conflict', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.failure(
          errCode: ErrorCode.IDEMPOTENCY_CONFLICT,
          errMsg: 'idempotency_conflict',
        );
      final e = await thrownBy(() async => api.detail('2001'));
      expect(e.isConflict, isTrue);
    });
  });

  group('Idempotency-Key / If-Match 头注入（请求构造）', () {
    test('create：Idempotency-Key 必带 + notice_ack/policy_version', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.success({'id': 1001, 'revision': 1});
      await api.create(
        clientRecordingId: 'uuid-1',
        scope: TalkRecordScope.organization,
        language: 'zh-CN',
        processingMode: TalkRecordProcessingMode.transcribe,
        policyVersion: 'notice-v1',
        idempotencyKey: 'idem-create-1',
        organizationId: '42',
      );
      expect(api.lastUri, API.talkRecords);
      expect(
        api.lastOptions?.headers?[TalkRecordHttpHeaders.idempotencyKey],
        'idem-create-1',
      );
      final body = api.lastData as Map<String, dynamic>;
      expect(body['notice_ack'], true);
      expect(body['policy_version'], 'notice-v1');
      expect(body['scope'], 'organization');
      expect(body['organization_id'], '42');
      expect(body['source_type'], 'live_recording');
    });

    test('无头需求时不构造 Options（保持基础头）', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.success({
          'id': 5001,
          'client_event_id': 'ce-1',
          'seq': 1,
          'revision': 2,
        });
      await api.postCaptureEvent(
        '2001',
        '5001',
        const TalkRecordCaptureEventInput(
          clientEventId: 'ce-1',
          deviceSessionId: 'ds-1',
          seq: 1,
          event: TalkRecordCaptureEventKind.start,
        ),
      );
      expect(api.lastOptions, isNull);
    });

    test('createCapture：Idempotency-Key + If-Match 双头', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.success({'id': 5001, 'revision': 1});
      await api.createCapture(
        '2001',
        deviceSessionId: 'ds-1',
        idempotencyKey: 'idem-cap-1',
        ifMatch: '"v1"',
      );
      expect(api.lastUri, API.talkRecordCaptures('2001'));
      expect(
        api.lastOptions?.headers?[TalkRecordHttpHeaders.idempotencyKey],
        'idem-cap-1',
      );
      expect(api.lastOptions?.headers?[TalkRecordHttpHeaders.ifMatch], '"v1"');
    });

    test('putGrants / deleteGrant / retryJob：If-Match 注入', () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.success({'list': <Map<String, dynamic>>[]});
      await api.putGrants('2001', grants: const [], ifMatch: '"acl-2"');
      expect(api.lastUri, API.talkRecordGrants('2001'));
      expect(
        api.lastOptions?.headers?[TalkRecordHttpHeaders.ifMatch],
        '"acl-2"',
      );

      await api.deleteGrant('2001', '9001', ifMatch: '"acl-3"');
      expect(api.lastUri, API.talkRecordGrantDetail('2001', '9001'));
      expect(
        api.lastOptions?.headers?[TalkRecordHttpHeaders.ifMatch],
        '"acl-3"',
      );

      await api.retryJob(
        '2001',
        '9101',
        idempotencyKey: 'idem-r-1',
        ifMatch: '"v5"',
      );
      expect(api.lastUri, API.talkRecordJobRetry('2001', '9101'));
      expect(
        api.lastOptions?.headers?[TalkRecordHttpHeaders.idempotencyKey],
        'idem-r-1',
      );
      expect(api.lastOptions?.headers?[TalkRecordHttpHeaders.ifMatch], '"v5"');
    });
  });

  group('ETag 捕获：拦截器组件', () {
    test('talk-records 前缀响应捕获 etag；takeLast 消费式读取', () {
      final interceptor = TalkRecordEtagInterceptor();
      final uri = API.talkRecordDetail('2001');
      interceptor.onResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: uri),
          headers: Headers.fromMap({
            TalkRecordHttpHeaders.etag: ['"v1-5"'],
          }),
        ),
        ResponseInterceptorHandler(),
      );
      expect(interceptor.takeLast(uri), '"v1-5"');
      // 消费后清空，不串页。
      expect(interceptor.takeLast(uri), isNull);
    });

    test('非 talk-records 路径不捕获；无 etag 头为 null', () {
      final interceptor = TalkRecordEtagInterceptor();
      interceptor.onResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1/other'),
          headers: Headers.fromMap({
            TalkRecordHttpHeaders.etag: ['"x"'],
          }),
        ),
        ResponseInterceptorHandler(),
      );
      expect(interceptor.takeLast('/api/v1/other'), isNull);
    });
  });

  group('ETag 捕获与头注入：dio 层全链路（fake adapter）', () {
    late _FixtureAdapter adapter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '91001'});
      await StorageService.init();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async {
              if (call.method == 'read') {
                final encode = base64Url.encode;
                return '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
                    '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
                    '${encode(utf8.encode('synthetic-signature'))}';
              }
              return null;
            },
          );
      adapter = _FixtureAdapter();
      HttpClient.adapterForTest = adapter;
    });

    tearDown(() {
      HttpClient.adapterForTest = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    });

    test('detail：响应 ETag 被捕获进 TalkRecordFetched', () async {
      adapter
        ..envelopePayload = {'id': 2001, 'revision': 5}
        ..extraHeaders = {
          TalkRecordHttpHeaders.etag: ['"record-2001-v5"'],
        };
      final api = TalkRecordApi();
      final fetched = await api.detail('2001');
      expect(fetched.data.id, '2001');
      expect(fetched.data.revision, 5);
      expect(fetched.etag, '"record-2001-v5"');
      expect(fetched.hasEtag, isTrue);
      expect(adapter.lastRequest?.path, API.talkRecordDetail('2001'));
    });

    test('create：Idempotency-Key 真实到达 dio 请求头', () async {
      adapter.envelopePayload = {'id': 2002, 'revision': 1};
      final api = TalkRecordApi();
      final fetched = await api.create(
        clientRecordingId: 'uuid-2',
        scope: TalkRecordScope.personal,
        language: 'zh-CN',
        processingMode: TalkRecordProcessingMode.recordOnly,
        policyVersion: 'notice-v1',
        idempotencyKey: 'idem-full-1',
      );
      expect(fetched.data.id, '2002');
      expect(
        adapter.lastRequest?.headers[TalkRecordHttpHeaders.idempotencyKey],
        'idem-full-1',
      );
      expect(adapter.lastRequest?.path, API.talkRecords);
    });

    test('失败信封（428）经 transformer 解析后抛分型异常', () async {
      adapter
        ..envelopeCode = 428
        ..httpStatus = 428
        ..envelopePayload = {'reason': 'if_match_required'};
      final api = TalkRecordApi();
      await expectLater(
        api.patchRecord('2001', title: 'x', ifMatch: '"stale"'),
        throwsA(
          isA<TalkRecordApiException>()
              .having(
                (e) => e.kind,
                'kind',
                TalkRecordErrorKind.preconditionRequired,
              )
              .having((e) => e.code, 'code', 428),
        ),
      );
    });
  });
}
