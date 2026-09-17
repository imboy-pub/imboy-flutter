/// Organization 模块路由（镜像 enterprise_routes.dart 分文件模式）。
///
/// 路由清单（本文件在 owned path 内；注册进 app_router.dart 的两行为
/// 共享文件精确行租约，逐行记录进 evidence）：
/// - /organization                       → 我所在组织（切换/创建）
/// - /organization/:orgId                → 组织详情/治理入口
/// - /organization/:orgId/members        → 成员治理（owner/admin）
/// - /organization/:orgId/invitations    → 邀请治理 或 我的邀请（?mode=mine）
/// - /organization/:orgId/departments    → 部门目录
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'organization_departments_page.dart';
import 'organization_detail_page.dart';
import 'organization_home_page.dart';
import 'organization_invitations_page.dart';
import 'organization_members_page.dart';

const String kOrganizationHomePath = '/organization';
const String kOrganizationDetailPath = '$kOrganizationHomePath/:orgId';
const String kOrganizationMembersPath = '$kOrganizationDetailPath/members';
const String kOrganizationInvitationsPath =
    '$kOrganizationDetailPath/invitations';
const String kOrganizationDepartmentsPath =
    '$kOrganizationDetailPath/departments';

List<RouteBase> organizationRoutes() => [
  GoRoute(
    path: kOrganizationHomePath,
    name: 'organization_home',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const OrganizationHomePage()),
    routes: [
      GoRoute(
        path: ':orgId',
        name: 'organization_detail',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: OrganizationDetailPage(
            orgId: state.pathParameters['orgId'] ?? '',
          ),
        ),
        routes: [
          GoRoute(
            path: 'members',
            name: 'organization_members',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: OrganizationMembersPage(
                orgId: state.pathParameters['orgId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: 'invitations',
            name: 'organization_invitations',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: OrganizationInvitationsPage(
                orgId: state.pathParameters['orgId'] ?? '',
                mineMode: state.uri.queryParameters['mode'] == 'mine',
              ),
            ),
          ),
          GoRoute(
            path: 'departments',
            name: 'organization_departments',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: OrganizationDepartmentsPage(
                orgId: state.pathParameters['orgId'] ?? '',
              ),
            ),
          ),
        ],
      ),
    ],
  ),
];
