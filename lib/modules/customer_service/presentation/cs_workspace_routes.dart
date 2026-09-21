/// 客服工作台路由（§12.5.1 / CSM-01+02；镜像 enterprise_routes.dart 分文件模式）。
///
/// 路由清单（本文件在 owned path 内；注册进 app_router.dart 的两行为
/// 共享文件改动，与 enterprise_routes 同款申报）：
/// - /customer_service/workspace → 坐席工作台（queued/active/closed 三视图）
/// - /customer_service/workspace/sessions/:sessionId → 坐席会话页
///   （企业消息通道 + 转接/关闭/评分状态；query: org_id, conversation_id,
///   identity_id, contact_name）
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'cs_session_page.dart';
import 'cs_workspace_page.dart';

/// 坐席工作台路由。
const String kCsWorkspacePath = '/customer_service/workspace';

List<RouteBase> csWorkspaceRoutes() => [
  GoRoute(
    path: kCsWorkspacePath,
    name: 'cs_workspace',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const CsWorkspacePage()),
    routes: [
      GoRoute(
        path: 'sessions/:sessionId',
        name: 'cs_session',
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          final query = state.uri.queryParameters;
          return CupertinoPage(
            key: state.pageKey,
            child: CsSessionPage(
              sessionId: sessionId,
              orgId: query['org_id'] ?? '',
              conversationId: query['conversation_id'] ?? '',
              identityId: query['identity_id'] ?? '',
              workspaceId: query['workspace_id'] ?? '',
              contactName: query['contact_name'] ?? '',
            ),
          );
        },
      ),
    ],
  ),
];
