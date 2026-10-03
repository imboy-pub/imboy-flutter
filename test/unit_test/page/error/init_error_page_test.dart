// #95 init 失败兜底页行为锁定
//
// - 失败时渲染错误标题 / 原始异常详情 / 重试按钮（替代永久白屏）
// - 点击重试触发 onRetry，重试期间按钮禁用防重复触发
import 'dart:async';

import 'package:flutter/material.dart';
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

  testWidgets('重试失败后恢复可点击并允许第二次成功重试', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      InitErrorPage(
        error: StateError('initial failure'),
        onRetry: () async {
          calls++;
          if (calls == 1) throw StateError('retry failure');
        },
      ),
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('同一帧快速连续点击只启动一次重试', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await tester.pumpWidget(
      InitErrorPage(
        error: StateError('initial failure'),
        onRetry: () async {
          calls++;
          await gate.future;
        },
      ),
    );
    await tester.tap(find.text('重试'));
    await tester.tap(find.text('重试'));
    expect(calls, 1);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('页面卸载后重试完成不更新已销毁状态', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await tester.pumpWidget(
      InitErrorPage(
        error: StateError('initial failure'),
        onRetry: () => gate.future,
      ),
    );
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(InitErrorPage), findsNothing);
  });
}
