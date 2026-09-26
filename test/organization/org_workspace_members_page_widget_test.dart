/// ENT-APP-06 — 工作区成员治理面（org 视角）focused widget 测试。
///
/// 覆盖：
/// - 身份闭合：WS Owner 看到邀请入口与成员菜单（改角色/转让/移除）；
///   非 Owner（普通成员可读列表）只读：无菜单、无邀请、有只读提示；
/// - 写后读：移除成功后重新拉取 detail + members（服务端事实收敛，
///   目标行从列表消失）；
/// - 冲突透出：移除被服务端 409 拒绝（仍是项目 Owner）时原样透出
///   服务端文案（不本地绕过），且仍回到服务端事实重读；
/// - 权限终态：detail 403 → 无权查看（不重试）；
/// - 四态：loading → 成功。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/organization/presentation/org_workspace_members_page.dart';

import '../ux_matrix/ux_harness.dart';

const String kWsId = '801';
const String kAccountKey = '1001';

Map<String, dynamic> _wsJson({
  String ownerId = kAccountKey,
  String status = 'active',
}) => {
  'id': kWsId,
  'name': '成员治理工作区',
  'owner_id': ownerId,
  'status': status,
  'organization_id': '900',
};

Map<String, dynamic> _memberJson(
  String userId,
  String role, {
  String nickname = '',
}) => {
  'workspace_id': kWsId,
  'user_id': userId,
  'role': role,
  'nickname': nickname,
  'account': '',
};

/// 成功桩：detail + members + 三个写端点（写按序消费可覆盖失败注入）。
RouteStubAdapter _adapter({
  String ownerId = kAccountKey,
  List<(int, Map<String, dynamic>)>? removeResponses,
}) {
  final members = [
    _memberJson(kAccountKey, 'owner', nickname: '我是所有者'),
    _memberJson('1002', 'member', nickname: '张三'),
    _memberJson('1003', 'guest', nickname: '李四'),
  ];
  final membersAfterRemove = [
    _memberJson(kAccountKey, 'owner', nickname: '我是所有者'),
    _memberJson('1003', 'guest', nickname: '李四'),
  ];
  return RouteStubAdapter([
    // 更具体的片段在前。
    (
      '/workspaces/$kWsId/members/remove',
      removeResponses ??
          [
            (200, uxEnvelope(payload: <String, dynamic>{'status': 'changed'})),
          ],
    ),
    (
      '/workspaces/$kWsId/members',
      [
        (200, uxPage(members)),
        (200, uxPage(membersAfterRemove)),
        (200, uxPage(membersAfterRemove)),
        (200, uxPage(membersAfterRemove)),
      ],
    ),
    (
      '/workspaces/$kWsId',
      [(200, uxEnvelope(payload: _wsJson(ownerId: ownerId)))],
    ),
  ]);
}

GoRoute _inviteSentinel() => GoRoute(
  path: '/workspace/:wsId/members/invite',
  pageBuilder: (_, s) => CustomTransitionPage(
    key: s.pageKey,
    transitionsBuilder: (_, _, _, child) => child,
    child: const Scaffold(body: Center(child: Text('SENTINEL-invite'))),
  ),
);

Widget _host() => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/ws-members',
    routes: [
      GoRoute(
        path: '/ws-members',
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          transitionsBuilder: (_, _, _, child) => child,
          child: const OrgWorkspaceMembersPage(
            workspaceId: kWsId,
            workspaceName: '成员治理工作区',
            accountKey: kAccountKey,
          ),
        ),
      ),
      _inviteSentinel(),
    ],
  ),
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
}

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets('WS Owner：邀请入口 + 成员行菜单（改角色/转让/移除）', (tester) async {
    uxInstallStub(_adapter());
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-ws-member-1002')),
    );

    expect(find.byKey(const ValueKey('org-ws-invite')), findsOneWidget);
    // Owner 行没有菜单（自己）
    expect(
      find.byKey(const ValueKey('org-ws-member-menu-$kAccountKey')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('org-ws-member-menu-1002')));
    await tester.pumpAndSettle();

    expect(find.text('设为访客'), findsOneWidget);
    expect(find.text('转让所有者'), findsOneWidget);
    expect(find.text('移除成员'), findsOneWidget);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
  });

  testWidgets('非 Owner：只读（无邀请、无菜单、有只读提示）', (tester) async {
    uxInstallStub(_adapter(ownerId: '9999'));
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-ws-member-1002')),
    );

    expect(find.byKey(const ValueKey('org-ws-invite')), findsNothing);
    expect(find.byKey(const ValueKey('org-ws-member-menu-1002')), findsNothing);
    expect(find.textContaining('只读'), findsOneWidget);
    // 列表本身 active 成员可读（服务端门内的事实）
    expect(find.byKey(const ValueKey('org-ws-member-1003')), findsOneWidget);
  });

  testWidgets('写后读：移除成功后重读服务端事实（1002 行消失）', (tester) async {
    final adapter = _adapter();
    uxInstallStub(adapter);
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-ws-member-1002')),
    );

    final membersBefore = adapter.requestCount;
    await tester.tap(find.byKey(const ValueKey('org-ws-member-menu-1002')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除成员'));
    await tester.pumpAndSettle();
    // 危险确认
    await tester.tap(find.text('确认执行'));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-ws-member-1003')),
    );
    await tester.pumpAndSettle();

    expect(
      adapter.requestCount,
      greaterThan(membersBefore),
      reason: '写后重新拉取服务端事实',
    );
    expect(
      find.byKey(const ValueKey('org-ws-member-1002')),
      findsNothing,
      reason: '被移除成员不残留（列表以服务端响应重建）',
    );
  });

  testWidgets('冲突透出：移除被 409 拒绝时原样透出服务端文案', (tester) async {
    final members = [
      _memberJson(kAccountKey, 'owner', nickname: '我是所有者'),
      _memberJson('1002', 'member', nickname: '张三'),
      _memberJson('1003', 'guest', nickname: '李四'),
    ];
    uxInstallStub(
      RouteStubAdapter([
        (
          '/workspaces/$kWsId/members/remove',
          [
            (409, {'code': 409, 'msg': '对方仍是 2 个项目的 Owner：P1、P2'}),
          ],
        ),
        ('/workspaces/$kWsId/members', [(200, uxPage(members))]),
        ('/workspaces/$kWsId', [(200, uxEnvelope(payload: _wsJson()))]),
      ]),
    );
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-ws-member-1002')),
    );

    await tester.tap(find.byKey(const ValueKey('org-ws-member-menu-1002')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认执行'));
    await _pumpUntilFound(tester, find.textContaining('移除成员：'));

    expect(find.textContaining('对方仍是 2 个项目的 Owner'), findsOneWidget);
    // 服务端事实重读后成员仍在（未被本地误删）
    expect(find.byKey(const ValueKey('org-ws-member-1002')), findsOneWidget);
  });

  testWidgets('权限终态：detail 403 → 无权查看（无重试）', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        (
          '/workspaces/$kWsId',
          [
            (403, {'code': 403, 'msg': 'forbidden'}),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(_host());
    await _pumpUntilFound(tester, find.textContaining('无权查看'));

    expect(find.textContaining('无权查看'), findsOneWidget);
    expect(find.text('重试'), findsNothing, reason: '403 是终态');
  });

  testWidgets('四态：loading 先于成功', (tester) async {
    uxInstallStub(_adapter());
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-ws-member-1002')),
    );
    expect(find.textContaining('成员治理工作区'), findsWidgets);
  });

  testWidgets('深链：邀请入口落到既有邀请向导路由', (tester) async {
    uxInstallStub(_adapter());
    await tester.pumpWidget(_host());
    await _pumpUntilFound(tester, find.byKey(const ValueKey('org-ws-invite')));
    await tester.tap(find.byKey(const ValueKey('org-ws-invite')));
    await tester.pumpAndSettle();

    expect(find.text('SENTINEL-invite'), findsOneWidget);
  });
}
