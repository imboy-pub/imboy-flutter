// ComposerField 共享富输入组件 Widget 测试 /
// ComposerField shared rich composer widget tests
//
// 覆盖三条关键行为 / Covers three key behaviours:
//   1. 输入超过 warnThreshold 时字数计数变警示色（iosOrange）
//   2. 点击表情按钮展开 EmojiPicker 面板
//   3. 光标 selection 无效(-1) 时插入表情不抛 RangeError
//
// 运行 / Run:
//   flutter test test/widget/composer_field_test.dart

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/theme/default/app_colors.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('输入超过 warnThreshold 时计数变警示色', (tester) async {
    // Arrange：上限 10、警示阈值 5
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        ComposerField(controller: controller, maxLength: 10, warnThreshold: 5),
      ),
    );

    // 阈值内：非警示色
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    Text counter = tester.widget<Text>(
      find.byKey(const Key('composer_counter')),
    );
    expect(counter.data, '3/10');
    expect(counter.style?.color, isNot(AppColors.iosOrange));

    // Act：超过阈值
    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();

    // Assert：计数变警示色
    counter = tester.widget<Text>(find.byKey(const Key('composer_counter')));
    expect(counter.data, '8/10');
    expect(counter.style?.color, AppColors.iosOrange);
  });

  testWidgets('点击表情按钮展开表情面板', (tester) async {
    // Arrange
    await tester.pumpWidget(_wrap(const ComposerField(maxLength: 100)));
    expect(find.byType(EmojiPicker), findsNothing);

    // Act：点击表情按钮
    await tester.tap(find.byKey(const Key('composer_emoji_button')));
    await tester.pump();

    // Assert：面板展开
    expect(find.byType(EmojiPicker), findsOneWidget);
  });

  testWidgets('光标无效(-1) 时插入表情不崩溃且追加到末尾', (tester) async {
    // Arrange：文本已存在但从未聚焦，selection 为 -1（无效）
    final controller = TextEditingController(text: 'hi');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(ComposerField(controller: controller, maxLength: 100)),
    );
    final state = tester.state<ComposerFieldState>(find.byType(ComposerField));
    expect(controller.selection.start, -1); // 前置条件：无效光标

    // Act：无效光标下插入表情
    state.debugInsertEmoji('😀');
    await tester.pump();

    // Assert：不抛异常，表情追加到末尾
    expect(tester.takeException(), isNull);
    expect(controller.text, 'hi😀');
  });
}
