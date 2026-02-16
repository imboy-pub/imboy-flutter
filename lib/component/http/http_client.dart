import 'dart:io';

import 'package:dio/dio.dart';

// ignore: implementation_imports
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
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

import 'http_config.dart';
import 'http_parse.dart';
import 'http_response.dart';
import 'http_transformer.dart';
import 'http_retry_interceptor.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 安全的证书验证回调
/// 生产环境严格验证证书，开发环境允许自签名证书
bool _certificateValidationCallback(X509Certificate cert) {
  // 仅在开发环境接受自签名证书
  if (currentEnv == 'dev' || currentEnv.startsWith('local')) {
    return true;
  }
  // 生产环境进行严格验证
  return false;
}

Future<Map<String, dynamic>> defaultHeaders() async {
  String key = await Env.signKey();
  String cos = getOperatingSystem();
  return {
    'cos': cos, // device_type: iso android macos web
    'vsn': appVsn,
    'pkg': packageName,
    'did': deviceId,
    'tz_offset': DateTime.now().timeZoneOffset.inMilliseconds,
    'method': 'sha512',
    // signKeyVsn 告知服务端用哪个签名key 不同设备类型签名不一样
    'sk': globalSignKeyVsn,
    'sign': EncrypterService.sha512("$deviceId|$appVsn|$cos|$packageName", key),
  };
}

class HttpClient {
  static HttpClient get client => serviceContainer.get<HttpClient>();
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

    // 添加重试拦截器（在日志拦截器之前添加，优先级更高）
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

    // Web 平台使用浏览器默认的 Fetch API，不需要 Http2Adapter
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

  void setProxy(String proxy) {
    // Web 平台不支持代理设置
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

  /// 是否正在处理登录过期（防止重复弹窗）
  static bool _isHandlingLoginExpired = false;

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

    // 检查 Token 是否为空，如果为空且用户已登录状态，说明 Token 过期或失效
    String tk = await UserRepoLocal.to.accessToken;
    final isLoggedIn = UserRepoLocal.to.isLoggedIn;

    // 如果用户本地记录显示已登录，但 Token 为空，说明 Token 失效
    if (isLoggedIn && strEmpty(tk)) {
      debugPrint("_setDefaultConfig: 用户已登录但 Token 为空，触发重新登录流程");
      await _handleTokenExpired();
      return;
    }

    // iPrint("_setDefaultConfig tk: $tk");
    if (tokenExpired(tk) == false) {
      String rtk = await UserRepoLocal.to.refreshToken;
      // 防御性检查：refresh token 为空时不尝试刷新
      if (rtk.isNotEmpty) {
        tk = await UserApi.to.refreshAccessTokenApi(rtk, checkNewToken: false);
      } else {
        debugPrint("_setDefaultConfig: refresh token 为空，跳过刷新");
      }
    }
    bool notRTK = !_dio.options.headers.containsKey(Keys.refreshTokenKey);
    if (strNoEmpty(tk) && notRTK) {
      _dio.options.headers[Keys.tokenKey] = tk;
    }
    Map<String, dynamic> headers = await defaultHeaders();
    // 安全日志：不输出包含敏感信息的完整 headers
    debugPrint("_setDefaultConfig: Adding ${headers.length} default headers");
    _dio.options.headers.addAll(headers);
  }

  /// 处理 Token 过期的后续流程（弹窗提示 + 跳转登录页）
  Future<void> _handleTokenExpired() async {
    // 防止重复弹窗
    if (_isHandlingLoginExpired) {
      debugPrint("_handleTokenExpired: 正在处理登录过期流程，跳过重复处理");
      return;
    }

    _isHandlingLoginExpired = true;
    debugPrint("_handleTokenExpired: 开始处理登录过期流程");

    try {
      // 执行登出操作
      await UserRepoLocal.to.quitLogin();

      // 获取当前 context（用于显示 SnackBar）
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null && context.mounted) {
        // 延迟显示，确保 UI 已经准备好
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

      // 延迟跳转，让用户看到提示
      await Future.delayed(const Duration(seconds: 1));

      // 跳转到登录页
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
    } catch (e) {
      debugPrint("_handleTokenExpired: 处理失败 $e");
    } finally {
      // 重置标志（延迟重置，防止跳转过程中的重复请求）
      Future.delayed(const Duration(seconds: 2), () {
        _isHandlingLoginExpired = false;
      });
    }
  }

  /// 处理令牌解密失败的后续流程
  Future<void> _handleTokenDecryptionFailure() async {
    debugPrint("_handleTokenDecryptionFailure: 开始清理并触发重新登录");
    // 清除失败标记
    UserRepoLocal.to.clearTokenDecryptionFailureFlag();
    // 执行登出操作
    await UserRepoLocal.to.quitLogin();
    // 跳转到登录页
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.signIn,
      (route) => false,
    );
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
      if (serviceContainer.isRegistered<NetworkMonitorService>() &&
          !NetworkMonitorService.to.hasNetwork) {
        return handleException(
          uri,
          NetworkException(message: t.tipConnectDesc),
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
      // 处理认证相关错误：401 (新标准) 和 706/707 (旧版兼容)
      if (ErrorCode.shouldReLogin(resp.code)) {
        UserRepoLocal.to.quitLogin();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.signIn,
          (route) => false,
        );
      } else if (resp.code == ErrorCode.TOKEN_EXPIRED) {
        // Token 过期，尝试刷新
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
    if (serviceContainer.isRegistered<NetworkMonitorService>() &&
        !NetworkMonitorService.to.hasNetwork) {
      // EasyLoading.showError(t.tipConnectDesc);
      return handleException(uri, NetworkException(message: t.tipConnectDesc));
    }
    try {
      debugPrint("http_post $uri");
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
      // 安全日志：不输出完整响应数据，可能包含敏感信息
      debugPrint("http_post $uri completed with status ${response.statusCode}");
      IMBoyHttpResponse resp = handleResponse(
        response,
        uri: uri,
        httpTransformer: httpTransformer,
      );
      return resp;
    } on Exception catch (e) {
      debugPrint("$uri http_post error: ${e.toString()}");
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
    if (serviceContainer.isRegistered<NetworkMonitorService>() &&
        !NetworkMonitorService.to.hasNetwork) {
      EasyLoading.showError(t.tipConnectDesc);
      return handleException(uri, NetworkException(message: t.tipConnectDesc));
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
    if (serviceContainer.isRegistered<NetworkMonitorService>() &&
        !NetworkMonitorService.to.hasNetwork) {
      EasyLoading.showError(t.tipConnectDesc);
      return handleException(uri, NetworkException(message: t.tipConnectDesc));
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
      return handleResponse(
        response,
        uri: uri,
        httpTransformer: httpTransformer,
      );
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
    if (serviceContainer.isRegistered<NetworkMonitorService>() &&
        !NetworkMonitorService.to.hasNetwork) {
      EasyLoading.showError(t.tipConnectDesc);
      return handleException(uri, NetworkException(message: t.tipConnectDesc));
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
      return handleResponse(
        response,
        uri: uri,
        httpTransformer: httpTransformer,
      );
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
