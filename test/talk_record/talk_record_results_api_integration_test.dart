import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_service.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/store/api/talk_record_api.dart';

class _Api extends TalkRecordApi {
  IMBoyHttpResponse response = IMBoyHttpResponse.success(<String, dynamic>{});
  String? uri;
  Object? body;
  Options? options;
  int calls = 0;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    calls++;
    this.uri = uri;
    return response;
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
    calls++;
    this.uri = uri;
    body = data;
    this.options = options;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final allowed in [true, false]) {
    test(
      'export policy uses record-scoped server projection $allowed',
      () async {
        final api = _Api()
          ..response = IMBoyHttpResponse.success({
            'id': 'r',
            'capabilities_for_actor': {'export': allowed},
          });
        final policy = await ApiTalkRecordResultsService(api).exportPolicy('r');
        expect(policy.exportAllowed, allowed);
        expect(api.calls, 1);
        expect(api.uri, '/api/v1/talk-records/r');
      },
    );
  }
  for (final state in ['queued', 'ready', 'failed', 'expired']) {
    test('poll real export route and preserves $state', () async {
      final api = _Api()
        ..response = IMBoyHttpResponse.success({
          'export_id': 7366418340025468940,
          'state': state,
          'format': 'md',
          'expires_at': '2026-10-21T15:00:00Z',
          'job_id': 3,
        });
      final result = await ApiTalkRecordResultsService(api)
          .exportState('r', '7366418340025468940');
      expect(api.uri, '/api/v1/talk-records/r/exports/7366418340025468940');
      expect(result.state, state);
      expect(result.expiresAt, DateTime.utc(2026, 10, 21, 15));
      expect(result.raw['job_id'], 3);
    });
  }
  test('transfer forwards explicit keep_access, capture-independent ETag and idempotency', () async {
    final api = _Api()
      ..response = IMBoyHttpResponse.success({
        'new_owner_user_id': 7366418340025468940,
        'new_owner_display_name': 'Synthetic',
        'keep_access': false,
      });
    final result = await ApiTalkRecordResultsService(api).transferOwnership(
      'r',
      targetUserId: '7366418340025468940',
      keepViewerForOriginalOwner: false,
      ifMatch: '"record:7"',
      idempotencyKey: 'stable-transfer',
    );
    expect(api.uri, '/api/v1/talk-records/r/ownership-transfers');
    expect(api.body, {
      'target_user_id': '7366418340025468940',
      'keep_access': false,
    });
    expect(api.options!.headers, {
      'If-Match': '"record:7"',
      'Idempotency-Key': 'stable-transfer',
    });
    expect(result.newOwnerUserId, '7366418340025468940');
    expect(result.originalOwnerKeptViewer, isFalse);
  });
  test(
    'authorization, expired, conflict and unavailable errors propagate',
    () async {
      for (final code in [403, 404, 410, 412, 503]) {
        final api = _Api()
          ..response = IMBoyHttpResponse.failure(
            errCode: code,
            errMsg: 'synthetic',
          );
        final service = ApiTalkRecordResultsService(api);
        await expectLater(
          service.exportState('r', 'e'),
          throwsA(isA<TalkRecordApiException>()),
        );
        await expectLater(
          service.exportPolicy('r'),
          throwsA(isA<TalkRecordApiException>()),
        );
      }
    },
  );
  test('malformed poll does not report ready', () async {
    final api = _Api()
      ..response = IMBoyHttpResponse.success({
        'export_id': 'other',
        'state': 'ready',
        'format': 'txt',
      });
    await expectLater(
      ApiTalkRecordResultsService(api).exportState('r', 'e'),
      throwsFormatException,
    );
  });
  test('owner cleanup retry never invents a privileged HTTP request', () async {
    final api = _Api();
    await expectLater(
      Future<void>.sync(
        () => ApiTalkRecordResultsService(api)
            .retryCleanup('r', ifMatch: '"record:7"', idempotencyKey: 'retry'),
      ),
      throwsA(isA<TalkRecordApiException>()),
    );
    expect(api.calls, 0);
  });
}
