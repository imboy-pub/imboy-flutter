import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';

import '../../../ux_matrix/ux_harness.dart';
import '../../../golden_baseline_guard.dart';

const _before = bool.fromEnvironment('UX_T14_BEFORE');
const _account = '91001';

class _Experience extends ProductExperienceNotifier {
  final selections = <ProductExperience>[];

  @override
  ProductExperience build() => ProductExperience.workspace;

  @override
  Future<void> select(ProductExperience experience) async {
    selections.add(experience);
    state = experience;
  }
}

Future<(ProviderContainer, GoRouter, _Experience)> _pumpDrawer(
  WidgetTester tester, {
  String scenario = 'organization',
  UxCombo combo = const UxCombo(Size(360, 800)),
}) async {
  final neutral = scenario == 'neutral';
  final organization = scenario == 'long' ? '合成企业名称' * 12 : '合成企业';
  final workspace = switch (scenario) {
    'long' => '合成工作区名称' * 12,
    'same' => organization,
    _ => '合成工作区',
  };
  if (!neutral) {
    await CurrentOrganizationStore.forAccount(_account)
        .set(Organization(id: '7001', name: organization));
  }
  final experience = _Experience();
  final adapter = RouteStubAdapter([]);
  HttpClient.adapterForTest = adapter;
  addTearDown(() => expect(adapter.requestCount, 0));
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        UserModel(uid: _account, account: 'synthetic', nickname: '合成用户'),
      ),
      currentWorkspaceProvider.overrideWithValue(
        neutral || scenario == 'workspace-null'
            ? null
            : WorkspaceModel(id: '9001', name: workspace, ownerId: _account),
      ),
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
          drawer: WorkspaceDrawerMenu(organizationId: neutral ? '' : '7001'),
          body: const SizedBox.shrink(),
        ),
      ),
      for (final path in [
        '/personal_info/profile',
        '/qrcode/user',
        '/organization/7001',
        '/organization/7001/tools',
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
        theme: ThemeData(brightness: combo.brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(combo.textScale)),
          child: TranslationProvider(child: child!),
        ),
      ),
    ),
  );
  scaffold.currentState!.openDrawer();
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  return (container, router, experience);
}

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });
  setUp(() async {
    await initUxHarness();
    CurrentOrganizationStore.disposeAccount(_account);
    await StorageService.to.setString(Keys.currentUid, _account);
  });
  tearDown(() {
    CurrentOrganizationStore.disposeAccount(_account);
    teardownUxHarness();
  });

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
        skip: !goldenBaselineExists(
          'test/unit_test/page/workspace_shell/goldens/t14_${scenario}_$label.png',
        ),
        (tester) async {
          final (container, _, experience) = await _pumpDrawer(
            tester,
            scenario: scenario,
            combo: combo,
          );
          expect(find.byType(Drawer), findsOneWidget);
          expect(find.text(t.workspace.myCard), findsOneWidget);
          expect(find.text(t.workspace.createOrJoinEnterprise), findsOneWidget);
          expect(find.text(t.main.setting), findsOneWidget);
          expect(find.text(t.workspace.switchToPersonal), findsOneWidget);
          expect(find.text(t.account.logOut), findsOneWidget);
          expect(experience.selections, isEmpty);
          expect(
            container.read(productExperienceProvider),
            ProductExperience.workspace,
          );
          if (scenario == 'neutral') {
            expect(find.text(t.workspace.advancedFeatures), findsNothing);
            expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
          } else {
            final organization = scenario == 'long' ? '合成企业名称' * 12 : '合成企业';
            expect(find.text(organization), findsNWidgets(_before ? 2 : 1));
            expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
            expect(find.text(t.workspace.advancedFeatures), findsOneWidget);
            if (!_before) {
              expect(find.text(t.workspace.orgUnverified), findsNothing);
              expect(
                find.textContaining(
                  scenario == 'long' ? '合成工作区名称' * 12 : '合成工作区',
                ),
                findsOneWidget,
              );
            }
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

  for (final (label, path) in [
    ('合成用户', '/personal_info/profile'),
    ('合', '/personal_info/profile'),
    (t.workspace.myCard, '/qrcode/user'),
    ('合成企业', '/organization/7001'),
    (t.workspace.advancedFeatures, '/organization/7001/tools'),
    (t.workspace.createOrJoinEnterprise, '/organization/picker'),
    (t.main.setting, '/mine/setting'),
  ]) {
    testWidgets('drawer action $path via $label', (tester) async {
      final (_, router, experience) = await _pumpDrawer(tester);
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

  testWidgets('switch personal preserves account and organization preference', (
    tester,
  ) async {
    final (container, _, experience) = await _pumpDrawer(tester);
    await tester.ensureVisible(find.text(t.workspace.switchToPersonal));
    await tester.tap(find.text(t.workspace.switchToPersonal));
    await tester.pumpAndSettle();
    expect(experience.selections, [ProductExperience.personal]);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    expect(StorageService.to.getString(Keys.currentUid), _account);
    expect(CurrentOrganizationStore.forAccount(_account).value?.id, '7001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout keeps confirmation and cancellation', (tester) async {
    final (_, router, experience) = await _pumpDrawer(
      tester,
      scenario: 'long',
      combo: const UxCombo(Size(360, 800), textScale: 2),
    );
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
    expect(StorageService.to.getString(Keys.currentUid), _account);
    expect(CurrentOrganizationStore.forAccount(_account).value?.id, '7001');
    expect(experience.selections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout remains destructive in drawer', (tester) async {
    await _pumpDrawer(tester);
    final label = tester.widget<Text>(find.text(t.account.logOut));
    expect(label.style?.color, AppColors.iosRed);
  });

  for (final scenario in ['same', 'workspace-null']) {
    testWidgets('current context avoids duplication: $scenario', (
      tester,
    ) async {
      await _pumpDrawer(tester, scenario: scenario);
      expect(find.text('合成企业'), findsNWidgets(_before ? 2 : 1));
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
      expect(find.textContaining(t.workspace.createNameLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long names and large text retain settings navigation', (
    tester,
  ) async {
    final (_, router, _) = await _pumpDrawer(
      tester,
      scenario: 'long',
      combo: const UxCombo(Size(360, 800), textScale: 2),
    );
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
