import 'package:imboy/component/http/web_control_fetch_adapter.dart';
import 'package:imboy/component/http/web_writer_http_adapter.dart';

import 'dart:async';
import 'dart:io';
import 'dart:io' as io show HttpClient;

import 'channel_id_response_decoder.dart';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'package:flutter/foundation.dart'
    show VoidCallback, kIsWeb, kReleaseMode, visibleForTesting;

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/web_writer_gate.dart';

import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'http_config.dart';
import 'http_parse.dart';
import 'http_response.dart';
import 'http_transformer.dart';
import 'http_retry_interceptor.dart';
import 'http_request_policy.dart';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/app_loading.dart';

/// 构造底层 HttpClient：统一挂证书校验，可选走代理。
io.HttpClient _buildHttpClient({String? proxy}) {
  final client = io.HttpClient();
  client.badCertificateCallback = (
    X509Certificate cert,
    String host,
    int port,
  ) => _certificateValidationCallback(cert);
  if (proxy != null && proxy.isNotEmpty) {
    final authority = Uri.parse(proxy).authority;
    client.findProxy = (uri) => 'PROXY $authority';
  }
  return client;
}

/// 安全的证书验证回调
/// 生产环境严格验证证书，开发环境允许白名单内的自签名证书
///
/// #105：放行条件必须叠加编译期 `!kReleaseMode`。currentEnv 是运行期
/// 全局字符串（且会从本地存储恢复旧值，见 init.dart），release 包中若
/// 它被诱导/残留为 dev|local*，自签证书白名单就会在生产放开——
/// 改为「非 release 构建 且 dev/local 环境」双条件，release 恒严格校验。
bool _certificateValidationCallback(X509Certificate cert) {
  // dio_http2_adapter 当前版本回调不再提供 host/port。
  // 仅在开发环境接受自签名证书，生产环境保持严格校验。
  if (!kReleaseMode &&
      (currentEnv == 'dev' || currentEnv.startsWith('local'))) {
    // 使用精确 CN 匹配，防止子串匹配被构造绕过
    final cn = _extractCN(cert.subject);
    const trustedCNs = <String>{
      'dev.imboy.pub',
      'localhost',
      '127.0.0.1',
      'imboy.pub',
    };
    final allowed = trustedCNs.contains(cn) || cn.endsWith('.imboy.pub');
    if (!allowed) {}
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
  if (kIsWeb) {
    return {
      'did': deviceId,
      'dname': 'Web Browser',
      'vsn': appVsn,
      'pkg': packageName,
      'tz_offset': DateTime.now().timeZoneOffset.inMilliseconds,
    };
  }
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

typedef _RequestSession = ({
  String uid,
  int generation,
  bool loggedIn,
  bool transitioning,
  bool clearing,
  String environment,
  String environmentEndpoint,
  String endpoint,
});

class _SessionChanged implements Exception {}

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
    "/api/v1/oa/login/exchange",
    "/api/v1/oa/login/register",
  };
  late Dio _dio;

  /// Expose the underlying Dio instance for advanced usage (e.g. 304 handling).
  Dio get dio => _dio;

  HttpClient({
    BaseOptions? options,
    HttpConfig? conf,
    bool retryEnabled = true,
  }) {
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
    if (retryEnabled) {
      final retryConfig = currentEnv == 'dev'
          ? HttpRetryConfig.devConfig
          : HttpRetryConfig.prodConfig;
      final retryInterceptor = createRetryInterceptor(retryConfig);
      retryInterceptor.bindDio(_dio);
      _dio.interceptors.add(retryInterceptor);
    }

    if (recordLog) {
      _dio.interceptors.add(SafeHttpLogInterceptor());
    }
    if (conf?.interceptors?.isNotEmpty ?? false) {
      _dio.interceptors.addAll(conf!.interceptors!);
    }

    // Web 控制 Fetch 路由在下方显式安装；只读 bytes/stream 保留原运输。
    //
    // 这里曾用 Http2Adapter：它自管 socket，App 长时间运行后连接会进入
    // 半死状态（对端已断、客户端不知），后续请求写进死连接后挂满 15s 才抛
    // TimeoutException——表现为频道列表打不开、社交资料查不到、群成员详情
    // 空白，重启 App 立即恢复，而同一端点 curl 0.2s 正常。改回 dart:io 的
    // IOHttpClientAdapter，由 HttpClient 自己做连接健康管理；顺带让
    // HttpOverrides 重新生效，flutter test 不会再真的打到线上。
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => _buildHttpClient(),
      );
    }

    // 测试注入点：让测试把出口换掉，约定同 SqliteService.setDbForTest。
    if (adapterForTest != null) {
      _dio.httpClientAdapter = adapterForTest!;
    }

    if (kIsWeb) {
      _dio.interceptors.add(InterceptorsWrapper(onRequest: _prepareWebRequest));
    }
    _dio.interceptors.add(HttpRequestGuardInterceptor());
    guardWebWriterDio(_dio);
    if (kIsWeb) {
      final endpoint = _dio.options.baseUrl.isEmpty
          ? Env().apiBaseUrl
          : _dio.options.baseUrl;
      guardWebControlDio(_dio, apiOrigin: Uri.parse(endpoint));
    }

    if (conf?.proxy?.isNotEmpty ?? false) {
      setProxy(conf!.proxy!);
    }
  }

  void setProxy(String proxy) {
    // Web 平台不支持代理设置
    if (kIsWeb) {
      return;
    }

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => _buildHttpClient(proxy: proxy),
    );
  }

  /// 测试专用：替换所有 HttpClient 实例的出口，避免测试打到真实服务器。
  ///
  /// 设置后对**之后构造**的实例生效（各 API 类都在自己的构造里建 Dio）。
  /// 用完在 tearDown 里置回 null。
  @visibleForTesting
  static HttpClientAdapter? adapterForTest;

  /// 防止重复处理登录过期流程
  static Completer<void>? _loginExpiredCompleter;
  static int? _loginExpiredGeneration;

  void _notifyAuthExpired({String reason = ''}) {
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
    return kIsWeb
        ? webHumanPublicPaths.contains(normalized)
        : _publicEndpoints.contains(normalized);
  }

  _RequestSession _captureSession() {
    if (_dio.options.baseUrl.isEmpty) _dio.options.baseUrl = Env().apiBaseUrl;
    final repo = UserRepoLocal.to;
    return (
      uid: repo.currentUid,
      generation: repo.sessionGeneration,
      loggedIn: repo.isLoggedIn,
      transitioning: repo.isAuthTransitioning,
      clearing: repo.isClearingSession,
      environment: currentEnv,
      environmentEndpoint: Env().apiBaseUrl,
      endpoint: _dio.options.baseUrl,
    );
  }

  bool _sessionMatches(_RequestSession session) {
    final repo = UserRepoLocal.to;
    return repo.currentUid == session.uid &&
        repo.isCurrentSession(session.generation) &&
        repo.isLoggedIn == session.loggedIn &&
        repo.isAuthTransitioning == session.transitioning &&
        repo.isClearingSession == session.clearing &&
        currentEnv == session.environment &&
        Env().apiBaseUrl == session.environmentEndpoint &&
        _dio.options.baseUrl == session.endpoint;
  }

  void _requireSession(_RequestSession session, String uri) {
    requireWebWriter();
    if (!_sessionMatches(session) ||
        (session.transitioning &&
            !session.clearing &&
            !_shouldSkipAuthForUri(uri))) {
      throw _SessionChanged();
    }
  }

  Future<void> _setDefaultConfig(
    String uri,
    _RequestSession session, {
    Map<String, dynamic>? requestHeaders,
  }) async {
    final target = requestHeaders ?? _dio.options.headers;
    _requireSession(session, uri);
    if (_shouldSkipAuthForUri(uri)) {
      final headers = await defaultHeaders();
      _requireSession(session, uri);
      target.remove(Keys.tokenKey);
      target.remove(Keys.refreshTokenKey);
      target.addAll(headers);
      return;
    }

    // Push unregister is part of logout and must not enqueue another logout.
    if (session.clearing) {
      final token = await UserRepoLocal.to.accessToken;
      _requireSession(session, uri);
      final headers = await defaultHeaders();
      _requireSession(session, uri);
      target.remove(Keys.tokenKey);
      target.remove(Keys.refreshTokenKey);
      target.addAll(headers);
      if (token.isNotEmpty) target[Keys.tokenKey] = token;
      return;
    }

    if (UserRepoLocal.to.hasTokenDecryptionFailure) {
      _requireSession(session, uri);
      await _handleTokenDecryptionFailure(session.generation);
      throw _SessionChanged();
    }

    String tk = await UserRepoLocal.to.accessToken;
    _requireSession(session, uri);
    if (session.loggedIn && strEmpty(tk)) {
      await _handleTokenExpired(session.generation);
      throw _SessionChanged();
    }

    if (tokenExpired(tk)) {
      tk = await _refreshToken(session, uri);
      _requireSession(session, uri);
    }
    final headers = await defaultHeaders();
    _requireSession(session, uri);
    final notRTK = !target.containsKey(Keys.refreshTokenKey);
    target.remove(Keys.tokenKey);
    if (strNoEmpty(tk) && notRTK) target[Keys.tokenKey] = tk;
    target.addAll(headers);
  }

  Future<void> _prepareWebRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final initialGuard = options.extra[httpRequestGuard];
      if (initialGuard != null) (initialGuard as void Function())();
      final session = _captureSession();
      final root = Uri.parse(session.environmentEndpoint);
      final rawPath = options.path.split(RegExp(r'[?#]')).first;
      if (rawPath.contains(RegExp(r'[%\\]')) ||
          rawPath.contains(RegExp(r'(^|/)\.{1,2}(/|$)'))) {
        throw const FormatException('Unsupported Web Human path');
      }
      webHumanRequestUri(options.method, Uri.parse(options.path), root);
      final uri = webHumanRequestUri(options.method, options.uri, root);
      if (uri.path == '/api/v1/web/passport/login' &&
          options.responseDecoder == null) {
        options.responseDecoder = channelIdResponseDecoder(
          ChannelResponseShape.login,
        );
      }
      if (uri.path == '/api/v1/web/refreshtoken') {
        throw StateError('Use the scoped refresh transport');
      }
      final headers = <String, dynamic>{
        for (final entry in options.headers.entries)
          if (webHumanMetadataHeaders.contains(entry.key.toLowerCase()))
            entry.key: entry.value,
      };
      _dio.options.headers.removeWhere(
        (key, _) => !webHumanMetadataHeaders.contains(key.toLowerCase()),
      );
      final guarded = _guardedOptions(
        Options(extra: options.extra),
        session,
        '$uri',
      );
      await _setDefaultConfig('$uri', session, requestHeaders: headers);
      _requireSession(session, '$uri');
      options.path = '$uri';
      // uri already contains both inline and queryParameters values exactly once.
      options.queryParameters = {};
      options.headers = headers;
      final method = options.method;
      final ownerGuard = guarded.extra![httpRequestGuard] as void Function();
      options.extra = {
        ...guarded.extra!,
        httpRequestGuard: () {
          ownerGuard();
          if (options.uri != uri || options.method != method) {
            throw StateError('Web control intent changed');
          }
        },
      };
      handler.next(options);
    } on DioException catch (error) {
      handler.reject(error);
    } catch (_) {
      options.extra[httpNoAutoRetry] = true;
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Web Human request rejected',
        ),
      );
    }
  }

  /// UserApi owns the shared refresh, including non-HTTP callers.
  Future<String> _refreshToken(_RequestSession session, String uri) async {
    final rtk = await UserRepoLocal.to.refreshToken;
    _requireSession(session, uri);
    if (rtk.isEmpty) return '';
    // Another caller may have completed its refresh while storage was pending.
    final currentToken = await UserRepoLocal.to.accessToken;
    _requireSession(session, uri);
    if (currentToken.isNotEmpty && !tokenExpired(currentToken)) {
      return currentToken;
    }
    final token = await UserApi.to.refreshAccessTokenApi(
      rtk,
      checkNewToken: false,
    );
    _requireSession(session, uri);
    return token;
  }

  /// 处理 Token 过期的后续流程（弹窗提示 + 跳转登录页）
  /// 使用 Completer 替代布尔标志，确保并发请求有序等待且标志不会锁死
  Future<void> _handleTokenExpired(int generation) async {
    // 已有过期处理流程在进行中，等待其完成
    if (_loginExpiredCompleter != null &&
        _loginExpiredGeneration == generation) {
      return _loginExpiredCompleter!.future;
    }

    final completer = Completer<void>();
    _loginExpiredCompleter = completer;
    _loginExpiredGeneration = generation;

    try {
      // 执行登出操作
      await UserRepoLocal.to.quitLogin(expectedGeneration: generation);

      // 获取当前 context（用于显示 SnackBar）
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null && context.mounted) {
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        if (context.mounted && UserRepoLocal.to.isLoggedOutAfter(generation)) {
          AppLoading.showToast(t.chat.loginExpiredMessage);
        }
      }

      // 延迟跳转，让用户看到提示
      await Future<dynamic>.delayed(const Duration(seconds: 1));

      if (UserRepoLocal.to.isLoggedOutAfter(generation)) {
        _notifyAuthExpired(reason: 'token_expired');
      }
      completer.complete();
    } catch (e, stack) {
      completer.completeError(e, stack);
    } finally {
      // 延迟重置，防止跳转过程中的重复请求立即重入
      Future<dynamic>.delayed(const Duration(seconds: 2), () {
        if (identical(_loginExpiredCompleter, completer)) {
          _loginExpiredCompleter = null;
          _loginExpiredGeneration = null;
        }
      });
    }
  }

  /// 处理令牌解密失败的后续流程
  Future<void> _handleTokenDecryptionFailure(int generation) async {
    // 清除失败标记
    UserRepoLocal.to.clearTokenDecryptionFailureFlag();
    // 执行登出操作
    await UserRepoLocal.to.quitLogin(expectedGeneration: generation);
    if (UserRepoLocal.to.isLoggedOutAfter(generation)) {
      _notifyAuthExpired(reason: 'token_decryption_failure');
    }
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
      (guardedOptions) => _dio.get(
        uri,
        queryParameters: queryParameters,
        options: guardedOptions,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
      httpTransformer: httpTransformer,
      options: options,
    );
  }

  /// 检查网络连通性
  bool get _isNetworkAvailable {
    return !serviceContainer.isRegistered<NetworkMonitorService>() ||
        NetworkMonitorService.to.hasNetwork;
  }

  /// 统一的认证过期响应处理
  Future<void> _checkAuthExpired(IMBoyHttpResponse resp, int generation) async {
    if (!ErrorCode.shouldReLogin(resp.code) ||
        UserRepoLocal.to.isClearingSession) {
      return;
    }
    await UserRepoLocal.to.quitLogin(expectedGeneration: generation);
    if (UserRepoLocal.to.isLoggedOutAfter(generation)) {
      _notifyAuthExpired(reason: 'api_relogin_required');
    }
  }

  Options _guardedOptions(
    Options? options,
    _RequestSession session,
    String uri,
  ) {
    final extra = <String, dynamic>{..._dio.options.extra, ...?options?.extra};
    final existingGuard = extra[httpRequestGuard];
    extra[httpRequestGuard] = () {
      _requireSession(session, uri);
      if (existingGuard != null) (existingGuard as void Function())();
      _requireSession(session, uri);
    };
    return (options ?? Options()).copyWith(extra: extra);
  }

  /// 带网络检查的通用请求执行器（DRY）
  Future<IMBoyHttpResponse> _executeWithNetworkCheck(
    String uri,
    Future<Response<dynamic>> Function(Options) requestFn, {
    HttpTransformer? httpTransformer,
    Options? options,
  }) async {
    if (!_isNetworkAvailable) {
      return handleException(
        uri,
        NetworkException(message: t.common.tipConnectDesc),
      );
    }
    final session = _captureSession();
    try {
      if (!kIsWeb) await _setDefaultConfig(uri, session);
      _requireSession(session, uri);
      final response = await requestFn(_guardedOptions(options, session, uri));
      _requireSession(session, uri);
      final resp = handleResponse(
        response,
        uri: safeHttpUri(uri),
        httpTransformer: httpTransformer,
      );
      if (!_shouldSkipAuthForUri(uri)) {
        await _checkAuthExpired(resp, session.generation);
        // Successful expiry intentionally changes the session. Do not treat it
        // as a stale response, but reject a concurrent switch to another user.
        if (!_sessionMatches(session) &&
            !UserRepoLocal.to.isLoggedOutAfter(session.generation)) {
          throw _SessionChanged();
        }
      }
      return resp;
    } on _SessionChanged {
      return IMBoyHttpResponse.failure(
        errCode: 409,
        errMsg: t.common.errorNetwork,
      );
    } on Exception catch (e) {
      if (!_sessionMatches(session)) {
        return IMBoyHttpResponse.failure(
          errCode: 409,
          errMsg: t.common.errorNetwork,
        );
      }
      return handleException(safeHttpUri(uri), e);
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
      (guardedOptions) => _dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: guardedOptions,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      httpTransformer: httpTransformer,
      options: options,
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
      (guardedOptions) => _dio.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: guardedOptions,
        cancelToken: cancelToken,
      ),
      httpTransformer: httpTransformer,
      options: options,
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
      (guardedOptions) => _dio.patch(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: guardedOptions,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      httpTransformer: httpTransformer,
      options: options,
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
      (guardedOptions) => _dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: guardedOptions,
        cancelToken: cancelToken,
      ),
      httpTransformer: httpTransformer,
      options: options,
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
      throw NetworkException(message: t.common.tipConnectDesc);
    }
    final session = _captureSession();
    try {
      await _setDefaultConfig(urlPath, session);
      _requireSession(session, urlPath);
      final response = await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        data: data,
        options: _guardedOptions(options, session, urlPath),
      );
      _requireSession(session, urlPath);
      return response;
    } on _SessionChanged {
      throw CancelException('Request session changed');
    }
  }
}
