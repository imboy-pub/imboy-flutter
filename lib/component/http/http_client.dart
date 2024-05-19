import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

// ignore: implementation_imports
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_exceptions.dart';

import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'http_config.dart';
import 'http_parse.dart';
import 'http_response.dart';
import 'http_transformer.dart';

Future<Map<String, dynamic>> defaultHeaders() async {
  iPrint("appVsnMajor $appVsnMajor");
  return {
    'cos': Platform.operatingSystem, // device_type: iso android macos web
    'cosv': Platform.operatingSystemVersion,
    'vsn': appVsn,
    'did': deviceId,
    'method': 'sha512',
    'tzoffset': DateTime.now().timeZoneOffset.inMilliseconds,
    'sign': EncrypterService.sha512("$deviceId|$appVsnMajor", SOLIDIFIED_KEY)
  };
}

class HttpClient {
  static HttpClient get client => getx.Get.find();
  late Dio _dio;

  HttpClient({BaseOptions? options, HttpConfig? dioConfig}) {
    options ??= BaseOptions(
      baseUrl: dioConfig?.baseUrl ?? "",
      contentType: 'application/json',
      connectTimeout: Duration(
          milliseconds:
              dioConfig?.connectTimeout ?? Duration.millisecondsPerMinute),
      sendTimeout: Duration(
          milliseconds:
              dioConfig?.sendTimeout ?? Duration.millisecondsPerMinute),
      receiveTimeout: Duration(
          milliseconds:
              dioConfig?.receiveTimeout ?? Duration.millisecondsPerMinute),
    )..headers = dioConfig?.headers;

    _dio = Dio(options);

    if (RECORD_LOG) {
      _dio.interceptors.add(LogInterceptor(
          responseBody: true,
          error: true,
          requestHeader: true,
          responseHeader: false,
          request: false,
          requestBody: true));
    }
    if (dioConfig?.interceptors?.isNotEmpty ?? false) {
      _dio.interceptors.addAll(dioConfig!.interceptors!);
    }
    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 10),
        onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
      ),
    );

    if (dioConfig?.proxy?.isNotEmpty ?? false) {
      setProxy(dioConfig!.proxy!);
    }
  }

  setProxy(String proxy) {
    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 10),
        onClientCreate: (_, config) {
          config.onBadCertificate = (_) => true;
          config.proxy = Uri.parse(proxy);
        },
      ),
    );
  }

  Future<void> _setDefaultConfig() async {
    if (_dio.options.baseUrl == "") {
      _dio.options.baseUrl = API_BASE_URL;
    }
    String tk = UserRepoLocal.to.accessToken;
    if (tokenExpired(tk) == false) {
      tk = await (UserProvider()).refreshAccessTokenApi(
          UserRepoLocal.to.refreshToken,
          checkNewToken: false);
    }
    bool notRTK = !_dio.options.headers.containsKey(Keys.refreshTokenKey);
    if (strNoEmpty(tk) && notRTK) {
      _dio.options.headers[Keys.tokenKey] = tk;
    }
    Map<String, dynamic> headers = await defaultHeaders();
    iPrint("_setDefaultConfig headers: ${headers.toString()}");
    _dio.options.headers.addAll(headers);
  }

  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    try {
      _setDefaultConfig();
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return handleException(NetworkException());
      }
      var response = await _dio.get(
        uri,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      iPrint("http_client/get/resp ${response.toString()}");
      IMBoyHttpResponse resp = handleResponse(
        response,
        httpTransformer: httpTransformer,
      );
      if (resp.code == 707) {
        response = await _dio.get(
          uri,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
        resp = handleResponse(
          response,
          httpTransformer: httpTransformer,
        );
      }
      return resp;
    } on Exception catch (e) {
      debugPrint("> on Exception: $e");
      return handleException(e);
    }
  }

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
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      EasyLoading.showError('network_exception'.tr);
      return handleException(NetworkException());
    }
    try {
      await _setDefaultConfig();
      var response = await _dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      // debugPrint("http_post response ${response.toString()}");
      IMBoyHttpResponse resp = handleResponse(
        response,
        httpTransformer: httpTransformer,
      );
      return resp;
    } on Exception catch (e) {
      debugPrint("http_post e ${e.toString()}");
      return handleException(e);
    }
  }

  Future<IMBoyHttpResponse> delete(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      EasyLoading.showError('network_exception'.tr);
      return handleException(NetworkException());
    }
    try {
      await _setDefaultConfig();
      var response = await _dio.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      IMBoyHttpResponse resp = handleResponse(
        response,
        httpTransformer: httpTransformer,
      );
      return resp;
    } on Exception catch (e) {
      return handleException(e);
    }
  }

  Future<IMBoyHttpResponse> patch(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      EasyLoading.showError('network_exception'.tr);
      return handleException(NetworkException());
    }
    try {
      await _setDefaultConfig();
      var response = await _dio.patch(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return handleResponse(response, httpTransformer: httpTransformer);
    } on Exception catch (e) {
      return handleException(e);
    }
  }

  Future<IMBoyHttpResponse> put(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      EasyLoading.showError('network_exception'.tr);
      return handleException(NetworkException());
    }
    try {
      await _setDefaultConfig();
      var response = await _dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return handleResponse(response, httpTransformer: httpTransformer);
    } on Exception catch (e) {
      return handleException(e);
    }
  }

  Future<Response> download(
    String urlPath,
    savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    data,
    Options? options,
    HttpTransformer? httpTransformer,
  }) async {
    try {
      await _setDefaultConfig();
      var response = await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        data: data,
        options: data,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
