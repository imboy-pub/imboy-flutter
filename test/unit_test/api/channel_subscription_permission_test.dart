// test/unit_test/api/channel_subscription_permission_test.dart
//
// 频道订阅/退订权限 mock 层契约测试（V3-26 B4 回归补测）。
// 纯 dart 覆写 HttpClient get/post，零真实网络，可 CI 运行。
// 断言面：订阅成功旅程、越权 403 反例（私有频道需要邀请）、
// 写操作 httpNoAutoRetry 语义、已订阅频道 cursor 分页与 403 反例。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ChannelApi {
  _Api(this.responses);
  final List<IMBoyHttpResponse> responses;
  final postUris = <String>[];
  final postBodies = <Object?>[];
  final postExtras = <Map<dynamic, dynamic>?>[];
  final getParams = <Map<String, dynamic>>[];

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
    expect(uri.startsWith('/api/v1/channel/'), isTrue, reason: uri);
    postUris.add(uri);
    postBodies.add(data);
    postExtras.add(options?.extra);
    return responses.removeAt(0);
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
    expect(uri, '/api/v1/channels/subscribed');
    getParams.add(queryParameters!);
    return responses.removeAt(0);
  }
}

Map<String, dynamic> _channel(int id) => {
  'id': '104603643803863$id',
  'name': 'Channel $id',
  'scope': 'workspace',
};

void main() {
  setUpAll(() async {
    // _subscriptionWriteOptions 读取 UserRepoLocal.currentUid → StorageService。
    // 空 mock（无 currentUid）→ guard 抛 stale-session StateError，
    // 被 subscribe/unsubscribe 的 _showSubscriptionErrorIfCurrent 内层
    // catch 吞掉，不触 EasyLoading——测试只断言 API 层返回语义。
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  group('订阅频道 subscribe', () {
    test('成功旅程：POST subscribe 空 body，返回 true，写操作禁自动重试', () async {
      final api = _Api([IMBoyHttpResponse.success(<String, dynamic>{})]);
      expect(await api.subscribe('104603643803863001'), isTrue);
      expect(api.postUris, ['/api/v1/channel/104603643803863001/subscribe']);
      expect(api.postBodies.single, <String, dynamic>{});
      // 订阅是写操作：必须带 httpNoAutoRetry，失败不自动重发
      expect(api.postExtras.single![httpNoAutoRetry], isTrue);
      expect(api.postExtras.single!.containsKey(httpRequestGuard), isTrue);
    });

    test('越权 403（私有频道需要邀请）：不抛异常，返回 false', () async {
      final api = _Api([
        IMBoyHttpResponse.failure(errCode: 403, errMsg: '私有频道需要邀请'),
      ]);
      expect(await api.subscribe('104603643803863002'), isFalse);
      expect(api.postUris.single.endsWith('/subscribe'), isTrue);
    });

    test('服务端 500：返回 false 不抛，且请求只发一次（不自动重试）', () async {
      final api = _Api([
        IMBoyHttpResponse.failure(errCode: 500, errMsg: 'server error'),
      ]);
      expect(await api.subscribe('104603643803863003'), isFalse);
      expect(api.postUris.length, 1, reason: 'httpNoAutoRetry 下无第二次请求');
    });
  });

  group('退订频道 unsubscribe', () {
    test('成功旅程：POST unsubscribe，返回 true', () async {
      final api = _Api([IMBoyHttpResponse.success(<String, dynamic>{})]);
      expect(await api.unsubscribe('104603643803863004'), isTrue);
      expect(api.postUris, ['/api/v1/channel/104603643803863004/unsubscribe']);
    });

    test('越权 403：返回 false，不抛异常', () async {
      final api = _Api([
        IMBoyHttpResponse.failure(errCode: 403, errMsg: 'forbidden'),
      ]);
      expect(await api.unsubscribe('104603643803863005'), isFalse);
    });
  });

  group('已订阅频道 cursor 分页 getSubscribedChannelsCursorPage', () {
    test('两页消费：首页 has_more 传 next_cursor，末页终止不回落第一页', () async {
      final api = _Api([
        IMBoyHttpResponse.success({
          'list': [_channel(1), _channel(2)],
          'has_more': true,
          'next_cursor': 'tok-2',
        }),
        IMBoyHttpResponse.success({
          'list': <Map<String, dynamic>>[],
          'has_more': false,
          'next_cursor': '',
        }),
      ]);
      final first = await api.getSubscribedChannelsCursorPage(limit: 50);
      expect(first.list.length, 2);
      expect(first.nextCursor, 'tok-2');
      expect(first.hasMore, isTrue);
      expect(api.getParams[0], {'pagination': 'cursor', 'limit': 50});

      final second = await api.getSubscribedChannelsCursorPage(
        token: first.nextCursor,
        limit: 50,
      );
      expect(second.list, isEmpty);
      expect(second.nextCursor, isNull);
      expect(second.hasMore, isFalse);
      expect(api.getParams[1], {
        'pagination': 'cursor',
        'limit': 50,
        'cursor': 'tok-2',
      });
    });

    test('越权 403：throwIfFailed 抛出 code=403，不得压成空列表', () async {
      final api = _Api([
        IMBoyHttpResponse.failure(errCode: 403, errMsg: 'forbidden'),
      ]);
      await expectLater(
        api.getSubscribedChannelsCursorPage(),
        throwsA(isA<HttpException>().having((e) => e.code, 'code', 403)),
      );
    });

    test('无效频道行（id 非法）抛 FormatException，不静默丢弃', () async {
      final api = _Api([
        IMBoyHttpResponse.success({
          'list': [
            {'id': 'not-a-number', 'name': 'bad'},
          ],
          'has_more': false,
        }),
      ]);
      await expectLater(
        api.getSubscribedChannelsCursorPage(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
