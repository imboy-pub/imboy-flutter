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
