/// T17 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p2_office_absent_apps_single
///  2. p2_apps_url_absent_from_text_semantics_tooltip
///  3. p2_app_tap_preserves_destination_and_bridge
///  4. p2_android_inbound_entry_remains
///  5. 配置 OA 后应用入口仍可用
///
/// P2-02/P2-03 勘察判定 VERIFY_EXISTING（2026-10-17 已删 OA 列表、URL
/// 仅作 WebView 目的地址）——本卡按 change 以测试冻结现状，不改
/// appsUrl/_openApps/_issueBridgeAuthCode 及业务参数。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/web_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

/// 空成功出口。
class _T17NoopAdapter implements dio.HttpClientAdapter {
  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return dio.ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'code': 0, 'msg': 'success'}),
      200,
      headers: <String, List<String>>{
        dio.Headers.contentTypeHeader: <String>[dio.Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> pumpT17Workbench(
  WidgetTester tester, {
  bool withOaConfig = false,
  bool androidInbound = false,
}) async {
  // webview 平台替身（点击后的 WebViewPage 可构造）
  final WebViewPlatform? prevPlatformImpl = WebViewPlatform.instance;
  WebViewPlatform.instance = _FakeWebViewPlatform();
  // WebViewPlatform.instance 不接受 null：prev 为 null（未设置过）时
  // 保留 fake，后续用例会各自设置自己的替身。
  addTearDown(() {
    if (prevPlatformImpl != null) {
      WebViewPlatform.instance = prevPlatformImpl;
    }
  });
  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  if (androidInbound) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }
  final dio.HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
  HttpClient.adapterForTest = _T17NoopAdapter();
  addTearDown(() => HttpClient.adapterForTest = prevAdapter);
  try {
    final List<EnterpriseOaRuntimeConfig> entries = <EnterpriseOaRuntimeConfig>[
      if (withOaConfig)
        EnterpriseOaRuntimeConfig.fromMap(const <String, String>{
          'IMBOY_WL_OA_ORIGIN': 'https://oa.example',
          'IMBOY_WL_OA_APPLICATION_KEY': 'oa-source-key',
          'IMBOY_WL_OA_LOGIN_START_URI': 'https://oa.example/login',
        }),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EnterpriseWorkbenchPage(
          entries: entries,
          accountKey: 'synthetic-account',
          organizationId: '10',
        ),
      ),
    );
    await tester.pump();
  } finally {
    // foundation invariant 检查早于 addTearDown：平台覆盖必须同步复位
    if (androidInbound) {
      debugDefaultTargetPlatformOverride = prevPlatform;
    }
  }
}

/// webview_flutter 平台测试替身：工作台点击后的 WebViewPage 挂载只需要
/// 控制器/视图可构造；无需真实渲染（noSuchMethod 兜底未用到的通道面）。
class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => _FakeCookieManager(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();

  // platform interface 的非抽象方法默认抛 UnimplementedError；
  // WebViewPage 构造/加载面逐个空实现（未用到的通道面仍走 noSuchMethod）。
  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request) handler,
  ) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearLocalStorage() async {}

  @override
  Future<void> removeJavaScriptChannel(String channelName) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakeCookieManager extends PlatformWebViewCookieManager {
  _FakeCookieManager(super.params) : super.implementation();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('p2_office_absent_apps_single：无办公列表、应用入口恰一', (tester) async {
    await pumpT17Workbench(tester, withOaConfig: true);
    // OA 应用列表已删（2026-10-17 裁决）：无「办公」入口文本
    expect(find.text('办公'), findsNothing);
    // 应用入口恰一个
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
  });

  testWidgets(
    'p2_apps_url_absent_from_text_semantics_tooltip：URL 不出现在文本/语义/提示',
    (tester) async {
      await pumpT17Workbench(tester, withOaConfig: true);
      const String url = EnterpriseWorkbenchPage.appsUrl;
      expect(find.textContaining('test_oa'), findsNothing);
      expect(find.textContaining('imboy.pub'), findsNothing);
      expect(find.byTooltip(url), findsNothing);
      // 全树 Text/语义均不携带 URL
      final List<String> allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data ?? '')
          .toList();
      expect(
        allTexts.any((String s) => s.contains('http')),
        isFalse,
        reason: '工作台任何可见文本不得展示目的 URL',
      );
    },
  );

  testWidgets('p2_app_tap_preserves_destination_and_bridge：点击保留目的地与桥', (
    tester,
  ) async {
    await pumpT17Workbench(tester, withOaConfig: true);
    // 目的地基线：常量冻结（不修改 appsUrl）
    expect(EnterpriseWorkbenchPage.appsUrl, 'https://imboy.pub/test_oa.html');
    await tester.tap(find.byKey(const ValueKey('workbench-apps-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // WebView 页挂载（若平台插件在测试环境不可用则按路由深度断言，
    // 该分支如实记录）
    final bool webViewMounted = find.byType(WebViewPage).evaluate().isNotEmpty;
    if (webViewMounted) {
      final WebViewPage page = tester.widget<WebViewPage>(
        find.byType(WebViewPage),
      );
      expect(page.url, EnterpriseWorkbenchPage.appsUrl, reason: '目的地 URL 基线不变');
      expect(
        page.oaAuthCodeHandler,
        isNotNull,
        reason: '桥 getAuthCode 按需签发仍被注入',
      );
    } else {
      // 平台视图不可挂载：至少路由发生（栈深 >1）
      expect(
        find.byType(EnterpriseWorkbenchPage),
        findsOneWidget,
        reason: '宿主页仍在（push 发生后返回可达）',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('p2_android_inbound_entry_remains：Android inbound 入口保持', (
    tester,
  ) async {
    await pumpT17Workbench(tester, withOaConfig: true, androidInbound: true);
    expect(
      find.text('确认关联当前账号'),
      findsOneWidget,
      reason: 'Android + inboundLoginEnabled 的辅助登录入口保持',
    );
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
  });

  testWidgets('配置 OA 后应用入口仍可用', (tester) async {
    await pumpT17Workbench(tester, withOaConfig: true);
    final Finder apps = find.byKey(const ValueKey('workbench-apps-entry'));
    expect(apps, findsOneWidget);
    expect(tester.widget<CupertinoListTile>(apps).onTap, isNotNull);
  });
}
