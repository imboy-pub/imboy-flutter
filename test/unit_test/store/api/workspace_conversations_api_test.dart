import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
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

class _ReadApi extends WorkspaceApi {
  final batches = <List<String>>[];
  Future<void> Function()? afterPost;
  IMBoyHttpResponse reply = IMBoyHttpResponse.success({'read_seq': 2});
  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/groups/123/read');
    batches.add(List<String>.from((data as Map)['msg_ids'] as List));
    await afterPost?.call();
    return reply;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: 'A'});
    await StorageService.init();
  });
  test(
    'read cursor batches actual opaque IDs and propagates rejected reads',
    () async {
      final api = _ReadApi();
      final ids = List.generate(201, (i) => 'message-$i');
      await api.markGroupRead('123', [...ids, ids.first], owner: 'A');
      expect(api.batches.map((b) => b.length), [200, 1]);
      expect(api.batches.expand((b) => b), ids);
      api.reply = IMBoyHttpResponse.failure(
        errCode: 404,
        errMsg: 'not authorized',
      );
      await expectLater(
        api.markGroupRead('123', ['opaque-message'], owner: 'A'),
        throwsA(
          isA<WorkspaceApiException>().having((e) => e.code, 'code', 404),
        ),
      );
    },
  );

  test(
    'read batches stop on account change and reject a stale owner',
    () async {
      final api = _ReadApi();
      api.afterPost = () async {
        await StorageService.to.setString(Keys.currentUid, 'B');
      };
      await expectLater(
        api.markGroupRead('123', List.generate(201, (i) => 'm$i'), owner: 'A'),
        throwsA(
          isA<WorkspaceApiException>().having((e) => e.code, 'code', 409),
        ),
      );
      expect(api.batches, hasLength(1));
      await expectLater(
        api.markGroupRead('123', ['old-message'], owner: 'A'),
        throwsA(isA<WorkspaceApiException>()),
      );
      expect(api.batches, hasLength(1));
    },
  );

  test('authorized unread DTO rejects malformed and negative counts', () async {
    expect(
      (await _Api([
        {...messageRow(), 'unread_count': 13},
      ]).conversations('100')).single.unreadCount,
      13,
    );
    for (final count in [-1, 'oops', 1.5, 2147483648]) {
      await expectLater(
        _Api([
          {...messageRow(), 'unread_count': count},
        ]).conversations('100'),
        throwsA(isA<WorkspaceApiException>()),
      );
    }
  });

  test(
    'scoped preview uses current generation contract and returns text',
    () async {
      expect(
        (await _Api([messageRow()]).conversations('100')).single.previewText,
        'current message',
      );
    },
  );
  test('real millisecond server timestamp keeps the preview usable', () async {
    const epoch = 1790931169467;
    for (final value in [epoch, '$epoch']) {
      final row = messageRow();
      (row['latest_message'] as Map)['server_ts'] = value;
      final preview = (await _Api([row]).conversations('100')).single;
      expect(preview.serverTs, epoch);
      expect(preview.previewText, 'current message');
    }
  });
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
      {'server_ts': 1.5},
      {'server_ts': 9999999999999999},
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
