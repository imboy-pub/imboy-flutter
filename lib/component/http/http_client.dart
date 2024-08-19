import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

// ignore: implementation_imports
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
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
  String key = await Env.signKey();
  String cos = Platform.operatingSystem;
  return {
    'cos': cos, // device_type: iso android macos web
    'vsn': appVsn,
    'pkg': packageName,
    'did': deviceId,
    'tz_offset': DateTime.now().timeZoneOffset.inMilliseconds,
    'method': 'sha512',
    // signKeyVsn 告知服务端用哪个签名key 不同设备类型签名不一样
    'sk': globalSignKeyVsn,
    'sign': EncrypterService.sha512("$deviceId|$appVsn|$cos|$packageName", key)
  };
}

class HttpClient {
  static HttpClient get client => getx.Get.find();
  late Dio _dio;

  HttpClient({BaseOptions? options, HttpConfig? conf}) {
    options ??= BaseOptions(
      baseUrl: conf?.baseUrl ?? "",
      contentType: 'application/json',
      validateStatus: (int? status) {
        return status != null;
        // return status != null && status >= 200 && status < 300;
      },
      connectTimeout: Duration(
        milliseconds: conf?.connectTimeout ?? Duration.millisecondsPerMinute,
      ),
      sendTimeout: Duration(
        milliseconds: conf?.sendTimeout ?? Duration.millisecondsPerMinute,
      ),
      receiveTimeout: Duration(
        milliseconds: conf?.receiveTimeout ?? Duration.millisecondsPerMinute,
      ),
    )..headers = conf?.headers;

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
    if (conf?.interceptors?.isNotEmpty ?? false) {
      _dio.interceptors.addAll(conf!.interceptors!);
    }
    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 10),
        onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
      ),
    );

    if (conf?.proxy?.isNotEmpty ?? false) {
      setProxy(conf!.proxy!);
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
      _dio.options.baseUrl = Env.apiBaseUrl;
    }
    String tk = await UserRepoLocal.to.accessToken;
    // iPrint("_setDefaultConfig tk: $tk");
    if (tokenExpired(tk) == false) {
      String rtk = await UserRepoLocal.to.refreshToken;
      tk = await (UserProvider())
          .refreshAccessTokenApi(rtk, checkNewToken: false);
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
      await _setDefaultConfig();
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return handleException(
          uri,
          NetworkException(message: 'tip_connect_desc'.tr),
        );
      }
      // iPrint("http_client/get $uri ?   queryParameters ${queryParameters.toString()}");
      var response = await _dio.get(
        uri,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      // iPrint("http_client/get/resp ${response.toString()}");
      IMBoyHttpResponse resp = handleResponse(
        response,
        uri: uri,
        httpTransformer: httpTransformer,
      );
      if (resp.code == 707) {
        EasyLoading.showInfo(resp.msg);
        response = await _dio.get(
          uri,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
        resp = handleResponse(
          response,
          uri: uri,
          httpTransformer: httpTransformer,
        );
      }

      return resp;
    } on Exception catch (e) {
      debugPrint("> $uri on Exception: $e");
      return handleException(uri, e);
    } finally {}
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
      // EasyLoading.showError('tip_connect_desc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tip_connect_desc'.tr),
      );
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
        uri: uri,
        httpTransformer: httpTransformer,
      );
      return resp;
    } on Exception catch (e) {
      debugPrint("$uri http_post e ${e.toString()}");
      return handleException(uri, e);
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
      EasyLoading.showError('tip_connect_desc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tip_connect_desc'.tr),
      );
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
        uri: uri,
        httpTransformer: httpTransformer,
      );
      return resp;
    } on Exception catch (e) {
      return handleException(uri, e);
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
      EasyLoading.showError('tip_connect_desc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tip_connect_desc'.tr),
      );
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
      return handleResponse(response,
          uri: uri, httpTransformer: httpTransformer);
    } on Exception catch (e) {
      return handleException(uri, e);
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
      EasyLoading.showError('tip_connect_desc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tip_connect_desc'.tr),
      );
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
      return handleResponse(response,
          uri: uri, httpTransformer: httpTransformer);
    } on Exception catch (e) {
      return handleException(uri, e);
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
