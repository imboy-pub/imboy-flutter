import 'package:feedback/feedback.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/router/routes/mine_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/feedback/feedback_page.dart';
import 'package:imboy/page/mine/feedback/feedback_provider.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

class _FeedbackFixture extends FeedbackPageNotifier {
  @override
  FeedbackPageState build() => FeedbackPageState(
    itemList: [
      FeedbackModel.fromJson({
        'feedback_id': 1,
        'body': 'synthetic-feedback',
        'type': 'bugReport',
        'status': 1,
        'created_at': '2026-11-11T00:00:00Z',
        'updated_at': '2026-11-11T00:00:00Z',
      }),
    ],
  );

  @override
  Future<void> loadData({int page = 1, int size = 1000}) async {}
}

void main() {
  testWidgets('反馈路由跟随 App 明暗主题，保留页面配色及编辑器文字对比度', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final mode = ValueNotifier(ThemeMode.dark);
    addTearDown(mode.dispose);
    final router = GoRouter(initialLocation: '/feedback', routes: mineRoutes());
    addTearDown(router.dispose);
    final light = ThemeData(brightness: Brightness.light);
    final dark = ThemeData(brightness: Brightness.dark);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedbackPageProvider.overrideWith(_FeedbackFixture.new)],
        child: TranslationProvider(
          child: ValueListenableBuilder(
            valueListenable: mode,
            builder: (context, selected, child) => MaterialApp.router(
              theme: light,
              darkTheme: dark,
              themeMode: selected,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );

    for (final brightness in [
      Brightness.dark,
      Brightness.light,
      Brightness.dark,
    ]) {
      tester.platformDispatcher.platformBrightnessTestValue =
          brightness == Brightness.dark ? Brightness.light : Brightness.dark;
      mode.value = brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
      await tester.pumpAndSettle();
      final page = find.byType(FeedbackPage);
      final expected = brightness == Brightness.dark ? dark : light;
      final pageTheme = Theme.of(tester.element(page));
      expect(pageTheme.brightness, brightness);
      expect(pageTheme.colorScheme, expected.colorScheme);
      expect(
        pageTheme.textTheme.bodyLarge!.color,
        expected.textTheme.bodyLarge!.color,
      );
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: page, matching: find.byType(Scaffold)),
      );
      expect(scaffold.backgroundColor, AppColors.getSurfaceGrouped(brightness));
      final history = tester.widget<CupertinoListTile>(
        find.descendant(of: page, matching: find.byType(CupertinoListTile)),
      );
      expect(
        history.backgroundColor,
        brightness == Brightness.dark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
      );
      final plugin = tester.widget<BetterFeedback>(find.byType(BetterFeedback));
      expect(plugin.themeMode, mode.value);
      expect(plugin.theme!.brightness, brightness);
      expect(plugin.theme!.colorScheme, expected.colorScheme);
      expect(
        plugin.theme!.bottomSheetTextInputStyle.color,
        expected.textTheme.bodyLarge!.color,
      );
      expect(find.text('synthetic-feedback'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
