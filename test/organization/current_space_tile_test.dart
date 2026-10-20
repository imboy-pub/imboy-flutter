import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/current_space_tile.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _PersonalExperience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.personal;
}

void main() {
  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 1.3, 2.0, 3.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('space title fits navigation $width $scale $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final router = _router();
          addTearDown(router.dispose);
          await tester.pumpWidget(_app(router, scale, brightness));
          await tester.pumpAndSettle();
          final title = find.descendant(
            of: find.byType(CurrentSpaceTile),
            matching: find.byType(Text),
          );
          final titleRect = tester.getRect(title);
          final navRect = tester.getRect(find.byType(CupertinoNavigationBar));
          expect(titleRect.top, greaterThanOrEqualTo(navRect.top));
          expect(titleRect.bottom, lessThanOrEqualTo(navRect.bottom));
          expect(titleRect.left, greaterThanOrEqualTo(navRect.left));
          expect(titleRect.right, lessThanOrEqualTo(navRect.right));
          final text = tester.widget<Text>(title);
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(find.text('Space picker'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const IosPageTemplate(
        title: '频道',
        middle: CurrentSpaceTile(heading: '频道'),
        actions: [Icon(CupertinoIcons.search), Icon(CupertinoIcons.add)],
        body: Center(child: Text('Content')),
      ),
    ),
    GoRoute(
      path: kOrganizationPickerPath,
      builder: (_, _) => const Scaffold(body: Text('Space picker')),
    ),
  ],
);

Widget _app(GoRouter router, double scale, Brightness brightness) =>
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        productExperienceProvider.overrideWith(_PersonalExperience.new),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 47),
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
        ),
      ),
    );
