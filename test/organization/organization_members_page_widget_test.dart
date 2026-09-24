/// ENT-APP-04 — 成员治理页 focused widget 测试。
///
/// 覆盖（任务卡验收锚点）：
/// - owner 不可被非法治理：owner 行的动作单不出现任何治理入口
///   （role/transfer/remove/suspend/offboard 全部隐藏），只有说明行；
/// - 生命周期命令（EB-D07/EB-08）：
///   · suspend 确认 → POST suspend → 列表刷新后目标成员消失（服务端
///     治理列表只回 active 行 = 立即失去可见性）；
///   · suspended 行（命令响应供料）→ restore 入口 → POST restore →
///     回到列表（active 恢复）；
///   · offboard 确认 → POST offboard → 成员消失（removed 终态）；
/// - 命令失败不假成功：500 透传 SnackBar（错误态），列表保留服务端事实；
/// - 详情入口：动作单含「查看详情」→ 跳成员详情页（go_router 真路由）。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/service/storage.dart';

const String _accountKey = '92001';
const String _orgId = '7301';

/// 按 URI path 分发的静态 adapter（members 分页 + 生命周期命令共用）。
class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  final Map<String, dynamic> Function(String path) routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = routes(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
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
  'payload': payload,
};

Map<String, dynamic> _memberPage(List<Map<String, dynamic>> list) => _ok({
  'list': list,
  'page': 1,
  'size': 10,
  'total': list.length,
  'total_page': 1,
});

Map<String, dynamic> _memberRow(
  int uid, {
  String role = 'member',
  String status = 'active',
  String nickname = '',
}) => {
  'organization_id': int.parse(_orgId),
  'user_id': uid,
  'role': role,
  'status': status,
  if (nickname.isNotEmpty) 'nickname': nickname,
};

/// 可变列表供料：命令成功后服务端事实变化（模拟 suspend 后 active-only
/// 列表不再返回该成员）。
class _MembersState {
  final List<Map<String, dynamic>> rows;
  final List<String> postedCommands = [];

  _MembersState(this.rows);
}

GoRouter _router() => GoRouter(
  initialLocation: '/organization/$_orgId/members',
  routes: [
    GoRoute(
      path: '/organization/:orgId/members',
      builder: (c, s) => OrganizationMembersPage(
        orgId: s.pathParameters['orgId'] ?? _orgId,
        accountKey: _accountKey,
      ),
    ),
    GoRoute(
      path: '/organization/:orgId/member/:uid',
      builder: (c, s) => OrganizationMemberDetailPage(
        orgId: s.pathParameters['orgId'] ?? _orgId,
        userId: s.pathParameters['uid'] ?? '',
        orgName: '测试企业',
      ),
    ),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(child: MaterialApp.router(routerConfig: _router())),
  );
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
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

  /// 挂 adapter：GET members 分页读 [state.rows] 快照；POST 生命周期命令
  /// 返回对应状态成员行并记录调用。命令成功同步服务端事实：suspend/
  /// offboard 后 active-only 治理列表不再返回该成员；restore 后回到 active。
  void wireAdapter(_MembersState state) {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/members')) {
        return _memberPage(List<Map<String, dynamic>>.from(state.rows));
      }
      if (path.endsWith('/suspend')) {
        state.postedCommands.add('suspend');
        state.rows.removeWhere((r) => r['user_id'] == 1002);
        return _ok(_memberRow(1002, status: 'suspended'));
      }
      if (path.endsWith('/restore')) {
        state.postedCommands.add('restore');
        return _ok(_memberRow(1002, status: 'active'));
      }
      if (path.endsWith('/offboard')) {
        state.postedCommands.add('offboard');
        state.rows.removeWhere((r) => r['user_id'] == 1002);
        return _ok(_memberRow(1002, status: 'removed'));
      }
      return _ok(null);
    });
  }

  testWidgets('owner 不可被非法治理：动作单只有说明行，无任何治理入口', (tester) async {
    wireAdapter(
      _MembersState([
        _memberRow(1001, role: 'owner', nickname: 'OwnerIder'),
        _memberRow(1002, role: 'member', nickname: '小明'),
      ]),
    );
    await _pump(tester);
    await pumpUntilFound(tester, find.text('OwnerIder'));

    // 打开 owner 行动作单。
    await tester.tap(find.text('OwnerIder'));
    await tester.pumpAndSettle();

    // UI 防御（减法）：owner 行不出现任何治理入口。
    expect(find.text('升级为管理员'), findsNothing);
    expect(find.text('转移所有者给「OwnerIder」'), findsNothing);
    expect(find.text('移除成员'), findsNothing);
    expect(find.text('暂停成员'), findsNothing);
    expect(find.text('离场（终态）'), findsNothing);
    // 只有说明行 + 详情入口（详情是只读面，全员可用）。
    expect(find.text('Owner 不可在此变更；请使用「转移所有者」'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
  });

  testWidgets('suspend：确认 → POST → 成员从列表消失（立即失去可见性）', (tester) async {
    final state = _MembersState([
      _memberRow(1001, role: 'owner', nickname: 'OwnerIder'),
      _memberRow(1002, role: 'member', nickname: '小明'),
    ]);
    wireAdapter(state);
    await _pump(tester);
    await pumpUntilFound(tester, find.text('小明'));

    await tester.tap(find.text('小明'));
    await tester.pumpAndSettle();
    expect(find.text('暂停成员'), findsOneWidget);

    await tester.tap(find.text('暂停成员'));
    await tester.pumpAndSettle();
    // 危险确认（第二步）。
    await tester.tap(find.text('确认暂停'));
    await pumpUntilFound(tester, find.text('OwnerIder'));

    expect(state.postedCommands, ['suspend']);
    // 服务端事实：suspend 后治理列表（active-only）不再返回该成员——
    // 页面刷新后小明消失 = 该 Org 内可见性立即失去。
    expect(find.text('小明'), findsNothing);
  });

  testWidgets('suspended 行：restore 入口 → POST → 回到列表（恢复可见）', (tester) async {
    // suspended 行由生命周期命令响应/服务端直出（客户端 DTO 原样承载；
    // restore 入口按 status 判定，不依赖列表过滤策略）。
    final state = _MembersState([
      _memberRow(1001, role: 'owner', nickname: 'OwnerIder'),
      _memberRow(1002, role: 'member', status: 'suspended', nickname: '小明'),
    ]);
    wireAdapter(state);
    await _pump(tester);
    await pumpUntilFound(tester, find.text('小明'));

    // 状态标签可见（已暂停）。
    expect(find.textContaining('已暂停'), findsWidgets);

    await tester.tap(find.text('小明'));
    await tester.pumpAndSettle();
    // suspended 行：不再提供 suspend（已暂停）/角色变更（非 active），
    // 提供 restore；remove/offboard 仍在（offboard 接受 suspended 来源）。
    expect(find.text('暂停成员'), findsNothing);
    expect(find.text('恢复成员'), findsOneWidget);
    expect(find.text('离场（终态）'), findsOneWidget);

    await tester.tap(find.text('恢复成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认恢复'));
    // 模拟服务端事实：restore 后回到 active 列表。
    state.rows[1]['status'] = 'active';
    await pumpUntilFound(tester, find.text('小明'));

    expect(state.postedCommands, ['restore']);
    expect(find.text('小明'), findsOneWidget);
  });

  testWidgets('offboard：确认 → POST → 成员消失（removed 终态）', (tester) async {
    final state = _MembersState([
      _memberRow(1001, role: 'owner', nickname: 'OwnerIder'),
      _memberRow(1002, role: 'member', nickname: '小明'),
    ]);
    wireAdapter(state);
    await _pump(tester);
    await pumpUntilFound(tester, find.text('小明'));

    await tester.tap(find.text('小明'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('离场（终态）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认离场'));
    await pumpUntilFound(tester, find.text('OwnerIder'));

    expect(state.postedCommands, ['offboard']);
    expect(find.text('小明'), findsNothing, reason: 'removed 终态不再出现在列表');
  });

  testWidgets('命令失败不假成功：500 → SnackBar 错误态 + 成员保留', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/members')) {
        return _memberPage([
          _memberRow(1001, role: 'owner', nickname: 'OwnerIder'),
          _memberRow(1002, role: 'member', nickname: '小明'),
        ]);
      }
      if (path.endsWith('/suspend')) {
        return {'code': 500, 'msg': '暂停失败，请稍后重试'};
      }
      return _ok(null);
    });
    await _pump(tester);
    await pumpUntilFound(tester, find.text('小明'));

    await tester.tap(find.text('小明'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂停成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认暂停'));

    // 错误透传（SnackBar 含服务端文案），不显示成功、成员仍在列表。
    await pumpUntilFound(tester, find.textContaining('暂停失败'));
    expect(find.textContaining('暂停失败：暂停失败，请稍后重试'), findsOneWidget);
    expect(find.text('小明'), findsOneWidget, reason: '失败不改变服务端事实');
  });

  testWidgets('查看详情：动作单 → 成员详情页（真路由跳转）', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path.endsWith('/members')) {
        return _memberPage([
          _memberRow(1001, role: 'owner', nickname: 'OwnerIder'),
          _memberRow(1002, role: 'member', nickname: '小明'),
        ]);
      }
      if (path.contains('/members/1002/workspaces')) {
        return _ok(<String, dynamic>{'list': <dynamic>[]});
      }
      return _ok(null);
    });
    await _pump(tester);
    await pumpUntilFound(tester, find.text('小明'));

    await tester.tap(find.text('小明'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看详情'));
    await pumpUntilFound(tester, find.byType(OrganizationMemberDetailPage));

    // 详情页可达（§5.2 成员详情：全员可见的企业成员视图）。测试路由
    // 未透传 extra member 行 → 标题/资料卡回退 userId（TSID string 原样）。
    expect(find.byType(OrganizationMemberDetailPage), findsOneWidget);
    expect(find.text('1002'), findsWidgets);
  });
}
