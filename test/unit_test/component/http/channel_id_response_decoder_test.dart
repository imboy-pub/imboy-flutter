import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/html') {
      return ResponseBody.fromString(
        '<html>bad gateway</html>',
        502,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }
    if (options.path == '/empty') {
      return ResponseBody.fromString(
        '',
        204,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"payload":{"id":9007199254740993,"timestamp":12}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Dio applies decoder only when explicitly requested', () async {
    final dio = Dio()..httpClientAdapter = _Adapter();
    final enabled = await dio.get<dynamic>(
      '/channel/1',
      options: Options(
        responseDecoder: channelIdResponseDecoder(ChannelResponseShape.detail),
      ),
    );
    expect(enabled.data['payload']['id'], '9007199254740993');
    expect(enabled.data['payload']['timestamp'], 12);
    final normal = await dio.get<dynamic>('/channel/1');
    expect(normal.data['payload']['id'], isA<num>());
  });
  test('non JSON HTTP errors and empty JSON retain Dio behavior', () async {
    final dio = Dio()..httpClientAdapter = _Adapter();
    final options = Options(
      responseDecoder: channelIdResponseDecoder(ChannelResponseShape.detail),
    );
    await expectLater(
      dio.get<dynamic>('/html', options: options),
      throwsA(
        isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 502)
            .having(
              (e) => e.response?.data,
              'body',
              '<html>bad gateway</html>',
            ),
      ),
    );
    final ordinary = await dio.get<dynamic>('/empty');
    final optedIn = await dio.get<dynamic>('/empty', options: options);
    expect(optedIn.statusCode, 204);
    expect(optedIn.data, ordinary.data);
  });
  test('detail preserves only the channel ID token', () {
    const raw =
        '{"payload":{"id":9007199254740993,"timestamp":9007199254740993,"nested":{"id":42},"message_id":123,"amount":2.5,"text":"9007199254740993"}}';
    final result = jsonDecode(
      rewriteChannelIds(raw, ChannelResponseShape.detail),
    );
    expect(result['payload']['id'], '9007199254740993');
    expect(result['payload']['timestamp'], jsonDecode('9007199254740993'));
    expect(result['payload']['nested']['id'], 42);
    // detail 形状键表包含 message_id：payload 顶层 message_id 属于
    // 改写范围（与 socket 形状一致），字符串才是契约；嵌套与范围外
    // 字段保持原生 JSON 语义。
    expect(result['payload']['message_id'], '123');
    expect(result['payload']['amount'], 2.5);
    expect(result['payload']['text'], '9007199254740993');
  });

  test('channel creator IDs retain exact decimal digits', () {
    final detail = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"id":1,"creator_uid":9007199254740993}}',
        ChannelResponseShape.detail,
      ),
    );
    final list = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"list":[{"id":1,"creator_id":9007199254740993}]}}',
        ChannelResponseShape.subscribed,
      ),
    );
    expect(detail['payload']['creator_uid'], '9007199254740993');
    expect(list['payload']['list'][0]['creator_id'], '9007199254740993');
  });

  test('preserves receipt, workspace and discussion identities', () {
    final detail = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"channel_id":9007199254740993,"workspace_id":9007199254740995,"discussion_group_id":9007199254740997}}',
        ChannelResponseShape.detail,
      ),
    );
    expect(detail['payload']['channel_id'], '9007199254740993');
    expect(detail['payload']['workspace_id'], '9007199254740995');
    expect(detail['payload']['discussion_group_id'], '9007199254740997');
  });

  test('workspace pagination preserves identity and numeric cursor', () {
    final value = jsonDecode(
      rewriteChannelIds(
        '{"payload":{"workspace_id":9007199254740993,"next_cursor":9007199254740995,"list":[{"id":9007199254740995,"workspace_id":9007199254740993}]}}',
        ChannelResponseShape.workspace,
      ),
    );
    expect(value['payload']['workspace_id'], '9007199254740993');
    expect(value['payload']['next_cursor'], '9007199254740995');
    expect(value['payload']['list'][0]['id'], '9007199254740995');
  });

  test('channel socket preserves identities without changing content', () {
    final data = jsonDecode(
      rewriteChannelIds(
        '{"action":"channel_message","payload":{"id":9007199254740993,"channel_id":9007199254740995,"author_id":9007199254740997,"content":"9007199254740993","channel":{"id":9007199254740995}}}',
        ChannelResponseShape.socket,
      ),
    );
    expect(data['payload']['id'], '9007199254740993');
    expect(data['payload']['channel_id'], '9007199254740995');
    expect(data['payload']['author_id'], '9007199254740997');
    expect(data['payload']['channel']['id'], '9007199254740995');
    expect(data['payload']['content'], '9007199254740993');
  });

  test('subscription list preserves boundaries and already quoted IDs', () {
    const raw =
        '{"payload":{"list":[{"id":9007199254740991},{"id":9007199254740992},{"id":9007199254740993},{"id":9223372036854775807},{"id":"123"}],"cursor":9007199254740991}}';
    final result = jsonDecode(
      rewriteChannelIds(raw, ChannelResponseShape.subscribed),
    );
    expect((result['payload']['list'] as List).map((e) => e['id']), [
      '9007199254740991',
      '9007199254740992',
      '9007199254740993',
      '9223372036854775807',
      '123',
    ]);
    expect(result['payload']['cursor'], jsonDecode('9007199254740991'));
  });

  test('escaped keys, invalid JSON and noninteger IDs', () {
    final result = jsonDecode(
      rewriteChannelIds(
        r'{"payload":{"\u0069d":12.5}}',
        ChannelResponseShape.detail,
      ),
    );
    expect(result['payload']['id'], 12.5);
    expect(
      () => rewriteChannelIds('{"payload":', ChannelResponseShape.detail),
      throwsFormatException,
    );
  });
}
