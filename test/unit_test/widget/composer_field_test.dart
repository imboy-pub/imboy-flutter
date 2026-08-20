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

    // 阈值内：计数隐藏（消除常驻 "0/N" 噪音，精修后仅接近阈值才出现）
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.byKey(const Key('composer_counter')), findsNothing);

    // Act：达到/超过阈值
    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();

    // Assert：计数出现且变警示色
    final counter = tester.widget<Text>(
      find.byKey(const Key('composer_counter')),
    );
    expect(counter.data, '8/10');
    expect(counter.style?.color, AppColors.iosOrange);
  });

  testWidgets('点击表情按钮展开表情面板', (tester) async {
    // Arrange
    await tester.pumpWidget(_wrap(const ComposerField(maxLength: 100)));
    expect(find.byType(EmojiPicker), findsNothing);

    // Act：点击表情按钮
    // emoji_picker_flutter 的 initState 会经 getRecentEmojis 排一个
    // 0 时长 Timer（emoji_picker_internal_utils.dart:103），必须推进假
    // 时钟让其触发，否则 teardown 报 pending timer。先 pump 建帧，
    // 再推进假时间消化 Timer 链。
    await tester.tap(find.byKey(const Key('composer_emoji_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Assert：面板展开
    expect(find.byType(EmojiPicker), findsOneWidget);
  });

  testWidgets('聚焦时边框变品牌蓝、失焦复原', (tester) async {
    // Arrange：内建 focusNode 场景
    await tester.pumpWidget(_wrap(const ComposerField(maxLength: 100)));

    Border borderOf() {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return (container.decoration! as BoxDecoration).border! as Border;
    }

    // 失焦态：非品牌蓝、细描边
    expect(borderOf().top.color, isNot(AppColors.primary));
    expect(borderOf().top.width, 0.5);

    // Act：聚焦输入框
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Assert：品牌蓝高亮 + 加粗描边（精修后 1.5）
    expect(borderOf().top.color, AppColors.primary);
    expect(borderOf().top.width, 1.5);
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

  // 多行创作区（朋友圈发布/频道撰写）：表情按钮不再并排独占右侧 44pt 一列，
  // 而是浮在右下角，输入框必须撑满整宽。Stack 少了 fit: passthrough 时
  // TextField 只拿到 loose 约束会缩宽 —— 这条测试就是钉住那个回归。
  testWidgets('多行模式下输入框撑满整宽，表情按钮浮于右下', (tester) async {
    const boxWidth = 300.0;
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: boxWidth,
          child: ComposerField(minLines: 5, maxLines: 10),
        ),
      ),
    );

    final fieldWidth = tester.getSize(find.byType(TextField)).width;
    final borderWidth = 1.5 * 2; // 聚焦态描边占宽，autofocus=false 时为 0.5*2
    expect(fieldWidth, greaterThan(boxWidth - borderWidth - 1));

    // 表情按钮贴在输入框右下角，而非纵向居中独占一列
    final fieldRect = tester.getRect(find.byType(TextField));
    final btnRect = tester.getRect(
      find.byKey(const Key('composer_emoji_button')),
    );
    expect(btnRect.right, closeTo(fieldRect.right, 1.0));
    expect(btnRect.bottom, closeTo(fieldRect.bottom, 1.0));
  });

  // 单行输入条（聊天）保持并排布局：按钮在右，输入框让出按钮宽度。
  testWidgets('单行模式下表情按钮仍并排在右侧', (tester) async {
    const boxWidth = 300.0;
    await tester.pumpWidget(
      _wrap(const SizedBox(width: boxWidth, child: ComposerField(maxLines: 1))),
    );

    final fieldRect = tester.getRect(find.byType(TextField));
    final btnRect = tester.getRect(
      find.byKey(const Key('composer_emoji_button')),
    );
    expect(fieldRect.right, lessThanOrEqualTo(btnRect.left + 1));
  });
}
