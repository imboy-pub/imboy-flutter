/// WP6 (T10a) — Projects 列表 / 创建表单 / 项目详情 视图测试
///
/// 计划锚点（T10a VALIDATE W0 版）：
/// - 列表展示集合 API 结果（W0 全部 active Workspace Member 可见）；
/// - 创建表单校验 + 提交（防抖 + 服务端错误透出）；
/// - 详情三态渲染（加载态、错误态；空列表空态由列表页承载）；
/// - （W0）active Workspace Member 可进入且**无成员区块**；
/// - Guest 只读（无状态切换 / 无新建任务入口）；
/// - Gate W Scope Contract：Pinned / Resources / Activity / 关联 Channel
///   全部 defer —— **任何占位 UI 均不得出现**（本文件显式断言）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart' as app_loading;
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;
import 'package:imboy/page/workspace/project/home/project_create_page.dart';
import 'package:imboy/page/workspace/project/home/project_detail_page.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/project_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show WorkspaceErrorView, WorkspaceLoadingView;

const String _wsId = '9001';
const String _ownerUid = '1001';
const String _guestUid = '1003';
const String _projectId = '5001';

WorkspaceModel _ws({WorkspaceStatus status = WorkspaceStatus.active}) =>
    WorkspaceModel(id: _wsId, name: '官网改版', ownerId: _ownerUid, status: status);

const List<WorkspaceMemberModel> _members = [
  WorkspaceMemberModel(
    workspaceId: _wsId,
    userId: _ownerUid,
    role: WorkspaceMemberRole.owner,
    nickname: '李雷',
    account: 'leilei',
  ),
  WorkspaceMemberModel(
    workspaceId: _wsId,
    userId: _guestUid,
    role: WorkspaceMemberRole.guest,
    nickname: '访客王',
    account: 'wang',
  ),
];

ProjectModel _project({ProjectStatus status = ProjectStatus.active}) =>
    ProjectModel(
      id: _projectId,
      workspaceId: _wsId,
      name: '官网改版项目',
      description: '公司官网 2026 改版',
      ownerId: _ownerUid,
      status: status,
    );

/// Project API 可控 Fake：记录调用并允许注入失败/延迟。
class _ProjectFakeApi extends ProjectApi {
  final List<ProjectModel> listSeed;
  Object? detailError;
  int createCalls = 0;
  int listCalls = 0;
  final List<(EntityId, ProjectStatus)> statusCalls = [];
  Completer<void>? createGate;

  _ProjectFakeApi({this.listSeed = const []});

  @override
  Future<WorkspacePageResult<ProjectModel>> list(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    listCalls += 1;
    return WorkspacePageResult<ProjectModel>(
      list: page == 1 ? listSeed : const <ProjectModel>[],
      total: listSeed.length,
      totalPage: 1,
    );
  }

  @override
  Future<ProjectModel> create({
    required EntityId workspaceId,
    required String name,
    String description = '',
  }) async {
    createCalls += 1;
    final gate = createGate;
    if (gate != null) await gate.future;
    return ProjectModel(
      id: '6001',
      workspaceId: workspaceId,
      name: name,
      description: description,
      ownerId: _ownerUid,
    );
  }

  @override
  Future<ProjectModel> detail(EntityId projectId) async {
    final err = detailError;
    if (err != null) throw err;
    return _project();
  }

  @override
  Future<ProjectModel> updateStatus(
    EntityId projectId,
    ProjectStatus status,
  ) async {
    statusCalls.add((projectId, status));
    return _project(status: status);
  }
}

/// Workspace API Fake：仅供 assigneeCandidatesProvider / 角色推导读成员。
class _MembersOnlyFakeApi extends WorkspaceApi {
  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    return WorkspacePageResult<WorkspaceMemberModel>(
      list: _members,
      total: _members.length,
      totalPage: 1,
    );
  }
}

GoRouter _router(Widget home) => GoRouter(
  initialLocation: '/x',
  routes: [
    GoRoute(path: '/x', builder: (c, s) => home),
    GoRoute(path: '/fallback', builder: (c, s) => const Text('popped')),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  required ProjectApi projectApi,
  required WorkspaceApi workspaceApi,
  WorkspaceModel? ws,
  bool withRouter = false,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // 注意：overrides 列表保持无类型注解的字面量（元素类型经 use-site
  // 推断为 riverpod Override），不要显式写 List<Override>——该类型
  // 未被 flutter_riverpod 3.3.1 导出。
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        // 测试区禁用 riverpod3 自动重试（FakeAsync 推不动退避 timer，
        // 会把 AsyncError 状态无限期挡在 loading 之后）
        retry: (retryCount, error) => null,
        overrides: [
          projectApiProvider.overrideWith((ref) => projectApi),
          workspaceApiProvider.overrideWith((ref) => workspaceApi),
          if (ws != null) currentWorkspaceProvider.overrideWithValue(ws),
        ],
        child: withRouter
            ? MaterialApp.router(
                routerConfig: _router(home),
                builder: app_loading.AppLoading.init(),
              )
            : MaterialApp(home: home, builder: app_loading.AppLoading.init()),
      ),
    ),
  );
  // 步进 pump 代替 pumpAndSettle：详情页存在常驻动画组件时 settle 永不满足
  for (final ms in const [16, 60, 200, 400]) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  group('Projects 列表页（T10a-1 完整列表）', () {
    testWidgets('展示集合 API 结果 + 创建入口 + 项目卡渲染', (tester) async {
      final api = _ProjectFakeApi(listSeed: [_project()]);
      await _pump(
        tester,
        home: const WorkspaceProjectsPage(),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        ws: _ws(),
      );

      expect(
        find.byKey(const ValueKey('workspace-project-create-entry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace-project-card-$_projectId')),
        findsOneWidget,
      );
      expect(find.text('官网改版项目'), findsOneWidget);
      expect(find.text(t.workspace.projectCreateEntry), findsOneWidget);
    });

    testWidgets('集合接口失败：整页错误态 + 服务端消息透出', (tester) async {
      await _pump(
        tester,
        home: const WorkspaceProjectsPage(),
        projectApi: _FailingListApi(),
        workspaceApi: _MembersOnlyFakeApi(),
        ws: _ws(),
      );
      expect(find.byType(WorkspaceErrorView), findsOneWidget);
      expect(find.textContaining('list failed'), findsOneWidget);
    });

    testWidgets('archived 工作区：创建入口禁用（对齐 WP5 归档模式）', (tester) async {
      final api = _ProjectFakeApi(listSeed: [_project()]);
      await _pump(
        tester,
        home: const WorkspaceProjectsPage(),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        ws: _ws(status: WorkspaceStatus.archived),
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('workspace-project-create-entry')),
      );
      expect(button.onPressed, isNull, reason: 'archived 下创建入口必须禁用');
    });
  });

  group('创建 Project 表单（T10a-3）', () {
    testWidgets('空名校验：本地提示且不发请求', (tester) async {
      final api = _ProjectFakeApi();
      await _pump(
        tester,
        home: const ProjectCreatePage(workspaceId: _wsId),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        withRouter: true,
      );

      await tester.tap(find.byKey(const ValueKey('project-create-submit')));
      await tester.pump();
      expect(api.createCalls, 0);
      expect(find.text(t.workspace.projectNameRequired), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('填写后创建成功：调用 create + 成功 toast + 返回上一页', (tester) async {
      final api = _ProjectFakeApi();
      await _pump(
        tester,
        home: const ProjectCreatePage(workspaceId: _wsId),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        withRouter: true,
      );

      await tester.enterText(
        find.byKey(const ValueKey('project-create-name-field')),
        '新项目',
      );
      await tester.tap(find.byKey(const ValueKey('project-create-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(api.createCalls, 1);
      expect(find.text(t.workspace.projectCreateSuccess), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('防抖：提交进行中按钮禁用，重复点击只发一次', (tester) async {
      final api = _ProjectFakeApi()..createGate = Completer<void>();
      await _pump(
        tester,
        home: const ProjectCreatePage(workspaceId: _wsId),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        withRouter: true,
      );

      await tester.enterText(
        find.byKey(const ValueKey('project-create-name-field')),
        '防抖项目',
      );
      await tester.tap(find.byKey(const ValueKey('project-create-submit')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('project-create-submit')),
      );
      expect(button.onPressed, isNull, reason: '提交进行中必须禁用');
      await tester.tap(find.byKey(const ValueKey('project-create-submit')));
      await tester.pump();
      expect(api.createCalls, 1, reason: '进行中的重复点击不得重复提交');

      api.createGate!.complete();
      for (final ms in const [16, 60, 200, 400]) {
        await tester.pump(Duration(milliseconds: ms));
      }
      expect(api.createCalls, 1);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Project 详情页（T10a-2）', () {
    testWidgets('加载态可见 → 数据态基本信息卡渲染', (tester) async {
      final api = _DelayedDetailApi();
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            retry: (retryCount, error) => null,
            overrides: [
              projectApiProvider.overrideWith((ref) => api),
              workspaceApiProvider.overrideWith((ref) => _MembersOnlyFakeApi()),
              currentWorkspaceProvider.overrideWithValue(_ws()),
            ],
            child: MaterialApp(
              home: const ProjectDetailPage(projectId: _projectId),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(WorkspaceLoadingView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      for (final ms in const [16, 60, 200, 400]) {
        await tester.pump(Duration(milliseconds: ms));
      }
      expect(find.text('官网改版项目'), findsOneWidget);
      expect(find.textContaining('公司官网 2026 改版'), findsOneWidget);
    });

    testWidgets('错误态：服务端消息 + 重试可点', (tester) async {
      final api = _ProjectFakeApi()
        ..detailError = const WorkspaceApiException(404, '项目不存在');
      await _pump(
        tester,
        home: const ProjectDetailPage(projectId: _projectId),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        ws: _ws(),
      );
      expect(find.byType(WorkspaceErrorView), findsOneWidget);
      expect(find.textContaining('项目不存在'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-error-retry')));
      for (final ms in const [16, 60, 200, 400]) {
        await tester.pump(Duration(milliseconds: ms));
      }
    });

    testWidgets('W0 defer 断言：Pinned/Resources/Activity/关联频道/成员区块无任何占位 UI', (
      tester,
    ) async {
      final api = _ProjectFakeApi();
      await _pump(
        tester,
        home: const ProjectDetailPage(projectId: _projectId),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        ws: _ws(),
      );

      // Gate W=W0 Scope Contract：defer 能力一律不出现 tab / 区块 / 空态占位
      // ——详情页只有「基本信息 + Tasks 区块」。
      expect(find.textContaining('置顶'), findsNothing);
      expect(find.textContaining('Pinned'), findsNothing);
      expect(find.textContaining('资源'), findsNothing);
      expect(find.textContaining('Resources'), findsNothing);
      expect(find.textContaining('动态'), findsNothing);
      expect(find.textContaining('Activity'), findsNothing);
      expect(find.textContaining('关联频道'), findsNothing);
      expect(find.textContaining('相关频道'), findsNothing);
      expect(find.textContaining('项目成员'), findsNothing);
      // 成员管理区块入口亦不存在（W0 无 Project Members）
      expect(find.textContaining('成员管理'), findsNothing);
    });

    testWidgets('Owner 可写：状态切换调用 updateStatus + toast；新建任务入口存在', (
      tester,
    ) async {
      final api = _ProjectFakeApi();
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await StorageService.to.setString(Keys.currentUid, _ownerUid);
      addTearDown(() => StorageService.to.remove(Keys.currentUid));

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            retry: (retryCount, error) => null,
            overrides: [
              projectApiProvider.overrideWith((ref) => api),
              workspaceApiProvider.overrideWith((ref) => _MembersOnlyFakeApi()),
              currentWorkspaceProvider.overrideWithValue(_ws()),
            ],
            child: MaterialApp(
              home: const ProjectDetailPage(projectId: _projectId),
              builder: app_loading.AppLoading.init(),
            ),
          ),
        ),
      );
      for (final ms in const [16, 60, 200, 400]) {
        await tester.pump(Duration(milliseconds: ms));
      }

      expect(
        find.byKey(const ValueKey('project-status-toggle-active')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-task-new-entry')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-status-toggle-active')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.statusCalls.length, 1);
      expect(api.statusCalls.single.$2, ProjectStatus.done);
      expect(find.text(t.workspace.projectStatusChanged), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Guest 只读：无状态切换与新建任务入口', (tester) async {
      final api = _ProjectFakeApi();
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await StorageService.to.setString(Keys.currentUid, _guestUid);
      addTearDown(() => StorageService.to.remove(Keys.currentUid));

      await _pump(
        tester,
        home: const ProjectDetailPage(projectId: _projectId),
        projectApi: api,
        workspaceApi: _MembersOnlyFakeApi(),
        ws: _ws(),
      );

      expect(
        find.byKey(const ValueKey('project-status-toggle-active')),
        findsNothing,
        reason: 'Guest 只读：状态切换入口不出现',
      );
      expect(
        find.byKey(const ValueKey('project-task-new-entry')),
        findsNothing,
      );
    });
  });
}

// ==================== 辅助 Fake ====================

class _DelayedDetailApi extends ProjectApi {
  @override
  Future<ProjectModel> detail(EntityId projectId) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return _project();
  }
}

class _FailingListApi extends ProjectApi {
  @override
  Future<WorkspacePageResult<ProjectModel>> list(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    throw const WorkspaceApiException(403, 'list failed: not a member');
  }
}
