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
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/page/error/init_error_page.dart';
import 'package:imboy/page/settings/e2ee_backup_setup_page.dart'
    show E2EEBackupSetupPage;
import 'package:imboy/page/welcome/welcome_page.dart';
import 'package:imboy/modules/organization/presentation/organization_member_detail_page.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/modules/organization/presentation/organization_detail_page.dart';
import 'package:imboy/modules/organization/presentation/organization_departments_page.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/service/group_file_service.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart'
    show WorkspaceConversationModel;
import 'package:imboy/config/init.dart' show AppInitializer, navigatorKey;
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
    if (const bool.fromEnvironment('TEST_NATIVE_GUANGZHOU_PROFILE')) {
      for (final feature in [
        FeatureKeys.project,
        FeatureKeys.channelDiscover,
        FeatureKeys.location,
        FeatureKeys.e2ee,
      ]) {
        expect(AppFeatureRegistry.isEnabled(feature), isFalse);
      }
      for (final feature in [FeatureKeys.channel, FeatureKeys.moment]) {
        expect(AppFeatureRegistry.isEnabled(feature), isTrue);
      }
      debugPrint('NATIVE_GUANGZHOU_PROFILE_PASS');
    }
    const loginContinuation = bool.fromEnvironment(
      'TEST_NATIVE_LOGIN_CONTINUATION',
    );
    const directTarget = '/organization/995101/directory?from=login#org';
    final router = GoRouter.of(navigatorKey.currentContext!);
    if (loginContinuation) {
      router.go(directTarget);
      await tester.pump();
      await waitFor(tester, find.byKey(const Key('login_phone_input')));
    }
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
    if (loginContinuation) {
      await waitFor(
        tester,
        find.byKey(const Key('org_directory_search_input')),
      );
      expect(
        router.routeInformationProvider.value.uri.toString(),
        directTarget,
      );
      await waitFor(
        tester,
        find.byKey(Key('org-dir-dept-list-$rootDepartment')),
      );
      expect(tester.takeException(), isNull);
      debugPrint('NATIVE_LOGIN_ROUTE_CONTINUATION_PASS');
      router.go('/bottom_navigation');
      await tester.pump();
    }
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is BottomNavigationPage ||
            widget is WorkspaceShellPage ||
            widget.key == const Key('enterprise-shell-rail') ||
            widget.key == const Key('enterprise-shell-bottom-nav'),
      ),
    );
    await dismissE2eeBackupSetup(tester);
    if (enterpriseNavigation().evaluate().isNotEmpty ||
        find.byType(WorkspaceShellPage).evaluate().isNotEmpty) {
      await selectPersonal(tester);
    }
    await waitForPersonalTab(tester, 'tab_conversations');
    await dismissE2eeBackupSetup(tester);
    for (final key in ['tab_contacts', 'tab_channel', 'tab_mine']) {
      await waitForPersonalTab(tester, key);
      final tab = personalTab(key);
      // 瞬时浮层（snackbar/横幅）可能短暂盖住底栏 tab：等 hitTestable 再点，
      // 与 openPersonalEnterprisePicker 的防浮层模式一致。E2EE 备份引导在主
      // 界面稳定后才异步弹出（首次 tab 等待即被其遮挡，r8 实证）——每次
      // 等待前后都清一次。
      await waitForTabDismissingSetup(tester, tab);
      await tester.tap(tab.hitTestable().first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    expect(find.byKey(const Key('workspace-shell-switcher')), findsNothing);
    await openPersonalEnterprisePicker(tester);
    final enterprise = find.byKey(const Key('org-picker-tile-995101'));
    await waitFor(tester, enterprise);
    await tester.tap(enterprise);
    await waitFor(tester, enterpriseNavigation());
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
    if (const bool.fromEnvironment('TEST_NATIVE_WORKSPACE_UNREAD')) {
      await checkNativeWorkspaceUnread(tester);
    }
    if (const bool.fromEnvironment('TEST_NATIVE_WORKSPACE_CONTENT')) {
      await checkNativeGroupMessage(tester);
      await checkNativeChannelDiscussion(tester);
    }
    if (const bool.fromEnvironment('TEST_NATIVE_GROUP_FILE')) {
      await checkNativeGroupFile(tester);
    }
    await selectPersonal(tester);
    expect(enterpriseNavigation(), findsNothing);
    expect(tester.takeException(), isNull);
    await joinEnterprise(tester);
    await leaveEnterprise(tester);
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Future<void> checkNativeWorkspaceUnread(WidgetTester tester) async {
  // 真机 USB 链路偶发 503/瞬态断连（r1 实证：同请求 curl 200）——退避重试。
  List<WorkspaceConversationModel>? initial;
  for (var i = 0; i < 4; i++) {
    try {
      initial = await tester.runAsync(
        () => WorkspaceApi().conversations('995201'),
      );
      break;
    } on WorkspaceApiException catch (e) {
      if (i == 3) rethrow;
      debugPrint('NATIVE_WS_CONVERSATIONS_RETRY #$i err=$e');
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: 500 * (i + 1))),
      );
    }
  }
  expect(initial, isNotNull);
  expect(
    initial!.singleWhere((row) => row.group.groupId == 995301).unreadCount,
    2,
  );
  await selectEnterpriseTab(tester, t.chat.titleMessage);
  const badgeKey = ValueKey('workspace-unread-995301');
  final badge = find.byKey(badgeKey);
  await waitFor(tester, badge);
  final before = tester.widget<BadgeWidget>(badge);
  expect(before.showBadge, isTrue);
  expect((before.content! as Text).data, '2');
  final row = find.byKey(const ValueKey('workspace-message-995301'));
  await waitFor(tester, row.hitTestable());
  await tester.tap(row);
  await waitFor(tester, find.byType(ChatPage));
  await tester.pump(const Duration(milliseconds: 2500));
  // 诊断 dump：气泡文本经 GptMarkdown 渲染，失败时看不出实际内容——
  // 把屏上全部 Text/RichText 纯文本打出来取证（含 E2EE 占位文案情形）。
  final onScreen = find
      .byWidgetPredicate((w) => w is Text || w is RichText)
      .evaluate()
      .map((e) {
        final w = e.widget;
        if (w is Text) return w.data ?? w.textSpan?.toPlainText() ?? '<span>';
        return (w as RichText).text.toPlainText();
      })
      .where((s) => s.trim().isNotEmpty)
      .join(' | ');
  debugPrint(
    'NATIVE_CHAT_TEXTS ${onScreen.length > 1200 ? '${onScreen.substring(0, 1200)}…' : onScreen}',
  );
  for (final body in ['native unread one', 'native unread two']) {
    // 气泡文本经 GptMarkdown（RichText/TextSpan）渲染——find.text 默认不
    // 匹配 RichText，须开 findRichText（r11 实证 fetched=2 但 0 匹配）。
    final bubble = find.text(body, findRichText: true);
    await waitFor(tester, bubble);
    await tester.ensureVisible(bubble);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await waitForNativeGroupRead(tester);
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is BadgeWidget && widget.key == badgeKey && !widget.showBadge,
    ),
  );
  expect(tester.takeException(), isNull);
  debugPrint('NATIVE_WORKSPACE_UNREAD_READ_CURSOR_UI_PASS');
}

Future<void> waitForNativeGroupRead(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (true) {
    final rows = await tester.runAsync(
      () => WorkspaceApi().conversations('995201'),
    );
    if (rows!.singleWhere((row) => row.group.groupId == 995301).unreadCount ==
        0) {
      break;
    }
    expect(
      DateTime.now().isBefore(deadline),
      isTrue,
      reason: 'Visible messages must persist their read receipt',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  }
}

Future<void> checkNativeGroupMessage(WidgetTester tester) async {
  const body = 'synthetic native workspace message';
  await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
  await waitFor(
    tester,
    find.byKey(const ValueKey('workbench-official-website')),
  );
  expect(find.text('https://imboy.pub/'), findsOneWidget);
  await waitFor(tester, find.text(t.workspace.navGroups).hitTestable());
  await tester.tap(find.text(t.workspace.navGroups));
  final group = find.byKey(const ValueKey('workspace-group-tile-995301'));
  await waitFor(tester, group.hitTestable());
  await tester.tap(group);
  await waitFor(tester, find.byType(ChatPage));
  final chat = tester.widget<ChatPage>(find.byType(ChatPage));
  expect(chat.peerId, '995301');
  expect(chat.type, 'C2G');
  expect(AppFeatureRegistry.isEnabled(FeatureKeys.e2ee), isFalse);
  final input = find.byKey(const Key('chat_message_input'));
  await waitFor(tester, input.hitTestable());
  await tester.enterText(input, body);
  await tester.pump(const Duration(milliseconds: 450));
  final send = find.byKey(const ValueKey('send_button_inner')).hitTestable();
  await waitFor(tester, send);
  await tester.tap(send);
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is CupertinoTextField &&
          widget.key == const Key('chat_message_input') &&
          widget.controller?.text.isEmpty == true,
    ),
  );
  await waitFor(tester, find.text(body, findRichText: true));
  expect(tester.takeException(), isNull);
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, group.hitTestable());
  await backDirectory(tester);
  debugPrint('NATIVE_WORKSPACE_GROUP_MESSAGE_UI_PASS');
}

Future<void> checkNativeChannelDiscussion(WidgetTester tester) async {
  await waitFor(tester, find.text(t.channel.title).hitTestable());
  await tester.tap(find.text(t.channel.title));
  final channel = find.byKey(const ValueKey('workspace-channel-tile-995501'));
  await waitFor(tester, channel.hitTestable());
  await tester.tap(channel);
  await waitFor(tester, find.byType(WorkspaceChannelDetailPage));
  expect(
    tester.widget<ChannelDetailPage>(find.byType(ChannelDetailPage)).channelId,
    '995501',
  );
  await waitFor(tester, find.text('intbe02-ch'));
  expect(find.byType(ChatInput), findsNothing);
  final guide = find.byKey(const ValueKey('workspace-channel-discuss-guide'));
  await waitFor(tester, guide.hitTestable());
  await tester.tap(guide);
  await waitFor(
    tester,
    find.byKey(const ValueKey('workspace-group-tile-995301')),
  );
  await backDirectory(tester);
  await waitFor(tester, find.byType(WorkspaceChannelDetailPage));
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, channel.hitTestable());
  await backDirectory(tester);
  debugPrint('NATIVE_WORKSPACE_CHANNEL_DISCUSSION_UI_PASS');
}

Future<void> checkNativeGroupFile(WidgetTester tester) async {
  const groupId = '995301';
  const name = 'native-enterprise-file.txt';
  const body = 'synthetic native enterprise file';
  // Purge stale same-name uploads left by earlier failed rounds so the fresh
  // file is the only matching row (tap() below needs a unique target).
  while (true) {
    final before = await tester.runAsync(
      () => GroupFileService.to.getFiles(groupId: groupId),
    );
    final staleRows = (before!['list'] as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['file_name'] == name)
        .toList();
    if (staleRows.isEmpty) break;
    expect(
      await tester.runAsync(
        () => GroupFileService.to.deleteFile(staleRows.first['id']),
      ),
      isTrue,
    );
  }
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
  await tester.pumpAndSettle();
  expect(find.byType(WebViewWidget), findsNothing);
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
  const observationSeconds = int.fromEnvironment(
    'TEST_NATIVE_PREVIEW_OBSERVATION_SECONDS',
    defaultValue: 90,
  );
  final deadline = DateTime.now().add(Duration(seconds: observationSeconds));
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
  // scrollUntilVisible 的内部判定不含 hitTestable 过滤，且 BouncingScrollPhysics
  // 会在返回后回弹、把刚滚到的 tile 弹离 lazy 视口（视口外即不 build）——
  // 小步 drag 循环直到 tile 可命中再点（与防浮层 waitFor 模式同族）。
  for (var i = 0; i < 24 && zone.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 150));
  }
  await waitFor(tester, zone.hitTestable());
  await tester.tap(zone.hitTestable().first);
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

Finder enterpriseNavigation() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const Key('enterprise-shell-rail') ||
      widget.key == const Key('enterprise-shell-bottom-nav'),
);

int enterpriseSelectedIndex(WidgetTester tester) {
  final nav = tester.widget(enterpriseNavigation());
  return nav is NavigationRail
      ? nav.selectedIndex!
      : (nav as NavigationBar).selectedIndex;
}

Future<void> selectEnterpriseTab(WidgetTester tester, String label) async {
  final nav = enterpriseNavigation();
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
  await waitFor(tester, find.byType(BottomNavigationPage));
  await waitFor(tester, personalTab('tab_conversations'));
}

/// 等待个人空间目标 tab 就位：tab 循环中段 App 可能被路由切走（r5 实证
/// 检查 tab_channel 时 BottomNavigationPage 已不在树上，疑似残留的
/// 企业空间/深链导航在异步初始化完成后抢占路由）——若企业壳出现则切回
/// 个人空间重等；仍失败则 dump 页面栈取证后再断言。
Future<void> waitForPersonalTab(WidgetTester tester, String key) async {
  Finder tab = personalTab(key);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (tab.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    if (find.byType(E2EEBackupSetupPage).evaluate().isNotEmpty) {
      await dismissE2eeBackupSetup(tester);
    }
    if (enterpriseNavigation().evaluate().isNotEmpty) {
      debugPrint('NATIVE_PERSONAL_TAB_HEAL $key enterprise-shell-detected');
      await selectPersonal(tester);
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    tab = personalTab(key);
  }
  if (tab.evaluate().isEmpty) {
    final pages = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString().endsWith('Page'),
    );
    debugPrint(
      'NATIVE_PERSONAL_TAB_STUCK $key '
      'bottomNav=${find.byType(BottomNavigationPage).evaluate().length} '
      'rail=${find.byType(NavigationRail).evaluate().length} '
      'pages=${pages.evaluate().map((e) => e.widget.runtimeType).join(',')}',
    );
  }
  debugPrint(
    'NATIVE_UI_CHECK $key count=${tab.evaluate().length} '
    'channel=${AppFeatureRegistry.isEnabled(FeatureKeys.channel)} '
    'e2ee=${AppFeatureRegistry.isEnabled(FeatureKeys.e2ee)}',
  );
  expect(tab, findsOneWidget);
}

/// 等待目标 tab 可命中的同时，持续清理异步弹出的 E2EE 备份引导（fresh
/// 安装每次启动触发、整页盖住主界面，r8 实证首个 tab 等待被其遮挡）。
Future<void> waitForTabDismissingSetup(WidgetTester tester, Finder tab) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    if (find.byType(E2EEBackupSetupPage).evaluate().isNotEmpty) {
      await dismissE2eeBackupSetup(tester);
    }
    if (tab.hitTestable().evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
}

/// E2EE 备份引导（fresh 安装每次启动触发）会整页盖住主界面——点「稍后再说」
/// 并在确认框里确认离开，让主旅程继续。
Future<void> dismissE2eeBackupSetup(WidgetTester tester) async {
  if (find.byType(E2EEBackupSetupPage).evaluate().isEmpty) {
    return;
  }
  final later = find.text(t.common.e2eeBackupSetupLater).hitTestable();
  await waitFor(tester, later);
  await tester.tap(later.first);
  final confirm = find.text(t.common.e2eeBackupSetupLaterConfirmLeave);
  await waitFor(tester, confirm.hitTestable());
  await tester.tap(confirm.first);
  await tester.pump(const Duration(milliseconds: 400));
  debugPrint('NATIVE_E2EE_BACKUP_SETUP_DISMISSED');
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

Finder personalTab(String key) {
  final mobile = find.byKey(Key(key));
  if (mobile.evaluate().isNotEmpty) return mobile;
  final label = switch (key) {
    'tab_conversations' => t.chat.titleMessage,
    'tab_contacts' => t.organization.directory.title,
    'tab_channel' => t.channel.title,
    'tab_mine' => t.common.me,
    _ => throw ArgumentError.value(key),
  };
  final rail = find.descendant(
    of: find.byType(BottomNavigationPage),
    matching: find.byType(NavigationRail),
  );
  if (rail.evaluate().isNotEmpty) {
    expect(
      (rail.evaluate().single.widget as NavigationRail).destinations,
      hasLength(4),
    );
  }
  return find.descendant(of: rail, matching: find.text(label));
}

Future<void> openPersonalEnterprisePicker(WidgetTester tester) async {
  final mine = personalTab('tab_mine');
  await waitFor(tester, mine.hitTestable());
  await tester.tap(mine);
  final switcher = find.descendant(
    of: find.byType(MinePage),
    matching: find.text(t.organization.picker.switchEnterprise),
  );
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
  final nav = enterpriseNavigation();
  await waitFor(tester, nav);
}

Future<void> leaveEnterprise(WidgetTester tester) async {
  await selectEnterpriseTab(tester, t.common.me);
  // 入口 tile 对所有成员恒在，但标签按角色门控（canManage 才显示
  // 「企业管理」，普通成员显示企业 tab 文案）——按 key 定位，不断言文案。
  final manage = find.byKey(const Key('enterprise-mine-organization-entry'));
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
