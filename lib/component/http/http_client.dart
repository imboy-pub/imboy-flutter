import 'dart:io';

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
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/service/network_monitor.dart';

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

  void setProxy(String proxy) {
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
      _dio.options.baseUrl = Env().apiBaseUrl;
    }

    // 检查是否存在令牌解密失败标记，如果有则触发重新登录
    if (UserRepoLocal.to.hasTokenDecryptionFailure) {
      debugPrint("_setDefaultConfig: 检测到令牌解密失败，触发重新登录流程");
      await _handleTokenDecryptionFailure();
      return;
    }

    String tk = await UserRepoLocal.to.accessToken;
    // iPrint("_setDefaultConfig tk: $tk");
    if (tokenExpired(tk) == false) {
      String rtk = await UserRepoLocal.to.refreshToken;
      // 防御性检查：refresh token 为空时不尝试刷新
      if (rtk.isNotEmpty) {
        tk = await (UserProvider())
            .refreshAccessTokenApi(rtk, checkNewToken: false);
      } else {
        debugPrint("_setDefaultConfig: refresh token 为空，跳过刷新");
      }
    }
    bool notRTK = !_dio.options.headers.containsKey(Keys.refreshTokenKey);
    if (strNoEmpty(tk) && notRTK) {
      _dio.options.headers[Keys.tokenKey] = tk;
    }
    Map<String, dynamic> headers = await defaultHeaders();
    iPrint("_setDefaultConfig headers: ${headers.toString()}");
    _dio.options.headers.addAll(headers);
  }

  /// 处理令牌解密失败的后续流程
  Future<void> _handleTokenDecryptionFailure() async {
    debugPrint("_handleTokenDecryptionFailure: 开始清理并触发重新登录");
    // 清除失败标记
    UserRepoLocal.to.clearTokenDecryptionFailureFlag();
    // 执行登出操作
    await UserRepoLocal.to.quitLogin();
    // 跳转到登录页
    getx.Get.offAll(() => const LoginPage());
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
      // 使用 NetworkMonitorService 检查网络状态（确保服务已注册）
      if (getx.Get.isRegistered<NetworkMonitorService>() && !NetworkMonitorService.to.hasNetwork) {
        return handleException(
          uri,
          NetworkException(message: 'tipConnectDesc'.tr),
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
      if (resp.code == 706) {
        UserRepoLocal.to.quitLogin();
        getx.Get.offAll(() => const LoginPage());
      } else if (resp.code == 707) {
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
    // 使用 NetworkMonitorService 检查网络状态（确保服务已注册）
    if (getx.Get.isRegistered<NetworkMonitorService>() && !NetworkMonitorService.to.hasNetwork) {
      // EasyLoading.showError('tipConnectDesc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tipConnectDesc'.tr),
      );
    }
    try {
      debugPrint("http_post $uri request ${queryParameters.toString()}");
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
      debugPrint("http_post response ${response.toString()}");
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
    // 使用 NetworkMonitorService 检查网络状态（确保服务已注册）
    if (getx.Get.isRegistered<NetworkMonitorService>() && !NetworkMonitorService.to.hasNetwork) {
      EasyLoading.showError('tipConnectDesc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tipConnectDesc'.tr),
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
    // 使用 NetworkMonitorService 检查网络状态（确保服务已注册）
    if (getx.Get.isRegistered<NetworkMonitorService>() && !NetworkMonitorService.to.hasNetwork) {
      EasyLoading.showError('tipConnectDesc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tipConnectDesc'.tr),
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
    // 使用 NetworkMonitorService 检查网络状态（确保服务已注册）
    if (getx.Get.isRegistered<NetworkMonitorService>() && !NetworkMonitorService.to.hasNetwork) {
      EasyLoading.showError('tipConnectDesc'.tr);
      return handleException(
        uri,
        NetworkException(message: 'tipConnectDesc'.tr),
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
