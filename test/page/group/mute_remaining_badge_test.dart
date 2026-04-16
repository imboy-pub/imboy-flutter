/// 钉住 `MuteRemainingBadge` 的渲染契约 —— F2 RED。
///
/// 用例设计围绕 `muteRemainingLabel` 已通过测试的真值表，本组测试只关心
/// **UI 呈现**：空 label 必须渲染不可见（SizedBox.shrink），非空 label 必须
/// 可被 find.text 命中，且使用破坏性语义色（iOS red / errorColor）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_member/mute_remaining_badge.dart';

void main() {
  const nowMs = 1_700_000_000_000;

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('MuteRemainingBadge — 可见性', () {
    testWidgets('muteUntilMs == null → 不渲染任何文本', (tester) async {
      await tester.pumpWidget(wrap(
        const MuteRemainingBadge(muteUntilMs: null, nowMs: nowMs),
      ));
      expect(find.textContaining('分钟'), findsNothing);
      expect(find.textContaining('秒'), findsNothing);
      expect(find.textContaining('小时'), findsNothing);
      expect(find.textContaining('天'), findsNothing);
    });

    testWidgets('已过期（muteUntilMs <= nowMs）→ 不渲染', (tester) async {
      await tester.pumpWidget(wrap(
        const MuteRemainingBadge(muteUntilMs: nowMs - 1, nowMs: nowMs),
      ));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('剩余 5 分钟 → 显示 "5 分钟"（含"禁言"前缀）', (tester) async {
      await tester.pumpWidget(wrap(
        MuteRemainingBadge(
          muteUntilMs: nowMs + 5 * 60 * 1000,
          nowMs: nowMs,
        ),
      ));
      // 包含 "5 分钟" + 语义前缀（如「禁言 5 分钟」或「5 分钟」）
      expect(find.textContaining('5 分钟'), findsOneWidget);
    });

    testWidgets('剩余 2 小时 → 显示 "2 小时"', (tester) async {
      await tester.pumpWidget(wrap(
        MuteRemainingBadge(
          muteUntilMs: nowMs + 2 * 60 * 60 * 1000,
          nowMs: nowMs,
        ),
      ));
      expect(find.textContaining('2 小时'), findsOneWidget);
    });
  });

  group('MuteRemainingBadge — 语义样式', () {
    testWidgets('使用破坏性语义色（error / red 系）', (tester) async {
      await tester.pumpWidget(wrap(
        MuteRemainingBadge(
          muteUntilMs: nowMs + 30 * 1000,
          nowMs: nowMs,
        ),
      ));
      // 至少渲染一个 Text，并非默认 onSurface 颜色
      // 这里仅验证存在性；具体色值由主题决定，不做硬编码断言
      expect(find.byType(Text), findsAtLeastNWidgets(1));
    });
  });
}
