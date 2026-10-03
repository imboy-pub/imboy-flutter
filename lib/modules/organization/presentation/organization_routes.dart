/// Organization 模块路由（镜像 enterprise_routes.dart 分文件模式）。
///
/// 路由清单（本文件在 owned path 内；注册进 app_router.dart 的两行为
/// 共享文件精确行租约，逐行记录进 evidence）：
/// - /organization                       → 我所在组织（切换/创建）
/// - /organization/picker                → 企业选择器（GZAPP-04 G9：切换/
///   加入企业，数据源 Organization membership）
/// - /organization/:orgId                → 组织详情/治理入口
/// - /organization/:orgId/members        → 成员治理（owner/admin）
/// - /organization/:orgId/invitations    → 邀请治理 或 我的邀请（?mode=mine）
/// - /organization/:orgId/departments    → 部门目录
/// - /organization/:orgId/directory      → 通讯录（GZAPP-04 G10：全员视角）
/// - /organization/:orgId/member/:uid    → 成员详情（GZAPP-C3：含该成员在本企业
///   内的有权工作区，§5.2；全员可见）
/// - /organization/:orgId/manage         → 企业管理（GZAPP-05：工作区/群/频道
///   治理；非 owner/admin 直达时页内给只读 + 无权限态）
/// - /organization/:orgId/tools           → 企业工具聚合（ENT-APP-06：本企业
///   已授权的工作区项目/任务入口，只读聚合）
/// - /organization/:orgId/ws/:wsId/members → 工作区成员治理（ENT-APP-06：
///   org 视角显式带 wsId 的成员面；写动作仅该工作区 Owner）
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';

import 'human_directory_page.dart';
import 'organization_departments_page.dart';
import 'organization_detail_page.dart';
import 'organization_home_page.dart';
import 'organization_invitations_page.dart';
import 'organization_manage_page.dart';
import 'organization_member_detail_page.dart';
import 'organization_members_page.dart';
import 'organization_picker_page.dart';
import 'organization_session_scope.dart';
import 'organization_tools_page.dart';
import 'org_workspace_members_page.dart';

const String kOrganizationHomePath = '/organization';
const String kOrganizationPickerPath = '$kOrganizationHomePath/picker';
const String kOrganizationDetailPath = '$kOrganizationHomePath/:orgId';
const String kOrganizationMembersPath = '$kOrganizationDetailPath/members';
const String kOrganizationInvitationsPath =
    '$kOrganizationDetailPath/invitations';
const String kOrganizationDepartmentsPath =
    '$kOrganizationDetailPath/departments';
const String kOrganizationDirectoryPath = '$kOrganizationDetailPath/directory';
const String kOrganizationMemberDetailPath = '$kOrganizationDetailPath/member';
const String kOrganizationManagePath = '$kOrganizationDetailPath/manage';

List<RouteBase> organizationRoutes() => [
  GoRoute(
    path: kOrganizationHomePath,
    name: 'organization_home',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: OrganizationSessionBoundary(
        builder: (account) => OrganizationHomePage(accountKey: account),
      ),
    ),
    routes: [
      // 静态段 'picker' 优先于参数段 ':orgId'（go_router 匹配序）。
      GoRoute(
        path: 'picker',
        name: 'organization_picker',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: OrganizationSessionBoundary(
            builder: (account) => OrganizationPickerPage(
              accountKey: account,
              // §5.1「加入企业」入口可直接落到加入动作（?autoJoin=1）
              autoJoin: state.uri.queryParameters['autoJoin'] == '1',
            ),
          ),
        ),
      ),
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
          GoRoute(
            path: 'directory',
            name: 'organization_directory',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: HumanDirectoryBrowserPage(
                orgId: state.pathParameters['orgId'] ?? '',
                orgName: state.uri.queryParameters['name'] ?? '',
                departmentId: state.uri.queryParameters['department_id'],
                departmentName:
                    state.uri.queryParameters['department_name'] ?? '',
              ),
            ),
          ),
          // GZAPP-C3 成员详情：静态段 'member' 与 'members' 不同路径段，
          // 不冲突（go_router 按完整段匹配）。
          GoRoute(
            path: 'member/:uid',
            name: 'organization_member_detail',
            pageBuilder: (context, state) {
              final extra = state.extra;
              final map = extra is Map<String, dynamic>
                  ? extra
                  : const <String, dynamic>{};
              final member = map['member'];
              return CupertinoPage(
                key: state.pageKey,
                child: OrganizationMemberDetailPage(
                  orgId: state.pathParameters['orgId'] ?? '',
                  userId: state.pathParameters['uid'] ?? '',
                  member: member is OrganizationMember ? member : null,
                  orgName: (map['orgName'] as String?) ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: 'manage',
            name: 'organization_manage',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: OrganizationManagePage(
                orgId: state.pathParameters['orgId'] ?? '',
              ),
            ),
          ),
          // ENT-APP-06：企业工具聚合（只读；深链既有 project 页）。
          GoRoute(
            path: 'tools',
            name: 'organization_tools',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: OrganizationToolsPage(
                orgId: state.pathParameters['orgId'] ?? '',
              ),
            ),
          ),
          // ENT-APP-06：工作区成员治理（org 视角显式 wsId 面）。
          GoRoute(
            path: 'ws/:wsId/members',
            name: 'organization_ws_members',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: OrgWorkspaceMembersPage(
                workspaceId: state.pathParameters['wsId'] ?? '',
                workspaceName: state.uri.queryParameters['name'] ?? '',
              ),
            ),
          ),
        ],
      ),
    ],
  ),
];
