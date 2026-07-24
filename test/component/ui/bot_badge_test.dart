import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/i18n/strings.g.dart';

/// BotBadge 三态渲染测试（透明 AI 披露的核心组件）。
///
/// account_type 契约：0=真人不渲染 / 1=AI / 2=官方 / 未知兜底不渲染。
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('BotBadge', () {
    testWidgets('BB-1 accountType=0 真人不渲染任何徽章', (tester) async {
      await _pump(tester, const BotBadge(accountType: 0));

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('BB-2 accountType=1 渲染 AI 徽章（sparkles 图标 + 文字）', (
      tester,
    ) async {
      await _pump(tester, const BotBadge(accountType: 1));

      expect(find.byIcon(CupertinoIcons.sparkles), findsOneWidget);
      expect(find.text(t.agent.badgeAi), findsOneWidget);
    });

    testWidgets('BB-3 accountType=2 渲染官方徽章（seal 图标 + 文字）', (tester) async {
      await _pump(tester, const BotBadge(accountType: 2));

      expect(find.byIcon(CupertinoIcons.checkmark_seal_fill), findsOneWidget);
      expect(find.text(t.agent.badgeOfficial), findsOneWidget);
    });

    testWidgets('BB-4 未知 accountType 兜底不渲染', (tester) async {
      await _pump(tester, const BotBadge(accountType: 9));

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('BB-5 compact 模式仅图标不带文字，Semantics 标签仍完整', (tester) async {
      await _pump(tester, const BotBadge(accountType: 1, compact: true));

      expect(find.byIcon(CupertinoIcons.sparkles), findsOneWidget);
      expect(find.text(t.agent.badgeAi), findsNothing);
      expect(find.bySemanticsLabel(t.agent.badgeAiA11y), findsOneWidget);
    });
  });
}
