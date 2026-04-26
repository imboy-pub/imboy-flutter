/// Phase 2.3 — WebDropTarget widget 测试
///
/// 覆盖：
/// - 默认（isDragging=false）只渲染 child
/// - isDragging=true 渲染 overlay (hint + icon)
/// - 自定义 dragIcon 生效
/// - 主题响应（light/dark）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/web_drop_target.dart';

const _kChild = Center(
  key: ValueKey('drop-child'),
  child: Text('CHILD'),
);

Future<void> _pump(
  WidgetTester tester, {
  bool isDragging = false,
  String dragHint = 'Drop to upload',
  IconData dragIcon = Icons.cloud_upload_outlined,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: WebDropTarget(
          isDragging: isDragging,
          dragHint: dragHint,
          dragIcon: dragIcon,
          child: _kChild,
        ),
      ),
    ),
  );
}

void main() {
  group('WebDropTarget — 默认（isDragging=false）', () {
    testWidgets('仅渲染 child', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('drop-child')), findsOneWidget);
      expect(find.text('CHILD'), findsOneWidget);
    });

    testWidgets('不渲染 overlay 提示', (tester) async {
      await _pump(tester, dragHint: 'TEST_HINT');
      expect(find.text('TEST_HINT'), findsNothing);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    });
  });

  group('WebDropTarget — isDragging=true', () {
    testWidgets('渲染 overlay (hint + 默认 icon)', (tester) async {
      await _pump(
        tester,
        isDragging: true,
        dragHint: '释放上传',
      );
      expect(find.text('释放上传'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('child 仍渲染（overlay 叠加在上层）', (tester) async {
      await _pump(tester, isDragging: true);
      expect(find.byKey(const ValueKey('drop-child')), findsOneWidget);
    });

    testWidgets('自定义 dragIcon 生效', (tester) async {
      await _pump(
        tester,
        isDragging: true,
        dragIcon: Icons.attach_file,
      );
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    });
  });

  group('WebDropTarget — 主题响应', () {
    testWidgets('light theme 不抛异常', (tester) async {
      await _pump(tester, isDragging: true, brightness: Brightness.light);
      expect(find.byType(WebDropTarget), findsOneWidget);
    });

    testWidgets('dark theme 不抛异常', (tester) async {
      await _pump(tester, isDragging: true, brightness: Brightness.dark);
      expect(find.byType(WebDropTarget), findsOneWidget);
    });
  });

}
