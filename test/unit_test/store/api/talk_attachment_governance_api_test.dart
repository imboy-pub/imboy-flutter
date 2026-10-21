import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/attachments/talk_record_attachment_governance_api.dart';
import 'package:imboy/store/api/workspace_api.dart';

Map<String, dynamic> payload() => {
  'organization_id': 100,
  'record_id': 50,
  'attachment_id': 77,
  'revision': 9,
  'hold_state': 'none',
  'purge_state': 'live',
  'retention_until': null,
};

class Client extends HttpClient {
  String? header = '"9"';
  int code = 0;
  Map<String, dynamic> data = payload();
  Options? sent;
  Object? body;
  IMBoyHttpResponse respond(dynamic transformer, String uri) =>
      transformer.parse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: uri),
          headers: Headers.fromMap({
            if (header != null) 'etag': [header!],
          }),
          data: {'code': code, 'msg': 'fixture', 'payload': data},
        ),
        uri,
      ) as IMBoyHttpResponse;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async => respond(httpTransformer, uri);
  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
    httpTransformer,
  }) async {
    sent = options;
    body = data;
    return respond(httpTransformer, uri);
  }
}

void main() {
  test('actual header used even when revision field differs', () async {
    final c = Client()..header = '"12"';
    final api = TalkAttachmentGovernanceApi(client: c);
    final read = await api.read('100', '50', '77');
    expect(read.etag, '"12"');
    await api.mutate(
      '100',
      '50',
      '77',
      etag: read.etag,
      intent: 'explicit-intent',
      body: {'op': 'hold', 'reason': 'review'},
    );
    expect(c.sent?.headers, {
      'If-Match': '"12"',
      'Idempotency-Key': 'explicit-intent',
    });
    expect(c.body, {'op': 'hold', 'reason': 'review'});
  });
  for (final header in <String?>[null, '', '9', 'W/"9"']) {
    test('missing or noncanonical ETag fails closed: $header', () async {
      final c = Client()..header = header;
      await expectLater(
        TalkAttachmentGovernanceApi(client: c).read('100', '50', '77'),
        throwsA(isA<WorkspaceApiException>()),
      );
    });
  }
  test('wrong organization and unknown states fail closed', () async {
    final c = Client()..data = {...payload(), 'organization_id': 200};
    final api = TalkAttachmentGovernanceApi(client: c);
    await expectLater(
      api.read('100', '50', '77'),
      throwsA(isA<WorkspaceApiException>()),
    );
    c.data = {...payload(), 'hold_state': 'unknown'};
    await expectLater(
      api.read('100', '50', '77'),
      throwsA(isA<WorkspaceApiException>()),
    );
  });
  test('version conflict remains 412', () async {
    final c = Client()..code = 412;
    await expectLater(
      TalkAttachmentGovernanceApi(client: c).read('100', '50', '77'),
      throwsA(isA<WorkspaceApiException>().having((e) => e.code, 'code', 412)),
    );
  });
}
