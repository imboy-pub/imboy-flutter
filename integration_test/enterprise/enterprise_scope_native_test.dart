import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        AlertDialog,
        BackButton,
        IconButton,
        ListTile,
        NavigationBar,
        NavigationDestination,
        NavigationRail,
        Scrollable,
        TextButton,
        TextField;
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
import 'package:imboy/modules/organization/presentation/organization_departments_page.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/service/group_file_service.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart' show AppInitializer;
import 'package:imboy/service/sqlite.dart' show SqliteService;

import 'macos_storage_isolation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('真实登录与个人、企业空间切换', (tester) async {
    const api = String.fromEnvironment('API_BASE_URL_OVERRIDE');
    const account = String.fromEnvironment('TEST_SYNTHETIC_ACCOUNT');
    const password = String.fromEnvironment('TEST_SYNTHETIC_PASSWORD');
    const rootDepartment = String.fromEnvironment('TEST_ROOT_DEPARTMENT');
    const childDepartment = String.fromEnvironment('TEST_CHILD_DEPARTMENT');
    expect(Platform.isAndroid || Platform.isMacOS, isTrue);
    expect(app.appEnv, 'local');
    expect(Uri.parse(api).host, '127.0.0.1');
    expect(account, 'synthetic_enterprise_mobile');
    expect(password, isNotEmpty);
    expect(rootDepartment, matches(RegExp(r'^[1-9][0-9]+$')));
    expect(childDepartment, matches(RegExp(r'^[1-9][0-9]+$')));
    final package = await PackageInfo.fromPlatform();
    expect(
      package.packageName,
      Platform.isMacOS ? 'pub.imboy.app' : 'pub.imboy.app.gzcustomer',
    );

    if (Platform.isMacOS) {
      final root = await tester.runAsync(isolateMacosStorage);
      expect(
        root,
        isNotNull,
        reason: 'Storage isolation must precede bootstrap',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await AppInitializer.dispose();
          await SqliteService.to.close();
          await clearMacosStorage(root!);
        });
      });
    }

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
            widget.key == enterpriseNavKey,
      ),
    );
    if (find.byKey(enterpriseNavKey).evaluate().isNotEmpty) {
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
    expect(find.byKey(const Key('workspace-shell-switcher')), findsNothing);
    await openPersonalEnterprisePicker(tester);
    final enterprise = find.byKey(const Key('org-picker-tile-995101'));
    await waitFor(tester, enterprise);
    await tester.tap(enterprise);
    await waitFor(tester, find.byKey(enterpriseNavKey));
    await tester.pump(const Duration(milliseconds: 500));
    await selectEnterpriseTab(tester, t.organization.directory.title);
    await tester.pump(const Duration(milliseconds: 500));
    expect(enterpriseSelectedIndex(tester), 1);
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

    if (const bool.fromEnvironment('TEST_NATIVE_ORG_GOVERNANCE')) {
      await checkNativeOrgGovernance(tester);
    }
    if (const bool.fromEnvironment('TEST_NATIVE_OA_SSO')) {
      await checkNativeOa(tester);
    }
    if (const bool.fromEnvironment('TEST_NATIVE_GROUP_FILE')) {
      await checkNativeGroupFile(tester);
    }
    await selectPersonal(tester);
    expect(find.byKey(enterpriseNavKey), findsNothing);
    expect(tester.takeException(), isNull);
    await joinEnterprise(tester);
    await leaveEnterprise(tester);
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Future<void> checkNativeGroupFile(WidgetTester tester) async {
  const groupId = '995301';
  const name = 'native-enterprise-file.txt';
  const body = 'synthetic native enterprise file';
  final created = await tester.runAsync(
    () => GroupFileService.to.uploadFile(
      groupId: groupId,
      fileName: name,
      fileBytes: body.codeUnits,
      fileType: 'text/plain',
    ),
  );
  expect(created, isNotNull);
  await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
  await waitFor(tester, find.text(t.chat.groupFile).hitTestable());
  await tester.tap(find.text(t.chat.groupFile));
  final group = find.byKey(const ValueKey('workspace-group-tile-995301'));
  await waitFor(tester, group.hitTestable());
  await tester.tap(group);
  await waitFor(tester, find.byType(GroupFilePage));
  await waitFor(tester, find.text(name).hitTestable());
  await tester.tap(find.text(name));
  await waitFor(tester, find.byType(WebViewWidget));
  await expectNativeFileBody(tester, body);
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, find.byType(GroupFilePage));
  await checkDeletedNativeFile(tester, groupId, name);
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, group.hitTestable());
  await backDirectory(tester);
}

Future<void> checkDeletedNativeFile(
  WidgetTester tester,
  String groupId,
  String name,
) async {
  final row = find
      .descendant(of: find.byType(GroupFilePage), matching: find.text(name))
      .hitTestable();
  await waitFor(tester, row);
  final payload = await tester.runAsync(
    () => GroupFileService.to.getFiles(groupId: groupId),
  );
  final files = (payload!['list'] as List).cast<Map<String, dynamic>>();
  final file = files.singleWhere((row) => row['file_name'] == name);
  expect(
    await tester.runAsync(() => GroupFileService.to.deleteFile(file['id'])),
    isTrue,
  );
  // Keep the stale row mounted: tapping it must reauthorize and refuse preview.
  await tester.tap(row);
  await waitFor(tester, find.text(t.common.groupFileOpenFailed));
  expect(find.byType(WebViewWidget), findsNothing);
  expect(tester.takeException(), isNull);
  debugPrint('NATIVE_GROUP_FILE_PREVIEW_AND_DELETION_DENIAL_PASS');
}

Future<void> expectNativeFileBody(WidgetTester tester, String body) async {
  final url = tester.widget<WebViewPage>(find.byType(WebViewPage)).url;
  final httpMatches = await tester.runAsync(() async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      final bytes = await response.fold<List<int>>(
        [],
        (all, part) => [...all, ...part],
      );
      debugPrint(
        'NATIVE_FILE_HTTP status=${response.statusCode} '
        'mime=${response.headers.contentType?.mimeType} bytes=${bytes.length}',
      );
      return response.statusCode == 200 &&
          response.headers.contentType?.mimeType == 'text/plain' &&
          String.fromCharCodes(bytes) == body;
    } finally {
      client.close(force: true);
    }
  });
  expect(httpMatches, isTrue);
  final controller = tester
      .widget<WebViewWidget>(find.byType(WebViewWidget))
      .platform
      .params
      .controller;
  await tester.pump(const Duration(milliseconds: 600));
  final currentUrl = await tester.runAsync(controller.currentUrl);
  expect(Uri.parse(currentUrl!).path, '/api/v1/attachment/content');
  // The download CSP sandbox forbids JavaScript; the host runner verifies
  // rendered text through Android accessibility instead of weakening the CSP.
  debugPrint('NATIVE_FILE_VISIBILITY_READY');
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
}

Future<void> checkNativeOrgGovernance(WidgetTester tester) async {
  await openNativeDepartments(tester);
  final create = find.byTooltip(t.organization.departments.createRootDept);
  await waitFor(tester, create.hitTestable());
  await tester.tap(create);
  await submitDepartmentName(tester, 'native-owner-created');
  await waitFor(tester, find.text('native-owner-created').hitTestable());
  await departmentAction(
    tester,
    'native-owner-created',
    t.organization.common.rename,
  );
  await submitDepartmentName(tester, 'native-owner-renamed');
  await waitFor(tester, find.text('native-owner-renamed').hitTestable());
  expect(find.text('native-owner-created'), findsNothing);
  await departmentAction(
    tester,
    'native-owner-renamed',
    t.organization.departments.archiveDept,
  );
  final dialog = find.byType(AlertDialog);
  await waitFor(tester, dialog);
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)).last,
  );
  await waitFor(tester, find.text('已归档').hitTestable());
  expect(tester.takeException(), isNull);
  await backDirectory(tester);
  await backDirectory(tester);
}

Future<void> openNativeDepartments(WidgetTester tester) async {
  await selectEnterpriseTab(tester, t.common.me);
  final manage = find.text(t.organization.manage.entry);
  await waitFor(tester, manage.hitTestable());
  await tester.tap(manage);
  final zone = find.byKey(const Key('organization-detail-zone-departments'));
  final scroll = find.descendant(
    of: find.byType(OrganizationDetailPage),
    matching: find.byType(Scrollable),
  );
  await waitFor(tester, scroll.hitTestable());
  await tester.scrollUntilVisible(zone, 250, scrollable: scroll);
  await tester.tap(zone.hitTestable());
  await waitFor(tester, find.byType(OrganizationDepartmentsPage));
}

Future<void> submitDepartmentName(WidgetTester tester, String name) async {
  final dialog = find.byType(AlertDialog);
  await waitFor(tester, dialog);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    name,
  );
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)).last,
  );
}

Future<void> departmentAction(
  WidgetTester tester,
  String name,
  String action,
) async {
  final row = find.ancestor(
    of: find.text(name),
    matching: find.byType(ListTile),
  );
  await tester.tap(find.descendant(of: row, matching: find.byType(IconButton)));
  await waitFor(tester, find.text(action).hitTestable());
  await tester.tap(find.text(action).hitTestable());
}

Future<void> checkNativeOa(WidgetTester tester) async {
  await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
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

Key get enterpriseNavKey => Key(
  Platform.isMacOS ? 'enterprise-shell-rail' : 'enterprise-shell-bottom-nav',
);

int enterpriseSelectedIndex(WidgetTester tester) {
  final nav = tester.widget(find.byKey(enterpriseNavKey));
  return nav is NavigationRail
      ? nav.selectedIndex!
      : (nav as NavigationBar).selectedIndex;
}

Future<void> selectEnterpriseTab(WidgetTester tester, String label) async {
  final nav = find.byKey(enterpriseNavKey);
  await waitFor(tester, nav);
  final widget = tester.widget(nav);
  final Finder tab;
  if (widget is NavigationRail) {
    expect(widget.destinations, hasLength(4));
    tab = find.descendant(of: nav, matching: find.text(label));
  } else {
    expect((widget as NavigationBar).destinations, hasLength(4));
    tab = find.descendant(
      of: nav,
      matching: find.byWidgetPredicate(
        (widget) => widget is NavigationDestination && widget.label == label,
      ),
    );
  }
  await waitFor(tester, tab.hitTestable());
  await tester.tap(tab);
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

Future<void> openPersonalEnterprisePicker(WidgetTester tester) async {
  final mine = find.byKey(const Key('tab_mine'));
  await waitFor(tester, mine.hitTestable());
  await tester.tap(mine);
  final switcher = find.text(t.organization.picker.switchEnterprise);
  await waitFor(tester, switcher.hitTestable());
  await tester.tap(switcher);
}

Future<void> joinEnterprise(WidgetTester tester) async {
  const code = String.fromEnvironment('TEST_JOIN_CODE');
  expect(code, matches(RegExp(r'^[A-Z0-9]{8}$')));
  await openPersonalEnterprisePicker(tester);
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
  final nav = find.byKey(enterpriseNavKey);
  await waitFor(tester, nav);
}

Future<void> leaveEnterprise(WidgetTester tester) async {
  await selectEnterpriseTab(tester, t.common.me);
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
