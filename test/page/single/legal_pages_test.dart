import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/single/network_failure_guidance_page.dart';
import 'package:imboy/page/single/terms_of_service_page.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(child: MaterialApp(home: child)),
    ),
  );
  await tester.pump();
}

void main() {
  // 原 PrivacyPolicyPage 的两组用例已随该页面一并删除（imboyapp b1a8b089）：
  // 那个页面是零入口死页面，且硬编码了第二份隐私政策全文，日期还与
  // assets/docs/privacy-policy.md 对不上。设置页实走通用 Markdown 页
  // 读该 asset，法务文本的唯一真相源在那里。

  group('NetworkFailureGuidancePage 渲染', () {
    testWidgets('NF-1 渲染不崩溃且含排查步骤卡片', (tester) async {
      await _pump(tester, const NetworkFailureGuidancePage());
      expect(find.byType(NetworkFailureGuidancePage), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NF-2 深色模式渲染不崩溃', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const NetworkFailureGuidancePage(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('TermsOfServicePage 渲染', () {
    testWidgets('TS-1 渲染不崩溃', (tester) async {
      await _pump(tester, const TermsOfServicePage());
      expect(find.byType(TermsOfServicePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TS-2 深色模式渲染不崩溃', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const TermsOfServicePage(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
