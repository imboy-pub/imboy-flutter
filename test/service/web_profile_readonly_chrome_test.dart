@TestOn('chrome')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/page/web_shell/web_shell_helper_panels.dart';
import 'package:imboy/page/web_shell/web_shell_route_params.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../fixtures/web_profile_readonly_cases.dart' as cases;

GoRouter _mineRouter(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/web_shell',
      builder: (_, state) {
        final selection =
            parseShellRouteParams(state.uri.queryParameters).selectedItem
                as MineSelection;
        return WebMineMinPanel(
          section: selection.section,
          logoutLabel: 'logout',
        );
      },
    ),
  ],
);

void main() {
  cases.main();

  testWidgets('unsupported Mine deep link leaves the detail pane empty', (
    tester,
  ) async {
    var profileReads = 0;
    final router = _mineRouter('/web_shell?tab=mine&id=unsupported');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((_) {
            profileReads++;
            return null;
          }),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.queryParameters['id'],
      'unsupported',
    );
    expect(profileReads, 0);
    expect(find.text(t.common.notLoggedIn), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mine privacy and settings URLs restore the Web settings pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final user = UserModel(uid: '990001', account: 'synthetic-account');
    var location = '/web_shell?tab=mine&id=privacy';
    for (final restoring in [false, true]) {
      final router = _mineRouter(location);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWith((_) => user)],
          child: TranslationProvider(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SettingPage>(find.byType(SettingPage)).webMode,
        isTrue,
      );
      expect(find.text(t.common.webReadOnlySettingsHint), findsOneWidget);

      if (!restoring) {
        router.go('/web_shell?tab=mine&id=settings');
        await tester.pumpAndSettle();
        expect(find.text(t.common.webReadOnlySettingsHint), findsOneWidget);
      }

      location = router.routeInformationProvider.value.uri.toString();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
