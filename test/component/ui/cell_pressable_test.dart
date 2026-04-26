import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/cell_pressable.dart';

/// 给定 brightness（亮/暗）渲染一个 CellPressable，便于断言主题感知
Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

ColoredBox _findColoredBox(WidgetTester tester) {
  return tester.widget<ColoredBox>(
    find.descendant(
      of: find.byType(CellPressable),
      matching: find.byType(ColoredBox),
    ),
  );
}

void main() {
  group('CellPressable', () {
    testWidgets('renders child untouched at idle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CellPressable(
            onTap: () {},
            child: const Text('hello'),
          ),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
      // idle 状态：高亮色透明
      expect(_findColoredBox(tester).color, Colors.transparent);
    });

    testWidgets('invokes onTap on tap up', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(
          CellPressable(
            onTap: () => tapCount++,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Text('tap me'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CellPressable));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets(
      'highlights with light theme color (~4% black) while pressed and '
      'restores to transparent on release',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CellPressable(
              onTap: () {},
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        );

        // 按下：startGesture + pump 让 onTapDown 生效
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CellPressable)),
        );
        await tester.pump();
        // pressed 状态：4% 黑（亮色主题）
        expect(
          _findColoredBox(tester).color,
          Colors.black.withValues(alpha: 0.04),
        );

        // 松开：onTapUp
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_findColoredBox(tester).color, Colors.transparent);
      },
    );

    testWidgets(
      'highlights with dark theme color (~6% white) while pressed',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CellPressable(
              onTap: () {},
              child: const SizedBox(width: 100, height: 50),
            ),
            brightness: Brightness.dark,
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CellPressable)),
        );
        await tester.pump();
        expect(
          _findColoredBox(tester).color,
          Colors.white.withValues(alpha: 0.06),
        );

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'restores to transparent when tap is cancelled (drag away)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CellPressable(
              onTap: () {},
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        );

        final cellCenter = tester.getCenter(find.byType(CellPressable));
        final gesture = await tester.startGesture(cellCenter);
        await tester.pump();
        expect(
          _findColoredBox(tester).color,
          Colors.black.withValues(alpha: 0.04),
        );

        // 拖出 cell 区域（>kTouchSlop）→ 触发 onTapCancel
        await gesture.moveBy(const Offset(0, 200));
        await tester.pump();
        // 预期高亮被清除
        expect(_findColoredBox(tester).color, Colors.transparent);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'when onTap and onLongPress are both null: ignores press '
      '(no highlight, no callback)',
      (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(
          _wrap(
            CellPressable(
              child: GestureDetector(
                // 外层 onTap=null 不响应；用一个内嵌 detector 做计数
                // 但注意：CellPressable 用 HitTestBehavior.opaque，
                // 内嵌 detector 不会被 hit。这里仅用于"如果 hit 到了就计数"。
                onTap: () => tapCount++,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        );

        // 按下：两个回调都 null 时 _enabled=false，不应触发 onTapDown 高亮
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CellPressable)),
        );
        await tester.pump();
        // 验证：高亮仍为 transparent（不触发 _setPressed(true)）
        expect(_findColoredBox(tester).color, Colors.transparent);

        await gesture.up();
        await tester.pumpAndSettle();

        // 验证：tap 不传给内嵌 detector（CellPressable 是 opaque 拦截）
        expect(tapCount, 0);
      },
    );

    testWidgets('invokes onLongPress after long press timer fires', (
      tester,
    ) async {
      var longPressCount = 0;
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(
          CellPressable(
            onTap: () => tapCount++,
            onLongPress: () => longPressCount++,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      await tester.longPress(find.byType(CellPressable));
      await tester.pumpAndSettle();

      // 长按触发 onLongPress 而非 onTap
      expect(longPressCount, 1);
      expect(tapCount, 0);
    });

    testWidgets(
      'highlights while long-pressing and clears after long press ends',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CellPressable(
              onLongPress: () {},
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CellPressable)),
        );
        await tester.pump();
        // 按下立即高亮
        expect(
          _findColoredBox(tester).color,
          Colors.black.withValues(alpha: 0.04),
        );

        // 等待长按阈值（>500ms）
        await tester.pump(const Duration(milliseconds: 600));
        // 长按触发期间仍然高亮
        expect(
          _findColoredBox(tester).color,
          Colors.black.withValues(alpha: 0.04),
        );

        // 抬起：onLongPressEnd 清除高亮
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_findColoredBox(tester).color, Colors.transparent);
      },
    );

    testWidgets(
      'when only onLongPress is provided (no onTap): highlights and '
      'long-press still works',
      (tester) async {
        var longPressCount = 0;
        await tester.pumpWidget(
          _wrap(
            CellPressable(
              onLongPress: () => longPressCount++,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        );

        // _enabled = true 因为 onLongPress 非 null → 应该高亮
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CellPressable)),
        );
        await tester.pump();
        expect(
          _findColoredBox(tester).color,
          Colors.black.withValues(alpha: 0.04),
        );

        // 长按触发回调
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(longPressCount, 1);
      },
    );
  });
}
