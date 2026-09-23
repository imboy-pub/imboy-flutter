/// P1 类企业微信通讯录浏览页 widget 测试（计划 §14.2 / §14.3 接线面）。
///
/// 状态机本体由 human_directory_controller_test 覆盖；本文件证明页面接线：
/// - 上半直接子部门、下半本级成员（+「我的部门」/me 捷径仅根级）；
/// - 搜索固定 300ms debounce；<2 字符不发请求；
/// - didUpdateWidget（orgId 变化）→ 重建请求换 Org，旧数据不展示；
/// - 部门行进入下一层（parentId 透传）；成员行 → 复用既有企业成员详情路由。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';
import 'package:imboy/modules/organization/presentation/human_directory_page.dart';
import 'package:imboy/service/storage.dart';

const orgA = '7001';
const orgB = '7002';
const dept1 = '8001';
const dept2 = '8002';

class _FakeSource implements HumanDirectoryDataSource {
  _FakeSource();

  final List<Completer<HumanDirectoryPage<HumanDirectoryDepartment>>>
  _pendingDepartments = [];
  final List<Completer<HumanDirectoryPage<HumanDirectorySearchItem>>>
  _pendingSearch = [];
  final List<String> deptCalls = [];
  final List<String> memberCalls = [];
  final List<String> meCalls = [];
  final List<String> searchCalls = [];

  @override
  Future<HumanDirectoryPage<HumanDirectoryDepartment>> directoryDepartments({
    required String organizationId,
    String? parentId,
    String? cursor,
    int? limit,
  }) {
    deptCalls.add('$organizationId|p=${parentId ?? '-'}|c=${cursor ?? '-'}');
    final c = Completer<HumanDirectoryPage<HumanDirectoryDepartment>>();
    _pendingDepartments.add(c);
    return c.future;
  }

  @override
  Future<HumanDirectoryPage<HumanDirectoryMember>> directoryMembers({
    required String organizationId,
    String? departmentId,
    String? cursor,
    int? limit,
  }) {
    memberCalls.add(
      '$organizationId|d=${departmentId ?? '-'}|c=${cursor ?? '-'}',
    );
    return Future.value(
      HumanDirectoryPage(
        list: const [HumanDirectoryMember(userId: '9001', displayName: '根成员甲')],
        cursor: null,
        hasMore: false,
      ),
    );
  }

  @override
  Future<HumanDirectoryMe> directoryMe({required String organizationId}) {
    meCalls.add(organizationId);
    return Future.value(
      HumanDirectoryMe(organizationId: organizationId, list: const []),
    );
  }

  @override
  Future<HumanDirectoryPage<HumanDirectorySearchItem>> directorySearch({
    required String organizationId,
    required String q,
    String? cursor,
    int? limit,
  }) {
    searchCalls.add('$organizationId|q=$q|c=${cursor ?? '-'}');
    final c = Completer<HumanDirectoryPage<HumanDirectorySearchItem>>();
    _pendingSearch.add(c);
    return c.future;
  }

  /// 放行当前挂起的 departments 请求（默认给两个直接子部门）。
  void resolveDepartments({
    List<HumanDirectoryDepartment> items = const [],
    String? cursor,
  }) {
    final c = _pendingDepartments.firstWhere(
      (c) => !c.isCompleted,
      orElse: () => throw StateError('no pending department request'),
    );
    c.complete(
      HumanDirectoryPage<HumanDirectoryDepartment>(
        list: items,
        cursor: cursor,
        hasMore: cursor != null,
      ),
    );
  }

  void resolveSearch(List<HumanDirectorySearchItem> items, {String? cursor}) {
    final c = _pendingSearch.firstWhere((c) => !c.isCompleted);
    c.complete(
      HumanDirectoryPage<HumanDirectorySearchItem>(
        list: items,
        cursor: cursor,
        hasMore: cursor != null,
      ),
    );
  }
}

const _defaultDepts = [
  HumanDirectoryDepartment(id: dept1, name: '研发部', memberCount: 2),
  HumanDirectoryDepartment(id: dept2, name: '设计部', memberCount: 1),
];

Widget _routerApp(GoRouter router) => TranslationProvider(
  child: UncontrolledProviderScope(
    container: ProviderContainer(),
    child: MaterialApp.router(routerConfig: router),
  ),
);

/// 无路由宿主（不需要 push 的用例）：重复 pumpWidget 同型树触发
/// didUpdateWidget。
Widget _plainApp(Widget home) =>
    TranslationProvider(child: MaterialApp(home: home));

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('企业根：上半直接子部门、下半本级成员；/me 捷径仅根级', (tester) async {
    final src = _FakeSource();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HumanDirectoryBrowserPage(
            orgId: orgA,
            orgName: '甲企业',
            dataSource: src,
          ),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(router));
    await tester.pump(); // 首帧 + initState 触发三请求

    src.resolveDepartments(items: _defaultDepts);
    await tester.pumpAndSettle();

    // 上半：部门节 + 直接子部门（member_count 文案）。
    expect(find.text(t.organization.directory.deptSection), findsOneWidget);
    expect(find.text('研发部'), findsOneWidget);
    expect(find.text('设计部'), findsOneWidget);
    // 下半：本级成员节 + 根成员行。
    expect(find.text(t.organization.directory.membersSection), findsOneWidget);
    expect(find.text('根成员甲'), findsOneWidget);
    expect(find.byKey(const Key('org-dir-member-9001')), findsOneWidget);
    // /me 无部门 → 捷径收起。
    expect(
      find.text(t.organization.directory.myDepartmentsSection),
      findsNothing,
    );
  });

  testWidgets('部门行点击 → 下一层（parentId 透传 + 标题切换）', (tester) async {
    final src = _FakeSource();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HumanDirectoryBrowserPage(
            orgId: orgA,
            orgName: '甲企业',
            dataSource: src,
          ),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(router));
    await tester.pump();
    src.resolveDepartments(items: _defaultDepts);
    await tester.pumpAndSettle();

    await tester.tap(find.text('研发部'));
    await tester.pump();
    src.resolveDepartments(
      items: const [
        HumanDirectoryDepartment(id: '8101', name: '后端组', memberCount: 1),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      src.deptCalls.last,
      '$orgA|p=$dept1|c=-',
      reason: '下一层 parent_id 透传',
    );
    expect(src.memberCalls.last, '$orgA|d=$dept1|c=-');
    expect(find.text('后端组'), findsOneWidget);
    // AppBar 标题切到「研发部」层级；父层级的兄弟行不再展示。
    expect(find.text('研发部'), findsOneWidget, reason: '标题 = 当前层级部门名');
    expect(find.text('设计部'), findsNothing, reason: '父层级兄弟行不残留');
  });

  testWidgets('搜索 300ms debounce：<2 字符不请求；>=2 字符走混排结果', (tester) async {
    final src = _FakeSource();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HumanDirectoryBrowserPage(
            orgId: orgA,
            orgName: '甲企业',
            dataSource: src,
          ),
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(router));
    await tester.pump();
    src.resolveDepartments(items: _defaultDepts);
    await tester.pumpAndSettle();
    final searchCallsBefore = src.searchCalls.length;

    await tester.enterText(
      find.byKey(const Key('org_directory_search_input')),
      '研',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(src.searchCalls, hasLength(searchCallsBefore), reason: '1 字符不请求');

    await tester.enterText(
      find.byKey(const Key('org_directory_search_input')),
      '研发',
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(
      src.searchCalls,
      hasLength(searchCallsBefore),
      reason: 'debounce 未到',
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(src.searchCalls, hasLength(searchCallsBefore + 1));
    expect(src.searchCalls.last, '$orgA|q=研发|c=-');
    src.resolveSearch([
      const HumanDirectorySearchItem(
        type: 'department',
        department: HumanDirectoryDepartment(id: dept1, name: '研发部'),
      ),
      const HumanDirectorySearchItem(
        type: 'member',
        member: HumanDirectoryMember(userId: '9002', displayName: '研发同学'),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('org-dir-dept-list-$dept1')), findsOneWidget);
    expect(find.byKey(const Key('org-dir-member-9002')), findsOneWidget);
    // 搜索模式不展示目录分页节。
    expect(find.text(t.organization.directory.deptSection), findsNothing);
  });

  testWidgets('didUpdateWidget：orgId 变化 → 新 Org 重建，旧数据不展示', (tester) async {
    final src = _FakeSource();
    var currentOrg = orgA;
    Widget host() => HumanDirectoryBrowserPage(
      orgId: currentOrg,
      orgName: currentOrg == orgA ? '甲企业' : '乙企业',
      dataSource: src,
    );

    await tester.pumpWidget(_plainApp(Scaffold(body: host())));
    await tester.pump();
    src.resolveDepartments(items: _defaultDepts);
    await tester.pumpAndSettle();
    expect(find.text('研发部'), findsOneWidget);

    // 同型同位 rebuild（无 key）→ didUpdateWidget 触发 configure。
    currentOrg = orgB;
    await tester.pumpWidget(_plainApp(Scaffold(body: host())));
    await tester.pump();

    expect(src.deptCalls.last, '$orgB|p=-|c=-', reason: '新 Org 从根重建');
    expect(find.text('研发部'), findsNothing, reason: '上一 Org 数据立即清除');
    src.resolveDepartments(
      items: const [HumanDirectoryDepartment(id: '9101', name: '乙企业研发')],
    );
    await tester.pumpAndSettle();
    expect(find.text('乙企业研发'), findsOneWidget);
  });

  testWidgets('成员行点击 → 复用既有企业成员详情路由（含 IM 资料次级入口）', (tester) async {
    final src = _FakeSource();
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HumanDirectoryBrowserPage(
            orgId: orgA,
            orgName: '甲企业',
            dataSource: src,
          ),
        ),
        GoRoute(
          path: '/organization/:orgId/member/:uid',
          builder: (context, state) {
            pushed.add(
              '${state.pathParameters['orgId']}/${state.pathParameters['uid']}',
            );
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(router));
    await tester.pump();
    src.resolveDepartments(items: _defaultDepts);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('org-dir-member-9001')));
    await tester.pumpAndSettle();

    expect(pushed, ['$orgA/9001']);
  });
}
