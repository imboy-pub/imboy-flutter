/// CS-APP-03 — 组织详情页「客服治理」入口可见性与导航 focused 测试。
///
/// 验收口径（CS-GOV-02B 权限负例的入口侧）：
/// - owner/admin：管理员区渲染「客服治理」入口（key 锚点），点击落到
///   /customer_service/governance/:orgId（租户 Human JWT 治理面路由）；
/// - member：管理员区经 PermissionGate 整区隐藏——入口**完全不渲染**
///   （零占位，服务端 403 仍是直达时的唯一裁决）；
/// - archived：入口区/管理员区不渲染（C16 只读口径不变）。
///
/// harness 复用 ux_matrix 共享件与 detail hub 测试同款静态桩。
library;

import 'package:flutter/cupertino.dart' show CupertinoPage;
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
  'name': '治理入口组织',
  'status': status,
  'owner_id': kAccountKey,
  'member_role': role,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

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

/// 治理页哨兵：命中即证明导航落在 /customer_service/governance/:orgId。
GoRoute _governanceSentinel() => GoRoute(
  path: '/customer_service/governance/:orgId',
  pageBuilder: (_, s) => CupertinoPage(
    key: s.pageKey,
    child: Scaffold(
      body: Center(
        child: Text('SENTINEL-governance-${s.pathParameters['orgId']}'),
      ),
    ),
  ),
);

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
            ),
          ],
        ),
        _governanceSentinel(),
      ],
    ),
  );
}

void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets('owner：管理员区渲染客服治理入口并导航到治理路由', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'owner'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('治理入口组织'));
    await settleUx(tester);

    final entry = find.byKey(
      const ValueKey('organization-detail-zone-cs-governance'),
    );
    expect(entry, findsOneWidget, reason: 'owner 视角治理入口渲染');
    expect(find.text('客服治理'), findsOneWidget);

    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
      find.text('SENTINEL-governance-$kOrgId'),
      findsOneWidget,
      reason: '导航落在 /customer_service/governance/:orgId（org 作用域）',
    );
  });

  testWidgets('admin：治理入口同样渲染（owner/admin 同门）', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'admin'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('治理入口组织'));
    await settleUx(tester);

    expect(
      find.byKey(const ValueKey('organization-detail-zone-cs-governance')),
      findsOneWidget,
      reason: 'admin 与 owner 同属 required_governance 门',
    );
  });

  testWidgets('member：入口完全不渲染（PermissionGate 整区隐藏）', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'member'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('治理入口组织'));
    await settleUx(tester);

    expect(
      find.byKey(const ValueKey('organization-detail-zone-cs-governance')),
      findsNothing,
      reason: 'member 零占位（权限动作隐藏）',
    );
    expect(find.text('客服治理'), findsNothing);
  });

  testWidgets('archived：管理员区整体不渲染（C16 只读口径）', (tester) async {
    _setTallViewport(tester);
    _installOrgStub(_orgJson(role: 'owner', status: 'archived'));

    await tester.pumpWidget(_host());
    await pumpUntilUxFound(tester, find.text('治理入口组织'));
    await settleUx(tester);

    expect(
      find.byKey(const ValueKey('organization-detail-zone-cs-governance')),
      findsNothing,
      reason: '归档组织治理入口不渲染',
    );
  });
}
