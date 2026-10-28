import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/msg_api.dart';

class _RecordingApi extends MsgApi {
  final queries = <Map<String, dynamic>>[];
  IMBoyHttpResponse response = IMBoyHttpResponse.success(<String, dynamic>{});

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, API.msgHistory);
    queries.add(Map<String, dynamic>.from(queryParameters!));
    return response;
  }
}

void main() {
  test('目标模式走history，保留原始msgId与DID，不传同步游标', () async {
    final api = _RecordingApi();
    final response = await api.historyContext(
      chatType: 'c2g',
      peerId: '2002',
      targetMsgId: 'synthetic_Target-01',
      did: 'synthetic-device',
    );
    expect(response, same(api.response));
    expect(api.queries.single, {
      'chat_type': 'c2g',
      'peer_id': '2002',
      'target_msg_id': 'synthetic_Target-01',
      'limit': 41,
      'did': 'synthetic-device',
    });
  });

  for (final limit in [-10, 0, 101, 999]) {
    test('目标请求limit=$limit限定于1..100，不附加空did', () async {
      final api = _RecordingApi();
      await api.historyContext(
        chatType: 'c2c',
        peerId: '2002',
        targetMsgId: 'target',
        limit: limit,
      );
      expect(api.queries.single['limit'], limit.clamp(1, 100));
      expect(api.queries.single.containsKey('did'), isFalse);
      expect(api.queries.single.containsKey('after_seq'), isFalse);
    });
  }

  test('目标模式完整保留envelope错误code/msg，不能吞成空列表', () async {
    final api = _RecordingApi()
      ..response = IMBoyHttpResponse.failure(
        errCode: 404,
        errMsg: 'history_context_unavailable',
      );
    final response = await api.historyContext(
      chatType: 'c2c',
      peerId: '2002',
      targetMsgId: 'target',
    );
    expect(response.ok, isFalse);
    expect(response.code, 404);
    expect(response.msg, 'history_context_unavailable');
  });

  test('旧增量history仍只传after_seq，不带target参数', () async {
    final api = _RecordingApi()
      ..response = IMBoyHttpResponse.success(<String, dynamic>{
        'messages': <Map<String, dynamic>>[],
        'next_seq': 9,
      });
    expect(await api.history(chatType: 'c2c', peerId: '2002', afterSeq: 7), {
      'messages': <Map<String, dynamic>>[],
      'next_seq': 9,
    });
    expect(api.queries.single, {
      'chat_type': 'c2c',
      'peer_id': '2002',
      'after_seq': 7,
      'limit': 50,
    });
  });
}
