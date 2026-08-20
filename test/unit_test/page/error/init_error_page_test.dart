// #95 init 失败兜底页行为锁定
//
// - 失败时渲染错误标题 / 原始异常详情 / 重试按钮（替代永久白屏）
// - 点击重试触发 onRetry，重试期间按钮禁用防重复触发
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/error/init_error_page.dart';

void main() {
  testWidgets('渲染标题、错误详情与重试按钮', (tester) async {
    await tester.pumpWidget(
      InitErrorPage(error: StateError('db corrupted'), onRetry: () async {}),
    );

    expect(find.text('应用初始化失败'), findsOneWidget);
    expect(find.textContaining('db corrupted'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('点击重试触发回调并进入重试中状态', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    await tester.pumpWidget(
      InitErrorPage(
        error: StateError('boom'),
        onRetry: () async {
          calls++;
          await gate.future;
        },
      ),
    );

    await tester.tap(find.text('重试'));
    await tester.pump();

    // 重试进行中：文案切换、按钮禁用
    expect(calls, 1);
    expect(find.text('重试中…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(calls, 1); // 未重复触发
    expect(find.text('重试'), findsOneWidget);
  });
}
