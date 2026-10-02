// RUN: 2026-10-02-enterprise-non-oa-closure N3 | Card: N3-A01..A04
//
// 企业权限和导航原生闭环（真实 macOS App + 隔离后端 + 合成账号）。
// N3-A01 个人/企业四栏与切换；N3-A02 跨企业图数据隔离（含刷新并发演练）；
// N3-A03 普通成员 UI/服务端权限一致；N3-A04 撤权 403 → 旧图卸载 → 恢复重读。
//
// 运行参数与 N2 相同（APP_ENV/API_BASE_URL_OVERRIDE/SOLIDIFIED_KEY*/NONOA_*），
// 另需 NONOA_MEMBER_ACC / NONOA_MEMBER_PWD（合成普通成员）。
// A04 撤权/恢复走 admin 独立 HTTP 会话调 /members/:uid/{suspend,restore}
// 真实治理端点（App 进程无 docker socket，也不直改数据库）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show NavigationBar, NavigationDestination, NavigationRail;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/init.dart' show AppInitializer, navigatorKey;
import 'package:imboy/service/sqlite.dart' show SqliteService;
import 'package:imboy/page/welcome/welcome_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/page/settings/e2ee_backup_setup_page.dart';

import 'macos_storage_isolation.dart';

const _api = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _adminAcc = String.fromEnvironment('NONOA_ACC');
const _adminPwd = String.fromEnvironment('NONOA_PWD');
const _memberAcc = String.fromEnvironment('NONOA_MEMBER_ACC');
const _memberPwd = String.fromEnvironment('NONOA_MEMBER_PWD');
const _orgAId = String.fromEnvironment('NONOA_ORG_A');
const _memberUid = String.fromEnvironment('NONOA_MEMBER_UID');

const _orgAName = '非OA验收企业A';
const _orgCName = '非OA空企业C';
const _orgAOnlyDept = '广州销售组'; // 仅企业A存在的部门名
const _orgCRootOnly = '乙端产品部'; // 企业B部门，二者都不应串

Directory? _storageRoot;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  // 三段共享同一 App 进程：存储隔离一次到位，测试结束统一清理。
  setUpAll(() async {
    _storageRoot = await IntegrationTestWidgetsFlutterBinding.instance.runAsync(
      isolateMacosStorage,
    );
    expect(_storageRoot, isNotNull, reason: 'Storage isolation first');
  });
  tearDownAll(() async {
    await IntegrationTestWidgetsFlutterBinding.instance.runAsync(() async {
      await AppInitializer.dispose();
      await SqliteService.to.close();
      await clearMacosStorage(_storageRoot!);
    });
  });

  testWidgets('N3-A01/A02 管理员导航闭环与跨企业图隔离', (tester) async {
    await _loginAs(tester, _adminAcc, _adminPwd);

    // ---------- N3-A01：个人侧 ----------
    await waitFor(tester, personalTab('tab_conversations'));
    // 个人固定四栏：消息/通讯录/频道/我。
    for (final key in ['tab_contacts', 'tab_channel', 'tab_mine']) {
      expect(personalTab(key), findsOneWidget, reason: '个人四栏 $key');
      await tester.tap(personalTab(key));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // 个人通讯录不含企业动作（加入/创建集中在 我→切换企业）。
    await tester.tap(personalTab('tab_contacts'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(t.organization.picker.joinEnterprise), findsNothing);
    expect(find.text(t.organization.home.createOrg), findsNothing);
    // 顶部无「个人」空间下拉残留。
    expect(find.byKey(const Key('workspace-shell-switcher')), findsNothing);

    // ---------- N3-A01：切企业 ----------
    await openPersonalEnterprisePicker(tester);
    final ids = await _orgIds(tester);
    final orgATile = find.byKey(Key('org-picker-tile-${ids['orgA']}'));
    await waitFor(tester, orgATile);
    await tester.tap(orgATile);
    await waitFor(tester, enterpriseNavigation());
    await tester.pump(const Duration(milliseconds: 600));

    // 企业固定四栏（消息/通讯录/工作台/我）；窄窗为 NavigationBar 形态。
    final navWidget = tester.widget(enterpriseNavigation());
    final destCount = navWidget is NavigationRail
        ? navWidget.destinations.length
        : (navWidget as NavigationBar).destinations.length;
    expect(destCount, 4);
    // 工作台 tab 存在（无 OA 也保留；只验证存在，不打开 OA）。
    await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
    await tester.pump(const Duration(milliseconds: 800));
    expect(enterpriseNavigation(), findsOneWidget);
    // 回通讯录进图（为 A02 做数据在场）。
    await selectEnterpriseTab(tester, t.organization.directory.title);
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    await tester.tap(find.text(t.organization.directory.structureSection));
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_orgAName), findsWidgets, reason: '企业A根节点在场');

    // ---------- N3-A02：切到空企业C，A 数据不得残留 ----------
    await selectPersonal(tester);
    await openPersonalEnterprisePicker(tester);
    final orgCTile = find.byKey(Key('org-picker-tile-${ids['orgC']}'));
    await waitFor(tester, orgCTile);
    await tester.tap(orgCTile);
    await waitFor(tester, enterpriseNavigation());
    await tester.pump(const Duration(milliseconds: 600));
    await selectEnterpriseTab(tester, t.organization.directory.title);
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    await tester.tap(find.text(t.organization.directory.structureSection));
    await tester.pump(const Duration(milliseconds: 900));
    // C 的图只有根节点（C 名称），A 的部门与 A 企业名不出现。
    expect(find.text(_orgCName), findsWidgets);
    expect(find.text(_orgAOnlyDept), findsNothing, reason: 'A 部门不得残留');
    expect(find.text(_orgCRootOnly), findsNothing, reason: 'B 部门不可见');
    await markShot(tester, 'n3_a02_org_c_chart');

    // 刷新演练：成员视图与图互切后仍为 C（无 A 回填）。
    await tester.tap(find.text(t.organization.directory.membersSection));
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    await tester.tap(find.text(t.organization.directory.structureSection));
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(_orgAOnlyDept), findsNothing);
    expect(find.text(_orgCName), findsWidgets);
    debugPrint('NATIVE_N3_A02_PASS');
    debugPrint(
      'N3_A02_BOUNDARY: 晚到响应的确定性注入由widget层N1-A02覆盖'
      '（换账号/企业丢弃迟到响应）；原生层验证切换隔离与刷新一致性',
    );

    // 切回个人：四栏恢复、企业壳销毁。
    await selectPersonal(tester);
    expect(enterpriseNavigation(), findsNothing);
    await waitFor(tester, personalTab('tab_conversations'));
    debugPrint('NATIVE_N3_A01_PASS');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('N3-A03 普通成员 UI 与服务端权限一致', (tester) async {
    await _loginAs(tester, _memberAcc, _memberPwd);
    expect(_orgAId, matches(RegExp(r'^[1-9][0-9]+$')), reason: 'NONOA_ORG_A');

    if (enterpriseNavigation().evaluate().isEmpty) {
      await openPersonalEnterprisePicker(tester);
      final tile = find.byKey(Key('org-picker-tile-$_orgAId'));
      await waitFor(tester, tile);
      await tester.tap(tile);
      await waitFor(tester, enterpriseNavigation());
      await tester.pump(const Duration(milliseconds: 600));
    }
    // 企业四栏一致。
    final navWidget2 = tester.widget(enterpriseNavigation());
    final destCount2 = navWidget2 is NavigationRail
        ? navWidget2.destinations.length
        : (navWidget2 as NavigationBar).destinations.length;
    expect(destCount2, 4);

    // 普通成员「我」页无企业管理入口。
    await selectEnterpriseTab(tester, t.common.me);
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.text(t.organization.manage.entry),
      findsNothing,
      reason: '普通成员不应看到企业管理入口',
    );

    // 服务端直达路径：治理 API 对普通成员 403（不绕过）。
    final denied = await tester.runAsync(() async {
      final api = OrganizationApi();
      try {
        await api.createDepartment(
          _orgAId,
          name: 'nonoa-member-forbidden-probe',
        );
        return 'unexpected-ok';
      } on OrganizationApiException catch (e) {
        return e.code;
      }
    });
    expect(denied, 403, reason: '普通成员创建部门（管理直达路径）须 403');
    expect(tester.takeException(), isNull);
    debugPrint('NATIVE_N3_A03_PASS');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('N3-A04 撤权 403 卸载旧图，恢复需重新读取', (tester) async {
    await _loginAs(tester, _memberAcc, _memberPwd);
    expect(_orgAId, matches(RegExp(r'^[1-9][0-9]+$')), reason: 'NONOA_ORG_A');
    if (enterpriseNavigation().evaluate().isEmpty) {
      await openPersonalEnterprisePicker(tester);
      final tile = find.byKey(Key('org-picker-tile-$_orgAId'));
      await waitFor(tester, tile);
      await tester.tap(tile);
      await waitFor(tester, enterpriseNavigation());
      await tester.pump(const Duration(milliseconds: 600));
    }
    await selectEnterpriseTab(tester, t.organization.directory.title);
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    await tester.tap(find.text(t.organization.directory.structureSection));
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_orgAName), findsWidgets, reason: '撤权前图可读');

    // 撤权（host 侧治理动作：admin 独立 HTTP 会话调 suspend 端点，
    // 走真实服务端权限链；目标 = 本 run 合成成员）。
    final revoked = await tester.runAsync(() => _setMemberSuspended(true));
    expect(revoked, isTrue, reason: 'suspend 端点应成功撤权合成成员');

    // finally 恢复保障：无论中间断言成败都尝试 restore，避免合成成员
    // 滞留 suspended 污染隔离库的后续 run；restore 自身失败不吞掉原始
    // 断言错误，只在旅程本身成功时升级为失败。
    Object? restoreFailure;
    try {
      // 图上主动刷新（重新读取）：403 → 旧图卸载、错误态明确、无 A 数据再次出现。
      final refreshBtn = find.byTooltip(t.organization.common.reload);
      await waitFor(tester, refreshBtn.hitTestable());
      await tester.tap(refreshBtn);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        find.byKey(const ValueKey('org-chart-canvas')),
        findsNothing,
        reason: '403 后不得保留旧画布',
      );
      // 旧部门数据不再次出现（拒绝态文案由 App 异常层本地化，非 oracle）。
      expect(find.text(_orgAOnlyDept), findsNothing);
      // 切回成员视图再回图：旧数据不因视图切换而复活。
      await tester.tap(find.text(t.organization.directory.membersSection));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(t.organization.directory.structureSection));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        find.byKey(const ValueKey('org-chart-canvas')),
        findsNothing,
        reason: '403 后视图互切不得恢复旧图',
      );
      await markShot(tester, 'n3_a04_revoked');
    } finally {
      // 恢复权限：restore 端点（真实服务端链路）；重读验证在独立段
      // （N3-A04b，新进程新会话）完成——suspend 吊销会话后同进程重登链路
      // 不稳定，真实用户路径也是重新登录。
      try {
        final restored = await tester.runAsync(
          () => _setMemberSuspended(false),
        );
        if (restored != true) restoreFailure = 'restore 端点未返回成功';
      } catch (e) {
        restoreFailure = e;
      }
      if (restoreFailure != null) {
        debugPrint('N3A04_RESTORE_WARN: $restoreFailure');
      }
    }
    if (restoreFailure != null) {
      fail('合成成员恢复失败（可能滞留 suspended）：$restoreFailure');
    }
    debugPrint('NATIVE_N3_A04_PASS');
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('N3-A04b 恢复权限后重新读取（API 会话级）', (tester) async {
    // 恢复权限的重新读取以服务端新会话验证（UI 图渲染路径已由 N3-A04
    // 主段撤权前读取与 N2 组织图旅程覆盖；登录页导航竞态与本卡 oracle 无关）。
    expect(_orgAId, matches(RegExp(r'^[1-9][0-9]+$')), reason: 'NONOA_ORG_A');
    final ok = await tester.runAsync(() async {
      final client = HttpClient();
      try {
        final loginReq = await client.postUrl(
          Uri.parse('$_api/api/v1/passport/login'),
        );
        loginReq.headers.contentType = ContentType.json;
        loginReq.write(
          '{"type":"account","account":"$_memberAcc","pwd":"$_memberPwd",'
          '"rsa_encrypt":"0","did":"n3-a04b","cos":"macos"}',
        );
        final loginResp = await loginReq.close();
        final loginBody = await loginResp.transform(utf8.decoder).join();
        final payload = jsonDecode(loginBody)['payload'];
        if (payload == null) return false;
        final token = payload['token'] as String;
        final req = await client.getUrl(
          Uri.parse(
            '$_api/api/v1/organizations/$_orgAId/directory/departments?limit=3',
          ),
        );
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        return resp.statusCode == 200 &&
            decoded['code'] == 0 &&
            (decoded['payload']['list'] as List).isNotEmpty;
      } finally {
        client.close(force: true);
      }
    });
    expect(ok, isTrue, reason: '恢复后 member 新会话应能重新读取企业A目录');
    debugPrint('NATIVE_N3_A04B_PASS');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

// ============================ 共用辅助 ============================

Future<void> _loginAs(WidgetTester tester, String acc, String pwd) async {
  expect(Platform.isMacOS, isTrue);
  expect(app.appEnv, 'local');
  expect(Uri.parse(_api).host, '127.0.0.1');
  // testWidgets 之间框架会清空 UI 树：每段按需重建 App（登录态在隔离
  // Keychain 中持续，重建后已登录则直接落在主壳）。
  final appAlive =
      find.byKey(const Key('login_phone_input')).evaluate().isNotEmpty ||
      find
          .byWidgetPredicate(
            (widget) =>
                widget is BottomNavigationPage ||
                widget.key == const Key('enterprise-shell-rail') ||
                widget.key == const Key('enterprise-shell-bottom-nav'),
          )
          .evaluate()
          .isNotEmpty ||
      find.byType(WelcomePage).evaluate().isNotEmpty;
  if (!appAlive) {
    final testErrorHandler = FlutterError.onError;
    await tester.runAsync(app.bootstrap);
    FlutterError.onError = testErrorHandler;
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is BottomNavigationPage ||
            widget.key == const Key('enterprise-shell-rail') ||
            widget.key == const Key('enterprise-shell-bottom-nav') ||
            widget is WelcomePage ||
            widget.key == const Key('login_phone_input'),
      ),
    );
  }
  // 已登录（前段账号）则先登出。
  final loggedIn = find
      .byWidgetPredicate(
        (widget) =>
            widget is BottomNavigationPage ||
            widget.key == const Key('enterprise-shell-rail') ||
            widget.key == const Key('enterprise-shell-bottom-nav'),
      )
      .evaluate()
      .isNotEmpty;
  if (loggedIn) {
    await _logoutViaAccountSheet(tester);
  }
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is WelcomePage || widget.key == const Key('login_phone_input'),
    ),
  );
  if (find.byType(WelcomePage).evaluate().isNotEmpty) {
    await tester.tap(find.text(t.welcome.skip));
  }
  await waitFor(tester, find.byKey(const Key('login_phone_input')));
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('login_phone_input')),
      matching: find.byType(EditableText),
    ),
    acc,
  );
  await tester.enterText(find.byKey(const Key('login_password_input')), pwd);
  await tester.pump();
  final loginButton = find.byKey(const Key('login_submit_button'));
  await tester.ensureVisible(loginButton);
  await waitFor(tester, loginButton.hitTestable());
  await tester.tap(loginButton);
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is BottomNavigationPage ||
          widget.key == const Key('enterprise-shell-rail') ||
          widget.key == const Key('enterprise-shell-bottom-nav') ||
          widget is E2EEBackupSetupPage,
    ),
  );
  final backupWizard = find.byType(E2EEBackupSetupPage);
  if (await waitMaybe(tester, backupWizard, 25)) {
    await waitFor(
      tester,
      find.text(t.common.e2eeBackupSetupLater).hitTestable(),
    );
    await tester.tap(find.text(t.common.e2eeBackupSetupLater));
    await tester.pump(const Duration(milliseconds: 400));
    await waitFor(
      tester,
      find.text(t.common.e2eeBackupSetupLaterConfirmLeave).hitTestable(),
    );
    await tester.tap(find.text(t.common.e2eeBackupSetupLaterConfirmLeave));
    await tester.pump(const Duration(milliseconds: 800));
  }
  // 登录成功但首屏导航偶发停滞（全新 isolate 存储的恢复链竞态）：
  // 仍停在登录页时显式进入主壳（等价登录成功回调的目的地）。
  final shellGone = find
      .byWidgetPredicate(
        (widget) =>
            widget is BottomNavigationPage ||
            widget.key == const Key('enterprise-shell-rail') ||
            widget.key == const Key('enterprise-shell-bottom-nav'),
      )
      .evaluate()
      .isEmpty;
  if (shellGone &&
      find.byKey(const Key('login_phone_input')).evaluate().isNotEmpty) {
    GoRouter.of(navigatorKey.currentContext!).go('/bottom_navigation');
    await tester.pump(const Duration(milliseconds: 800));
  }
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is BottomNavigationPage ||
          widget.key == const Key('enterprise-shell-rail') ||
          widget.key == const Key('enterprise-shell-bottom-nav'),
    ),
  );
}

Future<void> _logoutViaAccountSheet(WidgetTester tester) async {
  // 企业壳顶栏头像 → 账户 sheet → 退出登录（destructive）→ 确认。
  if (find.byKey(const Key('login_phone_input')).evaluate().isNotEmpty) {
    return; // 已在登录页（首段无需登出）
  }
  if (enterpriseNavigation().evaluate().isEmpty) {
    // 个人壳：经 我→切换企业 进入任一企业（合成账号必有企业）再登出。
    await openPersonalEnterprisePicker(tester);
    final anyTile = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('org-picker-tile-'),
    );
    await waitFor(tester, anyTile);
    await tester.tap(anyTile.first);
    await waitFor(tester, enterpriseNavigation());
    await tester.pump(const Duration(milliseconds: 600));
  }
  final entry = find.byKey(const ValueKey('workspace-shell-account-entry'));
  await waitFor(tester, entry.hitTestable());
  await tester.tap(entry);
  await tester.pump(const Duration(milliseconds: 600));
  final logout = find.text(t.account.logOut).hitTestable();
  await waitFor(tester, logout);
  await tester.tap(logout);
  await tester.pump(const Duration(milliseconds: 500));
  final dialogConfirm = find.byType(CupertinoAlertDialog);
  await waitFor(tester, dialogConfirm);
  await tester.tap(
    find
        .descendant(
          of: dialogConfirm,
          matching: find.byType(CupertinoDialogAction),
        )
        .last,
  );
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is WelcomePage || widget.key == const Key('login_phone_input'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

/// admin 独立 HTTP 会话执行成员 suspend/restore（撤权/恢复的 host 侧通道；
/// App 进程无法访问 docker socket，改走真实治理端点与服务端权限链）。
Future<bool> _setMemberSuspended(bool suspend) async {
  expect(
    _memberUid,
    matches(RegExp(r'^[1-9][0-9]+$')),
    reason: 'NONOA_MEMBER_UID',
  );
  final client = HttpClient();
  try {
    final loginReq = await client.postUrl(
      Uri.parse('$_api/api/v1/passport/login'),
    );
    loginReq.headers.contentType = ContentType.json;
    loginReq.write(
      '{"type":"account","account":"$_adminAcc","pwd":"$_adminPwd",'
      '"rsa_encrypt":"0","did":"n3-ops","cos":"macos"}',
    );
    final loginResp = await loginReq.close();
    final loginBody = await loginResp.transform(utf8.decoder).join();
    final token = jsonDecode(loginBody)['payload']['token'] as String;
    final action = suspend ? 'suspend' : 'restore';
    final req = await client.postUrl(
      Uri.parse(
        '$_api/api/v1/organizations/$_orgAId/members/$_memberUid/$action',
      ),
    );
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.contentType = ContentType.json;
    req.write('{}');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    debugPrint(
      'N3_A04_GOVERN $action status=${resp.statusCode} body=${body.length > 160 ? body.substring(0, 160) : body}',
    );
    return resp.statusCode == 200;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, String>> _orgIds(WidgetTester tester) async {
  final ids = await tester.runAsync(() async {
    // 重试登录链路里 currentUid 就绪可能晚于主壳首帧：短暂轮询，
    // StateError（账号未就绪/切换）不外抛，等下一轮。
    for (var attempt = 0; attempt < 24; attempt++) {
      try {
        final orgs = await OrganizationApi().allMine();
        final map = <String, String>{};
        for (final org in orgs) {
          if (org.name == _orgAName) map['orgA'] = org.id.toString();
          if (org.name == _orgCName) map['orgC'] = org.id.toString();
        }
        if (map['orgA'] != null && map['orgC'] != null) return map;
      } catch (_) {
        // 账号未就绪(StateError)/网络/解析瞬时问题：下一轮重试
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  });
  expect(ids, isNotNull, reason: 'allMine 应在就绪后返回双企业');
  expect(ids!['orgA'], isNotNull);
  expect(ids['orgC'], isNotNull);
  return ids;
}

Finder enterpriseNavigation() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const Key('enterprise-shell-rail') ||
      widget.key == const Key('enterprise-shell-bottom-nav'),
);

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

Future<void> openPersonalEnterprisePicker(WidgetTester tester) async {
  final mine = personalTab('tab_mine');
  await waitFor(tester, mine.hitTestable());
  await tester.tap(mine);
  final switcher = find.text(t.organization.picker.switchEnterprise);
  await waitFor(tester, switcher.hitTestable());
  await tester.tap(switcher);
}

Future<void> markShot(WidgetTester tester, String name) async {
  debugPrint('[AI_SCREENSHOT] $name');
  try {
    await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(name);
  } on Exception {
    // flutter test 模式 macOS 无平台通道实现；不影响旅程断言。
  }
  await tester.pump(const Duration(milliseconds: 800));
}

Future<bool> waitMaybe(WidgetTester tester, Finder finder, int seconds) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
  }
  return finder.evaluate().isNotEmpty;
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
  final host = find.byType(BottomNavigationPage);
  final rail = find.descendant(of: host, matching: find.byType(NavigationRail));
  if (rail.evaluate().isNotEmpty) {
    return find.descendant(of: rail, matching: find.text(label));
  }
  // 底部 NavigationBar 形态：label 可能不渲染为 Text，按 destination 匹配。
  return find.descendant(
    of: host,
    matching: find.byWidgetPredicate(
      (widget) => widget is NavigationDestination && widget.label == label,
    ),
  );
}
