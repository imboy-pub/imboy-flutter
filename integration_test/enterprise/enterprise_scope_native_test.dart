import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        AlertDialog,
        BackButton,
        NavigationBar,
        NavigationDestination,
        Scrollable,
        TextButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/page/error/init_error_page.dart';
import 'package:imboy/page/welcome/welcome_page.dart';
import 'package:imboy/modules/organization/presentation/organization_member_detail_page.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/modules/organization/presentation/organization_detail_page.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('真实登录与个人、企业空间切换', (tester) async {
    const api = String.fromEnvironment('API_BASE_URL_OVERRIDE');
    const account = String.fromEnvironment('TEST_SYNTHETIC_ACCOUNT');
    const password = String.fromEnvironment('TEST_SYNTHETIC_PASSWORD');
    const rootDepartment = String.fromEnvironment('TEST_ROOT_DEPARTMENT');
    const childDepartment = String.fromEnvironment('TEST_CHILD_DEPARTMENT');
    expect(Platform.isAndroid, isTrue);
    expect(app.appEnv, 'local');
    expect(Uri.parse(api).host, '127.0.0.1');
    expect(account, 'synthetic_enterprise_mobile');
    expect(password, isNotEmpty);
    expect(rootDepartment, matches(RegExp(r'^[1-9][0-9]+$')));
    expect(childDepartment, matches(RegExp(r'^[1-9][0-9]+$')));
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
    final loginButton = find.byKey(const Key('login_submit_button'));
    await tester.ensureVisible(loginButton);
    await waitFor(tester, loginButton.hitTestable());
    await tester.tap(loginButton);
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

    final rootRow = find.byKey(Key('org-dir-dept-list-$rootDepartment'));
    final childRow = find.byKey(Key('org-dir-dept-list-$childDepartment'));
    final member = find.byKey(const Key('org-dir-member-995012'));
    await waitFor(tester, rootRow);
    expect(childRow, findsNothing);
    expect(member, findsNothing);
    await tester.tap(rootRow);
    await waitFor(tester, childRow);
    await tester.tap(childRow);
    await waitFor(tester, member);
    expect(find.text('合成员工甲'), findsWidgets);
    await tester.tap(member);
    await waitFor(tester, find.byType(OrganizationMemberDetailPage));
    expect(
      find.byKey(const Key('org-member-detail-im-profile')),
      findsOneWidget,
    );
    await backDirectory(tester);
    await waitFor(tester, member);
    await backDirectory(tester);
    await waitFor(tester, childRow);
    await backDirectory(tester);
    await waitFor(tester, rootRow);

    if (const bool.fromEnvironment('TEST_NATIVE_OA_SSO')) {
      await checkNativeOa(tester);
    }
    await selectPersonal(tester);
    expect(find.byKey(const Key('enterprise-shell-bottom-nav')), findsNothing);
    expect(tester.takeException(), isNull);
    await joinEnterprise(tester);
    await leaveEnterprise(tester);
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Future<void> checkNativeOa(WidgetTester tester) async {
  final workbench = find.descendant(
    of: find.byKey(const Key('enterprise-shell-bottom-nav')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is NavigationDestination &&
          widget.label == t.enterpriseOa.workbenchTitle,
    ),
  );
  await waitFor(tester, workbench.hitTestable());
  await tester.tap(workbench);
  final entry = find.byKey(const Key('workbench-application-intbe02-oa-sso'));
  await waitFor(tester, entry.hitTestable());
  await tester.tap(entry);
  await waitFor(tester, find.byType(WebViewWidget));
  final controller = tester
      .widget<WebViewWidget>(find.byType(WebViewWidget))
      .platform
      .params
      .controller;
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  Object? result;
  while (result != '"995011"' && DateTime.now().isBefore(deadline)) {
    result = await tester.runAsync(
      () => controller.runJavaScriptReturningResult(
        'document.body.dataset.nativeSso || "loading"',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(result, '"995011"');
  expect(tester.takeException(), isNull);
  final back = find.byType(BackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, entry.hitTestable());
  expect(find.byType(WebViewWidget), findsNothing);
  expect(tester.takeException(), isNull);
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
  if (finder.evaluate().isEmpty) {
    final pages = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString().endsWith('Page'),
    );
    debugPrint(
      'NATIVE_UI_WAIT pages=${pages.evaluate().map((e) => e.widget.runtimeType).join(',')}',
    );
  }
  expect(finder, findsWidgets);
}

Future<void> backDirectory(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  final back = find.byType(BackButton);
  await waitFor(tester, back);
  await tester.tap(back.last);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> joinEnterprise(WidgetTester tester) async {
  const code = String.fromEnvironment('TEST_JOIN_CODE');
  expect(code, matches(RegExp(r'^[A-Z0-9]{8}$')));
  await tester.tap(find.byKey(const Key('workspace-shell-switcher')));
  final join = find.byKey(const Key('org-picker-join-entry'));
  await waitFor(tester, join.hitTestable());
  expect(find.byKey(const Key('org-picker-tile-995102')), findsNothing);
  await tester.tap(join);
  final input = find.byKey(const Key('org-join-code-field'));
  await waitFor(tester, input.hitTestable());
  await tester.enterText(input, code);
  final submit = find.byKey(const Key('org-join-submit'));
  await tester.tap(submit);
  await waitFor(tester, find.byKey(const Key('org-join-org-name')));
  expect(find.textContaining('intbe02-org-b'), findsWidgets);
  await waitFor(tester, submit.hitTestable());
  await tester.tap(submit);
  final nav = find.byKey(const Key('enterprise-shell-bottom-nav'));
  await waitFor(tester, nav);
}

Future<void> leaveEnterprise(WidgetTester tester) async {
  final nav = find.byKey(const Key('enterprise-shell-bottom-nav'));
  await waitFor(tester, nav.hitTestable());
  await tester.tap(
    find.descendant(
      of: nav,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is NavigationDestination && widget.label == t.common.me,
      ),
    ),
  );
  final manage = find.text(t.organization.manage.entry);
  await waitFor(tester, manage.hitTestable());
  await tester.tap(manage);
  final leave = find.byKey(const Key('organization-detail-leave'));
  await waitFor(tester, find.text('intbe02-org-b'));
  final directoryScroll = find.descendant(
    of: find.byType(OrganizationDetailPage),
    matching: find.byType(Scrollable),
  );
  await waitFor(tester, directoryScroll.hitTestable());
  await tester.scrollUntilVisible(leave, 250, scrollable: directoryScroll);
  await waitFor(tester, leave.hitTestable());
  await tester.tap(leave);
  final dialog = find.byType(AlertDialog);
  await waitFor(tester, dialog);
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)).last,
  );
  await waitFor(tester, find.byType(OrganizationHomePage));
  await assertDeparture(tester);
  expect(tester.takeException(), isNull);
}

Future<void> assertDeparture(WidgetTester tester) async {
  await tester.runAsync(() async {
    final api = OrganizationApi();
    final mine = await api.allMine();
    expect(mine.map((org) => org.id), contains('995101'));
    expect(mine.map((org) => org.id), isNot(contains('995102')));
    await expectLater(
      api.detail('995102'),
      throwsA(
        isA<OrganizationApiException>().having(
          (e) => e.code,
          'permission',
          403,
        ),
      ),
    );
  });
  expect(tester.takeException(), isNull);
}
