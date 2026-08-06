// 路由烟雾测试共享框架 / Shared smoke-test harness
//
// 职责 / Responsibilities:
//   1. prepareSmokeEnv  —— mock 登录态 + 原生 channel（在 setUp 调用）
//   2. buildRouterApp   —— 构建带真实 GoRouter 的测试 App（镜像 run.dart 的 IMBoyApp）
//   3. renderRoute      —— 对单条路由 go() 并 pump 固定帧，返回捕获的异常（null=通过）
//
// 设计要点 / Design notes:
//   - 全程 pump(Duration) 固定帧，绝不 pumpAndSettle（页面 initState 异步加载会挂死）
//   - 每条路由独立 ProviderContainer，避免页面间 provider 脏状态串扰
//   - 登录态仅通过 StorageService 写 currentUid，不 hack UserRepoLocal

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';

import '../helper/sqflite_test_helper.dart';
import 'route_registry.dart';

/// 安装全局网络拦截：所有 HTTP（Dio 底层 dart:io HttpClient）立即返回空 200。
/// 防止页面 initState 发起的网络请求在无网络环境下挂起，其 Future 在后续用例
/// 才 resolve/抛错而污染其它用例（级联失败的根因）。
/// 在 setUpAll 调用一次即可。
void installSmokeHttpOverrides() {
  HttpOverrides.global = _SmokeHttpOverrides();
}

/// 在 setUp 中调用：mock 登录态 + 原生 channel。
/// StorageService 已由 test/flutter_test_config.dart 全局初始化。
Future<void> prepareSmokeEnv() async {
  mockSqfliteSqlcipher();
  await StorageService.to.setString(Keys.currentUid, 'smoke_test_uid');
}

/// 构建带真实 GoRouter 的测试 App（镜像 lib/run.dart 的 IMBoyApp 关键结构）。
///
/// 固定窄屏 designSize(375,812)：
///   - 让 ScreenUtil 正常工作（页面用 .w/.h/.sp 否则崩）
///   - 让 /sign_in 走 LoginPage 而非 WebLoginPage（宽度 > 800 才切换）
Widget buildRouterApp(GoRouter router) {
  return TranslationProvider(
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocaleUtils.supportedLocales,
      ),
    ),
  );
}

/// 渲染单条路由并返回捕获到的异常（null = 通过）。
///
/// 关键设计：用 createAppRouter 把 initialLocation 直接设为目标路由，
/// 跳过 splash（避免其定时器污染）；并注入独立 navigatorKey，避免跨用例
/// 复用全局 GlobalKey 导致 `_elements.contains` 断言失败。
///
/// 仅捕获「同步 build 期」异常：pumpWidget 渲染目标页 → 固定 pump 若干帧。
/// 结尾 pumpWidget(SizedBox) 卸载页面，触发各 State.dispose() 取消其
/// 订阅/定时器，规避 teardown 的 `Timer still pending` 不变量失败。
Future<Object?> renderRoute(WidgetTester tester, SmokeRoute route) async {
  final container = ProviderContainer();

  // 每个用例独立 navigatorKey + 直接落在目标路由（无 splash）
  final router = createAppRouter(
    initialLocation: route.location,
    navigatorKeyOverride: GlobalKey<NavigatorState>(),
  );

  Object? captured;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: buildRouterApp(router),
    ),
  );

  // 固定帧 pump —— 绝不 pumpAndSettle（页面 initState 异步加载会挂死）
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  captured = tester.takeException();

  // 卸载页面树：触发 State.dispose 取消页面自身的订阅/定时器
  await tester.pumpWidget(const SizedBox.shrink());

  // 在本用例内显式、受保护地 dispose container：
  // 避免「provider 异步 build 未完成时 dispose」抛错残留到 teardown，
  // 污染共享 binding 引发后续用例级联（framework.dart:2168）。
  try {
    container.dispose();
  } on Object {
    // 清理期的 pending-provider 噪音不算页面崩溃，吞掉但不影响 captured。
  }

  // 冲刷本页遗留的一次性定时器（Future.delayed 等），把泄漏限制在本用例内。
  await tester.pump(const Duration(seconds: 5));

  return captured;
}

// ---------------------------------------------------------------------------
// 网络拦截 / HTTP stubbing —— 所有请求即时返回空 200，避免挂起 Future
// ---------------------------------------------------------------------------

class _SmokeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _SmokeHttpClient();
}

class _SmokeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  Future<HttpClientRequest> _request(Uri url) async =>
      _SmokeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _request(url);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _request(url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _request(url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _request(url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _request(url);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _request(url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _request(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> headUrl(Uri url) => _request(url);

  @override
  void close({bool force = false}) {}

  // 其余回调/认证接口在 smoke 测试中无需实现
  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) {}
  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) {}
  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {}
  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {}
  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  set keyLog(void Function(String line)? callback) {}
  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {}
}

class _SmokeHttpClientRequest implements HttpClientRequest {
  _SmokeHttpClientRequest(this.uri);
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _SmokeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _SmokeHttpClientResponse();
  @override
  Future<HttpClientResponse> get done async => _SmokeHttpClientResponse();

  @override
  void add(List<int> data) {}
  @override
  void write(Object? object) {}
  @override
  void writeln([Object? object = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<void> flush() async {}
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  String method = 'GET';
  @override
  List<Cookie> get cookies => <Cookie>[];
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _SmokeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int statusCode = 200;
  @override
  String reasonPhrase = 'OK';
  @override
  int contentLength = 0;
  @override
  final HttpHeaders headers = _SmokeHttpHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<Cookie> get cookies => <Cookie>[];
  @override
  List<RedirectInfo> get redirects => <RedirectInfo>[];
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  X509Certificate? get certificate => null;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // 空响应体，立即 done
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) async => this;
  @override
  Future<Socket> detachSocket() => throw UnsupportedError('smoke stub');
}

// utf8 来自 dart:convert

class _SmokeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _h = {};
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = 0;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = false;
  @override
  int? port;

  @override
  List<String>? operator [](String name) => _h[name.toLowerCase()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _h.putIfAbsent(name.toLowerCase(), () => []).add('$value');
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _h[name.toLowerCase()] = ['$value'];
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) => _h.remove(name.toLowerCase());
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _h.forEach(action);
  @override
  void noFolding(String name) {}
  @override
  void clear() => _h.clear();
  @override
  String? value(String name) => _h[name.toLowerCase()]?.first;
}
