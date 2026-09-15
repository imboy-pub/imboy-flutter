/// 企业模块路由（镜像 workspace_routes.dart 分文件模式）。
///
/// 路由清单（本文件在 owned path 内；注册进 app_router.dart 的两行为
/// 共享文件改动，A4 报告已申报）：
/// - /enterprise                                          → 企业入口页
/// - /enterprise/:orgId/conversations/:conversationId     → 企业会话页
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'enterprise_conversation_page.dart';
import 'enterprise_home_page.dart';

List<RouteBase> enterpriseRoutes() => [
  GoRoute(
    path: kEnterpriseHomePath,
    name: 'enterprise_home',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const EnterpriseHomePage()),
    routes: [
      GoRoute(
        path: ':orgId/conversations/:conversationId',
        name: 'enterprise_conversation',
        pageBuilder: (context, state) {
          final orgId = state.pathParameters['orgId'] ?? '';
          final conversationId = state.pathParameters['conversationId'] ?? '';
          final contactName = state.uri.queryParameters['contact_name'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: EnterpriseConversationPage(
              orgId: orgId,
              conversationId: conversationId,
              contactName: contactName,
            ),
          );
        },
      ),
    ],
  ),
];
