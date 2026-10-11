import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  var canOpen = true;
  late _Routes routes;

  setUp(() {
    calls.clear();
    routes = _Routes();
    canOpen = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'canLaunch' ? canOpen : true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget host({List<EnterpriseOaRuntimeConfig> entries = const []}) =>
      MaterialApp(
        navigatorObservers: [routes],
        home: Scaffold(
          body: EnterpriseWorkbenchPage(
            entries: entries,
            accountKey: 'synthetic-account',
            organizationId: '1',
            resourceEntries: const [CupertinoListTile(title: Text('资料'))],
          ),
        ),
      );

  // macOS 与移动端共用应用内导航；此处核验路由，不冒充原生页面加载。
  Future<void> runOnMacos(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('macOS OA办公进入应用内页面，显式传递 OA 设备权限边界', (tester) async {
    await runOnMacos(() async {
      await tester.pumpWidget(host());
      expect(find.text('资料'), findsOneWidget);
      expect(find.text(t.enterpriseOa.apps), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workbench-apps-entry')));
      expect(routes.pushed, hasLength(2));
      final route = routes.pushed.last as CupertinoPageRoute<void>;
      final page = route.builder(
        tester.element(find.byType(EnterpriseWorkbenchPage)),
      ) as WebViewPage;
      expect(page.url, EnterpriseWorkbenchPage.appsUrl);
      expect(page.allowOaDevicePermissions, isTrue);
      expect(page.oaAuthCodeHandler, isNotNull);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('系统浏览器不可用也不调用外部 launcher，仍发起内部导航', (tester) async {
    await runOnMacos(() async {
      canOpen = false;
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const ValueKey('workbench-apps-entry')));
      expect(routes.pushed, hasLength(2));
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('有效 OA 配置显示 OA 入口，联调入口常驻', (tester) async {
    await runOnMacos(() async {
      final config = EnterpriseOaRuntimeConfig.fromMap({
        'IMBOY_WL_OA_ENTRY_ENABLED': 'true',
        'IMBOY_WL_OA_ORIGIN': 'https://oa.example.test',
        'IMBOY_WL_OA_APPLICATION_KEY': 'synthetic-application',
        'IMBOY_WL_OA_REDIRECT_URI': 'https://oa.example.test/entry',
        'IMBOY_WL_OA_LABEL': '办公',
      });
      expect(config.runtimeEntryEnabled, isTrue);
      await tester.pumpWidget(host(entries: [config]));
      expect(find.text('办公'), findsOneWidget);
      // 联调入口常驻：按需免登取码依赖已登记 OA 应用，而应用入口走无桥
      // redirect 容器——联调页必须在有配置时仍可进入，否则配置完成后
      // 反而永远取不到码。
      expect(
        find.byKey(const ValueKey('workbench-apps-entry')),
        findsOneWidget,
      );
      expect(calls, isEmpty);
    });
  });
}
