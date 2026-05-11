import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/user_collect_api.dart';

class _FakeUserCollectApi extends UserCollectApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  Options? lastOptions;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'GET';
    lastUri = uri;
    lastQuery = queryParameters;
    lastOptions = options;
    return nextResponse;
  }

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
    lastQuery = queryParameters;
    lastOptions = options;
    return nextResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserCollectApi', () {
    test('page should request API.userCollectPage and return payload on success', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'items': [
          {'kind_id': 'a1'}
        ],
        'total': 1,
      });

      final result = await api.page({'page': 2, 'size': 10, 'kind': 3});

      expect(result, isNotNull);
      expect(result?['total'], 1);
      expect(api.lastMethod, 'GET');
      expect(api.lastUri, API.userCollectPage);
      expect(api.lastQuery, {'page': 2, 'size': 10, 'kind': 3});
    });

    test('page should return null on failure', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.failure(errCode: 500, errMsg: 'failed');

      final result = await api.page({'page': 1});

      expect(result, isNull);
      expect(api.lastUri, API.userCollectPage);
    });

    test('remove should post kind_id and return true', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.remove(kindId: 'k100');

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, API.userCollectRemove);
      expect(api.lastData, {'kind_id': 'k100'});
    });

    test('remove should return false when response is not ok', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.failure(errCode: 500, errMsg: 'failed');

      final ok = await api.remove(kindId: 'k100');

      expect(ok, isFalse);
      expect(api.lastUri, API.userCollectRemove);
    });

    test('change should post data and return true', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.change({'kind_id': 'k100', 'remark': 'todo'});

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, API.userCollectChange);
      expect(api.lastData, {'kind_id': 'k100', 'remark': 'todo'});
    });

    test('change should return false on failure', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.failure(errCode: 500, errMsg: 'failed');

      final ok = await api.change({'kind_id': 'k100', 'remark': 'todo'});

      expect(ok, isFalse);
      expect(api.lastUri, API.userCollectChange);
    });

    test('add should post kind payload and set 5 minute timeouts', () async {
      final api = _FakeUserCollectApi();
      api.nextResponse = IMBoyHttpResponse.success({'id': 'c1'});

      final ok = await api.add(2, 'kind_2', 'chat', {'text': 'hello'});

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, API.userCollectAdd);
      expect(api.lastData, {
        'kind': 2,
        'kind_id': 'kind_2',
        'source': 'chat',
        'info': {'text': 'hello'},
      });
      expect(api.lastOptions, isNotNull);
      expect(api.lastOptions?.sendTimeout, const Duration(minutes: 5));
      expect(api.lastOptions?.receiveTimeout, const Duration(minutes: 5));
    });
  });
}
