import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

// ignore: implementation_imports
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
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
/// 生产环境严格验证证书，开发环境允许白名单内的自签名证书
bool _certificateValidationCallback(X509Certificate cert) {
  // dio_http2_adapter 当前版本回调不再提供 host/port。
  // 仅在开发环境接受自签名证书，生产环境保持严格校验。
  if (currentEnv == 'dev' || currentEnv.startsWith('local')) {
    // 使用精确 CN 匹配，防止子串匹配被构造绕过
    final cn = _extractCN(cert.subject);
    const trustedCNs = <String>{
      'dev.imboy.pub',
      'localhost',
      '127.0.0.1',
      'imboy.pub',
    };
    final allowed = trustedCNs.contains(cn) || cn.endsWith('.imboy.pub');
    if (!allowed) {
      debugPrint("HttpClient: reject dev certificate, CN=$cn");
    }
    return allowed;
  }
  // 生产环境进行严格验证
  return false;
}

/// 从证书 subject 中提取 CN（Common Name）字段
String _extractCN(String subject) {
  final match = RegExp(r'CN=([^,]+)').firstMatch(subject);
  return match?.group(1)?.trim().toLowerCase() ?? '';
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
  static VoidCallback? onAuthExpired;
  static const Set<String> _publicEndpoints = <String>{
    API.initConfig,
    API.login,
    API.signup,
    API.getCode,
    API.quickLogin,
    API.findPassword,
  };
  late Dio _dio;

  /// Expose the underlying Dio instance for advanced usage (e.g. 304 handling).
  Dio get dio => _dio;

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
    final retryInterceptor = createRetryInterceptor(retryConfig);
    retryInterceptor.bindDio(_dio);
    _dio.interceptors.add(retryInterceptor);

    if (recordLog) {
      _dio.interceptors.add(
        LogInterceptor(
          responseBody: false,
          error: true,
          requestHeader: false, // 禁止输出 Header（含 Authorization token）
          responseHeader: false,
          request: true,
          requestBody: false, // 禁止输出请求体（可能含密码）
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

  /// 防止并发 Token 刷新：多个请求共享同一次刷新结果
  static Completer<String>? _tokenRefreshCompleter;

  /// 防止重复处理登录过期流程
  static Completer<void>? _loginExpiredCompleter;

  void _notifyAuthExpired({String reason = ''}) {
    debugPrint("HttpClient: auth expired event emitted, reason=$reason");
    if (onAuthExpired != null) {
      onAuthExpired!.call();
      return;
    }
    navigateToSignIn(source: 'http_client_auth_expired');
  }

  bool _shouldSkipAuthForUri(String uri) {
    final parsed = Uri.tryParse(uri);
    final path = parsed?.path;
    final normalized = (path != null && path.isNotEmpty) ? path : uri;
    return _publicEndpoints.contains(normalized);
  }

  Future<void> _setDefaultConfig(String uri) async {
    if (_dio.options.baseUrl == "") {
      _dio.options.baseUrl = Env().apiBaseUrl;
    }

    if (_shouldSkipAuthForUri(uri)) {
      _dio.options.headers.remove(Keys.tokenKey);
      _dio.options.headers.remove(Keys.refreshTokenKey);

      final headers = await defaultHeaders();
      debugPrint("_setDefaultConfig: skip auth bootstrap for public uri=$uri");
      _dio.options.headers.addAll(headers);
      return;
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

    // Token 已过期时尝试用 refresh token 刷新（互斥锁防止并发刷新）
    if (tokenExpired(tk)) {
      tk = await _refreshTokenWithMutex();
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

  /// 带互斥锁的 Token 刷新：并发请求共享同一次刷新结果
  Future<String> _refreshTokenWithMutex() async {
    // 已有刷新任务在进行中，等待其完成
    if (_tokenRefreshCompleter != null) {
      return _tokenRefreshCompleter!.future;
    }
    _tokenRefreshCompleter = Completer<String>();
    try {
      final rtk = await UserRepoLocal.to.refreshToken;
      if (rtk.isEmpty) {
        debugPrint("_refreshTokenWithMutex: refresh token 为空，跳过刷新");
        _tokenRefreshCompleter!.complete('');
        return '';
      }
      final newTk = await UserApi.to.refreshAccessTokenApi(
        rtk,
        checkNewToken: false,
      );
      _tokenRefreshCompleter!.complete(newTk);
      return newTk;
    } catch (e) {
      debugPrint("_refreshTokenWithMutex: 刷新失败 $e");
      _tokenRefreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _tokenRefreshCompleter = null;
    }
  }

  /// 处理 Token 过期的后续流程（弹窗提示 + 跳转登录页）
  /// 使用 Completer 替代布尔标志，确保并发请求有序等待且标志不会锁死
  Future<void> _handleTokenExpired() async {
    // 已有过期处理流程在进行中，等待其完成
    if (_loginExpiredCompleter != null) {
      debugPrint("_handleTokenExpired: 正在处理登录过期流程，等待完成");
      return _loginExpiredCompleter!.future;
    }

    _loginExpiredCompleter = Completer<void>();
    debugPrint("_handleTokenExpired: 开始处理登录过期流程");

    try {
      // 执行登出操作
      await UserRepoLocal.to.quitLogin();

      // 获取当前 context（用于显示 SnackBar）
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null && context.mounted) {
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

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
      await Future<dynamic>.delayed(const Duration(seconds: 1));

      _notifyAuthExpired(reason: 'token_expired');
      _loginExpiredCompleter!.complete();
    } catch (e) {
      debugPrint("_handleTokenExpired: 处理失败 $e");
      _loginExpiredCompleter!.completeError(e);
    } finally {
      // 延迟重置，防止跳转过程中的重复请求立即重入
      Future<dynamic>.delayed(const Duration(seconds: 2), () {
        _loginExpiredCompleter = null;
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
    _notifyAuthExpired(reason: 'token_decryption_failure');
  }

  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    return _executeWithNetworkCheck(
      uri,
      () => _dio.get(
        uri,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
      httpTransformer: httpTransformer,
      onResponse: _checkAuthExpired,
    );
  }

  /// 检查网络连通性
  bool get _isNetworkAvailable {
    return !serviceContainer.isRegistered<NetworkMonitorService>() ||
        NetworkMonitorService.to.hasNetwork;
  }

  /// 统一的认证过期响应处理
  void _checkAuthExpired(IMBoyHttpResponse resp) {
    if (ErrorCode.shouldReLogin(resp.code)) {
      unawaited(UserRepoLocal.to.quitLogin());
      _notifyAuthExpired(reason: 'api_relogin_required');
    }
  }

  /// 带网络检查的通用请求执行器（DRY）
  Future<IMBoyHttpResponse> _executeWithNetworkCheck(
    String uri,
    Future<Response<dynamic>> Function() requestFn, {
    HttpTransformer? httpTransformer,
    void Function(IMBoyHttpResponse)? onResponse,
  }) async {
    if (!_isNetworkAvailable) {
      return handleException(uri, NetworkException(message: t.tipConnectDesc));
    }
    try {
      await _setDefaultConfig(uri);
      final response = await requestFn();
      final resp = handleResponse(
        response,
        uri: uri,
        httpTransformer: httpTransformer,
      );
      onResponse?.call(resp);
      return resp;
    } on Exception catch (e) {
      return handleException(uri, e);
    }
  }

  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    return _executeWithNetworkCheck(
      uri,
      () => _dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      httpTransformer: httpTransformer,
      onResponse: _checkAuthExpired,
    );
  }

  Future<IMBoyHttpResponse> delete(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) async {
    return _executeWithNetworkCheck(
      uri,
      () => _dio.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      httpTransformer: httpTransformer,
      onResponse: _checkAuthExpired,
    );
  }

  Future<IMBoyHttpResponse> patch(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    return _executeWithNetworkCheck(
      uri,
      () => _dio.patch(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      httpTransformer: httpTransformer,
      onResponse: _checkAuthExpired,
    );
  }

  Future<IMBoyHttpResponse> put(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    HttpTransformer? httpTransformer,
  }) async {
    return _executeWithNetworkCheck(
      uri,
      () => _dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      httpTransformer: httpTransformer,
      onResponse: _checkAuthExpired,
    );
  }

  Future<Response<dynamic>> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
    HttpTransformer? httpTransformer,
  }) async {
    if (!_isNetworkAvailable) {
      throw NetworkException(message: t.tipConnectDesc);
    }
    await _setDefaultConfig(urlPath);
    return _dio.download(
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
  }
}
