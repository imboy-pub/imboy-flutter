import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/web_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _Platform extends WebViewPlatform {
  late void Function(PlatformWebViewPermissionRequest) permission;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _Controller(params, this);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params, this.host) : super.implementation();
  final _Platform host;
  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest) callback,
  ) async => host.permission = callback;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate delegate,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
  @override
  Future<void> clearLocalStorage() async {}
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Request extends PlatformWebViewPermissionRequest {
  _Request() : super(types: {WebViewPermissionResourceType.camera});
  final events = <String>[];
  int get granted => events.where((event) => event == 'grant').length;
  int get denied => events.where((event) => event == 'deny').length;
  @override
  Future<void> grant() async => events.add('grant');
  @override
  Future<void> deny() async => events.add('deny');
}

void main() {
  test('OA 设备能力必须显式启用且初始、当前、请求来源均匹配', () {
    bool allowed({
      bool enabled = true,
      String initial = 'https://imboy.pub/test_oa.html',
      String? current = 'https://imboy.pub/test_oa.html',
      String? origin,
    }) => WebViewPageState.allowsOaDevicePermissions(
      enabled: enabled,
      initialUrl: initial,
      currentUrl: current,
      requestOrigin: origin,
    );
    expect(allowed(origin: 'https://imboy.pub/'), isTrue);
    expect(allowed(enabled: false), isFalse);
    expect(allowed(current: null), isFalse);
    for (final value in [
      'https://thirdparty.test',
      'https://sub.imboy.pub',
      'http://imboy.pub',
      'https://imboy.pub:8443',
      'https://user@imboy.pub',
    ]) {
      expect(allowed(initial: value), isFalse);
      expect(allowed(current: value), isFalse);
      expect(allowed(origin: value), isFalse);
    }
  });

  testWidgets('普通网页相机请求明确拒绝，且不触发系统权限或 grant', (tester) async {
    final previous = WebViewPlatform.instance;
    final platform = _Platform();
    WebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage('https://thirdparty.test', 'synthetic page'),
      ),
    );
    final request = _Request();
    platform.permission(request);
    await tester.pump();
    expect(request.denied, 1);
    expect(request.granted, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
// Tests exercise the already resolved WebView permission callback interface.
// ignore_for_file: depend_on_referenced_packages
