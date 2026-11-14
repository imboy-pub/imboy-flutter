/// 壳级空间切换抽屉 focused widget 测试（2026-10 空间切换中心改版）。
///
/// 覆盖：
/// - 空间区渲染：个人空间行 + 企业列表（mine 真源），当前项 ✓ 语义唯一
///   （企业模式勾当前企业行、个人模式勾个人行，互斥）；
/// - 行内直接切换：个人→企业走两阶段原子链路（指针/壳/体验模式断言），
///   企业→个人仅切体验模式且保留企业指针；
/// - 底部功能簇跳转（名片/高级功能/创建加入/设置）与退出登录确认；
/// - mine 拉取失败时保留缓存播种（抽屉功能不中断）；
/// - golden 基线（t14_*.png）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/org_invite_qr_page.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;
import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';

import '../../../ux_matrix/ux_harness.dart';
import '../../../golden_baseline_guard.dart';
import '../../../uiux/support/golden_font_loader.dart';

const drawerAccount = '91001';
const _orgA = '7001';
const _orgB = '7002';

/// 合成未过期 JWT（exp=2100-01-01）：HttpClient 在 currentUid 非空但
/// token 为空时会走「鉴权过期 → 登出」流程，抽屉的 mine 拉取会被中断；
/// 与 enterprise_shell_page_test 同款 fixture。
final String _syntheticJwt = () {
  String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  return '${b64('{"alg":"HS256","typ":"JWT"}')}.${b64('{"exp":4102444800}')}.c3ludGhldGlj';
}();

class DrawerExperience extends ProductExperienceNotifier {
  DrawerExperience(this.initial, {this.beforeSelect});

  final ProductExperience initial;
  final Future<void> Function()? beforeSelect;
  final selections = <ProductExperience>[];

  @override
  ProductExperience build() => initial;

  @override
  Future<void> select(ProductExperience experience) async {
    await beforeSelect?.call();
    selections.add(experience);
    state = experience;
  }
}

Map<String, dynamic> _ok(dynamic payload) => {
  'code': 0,
  'msg': 'success',
  'payload': payload,
};

Map<String, dynamic> _mineOf(
  List<String> ids, {
  String role = 'member',
  Map<String, String> names = const {},
}) => _ok({
  'list': [
    for (final id in ids)
      {'id': int.parse(id), 'name': names[id] ?? '组织$id', 'member_role': role},
  ],
  'page': 1,
  'size': 100,
  'total': ids.length,
  'total_page': 1,
});

/// WS API Fake：mine 可控（两阶段切换预载/落位），不触网。
class _WsFakeApi extends WorkspaceApi {
  _WsFakeApi(this.workspaces);

  final List<WorkspaceModel> workspaces;

  @override
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) async =>
      const WorkspaceBranding();

  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async => WorkspacePageResult<WorkspaceModel>(
    list: workspaces,
    total: workspaces.length,
    totalPage: 1,
  );
}

/// 按 URI path 分发的 adapter 已由 DrawerDetailAdapter/_FailAdapter 承担。

Future<(ProviderContainer, GoRouter, DrawerExperience)> pumpDrawer(
  WidgetTester tester, {
  String scenario = 'organization',
  UxCombo combo = const UxCombo(Size(360, 800)),
  ProductExperience initialExperience = ProductExperience.workspace,
  List<WorkspaceModel> workspaces = const [],
  HttpClientAdapter? httpAdapter,
  bool compact = false,
  bool golden = false,
  double compactMaxHeight = 600,
  TextScaler? textScaler,
  CupertinoThemeData? cupertinoTheme,
  bool boldText = false,
  double? letterSpacingOverride,
  double? wordSpacingOverride,
  VoidCallback? onClose,
  DrawerExperience? experienceOverride,
}) async {
  final neutral = scenario == 'neutral';
  final organization = scenario == 'long' ? '合成企业名称' * 12 : '合成企业';
  if (!neutral) {
    await CurrentOrganizationStore.forAccount(drawerAccount)
        .set(Organization(id: _orgA, name: organization));
  }
  final experience = experienceOverride ?? DrawerExperience(initialExperience);
  HttpClient.adapterForTest =
      httpAdapter ??
      RouteStubAdapter([
        (
          'organizations/mine',
          [
            (
              200,
              _mineOf(
                neutral ? [] : [_orgA, _orgB],
                names: scenario == 'long' ? {_orgA: organization} : const {},
              ),
            ),
          ],
        ),
      ]);
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        UserModel(uid: drawerAccount, account: 'synthetic', nickname: '合成用户'),
      ),
      currentWorkspaceProvider.overrideWithValue(
        scenario == 'workspace-null' || neutral
            ? null
            : WorkspaceModel(
                id: '9001',
                name: '合成工作区',
                ownerId: drawerAccount,
                organizationId: _orgA,
              ),
      ),
      workspaceApiProvider.overrideWith((ref) => _WsFakeApi(workspaces)),
      productExperienceProvider.overrideWith(() => experience),
    ],
  );
  addTearDown(container.dispose);
  final scaffold = GlobalKey<ScaffoldState>();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          key: scaffold,
          drawer: compact
              ? null
              : WorkspaceDrawerMenu(organizationId: neutral ? '' : _orgA),
          body: const SizedBox.shrink(),
        ),
      ),
      for (final path in [
        '/personal_info/profile',
        '/qrcode/user',
        '/organization/$_orgA',
        '/organization/$_orgA/tools',
        '/organization/picker',
        '/mine/setting',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(body: Text(state.uri.path)),
        ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = combo.viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: golden
            ? applyGoldenFont(
                combo.brightness == Brightness.light
                    ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
                    : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
              )
            : ThemeData(brightness: combo.brightness),
        builder: AppLoading.init(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(
                  textScaler: textScaler ?? TextScaler.linear(combo.textScale),
                  boldText: boldText,
                )
                .applyTextStyleOverrides(
                  lineHeightScaleFactorOverride: null,
                  letterSpacingOverride: letterSpacingOverride,
                  wordSpacingOverride: wordSpacingOverride,
                  paragraphSpacingOverride: null,
                ),
            child: cupertinoTheme == null
                ? TranslationProvider(child: child!)
                : DefaultTextStyle.merge(
                    style: const TextStyle(letterSpacing: -5),
                    child: CupertinoTheme(
                      data: cupertinoTheme,
                      child: TranslationProvider(child: child!),
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
  if (compact) {
    unawaited(
      showDialog<void>(
        context: scaffold.currentContext!,
        builder: (menuContext) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 320,
              maxHeight: compactMaxHeight,
            ),
            child: WorkspaceDrawerMenu(
              organizationId: neutral ? '' : _orgA,
              compact: true,
              onClose: () {
                onClose?.call();
                Navigator.of(menuContext).pop();
              },
            ),
          ),
        ),
      ),
    );
  } else {
    scaffold.currentState!.openDrawer();
  }
  await tester.pumpAndSettle();
  addTearDown(() async {
    await AppLoading.dismiss(animation: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  return (container, router, experience);
}

void setupDrawerTests() {
  setUpAll(() async {
    await AppLocale.enUs.build();
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });
  setUp(() async {
    await initUxHarness();
    FlutterSecureStorage.setMockInitialValues({'secure_token': _syntheticJwt});
    CurrentOrganizationStore.disposeAccount(drawerAccount);
    OrganizationCache.disposeAccount(drawerAccount);
    await StorageService.to.setString(Keys.currentUid, drawerAccount);
  });
  tearDown(() {
    CurrentOrganizationStore.disposeAccount(drawerAccount);
    OrganizationCache.disposeAccount(drawerAccount);
    HttpClient.adapterForTest = null;
    teardownUxHarness();
  });
}

void main() {
  setupDrawerTests();

  for (final width in [320.0, 360.0]) {
    testWidgets('手机抽屉外侧留出触达区并可关闭 ($width)', (tester) async {
      await pumpDrawer(tester, combo: UxCombo(Size(width, 800), textScale: 2));
      final drawer = tester.getRect(find.byType(Drawer));
      expect(width - drawer.right, greaterThanOrEqualTo(44));
      await tester.tapAt(Offset((drawer.right + width) / 2, 200));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (label, combo) in [
    ('360_1_light', UxCombo(const Size(360, 800))),
    (
      '360_2_dark',
      UxCombo(const Size(360, 800), textScale: 2, brightness: Brightness.dark),
    ),
    (
      '1280_1_dark',
      UxCombo(const Size(1280, 900), brightness: Brightness.dark),
    ),
    ('1280_2_light', UxCombo(const Size(1280, 900), textScale: 2)),
  ]) {
    for (final scenario in ['organization', 'neutral', 'long']) {
      testWidgets(
        'golden: T14 $scenario $label',
        skip: !goldenBaselinesReady([
          'test/unit_test/page/workspace_shell/goldens/t14_${scenario}_$label.png',
        ]),
        (tester) async {
          final font = await prepareGoldenFonts(tester);
          final (container, _, experience) = await pumpDrawer(
            tester,
            scenario: scenario,
            combo: combo,
            golden: true,
          );
          expect(find.byType(Drawer), findsOneWidget);
          expectGoldenTextGlyphs(
            tester,
            font,
            sample: find.text(t.workspace.myCard),
          );
          if (scenario == 'long') {
            expect(find.text('合成企业名称' * 12).hitTestable(), findsOneWidget);
          }
          expect(find.text(t.workspace.myCard), findsOneWidget);
          expect(find.text(t.workspace.createOrJoinEnterprise), findsOneWidget);
          expect(find.text(t.main.setting), findsOneWidget);
          // 空间切换收敛：独立「切换到个人」行已删除（个人行取代）。
          expect(find.text(t.workspace.switchToPersonal), findsNothing);
          expect(find.text(t.account.logOut), findsOneWidget);
          expect(experience.selections, isEmpty);
          expect(
            container.read(productExperienceProvider),
            ProductExperience.workspace,
          );
          if (scenario == 'neutral') {
            expect(find.text(t.workspace.advancedFeatures), findsNothing);
          } else {
            expect(find.text(t.workspace.advancedFeatures), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(Drawer),
            matchesGoldenFile('goldens/t14_${scenario}_$label.png'),
          );
        },
      );
    }
  }

  testWidgets('长企业名称从 mine 真源进入可见企业行', (tester) async {
    await pumpDrawer(tester, scenario: 'long');
    final longName = find.descendant(
      of: find.byKey(const ValueKey('drawer-space-$_orgA')),
      matching: find.text('合成企业名称' * 12),
    );
    expect(longName, findsOneWidget);
    expect(longName.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空间区渲染：个人行 + 企业列表，当前勾选语义唯一（企业模式）', (tester) async {
    await pumpDrawer(tester);
    final personal = find.byKey(const ValueKey('drawer-space-personal'));
    final orgA = find.byKey(const ValueKey('drawer-space-$_orgA'));
    final orgB = find.byKey(const ValueKey('drawer-space-$_orgB'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(personal, findsOneWidget);
    expect(orgA, findsOneWidget);
    expect(orgB, findsOneWidget);
    // 企业模式：当前企业行唯一 ✓。
    expect(
      find.descendant(
        of: orgA,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: orgB,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: personal,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );
  });

  testWidgets('个人模式：个人行 ✓，企业行不亮勾', (tester) async {
    await pumpDrawer(tester, initialExperience: ProductExperience.personal);
    await tester.pumpAndSettle();
    final personal = find.byKey(const ValueKey('drawer-space-personal'));
    expect(
      find.descendant(
        of: personal,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('drawer-space-$_orgA')),
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );
  });

  testWidgets('企业→个人：行内直接切体验模式，企业指针保留', (tester) async {
    final (container, _, experience) = await pumpDrawer(tester);
    final personal = find.byKey(const ValueKey('drawer-space-personal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(personal);
    await tester.tap(personal);
    await tester.pumpAndSettle();
    expect(experience.selections, [ProductExperience.personal]);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    expect(StorageService.to.getString(Keys.currentUid), drawerAccount);
    expect(CurrentOrganizationStore.forAccount(drawerAccount).value?.id, _orgA);
    expect(tester.takeException(), isNull);
  });

  for (final (compact, combo) in [
    for (final width in [320.0, 360.0, 390.0])
      for (final scale in [1.0, 1.5, 2.0])
        for (final brightness in Brightness.values)
          (
            false,
            UxCombo(Size(width, 800), textScale: scale, brightness: brightness),
          ),
    (true, const UxCombo(Size(360, 800))),
  ]) {
    testWidgets(
      '个人→企业：两阶段切换移动指针、壳重载并切体验模式 '
      '(compact=$compact, ${combo.viewport.width}×${combo.textScale}×${combo.brightness.name})',
      (tester) async {
        final adapter = DrawerDetailAdapter();
        var closed = 0;
        final (container, _, experience) = await pumpDrawer(
          tester,
          initialExperience: ProductExperience.personal,
          combo: combo,
          workspaces: const [
            WorkspaceModel(
              id: '9002',
              name: 'WS乙',
              ownerId: '1',
              organizationId: _orgB,
            ),
          ],
          httpAdapter: adapter,
          compact: compact,
          onClose: () => closed++,
        );
        final orgB = find.byKey(const ValueKey('drawer-space-$_orgB'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(orgB);
        expect(orgB.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(orgB);
        await tester.pumpAndSettle();
        expect(adapter.detailCalls, greaterThanOrEqualTo(1));
        expect(experience.selections, [ProductExperience.workspace]);
        expect(
          CurrentOrganizationStore.forAccount(drawerAccount).value?.id,
          _orgB,
        );
        expect(
          container.read(workspaceShellProvider).currentWorkspaceId,
          '9002',
        );
        expect(
          container.read(productExperienceProvider),
          ProductExperience.workspace,
        );
        if (compact) {
          expect(closed, 1);
          expect(find.byType(WorkspaceDrawerMenu), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (label, path) in [
    ('合成用户', '/personal_info/profile'),
    ('合', '/personal_info/profile'),
    (t.workspace.myCard, '/qrcode/user'),
    (t.workspace.advancedFeatures, '/organization/$_orgA/tools'),
    (t.workspace.createOrJoinEnterprise, '/organization/picker'),
    (t.main.setting, '/mine/setting'),
  ]) {
    testWidgets('drawer action $path via $label', (tester) async {
      final (_, router, experience) = await pumpDrawer(tester);
      await tester.pumpAndSettle();
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
        path,
      );
      expect(find.text(path), findsOneWidget);
      expect(experience.selections, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mine 拉取失败：保留缓存播种，抽屉功能不中断', (tester) async {
    OrganizationCache.forAccount(drawerAccount)
        .saveOrgs(const [Organization(id: _orgA, name: '缓存企业')]);
    await pumpDrawer(tester, httpAdapter: _FailAdapter());
    await tester.pumpAndSettle();
    expect(find.text('缓存企业'), findsOneWidget);
    expect(find.text(t.workspace.createOrJoinEnterprise), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('企业二维码入口（出码为治理动作）', () {
    testWidgets('owner：我的名片旁显示企业二维码行并直达出码页', (tester) async {
      await pumpDrawer(
        tester,
        httpAdapter: RouteStubAdapter([
          (
            'organizations/mine',
            [
              (200, _mineOf([_orgA, _orgB], role: 'owner')),
            ],
          ),
        ]),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('drawer-org-qrcode'));
      expect(row, findsOneWidget);
      expect(find.text(t.organization.inviteQr.orgQrcode), findsOneWidget);
      // 与「我的名片」并列在同一功能簇（名片行在上）。
      expect(
        tester.getTopLeft(find.text(t.workspace.myCard)).dy,
        lessThan(tester.getTopLeft(row).dy),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      // 抽屉收起 + 根导航器 Cupertino 转场；出码页首帧有加载指示器，用有界
      // pump 推进而非 pumpAndSettle。
      for (
        var i = 0;
        i < 10 && find.byType(OrgInviteQrPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(OrgInviteQrPage), findsOneWidget);
    });

    testWidgets('member：不显示企业二维码行', (tester) async {
      await pumpDrawer(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawer-org-qrcode')), findsNothing);
      expect(find.text(t.workspace.myCard), findsOneWidget);
    });

    testWidgets('个人上下文（无企业 id）：不显示企业二维码行', (tester) async {
      await pumpDrawer(
        tester,
        scenario: 'neutral',
        initialExperience: ProductExperience.personal,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawer-org-qrcode')), findsNothing);
    });
  });

  testWidgets('logout keeps confirmation and cancellation', (tester) async {
    final (_, router, experience) = await pumpDrawer(
      tester,
      scenario: 'long',
      combo: const UxCombo(Size(360, 800), textScale: 2),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(t.account.logOut));
    await tester.tap(find.text(t.account.logOut));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text(t.account.areYouSureLogOut), findsOneWidget);
    final confirm = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, t.common.buttonConfirm),
    );
    expect(confirm.isDestructiveAction, isTrue);
    expect(confirm.onPressed, isNotNull);
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(StorageService.to.getString(Keys.currentUid), drawerAccount);
    expect(CurrentOrganizationStore.forAccount(drawerAccount).value?.id, _orgA);
    expect(experience.selections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout remains destructive in drawer', (tester) async {
    await pumpDrawer(tester);
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text(t.account.logOut));
    expect(label.style?.color, AppColors.getDestructiveText(Brightness.light));
  });

  testWidgets('long names and large text retain settings navigation', (
    tester,
  ) async {
    final (_, router, _) = await pumpDrawer(
      tester,
      scenario: 'long',
      combo: const UxCombo(Size(360, 800), textScale: 2),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(t.main.setting));
    await tester.tap(find.text(t.main.setting));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/mine/setting',
    );
    expect(find.text('/mine/setting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// organizations/* 全链路 stub：mine 列表 + detail + default-workspace。
class DrawerDetailAdapter implements HttpClientAdapter {
  DrawerDetailAdapter({this.failDetail = false});

  final bool failDetail;
  int detailCalls = 0;

  ResponseBody _response(dynamic body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.contains('organizations/mine')) {
      return _response(_mineOf([_orgA, _orgB]));
    }
    if (path.endsWith('/organizations/$_orgB')) {
      detailCalls++;
      if (failDetail) {
        return _response({
          'code': 500,
          'msg': 'synthetic detail failure',
          'payload': null,
        });
      }
      return _response(
        _ok({
          'id': int.parse(_orgB),
          'name': '组织$_orgB',
          'member_role': 'member',
        }),
      );
    }
    if (path.endsWith('/organizations/$_orgB/default-workspace')) {
      return _response(
        _ok({
          'organization_id': int.parse(_orgB),
          'default_workspace_id': 9002,
        }),
      );
    }
    return _response(_ok(null));
  }

  @override
  void close({bool force = false}) {}
}

/// mine 返回业务错误（HTTP 200 + code≠0）：不触发重试拦截器的退避 Timer，
/// 用例结束时无挂起定时器。
class _FailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'code': 500, 'msg': 'synthetic mine failure', 'payload': null}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
