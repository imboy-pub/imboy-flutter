// test/api/channel_order_api_test.dart
//
// 付费频道订单 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/channel_order_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/channel_order_api.dart：
//   channel/orders/my（GET 我的订单）、channel/order/{orderNo}（GET 详情）为只读。
//   create_order / order/pay / order/refund 为写/金钱端点，绝不真实调用。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

void main() {
  late ApiTestClient client;
  bool loggedIn = false;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 我的订单 GET /api/v1/channel/orders/my
  // ──────────────────────────────────────────────
  group('我的订单列表', () {
    test('1.1 分页拉取 — 返回含 code 的 JSON', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/channel/orders/my',
        queryParameters: {'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload 为分页信封（Map/List/null）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/channel/orders/my',
        queryParameters: {'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('orders/my 非成功');
      final payload = resp['payload'];
      expect(
        payload == null || payload is Map || payload is List,
        isTrue,
        reason: '订单列表 payload 应为 Map/List/null',
      );
    });

    test('1.3 订单项金额与 order_no 结构可解析（若有数据）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/channel/orders/my',
        queryParameters: {'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('orders/my 非成功');
      final order = _firstOrder(resp['payload']);
      if (order == null) return markTestSkipped('无订单数据');
      if (order.containsKey('amount')) {
        // 契约提示：ChannelOrderModel.amount 解析为 double，非 int(分)
        expect(order['amount'], isA<num>(), reason: '订单金额应为数值');
      }
      if (order.containsKey('order_no')) {
        expect(
          '${order['order_no']}'.isNotEmpty,
          isTrue,
          reason: 'order_no 不应为空',
        );
      }
    });
  });

  // ──────────────────────────────────────────────
  // 2. 订单详情 GET /api/v1/channel/order/{orderNo}
  // ──────────────────────────────────────────────
  group('订单详情', () {
    test('2.1 用真实 orderNo 查询（无则跳过），否则验无效 orderNo 不崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final listResp = await client.get(
        '/api/v1/channel/orders/my',
        queryParameters: {'page': 1, 'size': 20},
      );
      final order = listResp['code'] == 0
          ? _firstOrder(listResp['payload'])
          : null;
      final orderNo = order?['order_no']?.toString();
      if (orderNo == null || orderNo.isEmpty) {
        // 无真实 orderNo：用无效值仅验证接口存活、返回结构化 JSON
        final resp = await client.get('/api/v1/channel/order/0');
        expect(resp, containsPair('code', isA<int>()));
        markTestSkipped('无真实 orderNo，仅验证接口存活');
        return;
      }
      final resp = await client.get('/api/v1/channel/order/$orderNo');
      ApiAssert.success(resp, context: '订单详情');
    });
  });

  // ──────────────────────────────────────────────
  // 3. 未授权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('3.1 无 token 访问 orders/my — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get(
          '/api/v1/channel/orders/my',
          queryParameters: {'page': 1, 'size': 20},
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的订单数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}

/// 从分页信封中取第一条订单 Map；兼容 payload 为 List 或含 list/items/data 的 Map。
Map<String, dynamic>? _firstOrder(dynamic payload) {
  List<dynamic>? list;
  if (payload is List) {
    list = payload;
  } else if (payload is Map) {
    for (final k in ['list', 'items', 'data', 'rows']) {
      if (payload[k] is List) {
        list = payload[k] as List;
        break;
      }
    }
  }
  if (list == null || list.isEmpty) return null;
  final first = list.first;
  return first is Map ? Map<String, dynamic>.from(first) : null;
}
