import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/mine/mine_shortcut.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shortcut remains distinct from grouped page $brightness', (
      tester,
    ) async {
      final background = AppColors.getSurfaceGrouped(brightness);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              backgroundColor: background,
              body: Center(
                child: MineShortcut(
                  label: '收藏',
                  icon: CupertinoIcons.bookmark,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.widget<CupertinoButton>(find.byType(CupertinoButton));
      final surface = card.color!;
      expect(surface, isNot(background));
      expect(
        surface.computeLuminance(),
        greaterThan(background.computeLuminance()),
      );
      expect(
        surface,
        brightness == Brightness.dark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        background,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
