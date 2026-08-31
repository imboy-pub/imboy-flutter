/// T1.2/T1.4 — WorkspacePickerPage widget 测试
///
/// 覆盖：空列表 → 空态 + 创建 CTA（断头空态修复）；多工作区列表 + 底部
/// 常驻双入口（创建/加入，Slack「Add workspaces」模式）；点击入口的
/// go_router 导航断言（join 路由由测试 router 提供占位，阶段二转正）。
/// 壳状态经 UncontrolledProviderScope + applyCreated 直接播种（无网）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_picker_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
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

void main() {
  testWidgets('空列表：空态 + 创建 CTA（断头空态修复）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _seeded(container, count: 0);

    await _pump(tester, container);

    expect(find.text('还没有工作区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-picker-empty-create-entry')),
      findsOneWidget,
    );
    // 空态不加列表 footer（列表本身不存在）
    expect(
      find.byKey(const ValueKey('workspace-picker-create-entry')),
      findsNothing,
    );
  });

  testWidgets('2 个工作区：2 tile + 底部常驻双入口', (tester) async {
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
      findsOneWidget,
    );
    expect(find.text('创建工作区'), findsOneWidget);
    expect(find.text('加入工作区'), findsOneWidget);
  });

  testWidgets('点击底部双入口：分别导航 /workspace/create 与 /workspace/join', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _seeded(container, count: 2);

    await _pump(tester, container, withRouter: true);

    await tester.tap(
      find.byKey(const ValueKey('workspace-picker-create-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('probe-create'), findsOneWidget);

    // 返回 picker 再验证加入入口
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-picker-join-entry')));
    await tester.pumpAndSettle();
    expect(find.text('probe-join'), findsOneWidget);
  });
}
