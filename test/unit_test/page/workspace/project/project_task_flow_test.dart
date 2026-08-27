/// WP6 (T10b) — Tasks 四态视图 / 任务表单 测试
///
/// 计划锚点（T10b VALIDATE）：
/// - 四态前向流转 + 回退 + 流转反馈（成功 toast / 失败 toast 带服务端
///   错误信息；禁止静默失败）；
/// - 非法流转由服务端 400 拒绝：消息原样透出（UI 只提供合法按钮，服务端
///   竞态拒绝时反馈可见）；
/// - 重复点击防抖（同一任务进行中只发一次请求）；
/// - Guest 只读（无写操作入口）；
/// - assignee 候选 = active Workspace Member（非成员不在候选；后端 400
///   指派校验消息显示）；候选刷新；
/// - 空态 / 加载态 / 错误态三态渲染。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart' as app_loading;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;
import 'package:imboy/page/workspace/project/tasks/project_tasks_view.dart';
import 'package:imboy/page/workspace/project/tasks/task_form_page.dart';
import 'package:imboy/store/api/project_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

const String _wsId = '9001';
const String _projectId = '5001';
const String _memberUid = '1002';
const String _extraUid = '1009';

ProjectModel get _project => const ProjectModel(
  id: _projectId,
  workspaceId: _wsId,
  name: '官网改版项目',
  ownerId: '1001',
);

ProjectTaskModel _task(
  String id, {
  TaskStatus status = TaskStatus.todo,
  EntityId assigneeId = '',
}) => ProjectTaskModel(
  id: id,
  projectId: _projectId,
  title: '任务-$id',
  creatorId: '1001',
  assigneeId: assigneeId,
  status: status,
);

const List<WorkspaceMemberModel> _candidates = [
  WorkspaceMemberModel(
    workspaceId: _wsId,
    userId: _memberUid,
    role: WorkspaceMemberRole.member,
    nickname: '韩梅梅',
    account: 'hanmeimei',
  ),
];

class _TaskFakeApi extends ProjectApi {
  final List<ProjectTaskModel> seed;
  Completer<void>? statusGate;
  Object? transitionError;
  Object? createError;
  final List<(EntityId, TaskStatus)> transitions = [];
  int createCalls = 0;
  EntityId? lastCreateAssignee;

  _TaskFakeApi(this.seed);

  @override
  Future<List<ProjectTaskModel>> tasks(
    EntityId projectId, {
    String status = 'all',
    int page = 1,
    int size = 200,
  }) async {
    return seed;
  }

  @override
  Future<TaskWriteResult> createTask({
    required EntityId projectId,
    required String title,
    EntityId? assigneeId,
    int sort = 0,
  }) async {
    createCalls += 1;
    lastCreateAssignee = assigneeId;
    final err = createError;
    if (err != null) throw err;
    return TaskWriteResult(task: _task('7001', assigneeId: assigneeId ?? ''));
  }

  @override
  Future<ProjectTaskModel> changeTaskStatus(
    EntityId taskId,
    TaskStatus to,
  ) async {
    final gate = statusGate;
    if (gate != null) await gate.future;
    final err = transitionError;
    if (err != null) throw err;
    transitions.add((taskId, to));
    return seed.firstWhere((t) => t.id == taskId, orElse: () => _task(taskId));
  }
}

class _MembersCountingApi extends WorkspaceApi {
  int calls = 0;
  List<WorkspaceMemberModel> nextCandidates;

  _MembersCountingApi({this.nextCandidates = _candidates});

  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    calls += 1;
    return WorkspacePageResult<WorkspaceMemberModel>(
      list: nextCandidates,
      total: nextCandidates.length,
      totalPage: 1,
    );
  }
}

Future<void> _pumpView(
  WidgetTester tester, {
  required ProjectApi projectApi,
  required WorkspaceApi wsApi,
  required bool writable,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          projectApiProvider.overrideWith((ref) => projectApi),
          workspaceApiProvider.overrideWith((ref) => wsApi),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectTasksSection(project: _project, writable: writable),
            ),
          ),
          builder: app_loading.AppLoading.init(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('四态列表与流转（T10b-1/3）', () {
    testWidgets('筛选条渲染四态 + 全部；待办任务显示前向按钮', (tester) async {
      final api = _TaskFakeApi([_task('101')]);
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);

      expect(find.text(t.workspace.taskStatusTodo), findsWidgets);
      expect(find.text(t.workspace.taskFilterAll), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-task-forward-101-todo')),
        findsOneWidget,
      );
      // todo 无回退目标 → 无回退菜单
      expect(
        find.byKey(const ValueKey('project-task-fallback-menu-101')),
        findsNothing,
      );
    });

    testWidgets('前向流转成功：API 收到相邻下一态 + 成功 toast', (tester) async {
      final api = _TaskFakeApi([_task('202', status: TaskStatus.doing)]);
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);

      // doing → review（前向仅相邻一步）
      await tester.tap(
        find.byKey(const ValueKey('project-task-forward-202-doing')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.transitions.single.$1, '202');
      expect(api.transitions.single.$2, TaskStatus.review);
      expect(
        find.textContaining(t.workspace.taskStatusReview),
        findsWidgets,
        reason: '成功 toast 必须出现（禁止静默失败）',
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('done 任务提供回退菜单：回退任意更低 rank 态', (tester) async {
      final api = _TaskFakeApi([_task('303', status: TaskStatus.done)]);
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);

      // done 无前向
      expect(
        find.byKey(const ValueKey('project-task-forward-303-done')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('project-task-fallback-menu-303')),
      );
      await tester.pumpAndSettle();

      // 回退目标 = review / doing / todo 全部出现
      for (final s in const [
        TaskStatus.review,
        TaskStatus.doing,
        TaskStatus.todo,
      ]) {
        expect(
          find.byKey(ValueKey('project-task-fallback-${s.wireName}')),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('project-task-fallback-todo')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.transitions.single.$2, TaskStatus.todo);
      expect(find.textContaining(t.workspace.taskStatusTodo), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('非法流转服务端 400：错误信息原样透出，不伪装成功', (tester) async {
      final api = _TaskFakeApi([_task('404', status: TaskStatus.doing)])
        ..transitionError = const WorkspaceApiException(
          400,
          '非法任务状态流转：doing → done',
        );
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);

      await tester.tap(
        find.byKey(const ValueKey('project-task-forward-404-doing')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.transitions, isEmpty, reason: '失败请求不得计入成功');
      expect(
        find.textContaining('非法任务状态流转'),
        findsOneWidget,
        reason: '服务端 400 消息必须原样透出',
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('归档 980：写操作被拒时归档错误码消息透出', (tester) async {
      final api = _TaskFakeApi([_task('505', status: TaskStatus.doing)])
        ..transitionError = const WorkspaceApiException(980, '工作区已归档，写操作已禁用');
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);

      await tester.tap(
        find.byKey(const ValueKey('project-task-forward-505-doing')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('已归档'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('防抖：流转请求未完成时按钮禁用，重复点击只发一次', (tester) async {
      final api = _TaskFakeApi([_task('606', status: TaskStatus.todo)])
        ..statusGate = Completer<void>();
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);

      final forwardKey = find.byKey(
        const ValueKey('project-task-forward-606-todo'),
      );
      await tester.tap(forwardKey);
      await tester.pump();

      // 进行中：同任务前向按钮已不可点（disabled）
      final button = tester.widget<IconButton>(forwardKey);
      expect(button.onPressed, isNull);
      await tester.tap(forwardKey, warnIfMissed: false);
      await tester.pump();
      expect(api.transitions, isEmpty, reason: '进行中不得重复提交');

      api.statusGate!.complete();
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.transitions.length, 1);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Guest 只读：无前向 / 回退 / 编辑入口', (tester) async {
      final api = _TaskFakeApi([
        _task('707', status: TaskStatus.doing),
        _task('708', status: TaskStatus.done),
      ]);
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: false);

      for (final id in const ['707', '708']) {
        expect(
          find.byKey(ValueKey('project-task-fallback-menu-$id')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('project-task-forward-$id-doing')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('project-task-forward-$id-done')),
          findsNothing,
        );
      }
      expect(
        find.byKey(const ValueKey('project-task-new-entry')),
        findsNothing,
      );
      // 列表仍可读（读不因只读而隐藏）
      expect(find.text('任务-707'), findsOneWidget);
    });
  });

  group('三态渲染', () {
    testWidgets('空态文案可见（非空白占位）', (tester) async {
      final api = _TaskFakeApi(const []);
      final wsApi = _MembersCountingApi();
      await _pumpView(tester, projectApi: api, wsApi: wsApi, writable: true);
      expect(find.textContaining(t.workspace.taskEmptyTitle), findsOneWidget);
      expect(find.textContaining('待办'), findsOneWidget);
    });

    testWidgets('加载态可见', (tester) async {
      final slowApi = _SlowTasksApi();
      final wsApi = _MembersCountingApi();
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              projectApiProvider.overrideWith((ref) => slowApi),
              workspaceApiProvider.overrideWith((ref) => wsApi),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ProjectTasksSection(project: _project, writable: true),
                ),
              ),
              builder: app_loading.AppLoading.init(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator),
        findsWidgets,
        reason: '加载中必须有可见指示（Day-1 Bar）',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('错误态：服务端消息 + 重试可用', (tester) async {
      final wsApi = _MembersCountingApi();
      await _pumpViewWithTasksApi(tester, _FailingTasksApi(), wsApi);
      expect(find.textContaining('not a member'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('project-task-retry')));
      await tester.pumpAndSettle();
    });
  });

  group('任务表单 assignee 候选（W0：active Workspace Member）', () {
    testWidgets('候选只来自 active 工作区成员；保存把选中成员作为 assignee 提交', (tester) async {
      final api = _TaskFakeApi(const []);
      final wsApi = _MembersCountingApi(
        nextCandidates: [
          ..._candidates,
          WorkspaceMemberModel(
            workspaceId: _wsId,
            userId: _extraUid,
            role: WorkspaceMemberRole.guest,
            nickname: '补充成员',
            account: 'extra',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/x',
        routes: [
          GoRoute(
            path: '/x',
            builder: (c, s) =>
                TaskFormPage(projectId: _projectId, workspaceId: _wsId),
          ),
          GoRoute(path: '/back', builder: (c, s) => const Text('popped')),
        ],
      );
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              projectApiProvider.overrideWith((ref) => api),
              workspaceApiProvider.overrideWith((ref) => wsApi),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: app_loading.AppLoading.init(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 候选来源 = members 接口返回集（active 关系）；1003 非成员不在其中
      expect(wsApi.calls, greaterThanOrEqualTo(1));
      expect(
        find.byKey(ValueKey('task-assignee-option-$_memberUid')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('task-assignee-option-$_extraUid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('task-assignee-option-none')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('task-assignee-option-1003')),
        findsNothing,
        reason: '非 active Workspace Member 不在候选',
      );

      // 选韩梅梅并提交
      await tester.tap(find.byKey(const ValueKey('task-assignee-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('韩梅梅').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        '带指派任务',
      );
      await tester.tap(find.byKey(const ValueKey('task-form-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.createCalls, 1);
      expect(api.lastCreateAssignee, _memberUid);
      expect(find.text(t.workspace.taskCreatedToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('后端 400 指派校验：非 active 成员指派的错误消息显示', (tester) async {
      final api = _TaskFakeApi(const [])
        ..createError = const WorkspaceApiException(400, '指派对象必须是活跃的工作区成员');
      final wsApi = _MembersCountingApi();
      await _pumpForm(tester, api: api, wsApi: wsApi);

      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        '指派给非成员',
      );
      await tester.tap(find.byKey(const ValueKey('task-form-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('活跃的工作区成员'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('成员变化后刷新候选：invalidate 后重拉并渲染新候选', (tester) async {
      final api = _TaskFakeApi(const []);
      final wsApi = _MembersCountingApi();
      await _pumpForm(tester, api: api, wsApi: wsApi);
      final callsAfterFirstLoad = wsApi.calls;
      expect(callsAfterFirstLoad, greaterThanOrEqualTo(1));

      // 后台新增成员后 tap「刷新候选」
      wsApi.nextCandidates = [
        ...wsApi.nextCandidates,
        const WorkspaceMemberModel(
          workspaceId: _wsId,
          userId: _extraUid,
          role: WorkspaceMemberRole.member,
          nickname: '新成员',
          account: 'newcomer',
        ),
      ];
      await tester.tap(find.byKey(const ValueKey('task-assignee-refresh')));
      await tester.pumpAndSettle();

      expect(
        wsApi.calls,
        greaterThan(callsAfterFirstLoad),
        reason: '刷新必须重新拉取 active 成员',
      );
      expect(
        find.byKey(ValueKey('task-assignee-option-$_extraUid')),
        findsOneWidget,
        reason: '新候选在刷新后可见（成员变化即时反映）',
      );
    });

    testWidgets('空标题本地校验不发请求；标题为空时提示 taskTitleRequired', (tester) async {
      final api = _TaskFakeApi(const []);
      final wsApi = _MembersCountingApi();
      await _pumpForm(tester, api: api, wsApi: wsApi);

      await tester.tap(find.byKey(const ValueKey('task-form-submit')));
      await tester.pump();
      expect(api.createCalls, 0);
      expect(find.text(t.workspace.taskTitleRequired), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });
}

// ==================== 辅助 Fake（顶层，testWidgets 内不允许声明类） ====================

class _SlowTasksApi extends ProjectApi {
  @override
  Future<List<ProjectTaskModel>> tasks(
    EntityId projectId, {
    String status = 'all',
    int page = 1,
    int size = 200,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return const [];
  }
}

class _FailingTasksApi extends ProjectApi {
  @override
  Future<List<ProjectTaskModel>> tasks(
    EntityId projectId, {
    String status = 'all',
    int page = 1,
    int size = 200,
  }) async {
    throw const WorkspaceApiException(403, 'not a member');
  }
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required ProjectApi api,
  required WorkspaceApi wsApi,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/x',
    routes: [
      GoRoute(
        path: '/x',
        builder: (c, s) =>
            TaskFormPage(projectId: _projectId, workspaceId: _wsId),
      ),
    ],
  );
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          projectApiProvider.overrideWith((ref) => api),
          workspaceApiProvider.overrideWith((ref) => wsApi),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: app_loading.AppLoading.init(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpViewWithTasksApi(
  WidgetTester tester,
  ProjectApi tasksApi,
  WorkspaceApi wsApi,
) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          projectApiProvider.overrideWith((ref) => tasksApi),
          workspaceApiProvider.overrideWith((ref) => wsApi),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectTasksSection(project: _project, writable: true),
            ),
          ),
          builder: app_loading.AppLoading.init(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
