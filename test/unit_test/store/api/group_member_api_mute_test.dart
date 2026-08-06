/// 钉住 `GroupMemberApi.mute` 的前端入参契约。
///
/// 背景：后端 `group_member_handler.erl` 在 `Duration =< 0` 时直接返回
/// `"禁言时长必须大于0"` 错误 —— 因此「duration=0 表示取消禁言」的旧注释是错的。
/// 取消禁言需要单独的后端 action（待后续切片），本切片只做前端防呆。
///
/// 契约：
///   1. duration <= 0 → 抛 `ArgumentError`，不发任何网络请求
///   2. duration > 0 → POST `API.groupMemberMute`，body 为 {gid, user_id, duration}
///   3. 服务端返回 ok=true → 方法返回 true
///   4. 服务端返回 ok=false → 方法返回 false
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/group_member_api.dart';

class _FakeGroupMemberApi extends GroupMemberApi {
  String? lastMethod;
  String? lastUri;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
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
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'POST';
    lastUri = uri;
    lastData = data;
    return nextResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroupMemberApi.mute 入参校验', () {
    test('duration = 0 → 抛 ArgumentError，不发请求', () async {
      final api = _FakeGroupMemberApi();

      expect(
        () => api.mute(gid: 'g1', userId: 'u1', duration: 0),
        throwsA(isA<ArgumentError>()),
      );

      expect(api.requestCount, 0);
    });

    test('duration < 0 → 抛 ArgumentError，不发请求', () async {
      final api = _FakeGroupMemberApi();

      expect(
        () => api.mute(gid: 'g1', userId: 'u1', duration: -60),
        throwsA(isA<ArgumentError>()),
      );

      expect(api.requestCount, 0);
    });

    test('duration > 0 → POST 到 API.groupMemberMute 且 body 正确', () async {
      final api = _FakeGroupMemberApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.mute(gid: 'g-42', userId: 'u-7', duration: 600);

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, API.groupMemberMute);
      expect(api.lastData, {'gid': 'g-42', 'user_id': 'u-7', 'duration': 600});
    });

    test('后端返回失败 → 方法返回 false（不抛异常）', () async {
      final api = _FakeGroupMemberApi();
      api.nextResponse = IMBoyHttpResponse.failure(
        errCode: 500,
        errMsg: 'server error',
      );

      final ok = await api.mute(gid: 'g1', userId: 'u1', duration: 60);

      expect(ok, isFalse);
      expect(api.requestCount, 1);
    });
  });
}
