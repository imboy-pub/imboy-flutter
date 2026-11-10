import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/settings/widget/settings_notice_card.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  const title = '请妥善保存备份与恢复信息';
  const paragraphs = [
    '恢复前请确认账号，并保存当前设备上仍然可用的备份。',
    '请完整阅读这些说明，再继续处理当前设备上的聊天记录。',
  ];
  for (final brightness in Brightness.values) {
    testWidgets('设置说明卡 $brightness：两倍字号完整换行且正文对比度至少4.5', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pageColor = brightness == Brightness.dark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: pageColor,
            body: ListView(
              children: const [
                SettingsNoticeCard(
                  title: title,
                  icon: Icons.warning_amber_outlined,
                  accent: AppColors.iosOrange,
                  paragraphs: paragraphs,
                ),
              ],
            ),
          ),
        ),
      );
      final card = tester.widget<Card>(find.byType(Card));
      final background = Color.alphaBlend(card.color!, pageColor);
      final cardBounds = tester.getRect(find.byType(Card)).inflate(0.01);
      for (final label in [title, ...paragraphs]) {
        final finder = find.text(label);
        final text = tester.widget<Text>(finder);
        final foreground = Color.alphaBlend(text.style!.color!, background);
        final first = foreground.computeLuminance();
        final second = background.computeLuminance();
        final contrast = first > second
            ? (first + 0.05) / (second + 0.05)
            : (second + 0.05) / (first + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
        );
        final bounds = tester.getRect(finder);
        expect(cardBounds.contains(bounds.topLeft), isTrue);
        expect(cardBounds.contains(bounds.bottomRight), isTrue);
      }
      await tester.ensureVisible(find.text(paragraphs.last));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text(paragraphs.last)).bottom,
        lessThanOrEqualTo(480.01),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
