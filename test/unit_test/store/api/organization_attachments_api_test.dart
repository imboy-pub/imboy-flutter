import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart';

class _Api extends WorkspaceApi {
  _Api(this.payload);
  final Map<String, dynamic> payload;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/organizations/100/attachments');
    expect(queryParameters?['source'], 'talk_record');
    return IMBoyHttpResponse.success(payload);
  }
}

Map<String, dynamic> _row() => {
  'id': 10,
  'name': 'record.aac',
  'size': 42,
  'scope': 'talk_record',
  'scope_ref': '50',
  'record_id': 50,
  'organization_id': 100,
  'workspace_id': null,
  'open_kind': 'talk_record',
};
Map<String, dynamic> _payload() => {
  'organization_id': 100,
  'workspace_id': null,
  'items': [_row()],
  'next_cursor': null,
};
void main() {
  test('organization record without workspace reaches scoped index', () async {
    final data = await _Api(_payload())
        .organizationAttachments('100', {'source': 'talk_record'});
    expect((data['items'] as List).single['workspace_id'], null);
    expect((data['items'] as List).single['open_kind'], 'talk_record');
  });
  for (final row in [
    {..._row(), 'organization_id': 200},
    {..._row(), 'open_kind': 'url'},
    {..._row(), 'record_id': '0'},
    {..._row(), 'record_id': '51'},
    {..._row(), 'url': 'https://private.invalid'},
    {..._row(), 'path': 'private/key'},
  ]) {
    test(
      'rejects cross-organization or raw read metadata: ${row.keys}',
      () async {
        await expectLater(
          _Api({
            ..._payload(),
            'items': [row],
          }).organizationAttachments('100', {'source': 'talk_record'}),
          throwsA(isA<WorkspaceApiException>()),
        );
      },
    );
  }
}
