import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart';

class _Api extends WorkspaceApi {
  _Api(this.response);
  final IMBoyHttpResponse response;
  Map<String, dynamic>? filters;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/workspaces/100/attachments');
    filters = queryParameters;
    return response;
  }
}

Map<String, dynamic> _payload() => {
  'workspace_id': 100,
  'next_cursor': null,
  'items': [
    {
      'id': 99,
      'name': 'report.pdf',
      'size': 100,
      'scope': 'group',
      'scope_ref': '200',
    },
  ],
};

void main() {
  test(
    'all combined filters reach the authoritative scoped endpoint',
    () async {
      final api = _Api(IMBoyHttpResponse.success(_payload()));
      final filters = {
        'group_id': '200',
        'user_keyword': 'Alice',
        'from_ms': 1,
        'until_ms': 2,
        'keyword': 'report',
      };
      expect((await api.attachments('100', filters))['items'], isNotEmpty);
      expect(api.filters, filters);
    },
  );
  test('denied searches preserve the server error', () async {
    final api = _Api(IMBoyHttpResponse.failure(errCode: 403, errMsg: 'denied'));
    await expectLater(
      api.attachments('100', {}),
      throwsA(isA<WorkspaceApiException>()),
    );
  });
  for (final entry in <String, Map<String, dynamic>>{
    'wrong workspace': {..._payload(), 'workspace_id': 200},
    'invalid rows': {
      ..._payload(),
      'items': ['invalid'],
    },
    'storage key leakage': {
      ..._payload(),
      'items': [
        {
          ...((_payload()['items'] as List).single as Map<String, dynamic>),
          'path': 'private/key',
        },
      ],
    },
    'cursor does not advance': {..._payload(), 'next_cursor': 100},
  }.entries) {
    test('rejects ${entry.key}', () async {
      final api = _Api(IMBoyHttpResponse.success(entry.value));
      await expectLater(
        api.attachments('100', {'cursor': '100'}),
        throwsA(isA<WorkspaceApiException>()),
      );
    });
  }
}
