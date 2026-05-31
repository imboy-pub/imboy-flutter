import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/chat_input_height_listener.dart';

/// ChatInputHeightListener 渲染 + 高度同步契约测试（TypeA 纯 StatefulWidget）
void main() {
  Future<void> pump(
    WidgetTester tester,
    ValueNotifier<double> notifier,
    double childHeight,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputHeightListener(
              composerHeight: notifier,
              // Duration.zero → 走同步路径，便于断言
              animationDuration: Duration.zero,
              child: SizedBox(height: childHeight, width: 200),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('渲染 child 不崩溃', (tester) async {
    final notifier = ValueNotifier<double>(52.0);
    await pump(tester, notifier, 120);
    expect(find.byType(ChatInputHeightListener), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('postFrame 后将测量高度同步到 composerHeight', (tester) async {
    final notifier = ValueNotifier<double>(52.0);
    await pump(tester, notifier, 120);
    // 等待 addPostFrameCallback 执行测量
    await tester.pump();
    expect(notifier.value, 120.0);
  });
}
