/// CS-APP-03 — 企业自助客服治理页 widget 测试（CS-GOV-02B 验收口径）。
///
/// 覆盖：
/// - ready 态：额度事实卡（n|unlimited + used）+ 坐席行投影 + TSID 19 位
///   lossless 展示；
/// - 权限负例：403（governance_insufficient）诚实渲染权限终态（无重试
///   按钮、不伪装成空列表）；
/// - 一般错误（500）：错误态 + 重试入口；
/// - 额度变化：调整对话框提交 → PUT body `{seat_limit}` → 回显新额度
///   （含达上限徽标）；非法输入本地拒绝不发 PUT；
/// - 超额冲突可解释：动作失败 envelope msg=seat_limit_exceeded →
///   SnackBar 给可解释文案（含当前额度事实）；
/// - 切换 Organization 失效重建：orgId 变化即丢弃旧 Org 数据并按新
///   org 作用域路径重拉（didUpdateWidget 路径，不残留陈旧治理数据）。
///
/// 网络出口用「method+path 片段精确路由」的 HttpClientAdapter 注入
/// （ux_harness 提供初始化/settle；路由分桩按 method 区分 GET/PUT/POST）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/presentation/cs_governance_page.dart';

import '../ux_matrix/ux_harness.dart';

const String orgA = '7266418340025468901';
const String orgB = '7266418340025468999';
const String identityA = '7266418340025468902';
const String identityB = '7266418340025468912';

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

Map<String, dynamic> errEnvelope(int status, String tag) => {
  'code': status,
  'msg': tag,
  'payload': <String, dynamic>{},
};

Map<String, dynamic> _limitPayload(
  String org, {
  dynamic seatLimit = 5,
  int used = 3,
}) => okEnvelope(
  payload: {'organization_id': org, 'seat_limit': seatLimit, 'used': used},
);

Map<String, dynamic> _seatsPayload({
  List<Map<String, dynamic>>? seats,
  dynamic nextAfterId,
}) => okEnvelope(
  payload: {
    'seats': seats ?? <Map<String, dynamic>>[],
    'next_after_id': nextAfterId,
  },
);

Map<String, dynamic> _seatRow(
  String org,
  String identity, {
  bool enabled = true,
}) => {
  'organization_id': org,
  'business_identity_id': identity,
  'function_key': 'customer_service',
  'enabled': enabled,
  'max_concurrent': 3,
  'active_count': 1,
};

/// 按 `METHOD fragment` 复合键路由的桩（contains 匹配 path）；响应按序
/// 消耗、耗尽停留最后一个。记录命中序列供路径断言。
class _GovRouterAdapter implements HttpClientAdapter {
  _GovRouterAdapter(this.routes);

  final Map<String, List<(int, Map<String, dynamic>)>> routes;
  final List<String> hits = [];
  final Map<String, List<Object?>> bodies = {};
  final Map<String, int> _cursor = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final key in routes.keys) {
      final method = key.substring(0, key.indexOf(' '));
      final fragment = key.substring(key.indexOf(' ') + 1);
      if (options.method == method && options.uri.path.contains(fragment)) {
        hits.add(key);
        bodies.putIfAbsent(key, () => []).add(options.data);
        final queue = routes[key]!;
        // 按序消费、耗尽停留最后一个（首次 index 0，之后逐帧前进）。
        final i = _cursor.putIfAbsent(key, () => 0);
        _cursor[key] = (i + 1).clamp(0, queue.length - 1);
        final (status, body) = queue[i];
        return ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode(okEnvelope(payload: <String, dynamic>{})),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _host(String orgId) =>
    uxHost(CsGovernancePage(orgId: orgId), const UxCombo(kUxMediumViewport));

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets('ready：额度事实 + 坐席行 + TSID 19 位 lossless 展示', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (200, _limitPayload(orgA, seatLimit: 5, used: 3)),
      ],
      'GET /cs/organizations/$orgA/seats': [
        (200, _seatsPayload(seats: [_seatRow(orgA, identityA)])),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-limit-value')),
    );
    await settleUx(tester);

    expect(find.text('3/5 席位'), findsOneWidget, reason: '额度事实（used/limit）');
    expect(
      find.textContaining(identityA),
      findsOneWidget,
      reason: '坐席 TSID 19 位逐字展示（string lossless）',
    );
    expect(
      find.byKey(const ValueKey('cs-governance-limit-at-capacity')),
      findsNothing,
    );
    expect(adapter.hits.length, 2);
  });

  testWidgets('unlimited：显示「不限」且无上限徽标', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (200, _limitPayload(orgA, seatLimit: 'unlimited', used: 12)),
      ],
      'GET /cs/organizations/$orgA/seats': [
        (200, _seatsPayload(seats: [_seatRow(orgA, identityA)])),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-limit-value')),
    );
    await settleUx(tester);

    expect(find.text('不限'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cs-governance-limit-at-capacity')),
      findsNothing,
    );
  });

  testWidgets('权限负例：403 governance_insufficient 诚实权限终态（无重试）', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (403, errEnvelope(403, 'governance_insufficient')),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-error')),
    );
    await settleUx(tester);

    expect(
      find.textContaining('无治理权限'),
      findsOneWidget,
      reason: '权限终态文案诚实展示，不伪装成空列表',
    );
    expect(
      find.byKey(const ValueKey('cs-governance-retry')),
      findsNothing,
      reason: '403 权限终态不给重试（服务端是唯一裁决）',
    );
    expect(
      find.byKey(const ValueKey('cs-governance-limit-value')),
      findsNothing,
      reason: '不渲染任何额度事实（无陈旧/伪造数据）',
    );
  });

  testWidgets('一般错误：500 wire tag 透传 + 重试入口', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (500, errEnvelope(500, 'facts_unavailable')),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-error')),
    );
    await settleUx(tester);

    expect(find.textContaining('facts_unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('cs-governance-retry')), findsOneWidget);
  });

  testWidgets('空坐席：空态文案（不报错）', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [(200, _limitPayload(orgA))],
      'GET /cs/organizations/$orgA/seats': [(200, _seatsPayload())],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-seats-empty')),
    );
    await settleUx(tester);

    expect(find.text('暂无坐席席位'), findsOneWidget);
  });

  testWidgets('额度变化：调整 2 → PUT body + 新额度回显 + 达上限徽标', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (200, _limitPayload(orgA, seatLimit: 5, used: 3)),
        // PUT 后 _refresh 的下一次 GET。
        (200, _limitPayload(orgA, seatLimit: 2, used: 2)),
      ],
      'PUT /cs/organizations/$orgA/seat-limit': [
        (200, _limitPayload(orgA, seatLimit: 2, used: 2)),
      ],
      'GET /cs/organizations/$orgA/seats': [
        (200, _seatsPayload(seats: [_seatRow(orgA, identityA)])),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-limit-value')),
    );
    await settleUx(tester);

    await tester.tap(find.byKey(const ValueKey('cs-governance-limit-adjust')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cs-governance-limit-input')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('cs-governance-limit-save')));
    await tester.pumpAndSettle();
    await settleUx(tester);

    final putBodies =
        adapter.bodies['PUT /cs/organizations/$orgA/seat-limit'] ?? [];
    expect(putBodies.single, <String, dynamic>{'seat_limit': 2});
    expect(find.text('2/2 席位'), findsOneWidget, reason: '额度变化后回显服务端事实');
    expect(
      find.byKey(const ValueKey('cs-governance-limit-at-capacity')),
      findsOneWidget,
      reason: 'used == limit → 达上限提示',
    );
    expect(find.textContaining('额度已更新'), findsOneWidget);
  });

  testWidgets('非法输入（0）：本地拒绝，不发 PUT', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [(200, _limitPayload(orgA))],
      'GET /cs/organizations/$orgA/seats': [(200, _seatsPayload())],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-limit-value')),
    );
    await settleUx(tester);

    await tester.tap(find.byKey(const ValueKey('cs-governance-limit-adjust')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cs-governance-limit-input')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('cs-governance-limit-save')));
    await tester.pumpAndSettle();

    expect(adapter.hits.where((h) => h.startsWith('PUT')), isEmpty);
    expect(find.textContaining('请输入正整数'), findsOneWidget);
  });

  testWidgets('超额冲突：resume 失败 seat_limit_exceeded → 可解释 SnackBar', (
    tester,
  ) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (200, _limitPayload(orgA, seatLimit: 2, used: 2)),
      ],
      'GET /cs/organizations/$orgA/seats': [
        (
          200,
          _seatsPayload(seats: [_seatRow(orgA, identityA, enabled: false)]),
        ),
      ],
      // resume 撞额度上限（envelope tag；后端 classify 未显式登记时 500 漂移）。
      'POST /cs/organizations/$orgA/seats/$identityA/resume': [
        (500, errEnvelope(500, 'seat_limit_exceeded')),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-seat-$identityA')),
    );
    await settleUx(tester);

    await tester.tap(
      find.byKey(const ValueKey('cs-governance-seat-action-$identityA')),
    );
    await tester.pumpAndSettle();
    await settleUx(tester);

    expect(
      find.textContaining('席位额度已满'),
      findsOneWidget,
      reason: 'seat_limit_exceeded 可解释展示（含额度事实 2/2）',
    );
    expect(
      find.textContaining('席位额度已满：已用 2/2'),
      findsOneWidget,
      reason: '超额文案携带当前额度事实',
    );
  });

  testWidgets('停用坐席：确认 → POST suspend + 成功反馈 + 刷新', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [(200, _limitPayload(orgA))],
      'GET /cs/organizations/$orgA/seats': [
        (200, _seatsPayload(seats: [_seatRow(orgA, identityA)])),
        // suspend 后 _refresh 回显 enabled=false。
        (
          200,
          _seatsPayload(seats: [_seatRow(orgA, identityA, enabled: false)]),
        ),
      ],
      'POST /cs/organizations/$orgA/seats/$identityA/suspend': [
        (200, okEnvelope(payload: <String, dynamic>{})),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-seat-$identityA')),
    );
    await settleUx(tester);

    await tester.tap(
      find.byKey(const ValueKey('cs-governance-seat-action-$identityA')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cs-governance-suspend-confirm')),
    );
    await tester.pumpAndSettle();
    await settleUx(tester);

    expect(
      adapter.hits.where((h) => h.contains('/suspend')),
      isNotEmpty,
      reason: '停用动作真实发到租户治理端点',
    );
    expect(
      find.textContaining('已停用'),
      findsOneWidget,
      reason: '刷新后回显 enabled=false',
    );
  });

  testWidgets('切换 Organization：orgId 变化失效重建（新路径重拉 + 旧数据消失）', (tester) async {
    final adapter = _GovRouterAdapter({
      'GET /cs/organizations/$orgA/seat-limit': [
        (200, _limitPayload(orgA, seatLimit: 5, used: 1)),
      ],
      'GET /cs/organizations/$orgA/seats': [
        (200, _seatsPayload(seats: [_seatRow(orgA, identityA)])),
      ],
      'GET /cs/organizations/$orgB/seat-limit': [
        (200, _limitPayload(orgB, seatLimit: 'unlimited', used: 7)),
      ],
      'GET /cs/organizations/$orgB/seats': [
        (200, _seatsPayload(seats: [_seatRow(orgB, identityB)])),
      ],
    });
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(_host(orgA));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-seat-$identityA')),
    );
    await settleUx(tester);
    expect(find.text('1/5 席位'), findsOneWidget);

    // 同 runtimeType 重建（didUpdateWidget 路径）：orgId A → B。
    await tester.pumpWidget(_host(orgB));
    await pumpUntilUxFound(
      tester,
      find.byKey(const ValueKey('cs-governance-seat-$identityB')),
    );
    await settleUx(tester);

    expect(find.text('不限'), findsOneWidget, reason: '新 Org 额度事实');
    expect(
      find.byKey(const ValueKey('cs-governance-seat-$identityA')),
      findsNothing,
      reason: '旧 Org 坐席行不残留（失效重建）',
    );
    expect(
      adapter.hits.where((h) => h.contains(orgA)).length,
      2,
      reason: 'orgA 仅首轮 2 个请求（seat-limit + seats）',
    );
    expect(
      adapter.hits.where((h) => h.contains(orgB)),
      containsAllInOrder([
        'GET /cs/organizations/$orgB/seat-limit',
        'GET /cs/organizations/$orgB/seats',
      ]),
      reason: 'orgB 按新 org 作用域路径重拉',
    );
    for (final hit in adapter.hits) {
      expect(hit, isNot(contains('/api/adm')), reason: 'token 纪律：不打平台 Admin 面');
    }
  });
}
