/// GZAPP-04 G10 — 通讯录页 focused widget 测试（无网，adapter 供料）。
///
/// 覆盖：
/// - 部门树 + 部门成员（departmentDetail 合并）渲染；
/// - members() 治理面 403 → 全员名单节降级为受限提示（客户端不预判，
///   以服务端 403 为准）；members() 200 → 全员行渲染（昵称/角色）；
/// - 成员行点击 → /people/:id 成员详情（复用 PeopleInfoPage 路由口径）。
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
import 'package:imboy/modules/organization/presentation/organization_directory_page.dart';
import 'package:imboy/service/storage.dart';

const String _orgId = '7001';

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

/// 供料：1 个部门（研发部）+ 部门成员 42；members 可控（403 envelope 或名单）。
Map<String, dynamic> Function(String path) _routes({
  required Object membersResp,
}) {
  return (String path) {
    if (path == '/api/v1/organizations/$_orgId/departments') {
      // payloadList 契约：payload 为 Map 且含 list 键（镜像分页信封形态）。
      return _ok({
        'list': [
          {'id': 81, 'organization_id': int.parse(_orgId), 'name': '研发部'},
        ],
      });
    }
    if (path == '/api/v1/organizations/$_orgId/departments/81') {
      return _ok({
        'department': {
          'id': 81,
          'organization_id': int.parse(_orgId),
          'name': '研发部',
        },
        'members': [
          {
            'organization_id': int.parse(_orgId),
            'department_id': 81,
            'user_id': 42,
          },
        ],
      });
    }
    if (path == '/api/v1/organizations/$_orgId/members') {
      return membersResp as Map<String, dynamic>;
    }
    return _ok(null);
  };
}

GoRouter _router() => GoRouter(
  initialLocation: '/org/directory',
  routes: [
    GoRoute(
      path: '/org/directory',
      builder: (c, s) =>
          const OrganizationDirectoryPage(orgId: _orgId, orgName: '甲企业'),
    ),
    GoRoute(
      path: '/people/:id',
      builder: (c, s) => Scaffold(
        body: Center(child: Text('people-${s.pathParameters['id']}')),
      ),
    ),
  ],
);

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

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp.router(routerConfig: _router())),
    );
  }

  testWidgets('普通成员（members 403）：部门树 + 部门成员渲染，全员名单降级受限提示', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      _routes(membersResp: {'code': 403, 'msg': 'forbidden'}),
    );
    await pumpPage(tester);
    await pumpUntilFound(tester, find.text('研发部'));

    expect(find.text('研发部'), findsOneWidget);
    // departmentDetail 合并的部门成员行（无名单投影 → UID 口径）
    expect(find.textContaining('成员 42'), findsOneWidget);
    // members() 治理面 403 → 受限提示（全员名单不展示）
    expect(find.textContaining('全员名单仅企业管理员可见'), findsOneWidget);
  });

  testWidgets('管理员（members 200）：全员行渲染（昵称/角色）+ 点击进成员详情 /people/:id', (
    tester,
  ) async {
    // members 响应为完整 envelope（code=0 + payload 分页信封）。
    HttpClient.adapterForTest = _RoutingAdapter(
      _routes(
        membersResp: _ok({
          'list': [
            {
              'organization_id': int.parse(_orgId),
              'user_id': 42,
              'role': 'admin',
              'nickname': '张三',
            },
          ],
          'page': 1,
          'size': 100,
          'total': 1,
          'total_page': 1,
        }),
      ),
    );
    await pumpPage(tester);
    await pumpUntilFound(tester, find.text('张三'));

    expect(find.text('张三'), findsWidgets); // 部门成员行 + 全员行
    expect(find.textContaining('全员名单仅企业管理员可见'), findsNothing);

    // 成员详情跳转：复用 /people/:id 路由（uid 口径）
    await tester.tap(
      find.byKey(const ValueKey('org-directory-member-all-42')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('people-42'), findsOneWidget);
  });
}
