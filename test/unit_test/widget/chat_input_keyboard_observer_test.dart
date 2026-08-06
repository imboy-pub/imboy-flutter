// ChatInput 键盘 observer 生命周期 Widget 测试 /
// ChatInput keyboard observer lifecycle widget tests
//
// 回归目标 / Regression target:
//   旧实现在 build() 中每帧调用 _setupKeyboardListener()，每次都 new 一个
//   ChatKeyboardObserver 并 addObserver，从不 removeObserver → observer 泄漏 +
//   重建风暴（键盘每开合一次触发 N 次 setState，长群聊越用越卡）。
//   修复后：observer 只在 initState 注册一次，dispose 时 removeObserver。
//
//   本测试通过 ChatInputState.keyboardObserverAddCount（@visibleForTesting）
//   断言：无论 build 触发多少次，注册次数恒为 1。
//
// 运行方式 / How to run:
//   flutter test test/widget/chat_input_keyboard_observer_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';

Widget _wrap(ValueNotifier<double> composerHeight) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ChatInput(
          type: 'C2C',
          peerId: 'peer_1',
          composerHeight: composerHeight,
          onSendPressed: (_) async => true,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('observer 只在 initState 注册一次，多次 rebuild 不重复注册', (tester) async {
    // Arrange
    final composerHeight = ValueNotifier<double>(0);
    addTearDown(composerHeight.dispose);

    // Act: 首次挂载 + 多次强制 rebuild（复用同一个 State，build 重跑但
    // initState 不重跑）
    await tester.pumpWidget(_wrap(composerHeight));
    await tester.pump();
    await tester.pumpWidget(_wrap(composerHeight));
    await tester.pumpWidget(_wrap(composerHeight));
    await tester.pump();

    // Assert
    final state = tester.state<ChatInputState>(find.byType(ChatInput));
    expect(
      state.keyboardObserverAddCount,
      1,
      reason: '每帧重复注册 observer 属于回归 bug，注册次数应恒为 1',
    );
    // 丝滑动画基础设施仍在：输入框正常渲染
    expect(find.byKey(const Key('chat_message_input')), findsOneWidget);
  });

  testWidgets('dispose 时 removeObserver，不抛异常', (tester) async {
    // Arrange
    final composerHeight = ValueNotifier<double>(0);
    addTearDown(composerHeight.dispose);
    await tester.pumpWidget(_wrap(composerHeight));
    await tester.pump();

    // Act: 卸载触发 dispose
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // Assert: 卸载后不再存在该 widget，且未抛异常
    expect(find.byType(ChatInput), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
