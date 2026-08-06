import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/conversation_api.dart';

class _RecordingConversationApi extends ConversationApi {
  final List<Map<String, dynamic>> postCalls = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> getCalls = <Map<String, dynamic>>[];

  IMBoyHttpResponse postResponse = IMBoyHttpResponse.success(
    const <String, dynamic>{},
  );
  IMBoyHttpResponse getResponse = IMBoyHttpResponse.success(
    const <String, dynamic>{},
  );

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    postCalls.add(<String, dynamic>{
      'uri': uri,
      'data': data,
      'queryParameters': queryParameters,
    });
    return postResponse;
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    getCalls.add(<String, dynamic>{
      'uri': uri,
      'queryParameters': queryParameters,
    });
    return getResponse;
  }
}

void main() {
  group('ConversationApi', () {
    test('pin/unpin/delete/restore 应命中正确 endpoint 并规范化 type', () async {
      final api = _RecordingConversationApi();

      await api.pin(conversationId: 'peer-a', type: 'C2C');
      await api.unpin(conversationId: 'group-a', type: 'C2G');
      await api.deleteConversation(conversationId: 'peer-b', type: 'C2C');
      await api.restoreConversation(conversationId: 'group-b', type: 'C2G');

      expect(api.postCalls.length, 4);
      expect(api.postCalls[0]['uri'], API.conversationPin);
      expect(api.postCalls[0]['data'], {
        'conversation_id': 'peer-a',
        'type': 'c2c',
      });
      expect(api.postCalls[1]['uri'], API.conversationUnpin);
      expect(api.postCalls[1]['data'], {
        'conversation_id': 'group-a',
        'type': 'c2g',
      });
      expect(api.postCalls[2]['uri'], API.conversationDelete);
      expect(api.postCalls[2]['data'], {
        'conversation_id': 'peer-b',
        'type': 'c2c',
      });
      expect(api.postCalls[3]['uri'], API.conversationRestore);
      expect(api.postCalls[3]['data'], {
        'conversation_id': 'group-b',
        'type': 'c2g',
      });
    });

    test('pinnedList 应读取 items 包装结构', () async {
      final api = _RecordingConversationApi()
        ..getResponse = IMBoyHttpResponse.success({
          'items': [
            {'conversation_id': 'peer-a', 'conversation_type': 'c2c'},
            {'conversation_id': 'group-a', 'conversation_type': 'c2g'},
          ],
        });

      final result = await api.pinnedList();

      expect(api.getCalls.single['uri'], API.conversationPinned);
      expect(result, hasLength(2));
      expect(result.first['conversation_id'], 'peer-a');
      expect(result.last['conversation_type'], 'c2g');
    });

    test('listMine 应透传 last_server_ts 查询参数', () async {
      final api = _RecordingConversationApi()
        ..getResponse = IMBoyHttpResponse.success({
          'list': [
            {'conversation_id': 'peer-a'},
          ],
        });

      final result = await api.listMine(lastServerTs: 1700000000123);

      expect(api.getCalls.single['uri'], API.conversationList);
      expect(api.getCalls.single['queryParameters'], {
        'last_server_ts': 1700000000123,
      });
      expect(result, hasLength(1));
      expect(result.single['conversation_id'], 'peer-a');
    });
  });
}
