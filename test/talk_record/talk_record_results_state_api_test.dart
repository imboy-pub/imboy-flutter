import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_service.dart';
import 'package:imboy/store/api/talk_record_api.dart';

class _Client extends TalkRecordApi {
  String exportStatus = 'queued';
  int? pollError;
  bool failPost = false;
  final keys = <String>[];
  String? lastUri;

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
    if (uri.endsWith('/transfer-candidates')) {
      return IMBoyHttpResponse.success({
        'list': <Object>[],
        'next_cursor': null,
      });
    }
    if (uri.contains('/exports/')) {
      if (pollError case final code?) {
        return IMBoyHttpResponse.failure(errCode: code, errMsg: 'synthetic');
      }
      return IMBoyHttpResponse.success({
        'export_id': 'e',
        'format': 'txt',
        'state': exportStatus,
      });
    }
    return IMBoyHttpResponse.success({
      'id': 'r',
      'revision': 1,
      'capabilities_for_actor': {'export': true},
    });
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
    keys.add(options!.headers!['Idempotency-Key'] as String);
    if (failPost) throw StateError('synthetic response loss');
    return IMBoyHttpResponse.success({'export_id': 'e', 'state': 'queued'});
  }
}

Future<(ProviderContainer, TalkRecordExportCenterNotifier)> _bound(
  _Client api,
) async {
  final c = ProviderContainer(
    overrides: [
      talkRecordResultsServiceProvider.overrideWithValue(
        ApiTalkRecordResultsService(api),
      ),
    ],
  );
  final n = c.read(talkRecordExportCenterProvider.notifier);
  await n.bind('r');
  n.setIndependentCopyAcked(true);
  return (c, n);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in ['queued', 'ready', 'failed', 'expired']) {
    test('real API notifier preserves poll terminal $status', () async {
      final api = _Client()..exportStatus = status;
      final (c, n) = await _bound(api);
      addTearDown(c.dispose);
      await n.createExport();
      await n.refreshExportState();
      expect(c.read(talkRecordExportCenterProvider).artifactPhase.name, status);
    });
  }
  for (final code in [403, 404, 410, 503, 5554, 5555]) {
    test('poll error $code cannot remain queued or become ready', () async {
      final api = _Client()..pollError = code;
      final (c, n) = await _bound(api);
      addTearDown(c.dispose);
      await n.createExport();
      await n.refreshExportState();
      final s = c.read(talkRecordExportCenterProvider);
      expect(
        s.artifactPhase,
        (code == 410 || code == 5554)
            ? TalkRecordExportArtifactPhase.expired
            : TalkRecordExportArtifactPhase.failed,
      );
      if (code == 403 || code == 404 || code == 5555) {
        expect(s.phase, TalkRecordExportPhase.noAccess);
      }
    });
  }
  test(
    'response loss retry keeps UUID; deliberate regeneration replaces it',
    () async {
      final api = _Client()..failPost = true;
      final (c, n) = await _bound(api);
      addTearDown(c.dispose);
      await n.createExport();
      api.failPost = false;
      await n.createExport();
      expect(api.keys[0], api.keys[1]);
      expect(
        api.keys.first,
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
      n.prepareRegenerate();
      await n.createExport();
      expect(api.keys[2], isNot(api.keys[0]));
    },
  );
  test('known server failure starts a new generation UUID', () async {
    final api = _Client()..exportStatus = 'failed';
    final (c, n) = await _bound(api);
    addTearDown(c.dispose);
    await n.createExport();
    await n.refreshExportState();
    await n.createExport();
    expect(api.keys[1], isNot(api.keys[0]));
  });
  test('ownership candidates use dedicated endpoint', () async {
    final api = _Client();
    await ApiTalkRecordResultsService(api).transferCandidates('r');
    expect(api.lastUri, '/api/v1/talk-records/r/transfer-candidates');
  });
}
