import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../ux_matrix/ux_harness.dart';

const _before = bool.fromEnvironment('UX_T15_BEFORE');
const _organization = '合成企业';
const _nickname = '合成成员的较长显示名称';
const _resources = ['客服工作台', '项目', '群组', '频道', '附件'];
const _combos = [
  ('360_1_light', UxCombo(Size(360, 800))),
  (
    '360_2_dark',
    UxCombo(Size(360, 800), textScale: 2, brightness: Brightness.dark),
  ),
  ('1280_1_dark', UxCombo(Size(1280, 900), brightness: Brightness.dark)),
  ('1280_2_light', UxCombo(Size(1280, 900), textScale: 2)),
];

Future<GoRouter> _pumpPage(
  WidgetTester tester,
  String scenario,
  UxCombo combo,
) async {
  tester.view.physicalSize = combo.viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final adapter = RouteStubAdapter([
    (
      '/cs/me/seat-contexts',
      [
        (200, uxEnvelope(payload: {'contexts': <Object>[]})),
      ],
    ),
  ]);
  HttpClient.adapterForTest = adapter;
  addTearDown(() {
    expect(adapter.requestCount, scenario == 'personal' ? 1 : 0);
    HttpClient.adapterForTest = null;
  });
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text(_organization)),
          body: scenario == 'workbench'
              ? EnterpriseWorkbenchPage(
                  entries: const [],
                  accountKey: '91001',
                  organizationId: '7001',
                  resourceEntries: [
                    for (var index = 0; index < _resources.length; index++)
                      CupertinoListTile(
                        title: Text(_resources[index]),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => context.push('/resource/$index'),
                      ),
                  ],
                )
              : MinePage(
                  enterprise: scenario == 'enterprise',
                  enterpriseName: _organization,
                  enterpriseEntry: scenario == 'enterprise'
                      ? CupertinoListTile(
                          title: const Text('企业管理'),
                          onTap: () => context.push('/manage'),
                        )
                      : null,
                ),
        ),
      ),
      for (final path in [
        '/resource/:id',
        '/manage',
        '/favorites',
        '/organization/picker',
        '/qrcode/user',
        '/personal_info/profile',
        '/mine/setting',
        '/devices',
        '/feedback',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(body: Text(state.uri.path)),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          UserModel(
            uid: '91001',
            account: 'synthetic-account',
            nickname: _nickname,
          ),
        ),
      ],
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
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(initUxHarness);
  tearDownAll(teardownUxHarness);

  for (final (label, combo) in _combos) {
    for (final scenario in ['workbench', 'enterprise', 'personal']) {
      testWidgets('T15 $scenario $label', (tester) async {
        await _pumpPage(tester, scenario, combo);
        if (scenario == 'workbench') {
          final section = tester.widget<CupertinoListSection>(
            find.byType(CupertinoListSection).first,
          );
          expect(
            section.type,
            _before
                ? CupertinoListSectionType.insetGrouped
                : CupertinoListSectionType.base,
          );
          for (var index = 0; index < _resources.length; index++) {
            expect(find.text(_resources[index]), findsOneWidget);
            if (index > 0) {
              expect(
                tester.getTopLeft(find.text(_resources[index])).dy,
                greaterThan(
                  tester.getTopLeft(find.text(_resources[index - 1])).dy,
                ),
              );
            }
          }
          expect(
            find.byKey(const ValueKey('workbench-apps-entry')),
            findsOneWidget,
          );
        } else {
          expect(find.text(_nickname), findsOneWidget);
          expect(
            find.text(_organization),
            findsNWidgets(scenario == 'enterprise' && _before ? 2 : 1),
          );
          expect(
            find.text('ID: synthetic-account'),
            scenario == 'personal' ? findsOneWidget : findsNothing,
          );
          expect(find.byIcon(CupertinoIcons.qrcode), findsOneWidget);
          if (scenario == 'enterprise') {
            expect(find.text('企业管理'), findsOneWidget);
            expect(find.text(t.main.myFavorites), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/t15_${scenario}_$label.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }

  for (var index = 0; index < _resources.length; index++) {
    testWidgets('T15 resource callback $index', (tester) async {
      final router = await _pumpPage(tester, 'workbench', _combos.first.$2);
      await tester.tap(find.text(_resources[index]));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
        '/resource/$index',
      );
      expect(find.text('/resource/$index'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  for (final (label, path) in [
    ('企业管理', '/manage'),
    (t.main.myFavorites, '/favorites'),
    ('切换企业', '/organization/picker'),
    (_nickname, '/personal_info/profile'),
  ]) {
    testWidgets('T15 enterprise action $path', (tester) async {
      final router = await _pumpPage(tester, 'enterprise', _combos[1].$2);
      final action = find.text(label);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
        path,
      );
      expect(find.text(path), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
