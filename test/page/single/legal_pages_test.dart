import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/single/network_failure_guidance.dart';
import 'package:imboy/page/single/privacy_policy_page.dart';
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
  group('PrivacyPolicyPage 渲染', () {
    testWidgets('PP-1 渲染不崩溃且含分节标题', (tester) async {
      await _pump(tester, const PrivacyPolicyPage());
      expect(find.byType(PrivacyPolicyPage), findsOneWidget);
      expect(find.text('1. 信息收集'), findsOneWidget);
      expect(find.text('5. 用户权利'), findsOneWidget);
    });

    testWidgets('PP-2 深色模式渲染不崩溃', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const PrivacyPolicyPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('6. 账号注销'), findsOneWidget);
    });
  });

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
