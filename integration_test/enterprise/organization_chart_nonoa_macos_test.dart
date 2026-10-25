// Native organization journey: owned backend and synthetic data on macOS/Android.
// Run with --dart-define-from-file=<restricted external defines.json>.
// A04_NATIVE_INPUTS=true additionally requires A04_OWNED_BUNDLE and actual host
// window resizing, key events and chart scroll; printed READY markers are bounded.
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        IconButton,
        NavigationBar,
        NavigationDestination,
        NavigationRail,
        Slider,
        Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/init.dart'
    show AppInitializer, navigatorKey, currentFontSize;
import 'package:imboy/service/sqlite.dart' show SqliteService;
import 'package:imboy/page/welcome/welcome_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:imboy/theme/default/font_types.dart' show FontSizeOption;

import 'macos_storage_isolation.dart';
import 'a04_native_inputs.dart';
import 'a04_directory_fault_adapter.dart';

import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

const _api = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _account = String.fromEnvironment('NONOA_ACC');
const _password = String.fromEnvironment('NONOA_PWD');
const _expectedUid = String.fromEnvironment('NONOA_UID');
const _orgAName = '非OA验收企业A';
const _orgBDept = '乙端产品部';
const _orgCName = '非OA空企业C';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('N2 图形组织架构真实原生非OA旅程', (tester) async {
    expect(Platform.isMacOS || Platform.isAndroid, isTrue);
    expect(app.appEnv, 'local');
    expect(Uri.parse(_api).host, '127.0.0.1');
    expect(_account, isNotEmpty);
    expect(_password, isNotEmpty);
    final faults = A04DirectoryFaultAdapter();
    A04ObservedDirectorySource? observedDirectory;
    if (a04NativeInputs) {
      await tester.runAsync(verifyA04Bundle);
      app_http.HttpClient.adapterForTest = faults;
      addTearDown(() {
        app_http.HttpClient.adapterForTest = null;
        faults.close(force: true);
      });
    }

    final root = await tester.runAsync(isolateNativeStorage);
    expect(root, isNotNull, reason: 'Storage isolation must precede bootstrap');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await AppInitializer.dispose();
        await SqliteService.to.close();
        await clearMacosStorage(root!);
      });
    });

    final testErrorHandler = FlutterError.onError;
    await tester.runAsync(app.bootstrap);
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
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login_phone_input')),
        matching: find.byType(EditableText),
      ),
      _account,
    );
    await tester.enterText(
      find.byKey(const Key('login_password_input')),
      _password,
    );
    await tester.pump();
    final loginButton = find.byKey(const Key('login_submit_button'));
    await tester.ensureVisible(loginButton);
    await waitFor(tester, loginButton.hitTestable());
    await tester.tap(loginButton);
    // 登录成功；E2EE 备份向导由会话页异步查询后经 rootNavigator 推入
    //（有密钥+未完成备份即触发），出现时机晚于主壳首帧。
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is BottomNavigationPage ||
            widget.key == const Key('enterprise-shell-rail') ||
            widget.key == const Key('enterprise-shell-bottom-nav') ||
            '${widget.runtimeType}' == 'E2EEBackupSetupPage',
      ),
    );
    // 向导是合成账号的必然首启路径：等待其出现（至多 25s）后走
    // 「稍后再说 → 确认离开」；markPrompted 保证同会话不重推。
    final backupWizard = find.byWidgetPredicate(
      (widget) => '${widget.runtimeType}' == 'E2EEBackupSetupPage',
    );
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
      expect(backupWizard, findsNothing, reason: '备份向导应已离开');
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
    await markShot(tester, 'n2_00_after_login');

    expect(_expectedUid, matches(RegExp(r'^[1-9][0-9]+$')));
    expect(UserRepoLocal.to.currentUid, _expectedUid);

    // 组织 id 与部门名 → id 映射（真实 API，授权链路内）。
    final ids = await tester.runAsync(() async {
      final orgs = await OrganizationApi().allMine();
      final orgA = orgs.singleWhere((o) => o.name == _orgAName);
      final orgC = orgs.singleWhere((o) => o.name == _orgCName);
      final directory = OrganizationApi();
      Future<Map<String, String>> collect(String? parentId) async {
        final page = await directory.directoryDepartments(
          organizationId: orgA.id,
          parentId: parentId,
          limit: 100,
        );
        return {for (final d in page.list) d.name: d.id.toString()};
      }

      final roots = <String, String>{};
      var cursor = await collect(null);
      roots.addAll(cursor);
      // 根下 60 部门分页：继续取满（limit<=100 单页可容，仍显式消费游标）。
      var page = await directory.directoryDepartments(
        organizationId: orgA.id,
        limit: 100,
      );
      while (page.hasMore == true) {
        page = await directory.directoryDepartments(
          organizationId: orgA.id,
          cursor: page.cursor,
          limit: 100,
        );
        roots.addAll({for (final d in page.list) d.name: d.id.toString()});
      }
      final sales = await collect(roots['销售中心']);
      final tech = await collect(roots['技术中心']);
      final platform = await collect(tech['平台架构组']);
      return {
        'orgA': orgA.id.toString(),
        'orgC': orgC.id.toString(),
        'sales': roots['销售中心']!,
        'tech': roots['技术中心']!,
        'gz': sales['广州销售组']!,
        'platform': tech['平台架构组']!,
        'storage': platform['存储小组']!,
        'rootCount': roots.length.toString(),
        'rootIds': roots.values.join(','),
      };
    });
    expect(ids, isNotNull);
    // 103 个根部门（8 主 + 95 填充）真实可读：超过 chart 请求的 limit=100，
    // 必须消费签名游标翻第二页，漏页即断言失败。
    expect(ids!['rootCount'], '103');
    debugPrint('N2_IDS orgA=${ids['orgA']} orgC=${ids['orgC']}');

    // ============================ N2-A01 ============================
    if (enterpriseNavigation().evaluate().isNotEmpty) {
      await selectPersonal(tester);
    }
    await waitFor(tester, personalTab('tab_conversations'));
    // 个人四栏固定（消息/通讯录/频道/我）。
    for (final key in ['tab_contacts', 'tab_channel', 'tab_mine']) {
      expect(personalTab(key), findsOneWidget);
    }
    await markShot(tester, 'n2_a01_personal_four_tabs');

    await openPersonalEnterprisePicker(tester);
    final orgATile = find.byKey(Key('drawer-space-${ids['orgA']}'));
    await waitFor(tester, orgATile);
    await tester.tap(orgATile);
    await waitFor(tester, enterpriseNavigation());
    await tester.pump(const Duration(milliseconds: 500));
    if (a04NativeInputs) {
      await verifyA04Workspace(tester);
      await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
      await waitFor(tester, find.byType(EnterpriseWorkbenchPage));
    }
    await selectEnterpriseTab(tester, t.organization.directory.title);
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    if (a04NativeInputs && Platform.isMacOS) {
      await verifyA04Keyboard(
        tester,
        find.byKey(const Key('org_directory_search_input')),
      );
    }
    // 企业微信式：组织架构从首屏分段降级为页面级入口行（→ 全屏二级页）。
    expect(find.byKey(const Key('org-directory-chart-entry')), findsOneWidget);
    expect(
      find.text(t.organization.directory.structureSection),
      findsOneWidget,
    );
    await markShot(tester, 'n2_a01_directory_members_view');

    // 「组织架构」入口行 → 二级页图形视图。
    await tester.tap(find.text(t.organization.directory.structureSection));
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    await tester.pump(const Duration(milliseconds: 400));
    for (final id in ids['rootIds']!.split(',')) {
      await waitFor(tester, find.byKey(ValueKey('org-chart-node-$id')));
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(
              'org-chart-node-',
            ),
      ),
      findsNWidgets(104),
    );
    // 真实企业名作为根节点标题。
    expect(find.text(_orgAName), findsWidgets);
    expect(find.text(t.organization.chart.gestureHint), findsOneWidget);
    await markShot(tester, 'n2_a01_chart_root');

    // 展开两层：销售中心 → 广州销售组。
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-expand-${ids['sales']}')),
    );
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['gz']}')));
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-expand-${ids['tech']}')),
    );
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['platform']}')));
    // 只有授权节点：企业B（乙端产品部）不可见。
    expect(find.text(_orgBDept), findsNothing);
    expect(find.byKey(const ValueKey('org-chart-canvas')), findsOneWidget);
    await markShot(tester, 'n2_a01_chart_two_levels');

    // 点击子部门 → 成员视图定位到该部门（路径正确）。
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-node-${ids['gz']}')),
    );
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    await tester.pump(const Duration(milliseconds: 600));
    // 成员视图恢复（图卸载），标题含部门链路。
    expect(find.byKey(const ValueKey('org-chart-canvas')), findsNothing);
    expect(find.text('广州销售组'), findsWidgets);
    expect(find.text('非OA成员壹零零二'), findsWidgets);
    await markShot(tester, 'n2_a01_department_members_path');
    debugPrint('NATIVE_N2_A01_PASS');

    // ============================ N2-A02 ============================
    // A01 点图中部门已 pop 回目录页；重新进入组织架构二级页。
    // 点图中部门会 pop 回传路径令目录页下钻（isRoot=false，架构入口行仅
    // 根态展示）——先经面包屑回企业根再重进架构页。
    await tester.tap(find.byKey(const ValueKey('org-directory-path-0')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(t.organization.directory.structureSection));
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    await tester.pump(const Duration(milliseconds: 400));
    // 二级页每次进入重新拉取授权快照（不保留上个实例的展开态，与
    // 「撤权后不得恢复旧节点」的安全模型一致）——重新展开两层恢复现场，
    // 供 A04 宽树用例继续使用。
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['sales']}')));
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-expand-${ids['sales']}')),
    );
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['gz']}')));
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-expand-${ids['tech']}')),
    );
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['platform']}')));

    Matrix4 matrix() => tester
        .widget<InteractiveViewer>(
          find.byKey(const ValueKey('org-chart-canvas')),
        )
        .transformationController!
        .value;
    double scale() => matrix().getMaxScaleOnAxis();

    final initialScale = scale();
    // 按钮放大。
    await tester.tap(find.byKey(const ValueKey('org-chart-zoom-in')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), greaterThan(initialScale));
    expectScaleLabel(scale());
    final zoomed = scale();
    // 按钮缩小回位。
    await tester.tap(find.byKey(const ValueKey('org-chart-zoom-out')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), lessThan(zoomed));
    expectScaleLabel(scale());
    await markShot(tester, 'n2_a02_button_zoom');

    // 真实双指张开（两指针背向移动 = 触控板/触屏捏合的事件流）。
    final canvasCenter = tester.getCenter(
      find.byKey(const ValueKey('org-chart-canvas')),
    );
    final beforePinch = scale();
    final f1 = await tester.startGesture(canvasCenter - const Offset(40, 0));
    final f2 = await tester.startGesture(canvasCenter + const Offset(40, 0));
    await f1.moveBy(const Offset(-60, 0));
    await f2.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), greaterThan(beforePinch));
    expectScaleLabel(scale());
    await f1.up();
    await f2.up();
    await markShot(tester, 'n2_a02_pinch_zoom');

    // 拖动平移（横纵方向）。
    final beforeDrag = matrix().clone();
    await tester.drag(
      find.byKey(const ValueKey('org-chart-canvas')),
      const Offset(120, 80),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(matrix().storage[12], isNot(beforeDrag.storage[12]));
    expect(matrix().storage[13], isNot(beforeDrag.storage[13]));
    await markShot(tester, 'n2_a02_drag_pan');

    // 适应窗口：视图复位、根节点可找回，工具栏始终可操作。
    final beforeFit = scale();
    await tester.tap(find.byKey(const ValueKey('org-chart-fit')));
    await tester.pump(const Duration(seconds: 1));
    expect(scale(), lessThan(beforeFit), reason: 'fit 之后比例应回落到适配窗口');
    expect(
      find.byKey(const ValueKey('org-chart-zoom-in')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-chart-node-')).hitTestable(),
      findsOneWidget,
    );
    expectScaleLabel(scale());
    await markShot(tester, 'n2_a02_fit_reset');

    // 折叠：子部门从图中移除。
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-expand-${ids['sales']}')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(Key('org-chart-node-${ids['gz']}')), findsNothing);
    await markShot(tester, 'n2_a02_collapse');
    debugPrint('NATIVE_N2_A02_PASS');

    // 窄视口（约400逻辑像素）无溢出、工具栏可操作。
    if (a04NativeInputs) {
      await verifyA04Viewport(tester);
    } else {
      await tester.binding.setSurfaceSize(const Size(400, 800));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('org-chart-zoom-in')).hitTestable(),
      findsOneWidget,
      reason: '窄视口下工具栏仍可操作',
    );
    await markShot(tester, 'n2_a03_surface_400');

    // 宽视口。
    if (a04NativeInputs && Platform.isAndroid) {
      debugPrint('V32_A04_ANDROID_DESKTOP_INPUTS_WAIVED_NOT_PASS');
    } else if (a04NativeInputs) {
      await verifyA04Window(tester, narrow: false);
      await verifyA04Trackpad(
        tester,
        find.byKey(const ValueKey('org-chart-canvas')),
      );
    } else {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await markShot(
      tester,
      Platform.isAndroid ? 'n2_a03_phone' : 'n2_a03_surface_1440',
    );
    await tester.binding.setSurfaceSize(null);
    await tester.pump(const Duration(milliseconds: 400));

    // 暗色模式（App 内真实切换：/dark_model 页选择暗色）。
    final router = GoRouter.of(navigatorKey.currentContext!);
    router.push('/dark_model');
    await waitFor(tester, find.byType(CupertinoSwitch));
    // 「浅色/暗色」固定项仅在「跟随系统」关闭时渲染；全新存储默认关闭。
    // 若默认开启则先关掉开关，让固定项出现。
    final switchWidget = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    if (switchWidget.value) {
      await tester.tap(find.byType(CupertinoSwitch).first.hitTestable().first);
      await tester.pump(const Duration(milliseconds: 500));
    }
    // 滚动到暗色项（页面最后一个可点 tile）并整行点击。
    final darkRow = find.byType(CupertinoListTile).last;
    await waitFor(tester, darkRow);
    await tester.ensureVisible(darkRow);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(darkRow.hitTestable().first);
    await tester.pump(const Duration(milliseconds: 500));
    // 选中标记：tapDarkItem(3) 置 selectIndex=3 → 暗色行 trailing 勾选。
    expect(
      find.byIcon(CupertinoIcons.check_mark),
      findsWidgets,
      reason: '暗色项应显示选中标记（tap 生效的直接证据）',
    );
    final popped = navigatorKey.currentContext!;
    GoRouter.of(popped).pop();
    await tester.pump(const Duration(milliseconds: 600));
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    final isDarkNow =
        Theme.of(navigatorKey.currentContext!).brightness == Brightness.dark;
    expect(isDarkNow, isTrue, reason: '暗色模式切换后主题应为深色');
    expect(tester.takeException(), isNull);
    expect(find.text(_orgAName), findsWidgets);
    await markShot(tester, 'n2_a03_dark_chart');
    // 恢复浅色（避免影响后续断言）。
    GoRouter.of(navigatorKey.currentContext!).push('/dark_model');
    await waitFor(tester, find.byType(CupertinoListTile));
    final tiles = find.byType(CupertinoListTile).evaluate().length;
    final lightRow = find.byType(CupertinoListTile).at(tiles - 2);
    await tester.ensureVisible(lightRow);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(lightRow.hitTestable().first);
    await tester.pump(const Duration(milliseconds: 500));
    GoRouter.of(navigatorKey.currentContext!).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await checkMaximumFontSize(tester);
    if (a04NativeInputs) {
      debugPrint(
        Platform.isAndroid
            ? 'V32_A04_ANDROID_VIEWPORT_APP_FONT_PASS macOS=WAIVED_NOT_PASS'
            : 'V32_A04_WINDOW_FONT_KEYBOARD_SCROLL_PASS',
      );
    } else {
      debugPrint(
        'NATIVE_N2_A03_PARTIAL: physical window/native inputs not executed',
      );
    }

    // 多页/宽树/深层：根下 60 部门分页加载（图内自动翻页），抽样断言填充部门存在。
    for (final probe in ['专项测试组01', '专项测试组30', '专项测试组52']) {
      await waitFor(tester, find.text(probe));
    }
    // 三层深：技术中心 → 平台架构组（A02 进入时已重新展开）→ 存储小组。
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['platform']}')));
    await tapChartControl(
      tester,
      find.byKey(Key('org-chart-expand-${ids['platform']}')),
    );
    await waitFor(tester, find.byKey(Key('org-chart-node-${ids['storage']}')));
    await markShot(tester, 'n2_a04_wide_and_deep');

    if (a04NativeInputs) {
      faults.failOnce(ids['orgA']!);
      await tester.tap(find.byIcon(CupertinoIcons.refresh).last);
      await tester.runAsync(
        () => faults.observed.timeout(const Duration(seconds: 20)),
      );
      final retry = find.byKey(const ValueKey('org-chart-expand-'));
      await waitFor(tester, retry);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<IconButton>(retry).icon,
        isA<Icon>().having(
          (icon) => icon.icon,
          'retry icon',
          CupertinoIcons.refresh,
        ),
      );
      expect(find.byKey(Key('org-chart-node-${ids['sales']}')), findsNothing);
      expect(faults.injectedFailures, 1);
      await tester.tap(retry);
      await waitFor(tester, find.byKey(Key('org-chart-node-${ids['sales']}')));
      debugPrint(
        'V32_A04_API_FAILURE_RECOVERY_PASS injection=envelope503_over_actual_HTTP200',
      );
      observedDirectory = await observeA04ChartSource(tester);
      observedDirectory.observeNextRoot();
      faults.holdOnce(ids['orgA']!);
      await tester.tap(find.byIcon(CupertinoIcons.refresh).last);
      await tester.runAsync(
        () => faults.observed.timeout(const Duration(seconds: 20)),
      );
    }

    // 空企业C：明确的空态，不出现图。
    // A04 结束时仍在架构二级页（全屏路由盖住 shell 侧栏，切换器不可达）——
    // 图页顶栏是 IosPageTemplate，返回键为自定义 GlassBackButton（非 SDK
    // CupertinoNavigationBarBackButton）。先返回目录根，再切个人侧。
    await tester.tap(find.byType(GlassBackButton));
    await tester.pump(const Duration(milliseconds: 500));
    await selectPersonal(tester);
    await openPersonalEnterprisePicker(tester);
    final orgCTile = find.byKey(Key('drawer-space-${ids['orgC']}'));
    await waitFor(tester, orgCTile);
    await tester.tap(orgCTile);
    await waitFor(tester, enterpriseNavigation());
    await tester.pump(const Duration(milliseconds: 500));
    await selectEnterpriseTab(tester, t.organization.directory.title);
    await waitFor(tester, find.byKey(const Key('org_directory_search_input')));
    await tester.tap(find.text(t.organization.directory.structureSection));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    // 空企业：画布只渲染根节点（企业名），没有任何部门子节点。
    final nodeCount = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'org-chart-node-',
              ),
        )
        .evaluate()
        .length;
    expect(nodeCount, 1, reason: '空企业只应有根节点');
    expect(find.text(_orgCName), findsWidgets);
    await markShot(tester, 'n2_a04_empty_org');
    if (a04NativeInputs) {
      faults.release();
      await tester.runAsync(
        () => observedDirectory!.consumed.timeout(const Duration(seconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text(_orgAName), findsNothing);
      expect(find.byKey(Key('org-chart-node-${ids['sales']}')), findsNothing);
      expect(find.text(_orgCName), findsWidgets);
      expect(faults.heldResponses, 1);
      expect(tester.takeException(), isNull);
      debugPrint('V32_A04_LATE_RESPONSE_SPACE_ISOLATION_PASS');
      if (Platform.isAndroid) {
        if (const bool.fromEnvironment(
          'A04_ANDROID_TOUCH',
          defaultValue: true,
        )) {
          await verifyA04AndroidTouch(tester);
        } else {
          debugPrint('V32_A04_ANDROID_TOUCH_BLOCKED_PRIOR_ATTEMPTS');
        }
      }
    } else {
      debugPrint(
        'NATIVE_N2_A04_PARTIAL: native failure/late response not executed',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 18)));
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
  await selectEnterpriseTab(tester, t.chat.titleMessage);
  await waitFor(
    tester,
    find.byKey(const ValueKey('enterprise-shell-menu-button')),
  );
  await tester.tap(find.byKey(const ValueKey('enterprise-shell-menu-button')));
  final personal = find.byKey(const ValueKey('drawer-space-personal'));
  await waitFor(tester, personal);
  await tester.tap(personal);
  await waitFor(tester, find.byType(BottomNavigationPage));
  await waitFor(tester, personalTab('tab_conversations'));
}

Future<void> openPersonalEnterprisePicker(WidgetTester tester) async {
  await tester.tap(personalTab('tab_conversations'));
  final avatar = find.byKey(const ValueKey('personal-shell-drawer-avatar'));
  await waitFor(tester, avatar.hitTestable());
  await tester.tap(avatar);
}

/// 超宽树 fit 后视口锚定画布中段，前部节点可能在视口外：按目标全局
/// 坐标把画布平滑拖到目标居中（真实拖动手势），再命中点击。
Future<void> tapChartControl(WidgetTester tester, Finder finder) async {
  var hit = finder.hitTestable();
  if (hit.evaluate().isNotEmpty) {
    await tester.tap(hit.first);
    return;
  }
  expect(finder, findsWidgets, reason: '目标控件应存在于渲染树');
  final target = tester.getCenter(finder);
  final view = tester.getRect(find.byKey(const ValueKey('org-chart-canvas')));
  var delta = view.center - target;
  // 限制单轴主导，避免斜向大位移被识别为 fling。
  if (delta.dx.abs() > delta.dy.abs()) {
    delta = Offset(delta.dx, 0);
  } else {
    delta = Offset(0, delta.dy);
  }
  final gesture = await tester.startGesture(view.center);
  const step = Offset(240, 240);
  while (delta.distance > 60) {
    final move = Offset(
      delta.dx.abs() <= 240 ? delta.dx : (delta.dx > 0 ? step.dx : -step.dx),
      delta.dy.abs() <= 240 ? delta.dy : (delta.dy > 0 ? step.dy : -step.dy),
    );
    await gesture.moveBy(move);
    delta = delta - move;
    await tester.pump(const Duration(milliseconds: 24));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 400));
  hit = finder.hitTestable();
  expect(hit, findsWidgets, reason: '拖动到目标后控件应可命中');
  await tester.tap(hit.first);
}

/// 条件等待：至多 [seconds] 秒内 [finder] 是否出现（不抛断言）。
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
  final rail = find.descendant(
    of: find.byType(BottomNavigationPage),
    matching: find.byType(NavigationRail),
  );
  return find.descendant(of: rail, matching: find.text(label));
}

void expectScaleLabel(double scale) {
  final label = '${(scale * 100).toStringAsFixed(scale < .1 ? 1 : 0)}%';
  expect(find.text(label).hitTestable(), findsOneWidget);
}

Future<void> setFontSlider(WidgetTester tester, double value) async {
  final finder = find.byType(Slider);
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  final slider = tester.widget<Slider>(finder);
  final rect = tester.getRect(finder);
  // Flutter Slider retains 24px horizontal track inset with its 48px target.
  final x = rect.left + 24 + (rect.width - 48) * value / slider.max;
  final gesture = await tester.startGesture(Offset(x, rect.center.dy));
  await gesture.up();
  final expected = FontSizeOption.values[value.round()].value;
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (currentFontSize.value != expected &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(currentFontSize.value, expected);
  expect(UserRepoLocal.to.setting.fontSize, expected);
}

Future<void> checkMaximumFontSize(WidgetTester tester) async {
  final router = GoRouter.of(navigatorKey.currentContext!);
  router.push('/font_size');
  await waitFor(tester, find.byType(Slider));
  final original = tester.widget<Slider>(find.byType(Slider)).value;
  final maximum = tester.widget<Slider>(find.byType(Slider)).max;
  var onFontPage = true;
  try {
    await setFontSlider(tester, maximum);
    router.pop();
    onFontPage = false;
    await waitFor(tester, find.byKey(const ValueKey('org-chart-canvas')));
    if (a04NativeInputs) {
      await verifyA04Viewport(tester);
    } else {
      await tester.binding.setSurfaceSize(const Size(400, 800));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('org-chart-fit')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('org-chart-fit')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('org-chart-node-')).hitTestable(),
      findsOneWidget,
    );
    await markShot(tester, 'n2_a03_application_maximum_font');
  } finally {
    await tester.binding.setSurfaceSize(null);
    if (!onFontPage) router.push('/font_size');
    await setFontSlider(tester, original);
    router.pop();
    await tester.pump(const Duration(milliseconds: 400));
  }
}
