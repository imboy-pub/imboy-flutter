/// W2 (ZC-06) — 详情页「项目协作」入口区测试
///
/// 契约：仅挂导航入口不改既有交互；4 个入口 push 到 W2 子页路由；
/// workspaceId 缺失时不渲染。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_entry_section.dart';

import 'w2_test_helpers.dart';

Widget _host(Widget child) =>
    TranslationProvider(child: MaterialApp(home: child));

void main() {
  testWidgets('渲染四个协作入口（成员/里程碑/项目频道/内容聚合）', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProjectW2EntrySection(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('project-w2-entry-members')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-w2-entry-milestones')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-w2-entry-channels')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-w2-entry-insights')),
      findsOneWidget,
    );
  });

  testWidgets('workspaceId 缺失：整区不渲染', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProjectW2EntrySection(projectId: testProjectId, workspaceId: ''),
      ),
    );
    expect(
      find.byKey(const ValueKey('project-w2-entry-members')),
      findsNothing,
    );
  });

  testWidgets('入口可点击导航（go_router push 到 W2 子页路由）', (tester) async {
    final router = GoRouter(
      initialLocation: '/workspace/$testWsId/projects/$testProjectId',
      routes: [
        GoRoute(
          path: '/workspace/:workspaceId/projects/:projectId',
          builder: (c, s) => Scaffold(
            body: ProjectW2EntrySection(
              projectId: s.pathParameters['projectId'] ?? '',
              workspaceId: s.pathParameters['workspaceId'] ?? '',
            ),
          ),
          routes: [
            GoRoute(
              path: 'members',
              builder: (c, s) => const Scaffold(body: Text('W2-MEMBERS-PAGE')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.tap(find.byKey(const ValueKey('project-w2-entry-members')));
    await tester.pumpAndSettle();
    expect(find.text('W2-MEMBERS-PAGE'), findsOneWidget);
  });
}
