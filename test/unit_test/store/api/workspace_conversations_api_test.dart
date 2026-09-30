import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';

Map<String, dynamic> messageRow({
  int id = 1,
  String text = 'current message',
}) => {
  'id': id,
  'scope': 'workspace',
  'workspace_id': 100,
  'status': 1,
  'title': 'Group $id',
  'member_start_seq': 3,
  'latest_message': {
    'msg_id': 'msg$id',
    'conv_seq': 4,
    'msg_type': 'text',
    'payload': <String, dynamic>{
      'payload': <String, dynamic>{'text': text},
    },
    'e2ee': null,
    'server_ts': '2026-10-01T00:00:00Z',
    'expire_at': null,
  },
};

class _Api extends WorkspaceApi {
  _Api(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/workspaces/100/groups');
    expect(queryParameters, {
      'member_only': 1,
      'preview': 1,
      'limit': 200,
      'cursor': 0,
    });
    return IMBoyHttpResponse.success({
      'workspace_id': 100,
      'list': rows,
      'has_more': false,
      'next_cursor': 0,
    });
  }
}

void main() {
  test(
    'scoped preview uses current generation contract and returns text',
    () async {
      expect(
        (await _Api([messageRow()]).conversations('100')).single.previewText,
        'current message',
      );
    },
  );
  test('old backend without preview is rejected', () async {
    await expectLater(
      _Api([messageRow()..remove('latest_message')]).conversations('100'),
      throwsA(isA<WorkspaceApiException>()),
    );
  });
  test('pre-join and malformed snapshots never render', () async {
    for (final change in [
      {'conv_seq': 2},
      {'payload': 'raw cache'},
      {'server_ts': 'invalid'},
      {'expire_at': 'invalid'},
      {'msg_id': ''},
    ]) {
      final row = messageRow();
      (row['latest_message'] as Map).addAll(change);
      await expectLater(
        _Api([row]).conversations('100'),
        throwsA(isA<WorkspaceApiException>()),
      );
    }
  });
  test('newly joined group can have no authorized message', () async {
    final row = messageRow()..['latest_message'] = null;
    expect((await _Api([row]).conversations('100')).single.previewText, '');
  });
  test('expired and burn message previews hide text', () {
    final row = messageRow();
    (row['latest_message'] as Map)['expire_at'] = '2000-01-01T00:00:00Z';
    expect(WorkspaceConversationModel.fromJson(row).previewText, '');
    final burn = messageRow();
    (((burn['latest_message'] as Map)['payload'] as Map)['payload']
            as Map)['burn_after'] =
        60;
    expect(WorkspaceConversationModel.fromJson(burn).previewText, '');
  });
  test('ciphertext and revoke cannot expose original text', () {
    final encrypted = messageRow();
    (encrypted['latest_message'] as Map)['e2ee'] = {'ciphertext': 'secret'};
    expect(
      WorkspaceConversationModel.fromJson(encrypted).previewText,
      t.chat.encryptedMessagePlaceholder,
    );
    final revoked = messageRow();
    ((revoked['latest_message'] as Map)['payload'] as Map)['action'] =
        'message_revoke_ack';
    expect(
      WorkspaceConversationModel.fromJson(revoked).previewText,
      t.common.messageRevoked,
    );
  });
}
