import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/widget/bezier_container.dart';
import 'package:imboy/page/passport/widget/clip_painter.dart';
import 'package:imboy/page/passport/widget/fadeanimation.dart';

/// 纯装饰组件渲染测试（无 Riverpod / i18n 依赖）。
/// bezier_container / clip_painter / fadeanimation 均为零状态展示组件，
/// 仅验证渲染不崩溃 + 基本结构。
void main() {
  group('BezierContainer', () {
    testWidgets('BD-1 亮色模式渲染不崩溃并产出 ClipPath', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BezierContainer())),
      );
      expect(find.byType(BezierContainer), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('BD-2 暗色模式渲染不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(body: BezierContainer()),
        ),
      );
      expect(find.byType(BezierContainer), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
    });
  });

  group('ClipPainter', () {
    test('CP-1 getClip 返回非空 Path', () {
      final clipper = ClipPainter();
      final path = clipper.getClip(const Size(100, 200));
      expect(path, isNotNull);
      // 路径含裁剪边界点
      expect(path.getBounds().isEmpty, false);
    });

    test('CP-2 shouldReclip 恒为 true（静态裁剪）', () {
      final clipper = ClipPainter();
      expect(clipper.shouldReclip(ClipPainter()), true);
    });
  });

  group('FadeAnimation', () {
    testWidgets('FA-1 渲染 child 并包 AnimatedOpacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FadeAnimation(delay: 500, child: Text('hello'))),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('FA-2 不同 delay 仍正常渲染', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeAnimation(delay: 0, child: Icon(Icons.star)),
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });
}
