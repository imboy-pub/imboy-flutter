/// APP-M01-A02/A03 — 坐席工作台组织切换与三列表计数 widget 测试
///
/// 覆盖：
/// - A01：工作台组织选择器由 seat-contexts 列表驱动（两个 Org 可选，
///   默认选中列表首项；切换后选择器反映新 Org）；
/// - A02：徽标计数只取服务端键（total），服务端未给时显示占位符 `--`，
///   不用行数推断；
/// - A03：切换 Org 后三视图清空重载——旧 Org 列表项消失、请求命中
///   **新 org 作用域路径**、计数重置为新 Org 服务端值；
/// - A02：active / closed 视图走 seats/sessions?status=... 真实取数
///   （Tab 懒加载，机械钉 status query）。
///
/// 网络出口用「记录请求 + 按 org 路由」的 HttpClientAdapter 注入。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/storage.dart';

const String orgA = '7266418340025468901';
const String orgB = '7266418340025468999';

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

Map<String, dynamic> _contextsPayload({bool withWorkspace = false}) =>
    okEnvelope(
      payload: {
        'contexts': [
          {
            'organization_id': orgA,
            'organization_name': '组织甲',
            'workspaces': [
              if (withWorkspace) {'id': '7266418340025468921', 'name': '甲客服'},
            ],
            'business_identity_id': '7266418340025468902',
            'seat_enabled': true,
            'capabilities': ['conversation.read'],
          },
          {
            'organization_id': orgB,
            'organization_name': '组织乙',
            'workspaces': [
              if (withWorkspace) {'id': '7266418340025468922', 'name': '乙客服'},
            ],
            'business_identity_id': '7266418340025468912',
            'seat_enabled': true,
            'capabilities': ['conversation.read'],
          },
        ],
        'user_id': '7266418340025468800',
      },
    );

Map<String, dynamic> _queuePayload({
  required String id,
  required String maskedName,
  required int total,
  bool withTotal = true,
}) => okEnvelope(
  payload: {
    'sessions': [
      {
        'id': id,
        'contact_id': '7266418340025468941',
        'contact': {'masked_name': maskedName},
        'queued_at': 1789000000,
        'version': 3,
        'status': 'queued',
        'source': 'widget',
        'last_message': {'id': '7266418340025468961'},
        'organization_id': id,
        'conversation_id': '7266418340025468950',
      },
    ],
    'next_after_id': null,
    if (withTotal) 'total': total,
    if (withTotal) 'total_by_status': {'queued': total},
  },
);

Map<String, dynamic> _seatSessionsPayload(int total) => okEnvelope(
  payload: {
    'sessions': <Map<String, dynamic>>[],
    'next_after_id': null,
    'total': total,
    'total_by_status': <String, dynamic>{},
  },
);

/// 按 path 精确路由的桩：org A / org B 的 queue 与 seats/sessions 分响应。
class _OrgRouterAdapter implements HttpClientAdapter {
  _OrgRouterAdapter(this.routes);

  final Map<String, (int, Map<String, dynamic>)> routes;

  /// (path, query) 请求记录（顺序保留）。
  final List<(String, String)> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final query = options.uri.query;
    requests.add((path, query));
    final hit = routes[path];
    if (hit == null) {
      return ResponseBody.fromString(
        jsonEncode(okEnvelope(payload: <String, dynamic>{})),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(hit.$2),
      hit.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

_OrgRouterAdapter _buildAdapter() => _OrgRouterAdapter({
  '/api/v1/cs/me/seat-contexts': (200, _contextsPayload()),
  '/api/v1/cs/organizations/$orgA/sessions/queue': (
    200,
    _queuePayload(id: '7266418340025468951', maskedName: '甲访客', total: 5),
  ),
  '/api/v1/cs/organizations/$orgB/sessions/queue': (
    200,
    _queuePayload(id: '7266418340025468971', maskedName: '乙访客', total: 7),
  ),
  '/api/v1/cs/organizations/$orgA/seats/sessions': (
    200,
    _seatSessionsPayload(3),
  ),
  '/api/v1/cs/organizations/$orgB/seats/sessions': (
    200,
    _seatSessionsPayload(0),
  ),
});

class _PendingPresenceAdapter extends _OrgRouterAdapter {
  _PendingPresenceAdapter() : super(_buildAdapter().routes) {
    routes['/api/v1/cs/me/seat-contexts'] = (
      200,
      _contextsPayload(withWorkspace: true),
    );
    for (final org in [orgA, orgB]) {
      routes['/api/v1/cs/organizations/$org/seats/me/heartbeat'] = (
        200,
        okEnvelope(
          payload: {
            'status': 'online',
            'enabled': true,
            'max_concurrent': 3,
            'active_count': 0,
          },
        ),
      );
    }
  }

  final pending = <String, Completer<ResponseBody>>{};
  final manualOrgs = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.method == 'PUT' && options.uri.path.endsWith('/presence')) {
      final org = options.uri.path.split('/')[5];
      manualOrgs.add(org);
      return (pending[org] ??= Completer<ResponseBody>()).future;
    }
    return super.fetch(options, requestStream, cancelFuture);
  }

  void complete(String org) {
    final request = pending[org];
    if (request == null || request.isCompleted) return;
    request.complete(
      ResponseBody.fromString(
        jsonEncode(
          okEnvelope(
            payload: {
              'status': 'away',
              'manual_status': 'away',
              'enabled': true,
              'max_concurrent': 3,
              'active_count': 0,
            },
          ),
        ),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }
}

Future<void> _pumpWorkspace(WidgetTester tester) async {
  await tester.pumpWidget(
    // 对齐既有 CS widget 测试：TranslationProvider 挂在 MaterialApp.builder
    // 内（InheritedWidget 需在导航子树内）。
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: child ?? const SizedBox.shrink()),
      home: const CsWorkspacePage(),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // bootstrap 链路会读 flutter_secure_storage（平台通道）：无 mock 时
    // fakeAsync 下 MethodChannel 永不完成，页面 bootstrap 挂起（与
    // cs_session_page_test 同款 mock：无 token 直通）。
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'readAll') return <String, String>{};
          return null;
        });
    await StorageService.init();
  });

  testWidgets('切组织后独立操作状态，旧请求不能阻塞或解锁新请求', (tester) async {
    final adapter = _PendingPresenceAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() {
      adapter.complete(orgA);
      adapter.complete(orgB);
      HttpClient.adapterForTest = null;
    });
    await _pumpWorkspace(tester);
    await tester.tap(find.byTooltip('坐席状态'));
    await _settle(tester);
    await tester.tap(find.text('设为离开'));
    await _settle(tester);
    expect(adapter.manualOrgs, [orgA]);

    await tester.tap(find.byTooltip('组织'));
    await _settle(tester);
    await tester.tap(find.text('组织乙').last);
    await _settle(tester);
    await tester.tap(find.byTooltip('坐席状态'));
    await _settle(tester);
    await tester.tap(find.text('设为离开'));
    await _settle(tester);
    expect(adapter.manualOrgs, [orgA, orgB], reason: '新企业不被旧请求阻塞');

    adapter.complete(orgA);
    await _settle(tester);
    await tester.tap(find.byTooltip('坐席状态'));
    await _settle(tester);
    await tester.tap(find.text('设为离开'));
    await _settle(tester);
    expect(adapter.manualOrgs, [orgA, orgB], reason: '旧请求不能解锁新企业正在提交的操作');
    adapter.complete(orgB);
    await _settle(tester);
    expect(find.text('离开'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('A01+A02：seat-contexts 驱动组织选择器；徽标计数只取服务端键', (tester) async {
    final adapter = _buildAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await _pumpWorkspace(tester);

    // 组织选择器默认选中 seat-contexts 首个可用上下文。
    expect(find.text('组织甲'), findsWidgets);
    // 徽标 = 服务端 total（5），不是行数。
    expect(find.text('5'), findsWidgets);
    // 队列项来自 org A。
    expect(find.text('甲**'), findsOneWidget);
    expect(
      adapter.requests.any(
        (r) => r.$1 == '/api/v1/cs/organizations/$orgA/sessions/queue',
      ),
      isTrue,
      reason: '队列取数走 org A 作用域路径',
    );
  });

  testWidgets('A03：切换 Org → 旧列表/计数清空，新 org 作用域重载', (tester) async {
    final adapter = _buildAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await _pumpWorkspace(tester);
    expect(find.text('甲**'), findsOneWidget);
    expect(find.text('5'), findsWidgets);

    // 打开组织选择器并切换到组织乙。
    await tester.tap(find.byTooltip('组织'));
    await _settle(tester);
    await tester.tap(find.text('组织乙').last);
    await _settle(tester);

    // 旧 Org 列表项清空，新 Org 列表渲染。
    expect(find.text('甲**'), findsNothing, reason: 'A03：旧 Org 列表清空');
    expect(find.text('乙**'), findsOneWidget, reason: '新 Org 列表重载');
    // 选择器反映新 Org；计数重置为新 Org 服务端值（7），不残留 org A 的 5。
    expect(find.text('组织乙'), findsWidgets);
    expect(find.text('7'), findsWidgets);
    expect(
      find.text('5'),
      findsNothing,
      reason: 'A03：切换 Org 后旧服务端计数清空（不串租户缓存）',
    );
    expect(
      adapter.requests.any(
        (r) => r.$1 == '/api/v1/cs/organizations/$orgB/sessions/queue',
      ),
      isTrue,
      reason: '切 Org 后按新 org 作用域路径重载',
    );
  });

  testWidgets('A02：active/closed 视图走 seats/sessions（status query 机械钉）', (
    tester,
  ) async {
    final adapter = _buildAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await _pumpWorkspace(tester);

    // 切到「处理中」Tab（懒加载触发 seats/sessions?status=active）。
    await tester.tap(find.text('处理中'));
    await _settle(tester);

    final seatsRequests = adapter.requests
        .where((r) => r.$1 == '/api/v1/cs/organizations/$orgA/seats/sessions')
        .toList();
    expect(
      seatsRequests,
      isNotEmpty,
      reason: 'active 视图走 org 作用域 seats/sessions',
    );
    expect(
      seatsRequests.first.$2.contains('status=active'),
      isTrue,
      reason: 'status 必填（服务端显式必填且仅接受 active|closed）',
    );

    // 切到「已关闭」Tab。
    await tester.tap(find.text('已关闭'));
    await _settle(tester);
    expect(
      adapter.requests.any(
        (r) =>
            r.$1.contains('seats/sessions') && r.$2.contains('status=closed'),
      ),
      isTrue,
      reason: 'closed 视图显式 status=closed',
    );
  });

  testWidgets('A02：服务端未给计数键 → 徽标显示占位符（不用行数推断）', (tester) async {
    final adapter = _OrgRouterAdapter({
      '/api/v1/cs/me/seat-contexts': (200, _contextsPayload()),
      '/api/v1/cs/organizations/$orgA/sessions/queue': (
        200,
        _queuePayload(
          id: '7266418340025468951',
          maskedName: '甲访客',
          total: 0,
          withTotal: false,
        ),
      ),
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await _pumpWorkspace(tester);

    // 列表有 1 行（服务端给的），但服务端未给计数 → 徽标 `--`（不是 1）。
    expect(find.text('甲**'), findsOneWidget);
    expect(find.text('1'), findsNothing, reason: '禁止用已加载行数推断计数');
    expect(find.text('--'), findsWidgets, reason: 'countUnavailable 占位符');
  });
}
