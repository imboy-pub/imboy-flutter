// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  String? html;
  final scripts = <String>[];
  final channels = <String, JavaScriptChannelParams>{};
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
  final FakeWebViewPlatform host;
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
  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async =>
      host.html = html;
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async =>
      host.channels[params.name] = params;
  @override
  Future<void> runJavaScript(String javaScript) async =>
      host.scripts.add(javaScript);
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
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey('fake-webview-surface'));
}
