import 'package:flutter/cupertino.dart';
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

  testWidgets('无 OA 保留资料入口，点击官网才打开系统浏览器', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('资料'), findsOneWidget);
    expect(find.text(t.enterpriseOa.officialWebsite), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('workbench-official-website')));
    await tester.pumpAndSettle();
    expect(calls.map((call) => call.method), ['canLaunch', 'launch']);
    expect(calls.last.arguments['url'], 'https://imboy.pub/');
    expect(calls.last.arguments['useWebView'], isFalse);
  });

  testWidgets('系统浏览器不可用时显示错误', (tester) async {
    canOpen = false;
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const ValueKey('workbench-official-website')));
    await tester.pumpAndSettle();
    expect(find.text(t.common.cannotOpenWebpage), findsOneWidget);
    expect(calls.map((call) => call.method), ['canLaunch']);
  });

  testWidgets('有效 OA 配置显示 OA 入口，不显示官网替代入口', (tester) async {
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
    expect(
      find.byKey(const ValueKey('workbench-official-website')),
      findsNothing,
    );
    expect(calls, isEmpty);
  });
}
