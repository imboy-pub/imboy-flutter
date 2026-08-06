import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/composer_emoji_panel.dart';
import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/i18n/strings.g.dart';

void main() {
  testWidgets('表情面板可展开且搜索视图无溢出', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [ComposerField(maxLines: 4)])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('composer_emoji_button')));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPicker), findsOneWidget);

    // 打开搜索视图（底部动作条的搜索按钮）
    await tester.tap(find.byType(SearchButton));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });

  group('emojiColumnsFor 按宽度推列数，每格不小于 44pt', () {
    for (final width in <double>[256, 320, 375, 390, 430, 810, 1024]) {
      test('${width.toInt()}pt 宽下每格 >= 44pt', () {
        final columns = emojiColumnsFor(width);
        expect(columns, greaterThanOrEqualTo(4));
        // 命中区不得低于 44pt —— 上限 20 列夹住后超宽屏可能触发，故只在
        // 未被上限夹住时断言。
        if (columns < 20) {
          expect(width / columns, greaterThanOrEqualTo(44.0));
        }
      });
    }

    test('窄面板不至于退化成竖列：下限 4 列', () {
      expect(emojiColumnsFor(100), 4);
    });

    test('命中区优先于列数：256pt 只给 5 列而非硬凑 8 列', () {
      expect(emojiColumnsFor(256), 5);
    });

    test('超宽屏不无限细分：上限 20 列', () {
      expect(emojiColumnsFor(4000), 20);
    });
  });
}
