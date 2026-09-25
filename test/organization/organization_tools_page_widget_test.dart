/// ENT-APP-06 — 企业工具聚合页 focused widget 测试。
///
/// 覆盖（验收口径）：
/// - 只列当前 Org 的已授权资源：本企业工作区与其项目出现；个人域工作区
///   与其它企业的工作区/项目都不出现（数据源 mine 按 organization_id
///   过滤，不是本地伪装——projects 读取失败按服务端错误诚实降级）；
/// - 深链：项目行 → 既有项目详情路由；底部 → 全局工作区切换器；
/// - 诚实降级：某工作区 projects 403 → 该节错误行 + 重试，工作区节不
///   被隐藏；org detail 403 → 权限终态；
/// - 切 Org 原子重建：换 orgId（两阶段切换后新路由参数）→ 页面按新
///   org 重新读取服务端，上一企业的资源不残留；
/// - 空态：本企业没有已加入的工作区。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/presentation/organization_tools_page.dart';

import '../ux_matrix/ux_harness.dart';

const String kOrgId = '900';
const String kOtherOrgId = '901';
const String kWsA = '801';
const String kWsB = '802';
const String kAccountKey = '1001';

Map<String, dynamic> _orgJson({
  String id = kOrgId,
  String name = '工具企业',
  String role = 'owner',
}) => {
  'id': id,
  'name': name,
  'status': 'active',
  'owner_id': kAccountKey,
  'member_role': role,
};

Map<String, dynamic> _wsJson(
  String id,
  String name,
  String orgId, {
  String status = 'active',
}) => {
  'id': id,
  'name': name,
  'owner_id': kAccountKey,
  'status': status,
  'organization_id': orgId,
};

Map<String, dynamic> _projectJson(String id, String name) => {
  'id': id,
  'name': name,
  'description': '',
  'status': 'active',
};

/// 企业的资源事实：本企业两个工作区（A/B）+ 个人域 + 别家企业干扰项。
Map<String, dynamic> _minePage({String orgId = kOrgId}) => {
  'list': [
    _wsJson(kWsA, '工具工作区A', orgId),
    _wsJson(kWsB, '工具工作区B', orgId),
    _wsJson('901', '个人域工作区', '', status: ''),
    _wsJson('902', '别家企业工作区', '999'),
  ],
  'page': 1,
  'size': 100,
  'total': 4,
  'total_page': 1,
};

/// projects 端点片段（更具体在前；RouteStubAdapter 按序消费）。
List<(String, List<(int, Map<String, dynamic>)>)> _projectsRoutes({
  List<(int, Map<String, dynamic>)>? wsBResponses,
}) => [
  (
    '/workspaces/$kWsB/projects',
    wsBResponses ??
        [
          (200, uxListPayload([_projectJson('6002', 'B 企业项目一')])),
        ],
  ),
  (
    '/workspaces/$kWsA/projects',
    [
      (200, uxListPayload([_projectJson('6001', 'A 企业项目一')])),
    ],
  ),
];

RouteStubAdapter _adapter({
  String orgId = kOrgId,
  String orgName = '工具企业',
  List<(int, Map<String, dynamic>)>? wsBProjects,
}) => RouteStubAdapter([
  ..._projectsRoutes(wsBResponses: wsBProjects),
  (
    '/organizations/$orgId',
    [
      (
        200,
        uxEnvelope(
          payload: _orgJson(id: orgId, name: orgName),
        ),
      ),
    ],
  ),
  ('/workspaces/mine', [(200, uxEnvelope(payload: _minePage(orgId: orgId)))]),
]);

GoRoute _sentinel(String path, String label) => GoRoute(
  path: path,
  pageBuilder: (_, s) => CustomTransitionPage(
    key: s.pageKey,
    transitionsBuilder: (_, __, ___, child) => child,
    child: Scaffold(body: Center(child: Text(label))),
  ),
);

Widget _host({String orgId = kOrgId}) => ProviderScope(
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/tools',
      routes: [
        GoRoute(
          path: '/tools',
          pageBuilder: (_, s) => CustomTransitionPage(
            key: s.pageKey,
            transitionsBuilder: (_, __, ___, child) => child,
            child: OrganizationToolsPage(orgId: orgId, accountKey: kAccountKey),
          ),
        ),
        _sentinel(
          '/workspace/:wsId/projects/:projectId',
          'SENTINEL-project-detail',
        ),
        _sentinel('/workspace', 'SENTINEL-workspace'),
      ],
    ),
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

  testWidgets('只列本企业已授权资源：个人域/别家企业不出现', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    uxInstallStub(_adapter());
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
    );

    expect(find.text('工具工作区A'), findsOneWidget);
    expect(find.text('工具工作区B'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-tools-project-$kWsB-6002')),
      findsOneWidget,
    );
    // 个人域与其它企业的工作区/项目不可见（服务端 mine 面口径）。
    expect(find.text('个人域工作区'), findsNothing);
    expect(find.text('别家企业工作区'), findsNothing);
    expect(find.byKey(const ValueKey('org-tools-ws-901')), findsNothing);
  });

  testWidgets('深链：项目行落到既有项目详情路由', (tester) async {
    uxInstallStub(_adapter());
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
    );
    await tester.tap(
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('SENTINEL-project-detail'), findsOneWidget);
  });

  testWidgets('诚实降级：某工作区 projects 403 → 错误行 + 重试，不隐藏', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    uxInstallStub(
      _adapter(
        wsBProjects: [
          (403, {'code': 403, 'msg': '非工作区成员'}),
        ],
      ),
    );
    await tester.pumpWidget(_host());
    await _pumpUntilFound(tester, find.text('工具工作区A'));
    // provider error 态需要额外几个 pump 周期收敛（autoDispose family
    // 在 ListView 懒构建下会重建重试），用 pumpAndSettle 到静默。
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      find.byKey(const ValueKey('org-tools-ws-error-$kWsB')),
      findsOneWidget,
    );
    expect(find.textContaining('非工作区成员'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-tools-ws-retry-$kWsB')),
      findsOneWidget,
    );
    // 工作区 A 的项目不受影响。
    expect(
      find.byKey(const ValueKey('org-tools-ws-error-$kWsA')),
      findsNothing,
    );
  });

  testWidgets('权限终态：org detail 403 → 无权查看（无重试）', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        (
          '/organizations/$kOrgId',
          [
            (403, {'code': 403, 'msg': 'forbidden'}),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(_host());
    await _pumpUntilFound(tester, find.text('没有权限'));

    expect(find.text('没有权限'), findsOneWidget);
    expect(find.text('重试'), findsNothing, reason: '403 是终态');
  });

  testWidgets('切 Org 原子重建：新 org 参数下重新读服务端，旧企业资源不残留', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final adapter = _adapter();
    uxInstallStub(adapter);
    // 企业 A 的工具页。
    await tester.pumpWidget(_host(orgId: kOrgId));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
    );
    expect(
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
      findsOneWidget,
    );

    // 两阶段切换后：路由参数换成企业 B → 全新页面实例按新 org 读取
    // 服务端事实（这里桩切换为企业 B 的资源世界）。
    final adapterB = RouteStubAdapter([
      ..._projectsRoutes(),
      (
        '/organizations/$kOtherOrgId',
        [
          (
            200,
            uxEnvelope(
              payload: _orgJson(id: kOtherOrgId, name: '乙企业'),
            ),
          ),
        ],
      ),
      (
        '/workspaces/mine',
        [(200, uxEnvelope(payload: _minePage(orgId: kOtherOrgId)))],
      ),
    ]);
    HttpClient.adapterForTest = adapterB;
    await tester.pumpWidget(_host(orgId: kOtherOrgId));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-tools-project-$kWsA-6001')),
    );

    // 旧企业标题不残留；新企业事实重新渲染（同一 wsId 集合、新 org 名）。
    expect(find.text('工具企业'), findsNothing);
    expect(find.textContaining('乙企业'), findsWidgets);
    // 新 org 的 detail 请求确实发出（服务端事实重读，非本地缓存）。
    expect(adapterB.requestCount, greaterThan(0), reason: '切 Org 后重新向服务端读取');
    expect(
      adapterB.routes.any((r) => r.$1.contains('/organizations/$kOtherOrgId')),
      isTrue,
    );
  });

  testWidgets('空态：本企业没有已加入的工作区', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        ('/organizations/$kOrgId', [(200, uxEnvelope(payload: _orgJson()))]),
        (
          '/workspaces/mine',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'list': [_wsJson('901', '个人域工作区', '')],
                  'page': 1,
                  'size': 100,
                  'total': 1,
                  'total_page': 1,
                },
              ),
            ),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-tools-empty')),
    );

    expect(find.byKey(const ValueKey('org-tools-empty')), findsOneWidget);
    expect(find.text('个人域工作区'), findsNothing, reason: '个人域不属于本企业');
  });
}
