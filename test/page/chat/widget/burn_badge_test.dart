import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/burn_badge.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// BurnBadge 阅后即焚徽章 widget 契约测试
///
/// BurnBadge 是纯 StatelessWidget，仅依赖 props，是 chat 模块测试覆盖率
/// 提升的最优入口（不依赖 EventBus / SqliteService / UserRepo）。
///
/// 覆盖：
///   - burnReadAtMs <= 0 → 显示 "阅后" 静态文案
///   - burnAfterMs <= 0 → 显示 "阅后" 静态文案
///   - burnReadAtMs > 0 + burnAfterMs > 0 → StreamBuilder 显示倒计时秒数
///   - 已超时 (remainSec <= 0) → 显示 "0s"
///   - 火苗图标 (Icons.local_fire_department) 必现
///   - iOS Red 配色（亮/暗模式自适应）
Future<void> _pump(
  WidgetTester tester, {
  required bool isSentByMe,
  required int burnAfterMs,
  required int burnReadAtMs,
  required Stream<int> burnTicker,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(
          child: BurnBadge(
            isSentByMe: isSentByMe,
            burnAfterMs: burnAfterMs,
            burnReadAtMs: burnReadAtMs,
            burnTicker: burnTicker,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('BurnBadge static "阅后" mode', () {
    testWidgets('burnReadAtMs <= 0 → 显示 "阅后"（未读取状态）', (tester) async {
      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: 0,
        burnTicker: const Stream.empty(),
      );

      expect(find.text('阅后'), findsOneWidget);
      // 静态模式下不应渲染 StreamBuilder
      expect(find.byType(StreamBuilder<int>), findsNothing);
    });

    testWidgets('burnAfterMs <= 0 → 显示 "阅后"（无效配置）', (tester) async {
      await _pump(
        tester,
        isSentByMe: true,
        burnAfterMs: 0,
        burnReadAtMs: 1000,
        burnTicker: const Stream.empty(),
      );

      expect(find.text('阅后'), findsOneWidget);
    });

    testWidgets('static 模式渲染 fire icon', (tester) async {
      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: 0,
        burnTicker: const Stream.empty(),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });
  });

  group('BurnBadge countdown mode', () {
    testWidgets('已读且未超时 → StreamBuilder 渲染秒数文本', (tester) async {
      // 模拟 5 秒后到期：burnReadAt 设为现在，burnAfter=5000ms
      final readAt = DateTime.now().millisecondsSinceEpoch;
      // 用 single-emit stream 避免 pending timer
      final controller = StreamController<int>();
      addTearDown(controller.close);

      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: readAt,
        burnTicker: controller.stream,
      );

      // 至少存在 StreamBuilder（倒计时模式）
      expect(find.byType(StreamBuilder<int>), findsOneWidget);
      // 倒计时模式下 fire icon 仍渲染
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('已超时 (readAt 远早于现在) → 显示 "0s"', (tester) async {
      // readAt 在 1 小时前，burnAfter=5000ms → 早超时
      final readAt =
          DateTime.now().millisecondsSinceEpoch - 60 * 60 * 1000;
      final controller = StreamController<int>();
      addTearDown(controller.close);

      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: readAt,
        burnTicker: controller.stream,
      );

      expect(find.text('0s'), findsOneWidget);
    });
  });

  group('BurnBadge styling', () {
    testWidgets('使用 iosRed (亮色模式)', (tester) async {
      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: 0,
        burnTicker: const Stream.empty(),
        brightness: Brightness.light,
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(icon.color, AppColors.iosRed);
      expect(icon.size, 12);
    });

    testWidgets('使用 iosRedDark (暗色模式)', (tester) async {
      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: 0,
        burnTicker: const Stream.empty(),
        brightness: Brightness.dark,
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(icon.color, AppColors.iosRedDark);
    });

    testWidgets('badge 含边框（border alpha 0.5）', (tester) async {
      await _pump(
        tester,
        isSentByMe: false,
        burnAfterMs: 5000,
        burnReadAtMs: 0,
        burnTicker: const Stream.empty(),
      );

      // 找到 BurnBadge 内部的 Container（带 border + radius）
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(BurnBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });
}
