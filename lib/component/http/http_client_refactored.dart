/// HTTP 客户端重构方案
///
/// 基于 DRY 原则，消除 get/post/put/patch/delete 中的重复代码
/// 将公共逻辑抽取到 _request 方法中
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'http_config.dart';
import 'http_parse.dart';
import 'http_response.dart';
import 'http_transformer.dart';
import 'http_retry_interceptor.dart';
// ignore: implementation_imports
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

/// 安全的证书验证回调
bool _certificateValidationCallback(X509Certificate cert) {
  if (currentEnv == 'dev' || currentEnv.startsWith('local')) {
    return true;
  }
  return false;
}

/// 默认请求头
Future<Map<String, dynamic>> defaultHeaders() async {
  String key = await Env.signKey();
  String cos = getOperatingSystem();
  return {
    'cos': cos,
    'vsn': appVsn,
    'pkg': packageName,
    'did': deviceId,
    'tz_offset': DateTime.now().timeZoneOffset.inMilliseconds,
    'method': 'sha512',
    'sk': globalSignKeyVsn,
    'sign': EncrypterService.sha512("$deviceId|$appVsn|$cos|$packageName", key),
  };
}

/// HTTP 方法枚举
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
}

/// 重构后的 HTTP 客户端
///
/// 遵循 DRY 原则，所有 HTTP 方法共享公共逻辑
class HttpClient {
  static HttpClient get client => serviceContainer.get<HttpClient>();
  late Dio _dio;

  /// 是否正在处理登录过期
  static bool _isHandlingLoginExpired = false;

  HttpClient({BaseOptions? options, HttpConfig? conf}) {
    options ??= BaseOptions(
      baseUrl: conf?.baseUrl ?? "",
      contentType: 'application/json',
      validateStatus: (int? status) => status != null,
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

    // 添加重试拦截器
    final retryConfig = currentEnv == 'dev'
        ? HttpRetryConfig.devConfig
        : HttpRetryConfig.prodConfig;
    _dio.interceptors.add(createRetryInterceptor(retryConfig));

    if (recordLog) {
      _dio.interceptors.add(
        LogInterceptor(
          responseBody: true,
          error: true,
          requestHeader: true,
          responseHeader: false,
          request: false,
          requestBody: true,
        ),
      );
    }

    if (conf?.interceptors?.isNotEmpty ?? false) {
      _dio.interceptors.addAll(conf!.interceptors!);
    }

    // Web 平台不使用 Http2Adapter
    if (!kIsWeb) {
      _dio.httpClientAdapter = Http2Adapter(
        ConnectionManager(
          idleTimeout: const Duration(seconds: 10),
          onClientCreate: (_, config) =>
              config.onBadCertificate = _certificateValidationCallback,
        ),
      );
    }

    if (conf?.proxy?.isNotEmpty ?? false) {
      setProxy(conf!.proxy!);
    }
  }

  /// 设置代理
  void setProxy(String proxy) {
    if (kIsWeb) {
      debugPrint("HttpClient: Web 平台不支持代理设置");
      return;
    }

    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 10),
        onClientCreate: (_, config) {
          config.onBadCertificate = _certificateValidationCallback;
          config.proxy = Uri.parse(proxy);
        },
      ),
    );
  }

  /// ==================== 统一请求方法（DRY 原则核心）====================

  /// 统一请求方法
  ///
  /// 所有 HTTP 方法（get/post/put/patch/delete）都调用此方法
  /// 消除重复代码，便于维护和扩展
  Future<IMBoyHttpResponse> _request(
    HttpMethod method,
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
    bool showErrorToast = true,
  }) async {
    // 1. 网络检查
    if (!_checkNetwork()) {
      return handleException(uri, NetworkException(message: t.tipConnectDesc));
    }

    try {
      // 2. 设置默认配置（Token、签名等）
      await _setDefaultConfig();

      // 3. 发送请求
      final response = await _sendRequest(
        method,
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      // 4. 处理响应
      final resp = handleResponse(
        response,
        uri: uri,
        httpTransformer: httpTransformer,
      );

      // 5. 处理认证错误
      _handleAuthError(resp, uri, showErrorToast: showErrorToast);

      return resp;
    } on Exception catch (e) {
      debugPrint("> $uri on Exception: $e");
      return handleException(uri, e);
    }
  }

  /// 发送请求（内部方法）
  Future<Response> _sendRequest(
    HttpMethod method,
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final requestOptions = (options ?? Options()).copyWith(
      method: _methodToString(method),
    );

    return switch (method) {
      HttpMethod.get => await _dio.get(
          uri,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        ),
      HttpMethod.post => await _dio.post(
          uri,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        ),
      HttpMethod.put => await _dio.put(
          uri,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
        ),
      HttpMethod.patch => await _dio.patch(
          uri,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        ),
      HttpMethod.delete => await _dio.delete(
          uri,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
        ),
    };
  }

  /// ==================== 公共 HTTP 方法（简化版）====================

  /// GET 请求
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) {
    return _request(
      HttpMethod.get,
      uri,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      httpTransformer: httpTransformer,
    );
  }

  /// POST 请求
  Future<IMBoyHttpResponse> post(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) {
    return _request(
      HttpMethod.post,
      uri,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      httpTransformer: httpTransformer,
    );
  }

  /// PUT 请求
  Future<IMBoyHttpResponse> put(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) {
    return _request(
      HttpMethod.put,
      uri,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      httpTransformer: httpTransformer,
    );
  }

  /// PATCH 请求
  Future<IMBoyHttpResponse> patch(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) {
    return _request(
      HttpMethod.patch,
      uri,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      httpTransformer: httpTransformer,
    );
  }

  /// DELETE 请求
  Future<IMBoyHttpResponse> delete(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) {
    return _request(
      HttpMethod.delete,
      uri,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      httpTransformer: httpTransformer,
      showErrorToast: true,
    );
  }

  /// ==================== 辅助方法 ====================

  /// 检查网络状态
  bool _checkNetwork() {
    return !serviceContainer.isRegistered<NetworkMonitorService>() ||
        NetworkMonitorService.to.hasNetwork;
  }

  /// 处理认证错误
  void _handleAuthError(
    IMBoyHttpResponse resp,
    String uri, {
    bool showErrorToast = true,
  }) {
    if (ErrorCode.shouldReLogin(resp.code)) {
      UserRepoLocal.to.quitLogin();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
    } else if (resp.code == ErrorCode.TOKEN_EXPIRED) {
      if (showErrorToast) {
        EasyLoading.showInfo(resp.msg);
      }
      // Token 过期处理逻辑可以在这里添加
    }
  }

  /// HTTP 方法转换为字符串
  String _methodToString(HttpMethod method) {
    return switch (method) {
      HttpMethod.get => 'GET',
      HttpMethod.post => 'POST',
      HttpMethod.put => 'PUT',
      HttpMethod.patch => 'PATCH',
      HttpMethod.delete => 'DELETE',
    };
  }

  /// 设置默认配置
  Future<void> _setDefaultConfig() async {
    if (_dio.options.baseUrl == "") {
      _dio.options.baseUrl = Env().apiBaseUrl;
    }

    // 检查令牌解密失败
    if (UserRepoLocal.to.hasTokenDecryptionFailure) {
      debugPrint("_setDefaultConfig: 检测到令牌解密失败");
      await _handleTokenDecryptionFailure();
      return;
    }

    // 检查 Token
    String tk = await UserRepoLocal.to.accessToken;
    final isLoggedIn = UserRepoLocal.to.isLoggedIn;

    if (isLoggedIn && strEmpty(tk)) {
      debugPrint("_setDefaultConfig: Token 为空，触发重新登录");
      await _handleTokenExpired();
      return;
    }

    // 刷新 Token
    if (tokenExpired(tk) == false) {
      String rtk = await UserRepoLocal.to.refreshToken;
      if (rtk.isNotEmpty) {
        tk = await UserApi.to.refreshAccessTokenApi(rtk, checkNewToken: false);
      }
    }

    // 设置 Token
    bool notRTK = !_dio.options.headers.containsKey(Keys.refreshTokenKey);
    if (strNoEmpty(tk) && notRTK) {
      _dio.options.headers[Keys.tokenKey] = tk;
    }

    // 设置默认请求头
    Map<String, dynamic> headers = await defaultHeaders();
    _dio.options.headers.addAll(headers);
  }

  /// 处理 Token 过期
  Future<void> _handleTokenExpired() async {
    if (_isHandlingLoginExpired) return;

    _isHandlingLoginExpired = true;
    try {
      await UserRepoLocal.to.quitLogin();

      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null && context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.loginExpiredMessage),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await Future.delayed(const Duration(seconds: 1));
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isHandlingLoginExpired = false;
      });
    }
  }

  /// 处理令牌解密失败
  Future<void> _handleTokenDecryptionFailure() async {
    UserRepoLocal.to.clearTokenDecryptionFailureFlag();
    await UserRepoLocal.to.quitLogin();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.signIn,
      (route) => false,
    );
  }

  /// 下载文件
  Future<Response> download(
    String urlPath,
    savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    dynamic data,
    Options? options,
    HttpTransformer? httpTransformer,
  }) async {
    try {
      await _setDefaultConfig();
      return await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        data: data,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }
}
