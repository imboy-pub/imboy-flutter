/// GZAPP-C3（计划 §5.2）— 企业成员详情页 focused widget 测试（无网，adapter 供料）。
///
/// 覆盖：
/// - 有权 Workspace 从 `GET /organizations/:id/members/:uid/workspaces` 渲染；
/// - 治理面投影缺失（普通成员视角 member=null）时角色给「仅企业管理员可查看」
///   而不是编造角色，工作区仍可见（§5.2「所有企业成员可见」）；
/// - 空态：该成员在本企业内暂无工作区；
/// - 失败态：给重试入口，重试成功后渲染列表；
/// - 保留通往通用 IM 资料页的次级入口。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/presentation/organization_member_detail_page.dart';
import 'package:imboy/service/storage.dart';

const String _orgId = '7001';
const String _uid = '42';

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
    final code = body['code'] as int? ?? 0;
    return ResponseBody.fromString(
      jsonEncode(body),
      code == 0 ? 200 : code,
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

const String _wsPath = '/api/v1/organizations/$_orgId/members/$_uid/workspaces';

GoRouter _router() => GoRouter(
  initialLocation: '/member',
  routes: [
    GoRoute(
      path: '/member',
      builder: (c, s) => OrganizationMemberDetailPage(
        orgId: _orgId,
        userId: _uid,
        member: _member,
        orgName: '甲企业',
      ),
    ),
    GoRoute(
      path: '/member-plain',
      builder: (c, s) => const OrganizationMemberDetailPage(
        orgId: _orgId,
        userId: _uid,
        orgName: '甲企业',
      ),
    ),
    GoRoute(
      path: '/people/:id',
      builder: (c, s) => Scaffold(
        body: Center(child: Text('people-${s.pathParameters['id']}')),
      ),
    ),
  ],
);

OrganizationMember _member = const OrganizationMember(
  organizationId: _orgId,
  userId: _uid,
  role: 'member',
  nickname: '张三',
  account: 'zhangsan',
  joinedAt: '2026-09-01T10:00:00Z',
);

Future<void> _pump(WidgetTester tester, {String at = '/member'}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = _router();
  await tester.pumpWidget(
    TranslationProvider(child: MaterialApp.router(routerConfig: router)),
  );
  if (at != '/member') {
    router.go(at);
  }
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // 与通讯录页测试同款环境准备：HttpClient/Storage 未初始化时请求链会在
  // 到达 adapter 之前就失败，页面只会停在/落到错误态。
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

  testWidgets('有权 Workspace 渲染 + 角色/账号/加入时间 + IM 资料次级入口', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path == _wsPath) {
        return _ok({
          'list': [
            {'id': 9001, 'name': '总部工作区'},
            {'id': 9002, 'name': '广州项目组'},
          ],
        });
      }
      return _ok(null);
    });

    await _pump(tester);

    expect(find.text('张三'), findsWidgets);
    expect(find.text('甲企业'), findsOneWidget);
    expect(find.text('成员'), findsOneWidget); // orgRoleLabel('member')
    expect(find.text('zhangsan'), findsOneWidget);
    // §5.2 的核心交付面
    expect(
      find.byKey(const ValueKey('org-member-detail-ws-9001')),
      findsOneWidget,
    );
    expect(find.text('广州项目组'), findsOneWidget);
    expect(find.text('该成员在本企业内暂无工作区'), findsNothing);

    // 次级入口：通用 IM 资料页
    await tester.tap(
      find.byKey(const ValueKey('org-member-detail-im-profile')),
    );
    await tester.pumpAndSettle();
    expect(find.text('people-42'), findsOneWidget);
  });

  testWidgets('普通成员视角（无治理面投影）：角色标注受限但工作区仍可见', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path == _wsPath) {
        return _ok({
          'list': [
            {'id': 9001, 'name': '总部工作区'},
          ],
        });
      }
      return _ok(null);
    });

    await _pump(tester, at: '/member-plain');

    // 不编造角色，明确说明受限
    expect(find.text('仅企业管理员可查看'), findsOneWidget);
    // 工作区信息对普通成员依然可见（§5.2「所有企业成员可见」）
    expect(
      find.byKey(const ValueKey('org-member-detail-ws-9001')),
      findsOneWidget,
    );
  });

  testWidgets('空态：该成员在本企业内暂无工作区', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path == _wsPath) return _ok({'list': <dynamic>[]});
      return _ok(null);
    });

    await _pump(tester);

    expect(find.text('该成员在本企业内暂无工作区'), findsOneWidget);
  });

  testWidgets('失败态：给重试入口，重试成功后渲染列表', (tester) async {
    var calls = 0;
    HttpClient.adapterForTest = _RoutingAdapter((path) {
      if (path == _wsPath) {
        calls++;
        if (calls == 1) {
          return {'code': 500, 'msg': '查询失败，请稍后重试'};
        }
        return _ok({
          'list': [
            {'id': 9002, 'name': '广州项目组'},
          ],
        });
      }
      return _ok(null);
    });

    await _pump(tester);

    expect(find.text('有权工作区加载失败'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('org-member-detail-workspaces-retry')),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('广州项目组'), findsOneWidget);
    expect(find.text('有权工作区加载失败'), findsNothing);
  });
}
