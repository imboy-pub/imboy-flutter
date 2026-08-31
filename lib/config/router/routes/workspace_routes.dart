/// T8 (WP5) — Workspace 分域路由（镜像 channel_routes.dart 分文件模式）
///
/// 路由清单（静态路径先于动态参数注册，防 404/遮蔽）：
/// - /workspace                      → 工作区切换器（我的工作区列表）
/// - /workspace/create               → 创建工作区（Template 3 分钟建站）
/// - /workspace/:workspaceId/channels/:channelId → 工作区频道详情
///   （I6：只有发帖/评论入口 + 讨论引导至 Group）
/// - /workspace/:workspaceId/members/invite      → 邀请工作区成员向导
/// - /workspace/:workspaceId/branding            → Branding 编辑（T12）
///
/// 壳本体不走路由：experience=workspace 时由 ChatShellBootstrap 在
/// /bottom_navigation 挂载点分发到 WorkspaceShellBootstrap（镜像 T2 的
/// ChatShell 挂载方式）。
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../barrel/pages_barrel.dart';

List<RouteBase> workspaceRoutes() => [
  // ==================== 工作区 ====================
  GoRoute(
    path: '/workspace',
    name: 'workspace_picker',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const WorkspacePickerPage()),
    routes: [
      // 静态路径须注册在 :workspaceId 子路由之前
      GoRoute(
        path: '/create',
        name: 'workspace_create',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const WorkspaceCreatePage(),
        ),
      ),
      // 工作区成员（2026-08-31 UX 收敛：Members 退出五项导航，入口收敛进
      // Overview「工作区成员」卡片；页面读 currentWorkspaceProvider 无参挂载）
      GoRoute(
        path: '/members',
        name: 'workspace_members',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const WorkspaceMembersPage(),
        ),
      ),
      // ==================== Project（WP6 T10a/T10b） ====================
      // 静态 /projects/create 先于动态 /projects/:projectId 注册
      GoRoute(
        path: '/:workspaceId/projects/create',
        name: 'workspace_project_create',
        pageBuilder: (context, state) {
          final wsId = state.pathParameters['workspaceId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: ProjectCreatePage(workspaceId: wsId),
          );
        },
      ),
      GoRoute(
        path: '/:workspaceId/projects/:projectId',
        name: 'workspace_project_detail',
        pageBuilder: (context, state) {
          final wsId = state.pathParameters['workspaceId'] ?? '';
          final projectId = state.pathParameters['projectId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: ProjectDetailPage(projectId: projectId, workspaceId: wsId),
          );
        },
        routes: [
          // 任务创建（T10b）：/workspace/:wsId/projects/:projectId/tasks/new
          GoRoute(
            path: 'tasks/new',
            name: 'workspace_task_create',
            pageBuilder: (context, state) {
              final wsId = state.pathParameters['workspaceId'] ?? '';
              final projectId = state.pathParameters['projectId'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: TaskFormPage(projectId: projectId, workspaceId: wsId),
              );
            },
          ),
          // 任务编辑：…/tasks/:taskId/edit
          // （表单页按 taskId 内部经 projectTaskDetailProvider 加载既有行）
          GoRoute(
            path: 'tasks/:taskId/edit',
            name: 'workspace_task_edit',
            pageBuilder: (context, state) {
              final wsId = state.pathParameters['workspaceId'] ?? '';
              final projectId = state.pathParameters['projectId'] ?? '';
              final taskId = state.pathParameters['taskId'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: TaskFormPage(
                  projectId: projectId,
                  workspaceId: wsId,
                  taskId: taskId,
                ),
              );
            },
          ),
          // ==================== W2 (ZC-06)：项目协作子页 ====================
          // 成员 / 里程碑 / 项目频道 / 内容聚合（四聚合）
          GoRoute(
            path: 'members',
            name: 'workspace_project_members',
            pageBuilder: (context, state) {
              final wsId = state.pathParameters['workspaceId'] ?? '';
              final projectId = state.pathParameters['projectId'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: ProjectMembersPage(
                  projectId: projectId,
                  workspaceId: wsId,
                ),
              );
            },
          ),
          GoRoute(
            path: 'milestones',
            name: 'workspace_project_milestones',
            pageBuilder: (context, state) {
              final wsId = state.pathParameters['workspaceId'] ?? '';
              final projectId = state.pathParameters['projectId'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: ProjectMilestonesPage(
                  projectId: projectId,
                  workspaceId: wsId,
                ),
              );
            },
          ),
          GoRoute(
            path: 'channels',
            name: 'workspace_project_channels',
            pageBuilder: (context, state) {
              final wsId = state.pathParameters['workspaceId'] ?? '';
              final projectId = state.pathParameters['projectId'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: ProjectChannelsPage(
                  projectId: projectId,
                  workspaceId: wsId,
                ),
              );
            },
          ),
          GoRoute(
            path: 'insights',
            name: 'workspace_project_insights',
            pageBuilder: (context, state) {
              final wsId = state.pathParameters['workspaceId'] ?? '';
              final projectId = state.pathParameters['projectId'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: ProjectInsightsPage(
                  projectId: projectId,
                  workspaceId: wsId,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/:workspaceId/channels/:channelId',
        name: 'workspace_channel_detail',
        pageBuilder: (context, state) {
          final channelId = state.pathParameters['channelId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: WorkspaceChannelDetailPage(channelId: channelId),
          );
        },
      ),
      GoRoute(
        path: '/:workspaceId/members/invite',
        name: 'workspace_invite',
        pageBuilder: (context, state) {
          final wsId = state.pathParameters['workspaceId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: WorkspaceInvitePage(workspaceId: wsId),
          );
        },
      ),
      GoRoute(
        path: '/:workspaceId/branding',
        name: 'workspace_branding',
        pageBuilder: (context, state) {
          final wsId = state.pathParameters['workspaceId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: WorkspaceBrandingPage(workspaceId: wsId),
          );
        },
      ),
    ],
  ),
];
