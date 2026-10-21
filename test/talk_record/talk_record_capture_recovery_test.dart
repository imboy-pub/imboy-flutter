import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';

class _RecordingApi extends TalkRecordApi {
  String lastMethod = '';
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  Options? lastOptions;
  IMBoyHttpResponse next = IMBoyHttpResponse.success(<String, dynamic>{});

  void _record(
    String method,
    String uri, [
    Map<String, dynamic>? q,
    dynamic d,
  ]) {
    lastMethod = method;
    lastUri = uri;
    lastQuery = q;
    lastData = d;
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    _record('GET', uri, queryParameters);
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
    lastOptions = options;
    _record('POST', uri, queryParameters, data);
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
    _record('PATCH', uri, queryParameters, data);
    return next;
  }
}

Map<String, dynamic> capture() => {
  'capture_id': 7366418340025468940,
  'record_id': 7366418340025468941,
  'device_session_id': 'session',
  'status': 'paused',
  'revision': 3,
  'lease_epoch': 2,
  'lease_until': '2026-10-21T05:00:00Z',
  'last_seen_at': '2026-10-21T04:59:00Z',
  'started_at': '2026-10-21T04:58:00Z',
  'etag': '"3"',
  'last_event_seq': 7,
  'parts': {'confirmed': 2, 'pending': 1, 'last_seq': 2},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('server capture_id, lease and recovery metadata round trip', () {
    final json = capture()
      ..addAll({
        'recovered': true,
        'confirmed_parts': [
          {
            'part_id': 7366418340025468942,
            'seq': 0,
            'upload_status': 'confirmed',
          },
        ],
      });
    final model = TalkRecordCaptureModel.fromJson(json);
    expect(model.id, '7366418340025468940');
    expect(model.recordId, '7366418340025468941');
    expect(model.serverStartedAt, DateTime.utc(2026, 10, 21, 4, 58));
    expect(model.leaseEpoch, 2);
    expect(model.leaseUntil, DateTime.utc(2026, 10, 21, 5));
    expect(model.lastEventSeq, 7);
    expect(model.etag, '"3"');
    expect(model.recovered, isTrue);
    expect(model.confirmedParts.single['seq'], 0);
    expect(model.parts['pending'], 1);
    expect(TalkRecordCaptureModel.fromJson(model.toJson()).leaseEpoch, 2);
    expect(() => model.parts['pending'] = 8, throwsUnsupportedError);
    expect(() => model.confirmedParts.clear(), throwsUnsupportedError);
  });

  test('legacy fixtures remain readable without claiming a current lease', () {
    final model = TalkRecordCaptureModel.fromJson({'id': 'legacy'});
    expect(model.id, 'legacy');
    expect(model.leaseUntil, isNull);
    expect(model.lastEventSeq, -2);
    expect(model.recovered, isFalse);
    expect(model.confirmedParts, isEmpty);
  });

  test('captures GET reads captures envelope rather than list', () async {
    final api = _RecordingApi()
      ..next = IMBoyHttpResponse.success({
        'captures': [capture()],
      });
    final result = await api.captures('record');
    expect(api.lastMethod, 'GET');
    expect(api.lastUri, '/api/v1/talk-records/record/captures');
    expect(result.single.id, '7366418340025468940');
  });

  test(
    'recover sends original device session and preserves confirmation',
    () async {
      final api = _RecordingApi()
        ..next = IMBoyHttpResponse.success(capture()..['recovered'] = true);
      final result = await api.recoverCapture(
        'r',
        'c',
        deviceSessionId: 'original',
      );
      expect(api.lastUri, '/api/v1/talk-records/r/captures/c/recover');
      expect(api.lastData, {'device_session_id': 'original'});
      expect(api.lastOptions, isNull);
      expect(result.recovered, isTrue);
    },
  );

  test('abandon forwards explicit confirmation and capture If-Match', () async {
    final api = _RecordingApi()
      ..next = IMBoyHttpResponse.success(capture()..['abandoned'] = true);
    final result = await api.abandonCapture(
      'r',
      'c',
      confirm: true,
      ifMatch: '"3"',
    );
    expect(api.lastUri, '/api/v1/talk-records/r/captures/c/abandon');
    expect(api.lastData, {'confirm': true});
    expect(api.lastOptions!.headers!['If-Match'], '"3"');
    expect(result.abandoned, isTrue);
    await api.abandonCapture('r', 'c', confirm: false, ifMatch: '"3"');
    expect(api.lastData, {'confirm': false});
  });

  test(
    'recovery permission, fencing and stale revision errors propagate',
    () async {
      for (final code in [403, 409, 412]) {
        final api = _RecordingApi()
          ..next = IMBoyHttpResponse.failure(errCode: code, errMsg: 'denied');
        await expectLater(
          api.recoverCapture('r', 'c', deviceSessionId: 'original'),
          throwsA(isA<TalkRecordApiException>()),
        );
      }
    },
  );
  test('malformed recovery view cannot silently appear empty', () async {
    for (final payload in [
      <String, dynamic>{},
      {
        'captures': [42],
      },
    ]) {
      final api = _RecordingApi()..next = IMBoyHttpResponse.success(payload);
      await expectLater(api.captures('r'), throwsFormatException);
    }
  });
}
