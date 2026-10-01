import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show NavigationBar, NavigationDestination;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/page/error/init_error_page.dart';
import 'package:imboy/page/welcome/welcome_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实登录与个人、企业空间切换', (tester) async {
    const api = String.fromEnvironment('API_BASE_URL_OVERRIDE');
    const account = String.fromEnvironment('TEST_SYNTHETIC_ACCOUNT');
    const password = String.fromEnvironment('TEST_SYNTHETIC_PASSWORD');
    expect(Platform.isAndroid, isTrue);
    expect(app.appEnv, 'local');
    expect(Uri.parse(api).host, '127.0.0.1');
    expect(account, 'synthetic_enterprise_mobile');
    expect(password, isNotEmpty);
    final package = await PackageInfo.fromPlatform();
    expect(package.packageName, 'pub.imboy.app.gzcustomer');

    final testErrorHandler = FlutterError.onError;
    await tester.runAsync(app.bootstrap);
    // Preserve the integration binding's failure reporting after app logging setup.
    FlutterError.onError = testErrorHandler;
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is WelcomePage ||
            widget.key == const Key('login_phone_input'),
      ),
    );
    if (find.byType(WelcomePage).evaluate().isNotEmpty) {
      await tester.tap(find.text(t.welcome.skip));
    }
    await waitFor(tester, find.byKey(const Key('login_phone_input')));
    expect(find.byType(InitErrorPage), findsNothing);
    final accountField = find.descendant(
      of: find.byKey(const Key('login_phone_input')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(accountField, account);
    await tester.enterText(
      find.byKey(const Key('login_password_input')),
      password,
    );
    await tester.pump();
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('login_submit_button')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget.key == const Key('tab_conversations') ||
            widget.key == const Key('enterprise-shell-bottom-nav'),
      ),
    );
    if (find
        .byKey(const Key('enterprise-shell-bottom-nav'))
        .evaluate()
        .isNotEmpty) {
      await selectPersonal(tester);
    }
    await waitFor(tester, find.byKey(const Key('tab_conversations')));
    for (final key in ['tab_contacts', 'tab_channel', 'tab_mine']) {
      final tab = find.byKey(Key(key));
      debugPrint(
        'NATIVE_UI_CHECK $key count=${tab.evaluate().length} '
        'channel=${AppFeatureRegistry.isEnabled(FeatureKeys.channel)} '
        'e2ee=${AppFeatureRegistry.isEnabled(FeatureKeys.e2ee)}',
      );
      expect(tab, findsOneWidget);
      await tester.tap(tab);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const Key('tab_conversations')));
    await waitFor(tester, find.byKey(const Key('workspace-shell-switcher')));
    await tester.tap(find.byKey(const Key('workspace-shell-switcher')));
    final enterprise = find.byKey(const Key('org-picker-tile-995101'));
    await waitFor(tester, enterprise);
    await tester.tap(enterprise);
    await waitFor(tester, find.byKey(const Key('enterprise-shell-bottom-nav')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('enterprise-shell-bottom-nav')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is NavigationDestination &&
              widget.label == t.organization.directory.title,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const Key('enterprise-shell-bottom-nav')),
          )
          .selectedIndex,
      1,
    );
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    expect(tester.takeException(), isNull);

    await selectPersonal(tester);
    expect(find.byKey(const Key('enterprise-shell-bottom-nav')), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> selectPersonal(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('workspace-shell-switcher')));
  final personal = find.byKey(const Key('org-picker-personal-entry'));
  await waitFor(tester, personal);
  await tester.tap(personal);
  await waitFor(tester, find.byKey(const Key('tab_conversations')));
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(finder, findsWidgets);
}
