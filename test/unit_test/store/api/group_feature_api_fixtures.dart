part of 'group_feature_api_id_compat_test.dart';

class _FakeGroupScheduleApi extends GroupScheduleApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

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
    return nextResponse;
  }
}

class _FakeGroupTaskApi extends GroupTaskApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

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
    return nextResponse;
  }
}

class _FakeGroupFileApi extends GroupFileApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

  /// 按 URI 分发响应（direct 会话 register/declare/grant/finalize 与 bind
  /// 各返回不同信封，nextResponse 单值不够用）。
  IMBoyHttpResponse Function(String uri, dynamic data)? postHandler;

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
    return postHandler?.call(uri, data) ?? nextResponse;
  }
}

class _FakeGroupAlbumApi extends GroupAlbumApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

  /// 按 URI 分发响应（direct 会话与 bind_batch 信封不同）。
  IMBoyHttpResponse Function(String uri, dynamic data)? postHandler;

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
    return postHandler?.call(uri, data) ?? nextResponse;
  }
}
