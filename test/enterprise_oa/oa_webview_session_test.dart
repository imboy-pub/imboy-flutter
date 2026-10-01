import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Installed WebView plugin's existing platform interface, no new dependency.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_webview_container.dart';

class _Platform extends WebViewPlatform {
  final events = <String>[];
  Completer<bool>? clearing;
  bool failClear = false;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams p,
  ) => _Controller(p, this);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams p,
  ) => _Delegate(p);
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams p,
  ) => _Cookies(p, this);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams p,
  ) => _View(p);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params, this.host) : super.implementation();
  final _Platform host;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate delegate,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    expect(params.headers, isEmpty);
    host.events.add('load:${params.uri.path}');
  }

  @override
  Future<void> runJavaScript(String script) async => host.events.add('stop');
  @override
  Future<void> clearLocalStorage() async => host.events.add('storage');
  @override
  Future<void> clearCache() async => host.events.add('cache');
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params, this.host) : super.implementation();
  final _Platform host;
  @override
  Future<bool> clearCookies() async {
    host.events.add('cookies');
    if (host.failClear) throw StateError('synthetic cleanup failure');
    return host.clearing == null ? true : await host.clearing!.future;
  }
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _host(String path, OaTabStateMachine machine) => MaterialApp(
  home: OaWebViewContainer(
    key: ValueKey(path),
    initialUrl: 'https://oa.example.com/$path?code=synthetic',
    machine: machine,
    allowedOrigin: 'https://oa.example.com',
  ),
);
Future<void> _checkOrder(WidgetTester tester, _Platform platform) async {
  platform.clearing = Completer<bool>();
  await tester.pumpWidget(_host('a', OaTabStateMachine()));
  await tester.pump();
  expect(platform.events, ['cookies']);
  platform.clearing!.complete(true);
  await tester.pumpAndSettle();
  expect(platform.events, ['cookies', 'storage', 'cache', 'load:/a']);
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pumpAndSettle();
  expect(platform.events.sublist(4), [
    'stop',
    'load:blank',
    'cookies',
    'storage',
    'cache',
  ]);
}

Future<void> _checkFailure(WidgetTester tester, _Platform platform) async {
  platform.failClear = true;
  final machine = OaTabStateMachine();
  await tester.pumpWidget(_host('a', machine));
  await tester.pumpAndSettle();
  expect(machine.status, OaTabStatus.error);
  expect(platform.events.where((event) => event.startsWith('load:')), isEmpty);
  expect(tester.takeException(), isNull);
  platform.failClear = false;
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pumpAndSettle();
}

Future<void> _checkReplacement(WidgetTester tester, _Platform platform) async {
  await tester.pumpWidget(_host('a', OaTabStateMachine()));
  await tester.pumpAndSettle();
  platform.events.clear();
  await tester.pumpWidget(_host('b', OaTabStateMachine()));
  await tester.pumpAndSettle();
  expect(platform.events, [
    'stop',
    'load:blank',
    'cookies',
    'storage',
    'cache',
    'cookies',
    'storage',
    'cache',
    'load:/b',
  ]);
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pumpAndSettle();
}

Widget _overlapHost(bool showA, bool showB) => MaterialApp(
  home: Stack(
    children: [
      if (showA)
        OaWebViewContainer(
          key: const ValueKey('a'),
          initialUrl: 'https://oa.example.com/a',
          machine: OaTabStateMachine(),
          allowedOrigin: 'https://oa.example.com',
        ),
      if (showB)
        OaWebViewContainer(
          key: const ValueKey('b'),
          initialUrl: 'https://oa.example.com/b',
          machine: OaTabStateMachine(),
          allowedOrigin: 'https://oa.example.com',
        ),
    ],
  ),
);
Future<void> _checkOverlap(WidgetTester tester, _Platform platform) async {
  await tester.pumpWidget(_overlapHost(true, false));
  await tester.pumpAndSettle();
  platform.events.clear();
  await tester.pumpWidget(_overlapHost(true, true));
  await tester.pumpAndSettle();
  expect(platform.events, [
    'stop',
    'load:blank',
    'cookies',
    'storage',
    'cache',
    'load:/b',
  ]);
  platform.events.clear();
  await tester.pumpWidget(_overlapHost(false, true));
  await tester.pumpAndSettle();
  expect(
    platform.events,
    isEmpty,
    reason: 'retired page cannot clear the new session',
  );
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pumpAndSettle();
}

Future<void> _checkCancelledEntry(
  WidgetTester tester,
  _Platform platform,
) async {
  platform.clearing = Completer<bool>();
  await tester.pumpWidget(_host('cancelled', OaTabStateMachine()));
  await tester.pump();
  expect(platform.events, ['cookies']);
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  platform.clearing!.complete(false);
  await tester.pumpAndSettle();
  expect(platform.events, ['cookies', 'storage', 'cache']);
}

void main() {
  testWidgets('OA session entry, cleanup failure, replacement and exit', (
    tester,
  ) async {
    final platform = _Platform();
    WebViewPlatform.instance = platform;
    await _checkOrder(tester, platform);
    platform.events.clear();
    await _checkFailure(tester, platform);
    platform.events.clear();
    await _checkReplacement(tester, platform);
    platform.events.clear();
    await _checkOverlap(tester, platform);
    platform.events.clear();
    await _checkCancelledEntry(tester, platform);
    WebViewPlatform.instance = _Platform();
  });
}
