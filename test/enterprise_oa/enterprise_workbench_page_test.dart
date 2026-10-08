import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  var canOpen = true;

  setUp(() {
    calls.clear();
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
        home: Scaffold(
          body: EnterpriseWorkbenchPage(
            entries: entries,
            accountKey: 'synthetic-account',
            organizationId: '1',
            resourceEntries: const [CupertinoListTile(title: Text('资料'))],
          ),
        ),
      );

  /// 测试环境无 webview_flutter 平台实现，用 macOS 模拟
  /// 「系统浏览器兜底」分支；Android/iOS 的应用内 WebView 分支
  /// 需要真机/模拟器验证（与仓内不挂真 WebView 的测试惯例一致）。
  /// foundation debug 变量必须在 invariant 检查前手动复位（try/finally），
  /// addTearDown 的执行时机在 _verifyInvariants 之后，不够。
  Future<void> runOnMacos(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('无 OA 保留资料入口，点击 OA办公走系统浏览器兜底', (tester) async {
    await runOnMacos(() async {
      await tester.pumpWidget(host());
      expect(find.text('资料'), findsOneWidget);
      expect(find.text(t.enterpriseOa.oaOffice), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('workbench-oa-office')));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['canLaunch', 'launch']);
      expect(calls.last.arguments['url'], EnterpriseWorkbenchPage.oaOfficeUrl);
      expect(calls.last.arguments['useWebView'], isFalse);
    });
  });

  testWidgets('系统浏览器不可用时显示错误', (tester) async {
    await runOnMacos(() async {
      canOpen = false;
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const ValueKey('workbench-oa-office')));
      await tester.pumpAndSettle();
      expect(find.text(t.common.cannotOpenWebpage), findsOneWidget);
      expect(calls.map((call) => call.method), ['canLaunch']);
    });
  });

  testWidgets('有效 OA 配置显示 OA 入口，不显示 OA办公替代入口', (tester) async {
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
      expect(find.byKey(const ValueKey('workbench-oa-office')), findsNothing);
      expect(calls, isEmpty);
    });
  });
}
