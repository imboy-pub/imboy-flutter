/// GZAPP-J11 — 企业邀请二维码页 widget 测试（出码侧）。
///
/// 覆盖三态：
/// - 有 active 码：QR 渲染（payload `imboy://org/join?c=CODE`）+ 明码
///   + 有效期行 + 重新生成入口；
/// - 无 active 码（code=null 可空语义）：显示「生成邀请码」引导；
/// - 非 owner/admin（403）：notAdmin 提示，不出码。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/org_invite_qr_page.dart';
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

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: const MaterialApp(
        home: OrgInviteQrPage(orgId: _orgId, orgName: '演示企业'),
      ),
    ),
  );
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

  testWidgets('有 active 码：QR + 明码 + 有效期 + 重新生成入口', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) => path.endsWith('/invite_code')
          ? _ok({
              'organization_id': int.parse(_orgId),
              'code': 'ABCD2345',
              'status': 'active',
              'expires_at': 1789000000,
            })
          : _ok(null),
    );
    await _pumpPage(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(const ValueKey('org-invite-qr')), findsOneWidget);
    expect(find.text('ABCD2345'), findsOneWidget);
    expect(find.byKey(const ValueKey('org-invite-regenerate')), findsOneWidget);
    expect(find.byKey(const ValueKey('org-invite-copy')), findsOneWidget);
    expect(find.textContaining('有效期至'), findsOneWidget);
  });

  testWidgets('无 active 码：显示生成引导', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) => path.endsWith('/invite_code')
          ? _ok({
              'organization_id': int.parse(_orgId),
              'code': null,
              'status': null,
            })
          : _ok(null),
    );
    await _pumpPage(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(const ValueKey('org-invite-generate')), findsOneWidget);
  });

  testWidgets('非 owner/admin（403）：OrgStateView 统一无权限态，不出码', (tester) async {
    HttpClient.adapterForTest = _RoutingAdapter(
      (path) => path.endsWith('/invite_code')
          ? {'code': 403, 'msg': 'governance only'}
          : _ok(null),
    );
    await _pumpPage(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(const ValueKey('org-invite-qr')), findsNothing);
    // OrgStateView 的 403 专用文案（permissionDenied ≠ 系统错误）。
    expect(find.textContaining('无权查看'), findsOneWidget);
  });
}
