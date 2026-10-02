/// ENT-APP-01 — 组织聚合页（/organization/:orgId）focused widget 测试。
///
/// 覆盖（验收口径）：
/// - 聚合渲染：企业头信息卡（名称/角色徽标/默认 WS）+ 五域入口
///   （成员/部门/群/频道/工具）+ 管理员区（owner/admin）；
/// - 权限分层：member 视角管理员动作经 PermissionGate hide 整区隐藏，
///   五域入口与 danger 只读动作（删除预检）仍可见；
/// - 四态：Loading（首帧）/ Error（500 wire message + 重试）/
///   Permission（403 终态无重试）/ Empty（adapter 参数链路，组件级）；
/// - 导航：五域与管理员入口全部落到既有路由的哨兵页；
/// - archived：入口区/管理员区不渲染，restore 入口保留。
///
/// harness 复用 ux_matrix 共享件（静态 HTTP 桩 + secure storage mock）；
/// accountKey 注入 '1001'，不触碰 UserRepoLocal 登录链。
library;

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/organization/public.dart';

import '../ux_matrix/ux_harness.dart';

const String kOrgId = '7266418340025468901';
const String kAccountKey = '1001';
const String kDefaultWsId = '7266418340025468942';

Map<String, dynamic> _orgJson({
  String role = 'owner',
  String status = 'active',
}) => {
  'id': kOrgId,
  'name': '聚合组织甲',
  'status': status,
  'owner_id': kAccountKey,
  'member_role': role,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

/// 详情 + 默认 workspace 双请求桩（具体片段在前）。
void _installOrgStub(Map<String, dynamic> org) {
  uxInstallStub(
    RouteStubAdapter([
      (
        '/default-workspace',
        [
          (200, uxEnvelope(payload: {'default_workspace_id': kDefaultWsId})),
        ],
      ),
      ('/organizations/$kOrgId', [(200, uxEnvelope(payload: org))]),
    ]),
  );
}

GoRoute _sentinel(String path, String label) => GoRoute(
  path: path,
  pageBuilder: (_, s) => CupertinoPage(
    key: s.pageKey,
    child: Scaffold(
      appBar: AppBar(title: const Text('sentinel')),
      body: Center(child: Text(label)),
    ),
  ),
);

/// 超高视口：ListView(children:) 仍是懒构建（SliverChildListDelegate），
/// 视口外 tile 不 build——聚合页断言（含 findsNothing 负向断言）需要
/// 一次让全部 children 落进视口，避免"未 build 即假绿"。
void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 角色差异由 HTTP 桩注入（_installOrgStub），host 本身与角色无关。
Widget _host() {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/organization/$kOrgId',
      routes: [
        GoRoute(
          path: kOrganizationHomePath,
          pageBuilder: (_, s) =>
              CupertinoPage(key: s.pageKey, child: const SizedBox.shrink()),
          routes: [
            GoRoute(
              path: ':orgId',
              pageBuilder: (_, s) => CupertinoPage(
                key: s.pageKey,
                child: OrganizationDetailPage(
                  orgId: kOrgId,
                  accountKey: kAccountKey,
                ),
              ),
              routes: [
                _sentinel('directory', 'SENTINEL-directory'),
                _sentinel('departments', 'SENTINEL-departments'),
                _sentinel('members', 'SENTINEL-members'),
                _sentinel('invitations', 'SENTINEL-invitations'),
                _sentinel('manage', 'SENTINEL-manage'),
                _sentinel('tools', 'SENTINEL-tools'),
              ],
            ),
          ],
        ),
        _sentinel('/workspace', 'SENTINEL-workspace'),
      ],
    ),
  );
}

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets('owner 聚合渲染：企业头 + 五域入口 + 管理员区 + danger', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'owner'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('聚合组织甲'));
    await settleUx(tester);

    // 企业头：名称、角色徽标（owner → 所有者）、角色状态行、默认 WS。
    expect(find.text('聚合组织甲'), findsWidgets);
    expect(find.text('所有者'), findsOneWidget, reason: '角色徽标 wire→标签映射');
    expect(find.textContaining('我的角色'), findsOneWidget);
    expect(find.textContaining(kDefaultWsId), findsOneWidget);

    // 五域入口（全员）全部渲染。
    for (final key in const [
      'organization-detail-zone-members',
      'organization-detail-zone-departments',
      'organization-detail-zone-groups',
      'organization-detail-zone-channels',
      'organization-detail-zone-tools',
    ]) {
      expect(
        find.byKey(ValueKey(key)),
        findsOneWidget,
        reason: '五域入口 $key 应渲染',
      );
    }

    // 管理员区（owner 可见）：治理入口 + 既有 GZAPP-05 锚点 key。
    expect(find.text('成员治理'), findsOneWidget);
    expect(find.text('邀请管理'), findsOneWidget);
    expect(find.text('企业管理'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('organization-detail-manage-entry')),
      findsOneWidget,
      reason: 'GZAPP-05 既有测试锚点 key 必须保留',
    );

    // danger zone（全员只读动作）仍在。
    expect(find.text('账号删除预检'), findsOneWidget);
    expect(find.text('归档组织'), findsOneWidget);
  });

  testWidgets('member 权限分层：管理员动作整区隐藏，五域与只读动作保留', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'member'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('聚合组织甲'));
    await settleUx(tester);

    // 五域入口对全员开放。
    for (final key in const [
      'organization-detail-zone-members',
      'organization-detail-zone-groups',
      'organization-detail-zone-channels',
      'organization-detail-zone-tools',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '五域入口 $key');
    }

    expect(
      find.byKey(const ValueKey('organization-detail-zone-departments')),
      findsNothing,
    );
    expect(find.text('通讯录'), findsOneWidget);

    // 管理员区经 PermissionGate hide：member 看不到管理员动作。
    expect(find.text('管理员区'), findsNothing);
    expect(find.text('成员治理'), findsNothing);
    expect(find.text('邀请管理'), findsNothing);
    expect(find.text('企业管理'), findsNothing);
    expect(
      find.byKey(const ValueKey('organization-detail-manage-entry')),
      findsNothing,
    );

    // member 角色徽标 + danger 只读动作保留；治理类危险动作隐藏。
    expect(find.textContaining('我的角色：成员'), findsOneWidget);
    expect(find.text('账号删除预检'), findsOneWidget);
    expect(find.text('归档组织'), findsNothing, reason: '归档仅 owner/admin');
  });

  testWidgets('四态-loading：首帧渲染加载指示器', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson());

    await tester.pumpWidget(_host());
    // 不 settle：首帧即 loading 态。
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('聚合组织甲'), findsNothing);
    await settleUx(tester);
  });

  testWidgets('四态-error：500 透传 wire message 并给重试入口', (tester) async {
    _setTallViewport(tester);
    uxInstallStub(
      RouteStubAdapter([
        (
          '/organizations/',
          [
            (500, {'code': 500, 'msg': 'boom'}),
          ],
        ),
      ]),
    );

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('boom'));

    expect(find.text('boom'), findsOneWidget, reason: 'wire message 原样呈现');
    expect(find.text('重试'), findsOneWidget, reason: 'error 态引导重试');
  });

  testWidgets('四态-permission：403 为权限终态，不渲染重试', (tester) async {
    _setTallViewport(tester);
    uxInstallStub(
      RouteStubAdapter([
        (
          '/organizations/',
          [
            (403, {'code': 403, 'msg': 'forbidden'}),
          ],
        ),
      ]),
    );

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('没有权限'));

    expect(find.text('没有权限'), findsOneWidget, reason: 't.common.noPermission');
    expect(find.text('重试'), findsNothing, reason: '403 是终态，重试不改变结果');
  });

  testWidgets('四态-empty：OrgAsyncAdapter empty 参数链路透传 emptyText', (
    tester,
  ) async {
    _setTallViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrgAsyncAdapter(
            loading: false,
            empty: true,
            emptyText: '组织不存在',
            child: Text('hub-content'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('组织不存在'), findsOneWidget);
    expect(find.text('hub-content'), findsNothing);
  });

  testWidgets('导航：五域入口全部落到既有路由', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'owner'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('聚合组织甲'));
    await settleUx(tester);

    // 依次 tap → 哨兵出现 → back 回聚合页继续（context.push 不销毁页面态）。
    final cases = <(String, String)>[
      ('organization-detail-zone-members', 'SENTINEL-directory'),
      ('organization-detail-zone-departments', 'SENTINEL-departments'),
      ('organization-detail-zone-groups', 'SENTINEL-manage'),
      ('organization-detail-zone-channels', 'SENTINEL-manage'),
      ('organization-detail-zone-tools', 'SENTINEL-workspace'),
      // ENT-APP-06：本企业工具聚合（Org 限定视角）。
      ('organization-detail-zone-org-tools', 'SENTINEL-tools'),
    ];
    for (final (key, sentinel) in cases) {
      await tester.tap(find.byKey(ValueKey(key)));
      await settleUx(tester);
      expect(
        find.text(sentinel),
        findsOneWidget,
        reason: '$key 应导航到 $sentinel（既有页面）',
      );
      await tester.tap(find.byType(BackButton).last);
      await settleUx(tester);
      expect(find.text('聚合组织甲'), findsWidgets, reason: '返回聚合页');
    }
  });

  testWidgets('导航：管理员区入口落到既有治理路由', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'owner'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('成员治理'));
    await settleUx(tester);

    final cases = <(String, String)>[
      ('organization-detail-admin-members', 'SENTINEL-members'),
      ('organization-detail-admin-invitations', 'SENTINEL-invitations'),
      ('organization-detail-manage-entry', 'SENTINEL-manage'),
    ];
    for (final (key, sentinel) in cases) {
      await tester.tap(find.byKey(ValueKey(key)));
      await settleUx(tester);
      expect(find.text(sentinel), findsOneWidget, reason: '$key → $sentinel');
      await tester.tap(find.byType(BackButton).last);
      await settleUx(tester);
    }
  });

  testWidgets('archived：入口区/管理员区不渲染，restore 入口保留', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'owner', status: 'archived'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('聚合组织甲'));
    await settleUx(tester);

    // 企业头展示归档事实（C16 整页只读）。
    expect(find.textContaining('组织已归档'), findsOneWidget);
    expect(find.textContaining('状态：已归档'), findsOneWidget);

    // 五域与管理员区都不渲染（archived 无入口语义）。
    expect(
      find.byKey(const ValueKey('organization-detail-zone-members')),
      findsNothing,
    );
    expect(find.text('成员治理'), findsNothing);
    expect(find.text('管理员区'), findsNothing);

    // restore 是唯一放行写入口（owner 视角）。
    expect(find.text('恢复组织'), findsOneWidget);
    expect(find.text('归档组织'), findsNothing, reason: '已归档不再出现归档入口');
  });
}
