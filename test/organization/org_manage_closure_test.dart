/// ENT-APP-06 — 企业管理页入口闭包 focused widget 测试。
///
/// 覆盖（四身份闭合矩阵 + 写后读 + 深链）：
/// - Org owner：工作区行菜单含 成员治理/重命名/设默认/归档；群行菜单含
///   重命名/成员与角色/解散；频道行菜单含 重命名/管理员/订阅者/归档；
/// - Workspace Owner（org member 但拥有本企业工作区）：工作区菜单仍有
///   成员治理/重命名/归档，组织级动作（新建工作区）不出现；
/// - 写后读：工作区重命名 / 群重命名 成功后重新拉取服务端事实
///   （mine / groups 二次请求）；
/// - 深链：群「成员与角色」→ 既有群详情路由；频道「管理员」→ 既有
///   channel admins 子路由；工作区「成员治理」→ org 模块 ws 成员面。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/presentation/organization_manage_page.dart';
import 'package:imboy/service/storage.dart';

const String kOrgId = '900';
const String kWsId = '801';

class _Route {
  const _Route(this.fragment, this.status, this.body, {this.prefix = false});

  final String fragment;
  final int status;
  final dynamic body;
  final bool prefix;
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  final List<_Route> routes;
  final List<String> hits = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits.add('${options.method} ${options.path}');
    for (final r in routes) {
      if (!options.path.contains(r.fragment)) continue;
      return ResponseBody.fromString(
        jsonEncode(r.body),
        r.status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 404, 'msg': 'not found'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(dynamic payload) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

Map<String, dynamic> _org({required String role}) => {
  'id': kOrgId,
  'name': '闭包企业',
  'owner_id': '1001',
  'status': 'active',
  'member_role': role,
};

Map<String, dynamic> _wsPage({String ownWsOwner = '1001'}) => {
  'list': [
    {
      'id': kWsId,
      'name': '闭包工作区',
      'owner_id': ownWsOwner,
      'status': 'active',
      'organization_id': kOrgId,
    },
    {
      'id': '901',
      'name': '个人区不该出现',
      'owner_id': '1001',
      'status': 'active',
      'organization_id': null,
    },
  ],
  'page': 1,
  'size': 100,
  'total': 2,
  'total_page': 1,
};

Map<String, dynamic> _resources() => {
  'list': [
    {'id': '7001', 'title': '闭包群', 'member_count': 3, 'status': 1},
  ],
};

_RoutingAdapter _closureAdapter({String role = 'owner'}) => _RoutingAdapter([
  _Route(
    '/api/v1/organizations/$kOrgId/default-workspace',
    200,
    _ok({'organization_id': kOrgId, 'default_workspace_id': '999'}),
  ),
  _Route('/api/v1/organizations/$kOrgId', 200, _ok(_org(role: role))),
  _Route('/api/v1/workspaces/mine', 200, _ok(_wsPage())),
  // 工作区重命名（ENT-APP-06）
  _Route('/api/v1/workspaces/$kWsId/update', 200, _ok(null)),
  _Route('/api/v1/workspaces/$kWsId/groups', 200, _ok(_resources())),
  // 群重命名（ENT-APP-06；group/edit）
  _Route('/api/v1/group/edit', 200, _ok(null)),
  _Route(
    '/api/v1/workspaces/$kWsId/channels',
    200,
    _ok({
      'list': [
        {'id': '6001', 'name': '闭包频道', 'subscriber_count': 2, 'status': 1},
      ],
    }),
    prefix: true,
  ),
]);

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

/// 深链哨兵页：命中即证明走到了既有路由（不挂真实业务页）。
GoRoute _sentinel(String path, String label) => GoRoute(
  path: path,
  pageBuilder: (_, s) => CustomTransitionPage(
    key: s.pageKey,
    transitionsBuilder: (_, __, ___, child) => child,
    child: Scaffold(body: Center(child: Text(label))),
  ),
);

Widget _host() => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/organization/$kOrgId/manage',
    routes: [
      GoRoute(
        path: '/organization',
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          transitionsBuilder: (_, __, ___, child) => child,
          child: const SizedBox.shrink(),
        ),
        routes: [
          GoRoute(
            path: ':orgId/manage',
            pageBuilder: (_, s) => CustomTransitionPage(
              key: s.pageKey,
              transitionsBuilder: (_, __, ___, child) => child,
              child: const OrganizationManagePage(
                orgId: kOrgId,
                accountKey: '1001',
              ),
            ),
          ),
          _sentinel(':orgId/ws/:wsId/members', 'SENTINEL-ws-members'),
        ],
      ),
      _sentinel('/group/detail/:groupId', 'SENTINEL-group-detail'),
      _sentinel('/channel/:channelId/edit', 'SENTINEL-channel-edit'),
      _sentinel('/channel/:channelId/admins', 'SENTINEL-channel-admins'),
      _sentinel('/channel/:channelId/subscribers', 'SENTINEL-channel-subs'),
      _sentinel('/workspace/:wsId/projects/:projectId', 'SENTINEL-project'),
    ],
  ),
);

Future<void> _openWsMenu(WidgetTester tester) async {
  await _pumpUntilFound(tester, find.text('闭包工作区'));
  await tester.tap(find.byKey(ValueKey('org-manage-ws-menu-$kWsId')));
  await tester.pumpAndSettle();
}

Future<void> _scrollToResources(WidgetTester tester) async {
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('org-manage-group-7001')),
  );
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('org-manage-channel-menu-6001')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    HttpClient.adapterForTest = null;
  });

  testWidgets('Org owner：工作区菜单四动作闭合', (tester) async {
    HttpClient.adapterForTest = _closureAdapter();
    await tester.pumpWidget(_host());
    await _openWsMenu(tester);

    expect(find.text('成员治理'), findsOneWidget);
    expect(find.text('重命名工作区'), findsOneWidget);
    expect(find.text('设为默认工作区'), findsOneWidget);
    expect(find.text('归档工作区'), findsOneWidget);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
  });

  testWidgets('Workspace Owner：菜单动作保留，组织级动作不出现', (tester) async {
    HttpClient.adapterForTest = _closureAdapter(role: 'member');
    await tester.pumpWidget(_host());
    await _openWsMenu(tester);

    expect(find.text('成员治理'), findsOneWidget);
    expect(find.text('重命名工作区'), findsOneWidget);
    // 组织级动作（新建工作区）对 WS Owner 不出现
    expect(
      find.byKey(const ValueKey('org-manage-create-workspace')),
      findsNothing,
    );
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
  });

  testWidgets('Org member（不拥有工作区）：无菜单入口', (tester) async {
    final adapter = _RoutingAdapter([
      _Route(
        '/api/v1/organizations/$kOrgId/default-workspace',
        200,
        _ok({'organization_id': kOrgId, 'default_workspace_id': '999'}),
      ),
      _Route('/api/v1/organizations/$kOrgId', 200, _ok(_org(role: 'member'))),
      _Route('/api/v1/workspaces/mine', 200, _ok(_wsPage(ownWsOwner: '1002'))),
    ]);
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(_host());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('org-manage-forbidden')),
    );

    expect(find.byKey(const ValueKey('org-manage-forbidden')), findsOneWidget);
    expect(
      find.byKey(ValueKey('org-manage-ws-menu-$kWsId')),
      findsNothing,
      reason: '非 owner/admin 且不拥有工作区：治理菜单不渲染',
    );
  });

  testWidgets('群/频道行菜单闭合（重命名/成员与角色/管理员/订阅者）', (tester) async {
    HttpClient.adapterForTest = _closureAdapter();
    await tester.pumpWidget(_host());
    await _scrollToResources(tester);

    // 群菜单
    await tester.tap(find.byKey(const ValueKey('org-manage-group-menu-7001')));
    await tester.pumpAndSettle();
    expect(find.text('成员与角色'), findsOneWidget);
    expect(find.text('解散群'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-manage-rename-7001')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();

    // 频道菜单
    await tester.tap(
      find.byKey(const ValueKey('org-manage-channel-menu-6001')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('org-manage-channel-rename-6001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-manage-channel-admins-6001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-manage-channel-subscribers-6001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-manage-archive-6001')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
  });

  testWidgets('写后读：工作区重命名成功后回到服务端事实（mine 二次读取）', (tester) async {
    final adapter = _closureAdapter();
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(_host());
    await _openWsMenu(tester);

    final mineBefore = adapter.hits
        .where((h) => h.contains('/workspaces/mine'))
        .length;
    await tester.tap(find.text('重命名工作区'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新闭包工作区名');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey('org-manage-ws-menu-$kWsId')),
    );

    expect(
      adapter.hits.where((h) => h.contains('/workspaces/$kWsId/update')).length,
      1,
      reason: '改名写请求恰好一次',
    );
    expect(
      adapter.hits.where((h) => h.contains('/workspaces/mine')).length,
      greaterThan(mineBefore),
      reason: '写后重新读取服务端事实',
    );
  });

  testWidgets('写后读：群重命名成功后 groups 二次读取', (tester) async {
    final adapter = _closureAdapter();
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(_host());
    await _pumpUntilFound(tester, find.text('闭包群'));

    final groupsBefore = adapter.hits
        .where((h) => h.contains('/workspaces/$kWsId/groups'))
        .length;
    await tester.tap(find.byKey(const ValueKey('org-manage-group-menu-7001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('org-manage-rename-7001')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新闭包群名');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('闭包频道'));

    expect(
      adapter.hits.where((h) => h.contains('/group/edit')).length,
      1,
      reason: '群改名写请求恰好一次',
    );
    expect(
      adapter.hits.where((h) => h.contains('/workspaces/$kWsId/groups')).length,
      greaterThan(groupsBefore),
      reason: '写后重新读取服务端事实',
    );
  });

  testWidgets('深链：群「成员与角色」落到既有群详情路由', (tester) async {
    HttpClient.adapterForTest = _closureAdapter();
    await tester.pumpWidget(_host());
    await _pumpUntilFound(tester, find.text('闭包群'));
    await tester.tap(find.byKey(const ValueKey('org-manage-group-menu-7001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成员与角色'));
    await tester.pumpAndSettle();

    expect(find.text('SENTINEL-group-detail'), findsOneWidget);
  });

  testWidgets('深链：频道「管理员」落到既有 channel admins 子路由', (tester) async {
    HttpClient.adapterForTest = _closureAdapter();
    await tester.pumpWidget(_host());
    await _scrollToResources(tester);
    await tester.tap(
      find.byKey(const ValueKey('org-manage-channel-menu-6001')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('org-manage-channel-admins-6001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('SENTINEL-channel-admins'), findsOneWidget);
  });

  testWidgets('深链：工作区「成员治理」落到 org 模块 ws 成员面', (tester) async {
    HttpClient.adapterForTest = _closureAdapter();
    await tester.pumpWidget(_host());
    await _openWsMenu(tester);
    await tester.tap(find.text('成员治理'));
    await tester.pumpAndSettle();

    expect(find.text('SENTINEL-ws-members'), findsOneWidget);
  });
}
