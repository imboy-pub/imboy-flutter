import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart' as http;
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/channel_api.dart';

class _Api extends ChannelApi {
  _Api(this.response);
  final IMBoyHttpResponse response;
  String? path;
  Map<String, dynamic>? query;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    path = uri;
    query = queryParameters;
    return response;
  }
}

void main() {
  group('订阅者失败与正常空页分离', () {
    for (final code in [403, 503]) {
      test('非成功响应 $code 不返回空列表', () async {
        final api = _Api(
          IMBoyHttpResponse.failure(errCode: code, errMsg: 'unavailable'),
        );
        await expectLater(
          api.getSubscribers(channelId: '12', cursor: 30, limit: 30),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'channel_subscribers_request_failed',
            ),
          ),
        );
      });
    }
    test('成功码但缺失payload仍为失败', () async {
      final api = _Api(IMBoyHttpResponse.success(null));
      await expectLater(api.getSubscribers(channelId: '12'), throwsStateError);
    });
    test('真实成功空列表保持末页含义和原cursor参数', () async {
      final api = _Api(IMBoyHttpResponse.success({'list': <dynamic>[]}));
      expect(
        await api.getSubscribers(channelId: '12', cursor: 30, limit: 30),
        isEmpty,
      );
      expect(api.path, '/api/v1/channel/12/subscribers');
      expect(api.query, {'cursor': 30, 'limit': 30});
    });
  });

  for (final code in [1, 403, 404, 503]) {
    test('详情失败保留服务端状态 $code', () async {
      final api = _Api(
        IMBoyHttpResponse.failure(errCode: code, errMsg: 'unavailable'),
      );
      await expectLater(
        api.getChannelChecked('12'),
        throwsA(isA<http.HttpException>().having((e) => e.code, 'code', code)),
      );
    });
  }
  test('自定义地址成功解析并使用对应入口', () async {
    final api = _Api(IMBoyHttpResponse.success({'id': 12, 'name': 'test'}));
    expect((await api.getChannelByCustomIdChecked('news')).id, '12');
    expect(api.path, '/api/v1/channel/by_custom_id/news');
  });
  for (final payload in [null, <String, dynamic>{}, 'invalid']) {
    test('成功状态但无效 payload 不伪装成频道: $payload', () async {
      final api = _Api(IMBoyHttpResponse.success(payload));
      await expectLater(api.getChannelChecked('12'), throwsFormatException);
    });
  }
  test('网络异常保留原有异常类型', () async {
    final api = _Api(
      IMBoyHttpResponse.failureFromError(
        error: http.NetworkException(message: 'offline'),
      ),
    );
    await expectLater(
      api.getChannelChecked('12'),
      throwsA(isA<http.NetworkException>()),
    );
  });
}
