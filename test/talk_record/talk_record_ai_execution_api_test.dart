import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/store/api/talk_record_api.dart';

class _Api extends TalkRecordApi {
  String method = '', path = '';
  Options? sent;
  Object? body;
  IMBoyHttpResponse capture(
    String verb,
    String uri,
    Options? options,
    Object? data,
  ) {
    method = verb;
    path = uri;
    sent = options;
    body = data;
    (options!.extra![httpRequestGuard] as void Function())();
    return IMBoyHttpResponse.success({'id': 1});
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async => capture('GET', uri, options, null);
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
  }) async => capture('POST', uri, options, data);
  @override
  Future<IMBoyHttpResponse> put(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async => capture('PUT', uri, options, data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = <String, (String, String)>{
    'provider-create': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/provider-tasks',
    ),
    'provider-get': ('GET', '/api/v1/talk-records/1/provider-tasks/50'),
    'provider-submit-intent': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/provider-tasks/50/submit-intents',
    ),
    'provider-submission-receipt': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/provider-tasks/50/submission-receipts',
    ),
    'provider-reconcile-receipt': (
      'POST',
      '/api/v1/talk-records/1/provider-tasks/50/reconcile-receipt',
    ),
    'provider-query-execution': (
      'POST',
      '/api/v1/talk-records/1/provider-tasks/50/query-executions',
    ),
    'provider-query-intent': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/provider-tasks/50/query-intents',
    ),
    'provider-query-receipt': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/provider-tasks/50/query-receipts',
    ),
    'provider-complete': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/provider-tasks/50/complete',
    ),
    'provider-cancel': (
      'POST',
      '/api/v1/talk-records/1/provider-tasks/50/cancel',
    ),
    'provider-resubmission': (
      'POST',
      '/api/v1/talk-records/1/provider-tasks/50/resubmissions',
    ),
    'request': ('POST', '/api/v1/talk-records/1/processing-requests'),
    'claim': ('POST', '/api/v1/talk-records/1/jobs/3/client-executions'),
    'latest': ('GET', '/api/v1/talk-records/1/jobs/3/client-executions/latest'),
    'recover-unprepared': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/recover-unprepared',
    ),
    'get': ('GET', '/api/v1/talk-records/1/jobs/3/client-executions/4'),
    'plan': (
      'PUT',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/chunk-plan',
    ),
    'heartbeat': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/heartbeat',
    ),
    'dispatch': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/parts/2/dispatch-intents',
    ),
    'result': (
      'PUT',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/parts/2/result',
    ),
    'complete': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/complete',
    ),
    'settle': (
      'POST',
      '/api/v1/talk-records/1/jobs/3/client-executions/4/settle',
    ),
  };
  for (final entry in cases.entries) {
    test(
      'actual API extension ${entry.key} path headers and no retry policy',
      () async {
        final api = _Api();
        var guards = 0;
        await api.clientExecutionRequest(
          recordId: '1',
          jobId: '3',
          runId: '4',
          taskId: '50',
          action: entry.key,
          seq: 2,
          body: {'synthetic': true},
          idempotencyKey: 'synthetic-key',
          ifMatch: '"client-run:4:1"',
          token: 'synthetic-run-token',
          guard: () => guards++,
        );
        expect((api.method, api.path), entry.value);
        expect(api.sent!.extra![httpNoAutoRetry], isTrue);
        expect(api.sent!.headers, {
          'Idempotency-Key': 'synthetic-key',
          'If-Match': '"client-run:4:1"',
          'X-Talk-Run-Token': 'synthetic-run-token',
        });
        expect(guards, 3);
      },
    );
  }
  test(
    'context uses detail projection and rejects invalidated caller',
    () async {
      final api = _Api();
      await api.clientProcessingContext('1', () {});
      expect(api.path, '/api/v1/talk-records/1');
      expect(api.sent!.extra![httpNoAutoRetry], isTrue);
      await expectLater(
        api.clientProcessingContext('2', () => throw StateError('changed')),
        throwsStateError,
      );
      expect(api.path, '/api/v1/talk-records/1');
    },
  );
  test('unknown successor uses actual claim endpoint with exact consent whitelist and predecessor ETag', () async {
    final api = _Api();
    final body = {
      'previous_run_id': 9007199254740993,
      'ack_possible_duplicate_charge': true,
      'processing_consent': {
        'confirmed': true,
        'execution_mode': 'client_byok',
        'provider': 'minimax',
        'model': 'asr-1.0',
        'policy_version': 'v1',
        'config_version': 'a' * 64,
      },
    };
    await api.clientExecutionRequest(
      recordId: '1',
      jobId: '3',
      runId: '9007199254740993',
      action: 'claim',
      body: body,
      idempotencyKey: 'saved-confirmed-claim',
      ifMatch: '"client-run:9007199254740993:7"',
      guard: () {},
    );
    expect(api.method, 'POST');
    expect(api.path, '/api/v1/talk-records/1/jobs/3/client-executions');
    expect(api.body, body);
    expect(api.sent!.headers, {
      'Idempotency-Key': 'saved-confirmed-claim',
      'If-Match': '"client-run:9007199254740993:7"',
    });
    expect(api.sent!.extra![httpNoAutoRetry], isTrue);
  });
}
