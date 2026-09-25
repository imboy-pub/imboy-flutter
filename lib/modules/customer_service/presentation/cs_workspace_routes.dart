/// 客服工作台路由（§12.5.1 / CSM-01+02；镜像 enterprise_routes.dart 分文件模式）。
///
/// 路由清单（本文件在 owned path 内；注册进 app_router.dart 的两行为
/// 共享文件改动，与 enterprise_routes 同款申报）：
/// - /customer_service/workspace → 坐席工作台（queued/active/closed 三视图）
/// - /customer_service/workspace/sessions/:sessionId → 坐席会话页
///   （企业消息通道 + 转接/关闭/评分状态；query: org_id, conversation_id,
///   identity_id, contact_name）
/// - /customer_service/governance/:orgId → 企业自助客服治理页
///   （CS-APP-03 / CS-GOV-02B：owner/admin 治理区，租户 Human JWT API；
///   顶层路由——治理域独立于坐席工作台，不得混入 Seat 会话域）。
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'cs_governance_page.dart';
import 'cs_session_page.dart';
import 'cs_workspace_page.dart';

/// 坐席工作台路由。
const String kCsWorkspacePath = '/customer_service/workspace';

/// 客服治理页路径前缀（CS-APP-03；顶层路由，入口 tile 在组织详情页
/// 管理员区，Human JWT 治理域与 Seat 工作台分离）。
const String kCsGovernancePathPrefix = '/customer_service/governance';

/// 拼 org 作用域的治理页路径。
String csGovernancePath(EntityId orgId) => '$kCsGovernancePathPrefix/$orgId';

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
  GoRoute(
    path: '$kCsGovernancePathPrefix/:orgId',
    name: 'cs_governance',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: CsGovernancePage(orgId: state.pathParameters['orgId'] ?? ''),
    ),
  ),
];
