import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/rtc_room_api.dart';

class _FakeRtcRoomApi extends RtcRoomApi {
  String? lastUri;
  dynamic lastData;
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
    lastUri = uri;
    lastData = data;
    return nextResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RtcRoomApi.joinRoom', () {
    test('posts kind/target_id/did and maps payload to camelCase', () async {
      final api = _FakeRtcRoomApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'ws_url': 'wss://rtc.example.com',
        'token': 'jwt-token',
        'room_name': 'rtc_group_123',
      });

      final result = await api.joinRoom(
        kind: 'group',
        targetId: '123',
        did: 'device-1',
      );

      expect(api.lastUri, API.rtcRoomJoin);
      expect(api.lastData, {
        'kind': 'group',
        'target_id': 123,
        'did': 'device-1',
      });
      expect(result, {
        'wsUrl': 'wss://rtc.example.com',
        'token': 'jwt-token',
        'roomName': 'rtc_group_123',
      });
    });

    test('omits did when not provided', () async {
      final api = _FakeRtcRoomApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'ws_url': 'wss://x',
        'token': 't',
        'room_name': 'r',
      });

      await api.joinRoom(kind: 'c2c', targetId: '42');

      expect(api.lastData, {'kind': 'c2c', 'target_id': 42});
    });

    test('returns null on business failure', () async {
      final api = _FakeRtcRoomApi();
      api.nextResponse = IMBoyHttpResponse.failure(
        errCode: 403,
        errMsg: 'not a member',
      );

      final result = await api.joinRoom(kind: 'group', targetId: '123');

      expect(result, isNull);
    });

    test('returns null when payload misses ws_url or token', () async {
      final api = _FakeRtcRoomApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'room_name': 'rtc_group_123',
      });

      final result = await api.joinRoom(kind: 'group', targetId: '123');

      expect(result, isNull);
    });

    test('returns null for non-numeric targetId without requesting', () async {
      final api = _FakeRtcRoomApi();

      final result = await api.joinRoom(kind: 'group', targetId: 'abc');

      expect(result, isNull);
      expect(api.lastUri, isNull);
    });
  });
}
