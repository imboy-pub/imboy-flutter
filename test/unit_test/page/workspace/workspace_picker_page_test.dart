/// T1.2/T1.4 — WorkspacePickerPage widget 测试
///
/// 覆盖：空列表 → 空态 + 创建 CTA（断头空态修复）；多工作区列表 + 底部
/// 常驻创建入口；点击入口的 go_router 导航断言；按当前企业过滤列表
/// （mine 行带 organization_id + 企业指针，非当前企业/个人域工作区不显示）。
/// 壳状态经 UncontrolledProviderScope + applyCreated 直接播种（无网）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/page/workspace/workspace_picker_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/workspace_model.dart';

Future<void> _seeded(ProviderContainer container, {int count = 0}) async {
  for (var i = 0; i < count; i++) {
    container
        .read(workspaceShellProvider.notifier)
        .applyCreated(
          WorkspaceCreateResult(
            workspace: WorkspaceModel(
              id: '900${1 + i}',
              name: '工作区$i',
              ownerId: '1001',
            ),
            channelId: '910$i',
            groupId: '920$i',
            status: 'created',
          ),
        );
  }
}

/// 播种带归属企业的工作区行（直接写壳状态，语义同 loadMine 回写）。
void _seedOrgWorkspaces(
  ProviderContainer container,
  List<WorkspaceModel> workspaces,
) {
  container.read(workspaceShellProvider.notifier).state = WorkspaceShellState(
    workspaces: workspaces,
    currentWorkspaceId: workspaces.isEmpty ? '' : workspaces.first.id,
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/workspace',
  routes: [
    GoRoute(path: '/workspace', builder: (c, s) => const WorkspacePickerPage()),
    GoRoute(
      path: '/workspace/create',
      builder: (c, s) => const _ProbePage(label: 'probe-create'),
    ),
    GoRoute(
      path: '/workspace/join',
      builder: (c, s) => const _ProbePage(label: 'probe-join'),
    ),
    // §5.1：企业上下文的加入入口现在落到企业选择器（?autoJoin=1）
    GoRoute(
      path: '/organization/picker',
      builder: (c, s) => const _ProbePage(label: 'probe-org-picker'),
    ),
  ],
);

class _ProbePage extends StatelessWidget {
  final String label;
  const _ProbePage({required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(label)),
    body: const SizedBox.shrink(),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  bool withRouter = false,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: withRouter
            ? MaterialApp.router(routerConfig: _router())
            : const MaterialApp(home: WorkspacePickerPage()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// 企业指针测试前置：真实 StorageService（SharedPreferences mock 后端）
/// + 当前账号身份 + 指针播种（页面过滤与顶部企业行共用该数据源）。
Future<void> _seedCurrentOrg(String uid, Organization org) async {
  SharedPreferences.setMockInitialValues({});
  await StorageService.init();
  await StorageService.to.setString(Keys.currentUid, uid);
  addTearDown(() => StorageService.to.remove(Keys.currentUid));
  final store = CurrentOrganizationStore.forAccount(uid);
  await store.set(org);
  addTearDown(() => CurrentOrganizationStore.disposeAccount(uid));
}

void main() {
  testWidgets('空列表：空态 + 创建 CTA（断头空态修复；加入入口不在本页）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _seeded(container, count: 0);

    await _pump(tester, container);

    expect(find.text('还没有工作区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-picker-empty-create-entry')),
      findsOneWidget,
    );
    // 「加入企业」入口收敛到企业选择器，本页不再出现
    expect(
      find.byKey(const ValueKey('workspace-picker-empty-join-entry')),
      findsNothing,
    );
    expect(find.text('加入企业'), findsNothing);
    // 空态不加列表 footer（列表本身不存在）
    expect(
      find.byKey(const ValueKey('workspace-picker-create-entry')),
      findsNothing,
    );
  });

  testWidgets('2 个工作区：2 tile + 底部常驻创建入口（无加入入口）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _seeded(container, count: 2);

    await _pump(tester, container);

    expect(
      find.byKey(const ValueKey('workspace-picker-tile-9001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-picker-tile-9002')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-picker-create-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-picker-join-entry')),
      findsNothing,
    );
    expect(find.text('创建工作区'), findsOneWidget);
    expect(find.text('加入企业'), findsNothing);
    expect(find.text('加入工作区'), findsNothing);
  });

  testWidgets('点击底部创建入口：导航 /workspace/create', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _seeded(container, count: 2);

    await _pump(tester, container, withRouter: true);

    await tester.tap(
      find.byKey(const ValueKey('workspace-picker-create-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('probe-create'), findsOneWidget);
  });

  testWidgets('有企业指针：只显示该企业的工作区（他企业/个人域不显示）', (tester) async {
    await _seedCurrentOrg(
      'filter-test-uid',
      const Organization(id: 'org117', name: 'org117'),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    _seedOrgWorkspaces(container, [
      const WorkspaceModel(
        id: '9001',
        name: '本企业A',
        ownerId: '1001',
        organizationId: 'org117',
      ),
      const WorkspaceModel(
        id: '9002',
        name: '他企业B',
        ownerId: '1001',
        organizationId: 'org999',
      ),
      const WorkspaceModel(id: '9003', name: '个人域C', ownerId: '1001'),
    ]);

    await _pump(tester, container);

    expect(
      find.byKey(const ValueKey('workspace-picker-tile-9001')),
      findsOneWidget,
    );
    expect(find.text('本企业A'), findsOneWidget);
    expect(find.text('他企业B'), findsNothing);
    expect(find.text('个人域C'), findsNothing);
    // 顶部企业行展示当前企业
    expect(find.text('org117'), findsOneWidget);
  });

  testWidgets('无企业指针：维持全量已加入列表（个人域模式向后兼容）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    _seedOrgWorkspaces(container, [
      const WorkspaceModel(id: '9001', name: '个人域A', ownerId: '1001'),
      const WorkspaceModel(
        id: '9002',
        name: '企业B',
        ownerId: '1001',
        organizationId: 'org999',
      ),
    ]);

    await _pump(tester, container);

    expect(find.text('个人域A'), findsOneWidget);
    expect(find.text('企业B'), findsOneWidget);
  });
}
