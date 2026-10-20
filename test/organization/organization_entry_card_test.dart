/// P0 企业入口卡 widget 测试（计划 §14.1）。
///
/// 覆盖四态：有企业（单/多企业切换入口）、无企业（加入/创建入口）、
/// 网络/权限错误（错误态 + 重试，不伪装成无企业）、刷新失败保留旧数据
/// 与入口行。mine() 经 [organizationApiProvider] override 注入 fake。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_card.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/service/storage.dart';

const org1 = '7101';
const org2 = '7102';

class _FakeOrgApi extends OrganizationApi {
  _FakeOrgApi({this.mineResult});

  final List<Organization>? mineResult;

  @override
  Future<OrganizationPage<Organization>> mine({
    int page = 1,
    int size = 10,
  }) async {
    return OrganizationPage(
      list: mineResult ?? const <Organization>[],
      page: 1,
      size: size,
      total: mineResult?.length ?? 0,
      totalPage: 1,
    );
  }
}

Widget _wrap(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required OrganizationApi api,
}) async {
  final container = ProviderContainer(
    overrides: [organizationApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  await container.read(organizationEntryProvider.notifier).fetch();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _wrap(const OrganizationEntryCard(accountKey: 'u1')),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('有企业：展示当前企业行；多企业出现切换入口', (tester) async {
    await _pump(
      tester,
      api: _FakeOrgApi(
        mineResult: [
          const Organization(id: org1, name: '甲企业'),
          const Organization(id: org2, name: '乙企业'),
        ],
      ),
    );

    expect(find.byKey(const Key('org_entry_row')), findsOneWidget);
    expect(find.text('甲企业'), findsOneWidget); // 指针空 → 回落首个 active
    expect(find.text(t.organization.experienceUi.switchSpace), findsOneWidget);
    expect(find.byKey(const Key('org_entry_empty')), findsNothing);
  });

  testWidgets('无企业：加入/创建入口（不整块卸载）', (tester) async {
    await _pump(tester, api: _FakeOrgApi());

    expect(find.byKey(const Key('org_entry_empty')), findsOneWidget);
    expect(find.text(t.organization.picker.joinEnterprise), findsOneWidget);
    expect(find.text(t.organization.home.createOrg), findsOneWidget);
    expect(find.byKey(const Key('org_entry_error')), findsNothing);
  });

  testWidgets('网络/权限错误：错误态 + 重试；不伪装成无企业', (tester) async {
    var fail = true;
    final dynamicApi = _ToggleApi(() => fail);
    await _pump(tester, api: dynamicApi);

    expect(find.byKey(const Key('org_entry_error')), findsOneWidget);
    expect(
      find.byKey(const Key('org_entry_empty')),
      findsNothing,
      reason: '错误不得伪装成无企业',
    );
    expect(find.text(t.common.buttonRetry), findsOneWidget);

    // 重试成功 → 企业行出现。
    fail = false;
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(find.byKey(const Key('org_entry_row')), findsOneWidget);
    expect(find.byKey(const Key('org_entry_error')), findsNothing);
  });

  testWidgets('刷新失败但已有企业数据：保留入口行 + 内联错误', (tester) async {
    final api = _ToggleApi(() => false);
    final container = await _pump(tester, api: api);
    expect(find.byKey(const Key('org_entry_row')), findsOneWidget);

    api.failing = () => true;
    await container.read(organizationEntryProvider.notifier).fetch();
    await tester.pump();

    expect(
      find.byKey(const Key('org_entry_row')),
      findsOneWidget,
      reason: '入口行保留',
    );
    expect(find.byKey(const Key('org_entry_stale_error')), findsOneWidget);
    expect(find.text('甲企业'), findsOneWidget, reason: '旧数据保留');
  });

  testWidgets('入口行点击 → P1 通讯录路由（orgId + name）', (tester) async {
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: OrganizationEntryCard(accountKey: 'u1')),
        ),
        GoRoute(
          path: '/organization/:orgId/directory',
          builder: (context, state) {
            pushed.add(
              '${state.pathParameters['orgId']}|'
              '${state.uri.queryParameters['name']}',
            );
            return const Scaffold(body: SizedBox());
          },
        ),
        GoRoute(
          path: '/organization',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/organization/picker',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        organizationApiProvider.overrideWithValue(
          _FakeOrgApi(
            mineResult: [const Organization(id: org1, name: '甲企业')],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(organizationEntryProvider.notifier).fetch();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('甲企业'));
    await tester.pumpAndSettle();

    expect(pushed, ['$org1|甲企业']);
  });
}

/// 可切换成败的 fake（用于重试/刷新失败场景）。
class _ToggleApi extends OrganizationApi {
  _ToggleApi(bool Function() failing) : _failing = failing;

  bool Function() _failing;
  set failing(bool Function() f) => _failing = f;

  @override
  Future<OrganizationPage<Organization>> mine({
    int page = 1,
    int size = 10,
  }) async {
    if (_failing()) {
      throw const OrganizationApiException(503, 'unavailable');
    }
    return OrganizationPage(
      list: const [Organization(id: org1, name: '甲企业')],
      page: 1,
      size: size,
      total: 1,
      totalPage: 1,
    );
  }
}
