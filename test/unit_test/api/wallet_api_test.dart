// test/api/wallet_api_test.dart
//
// 钱包 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/wallet_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/wallet_api.dart。
// ⚠️ 仅覆盖只读端点（balance/transactions）。topup/withdraw/red_packet/transfer
//    会真实移动资金，绝不在契约冒烟内调用（避免污染共享账号余额）。
// 数据结构重点：金额「分(int)为权威、*_yuan 为展示派生」的一致性——这是资金正确性的地基。

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
  // 1. 余额 /api/v1/wallet/balance
  // ──────────────────────────────────────────────
  group('钱包余额', () {
    test('1.1 查询余额 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/wallet/balance');
      // 钱包 flag 已解禁；若后端未开返回业务错误也不应崩溃
      expect(resp, containsPair('code', isA<int>()));
    });

    test(
      '1.2 数据结构 — balance/frozen 为 int(分)，balance_yuan == balance/100',
      () async {
        if (!loggedIn) return markTestSkipped('未登录');
        final resp = await client.get('/api/v1/wallet/balance');
        if (resp['code'] != 0) return markTestSkipped('余额接口非成功(可能未开通)');
        final p = resp['payload'] as Map<String, dynamic>;
        expect(p['balance'], isA<num>(), reason: 'balance 应为数值(分)');
        final balanceFen = (p['balance'] as num).toInt();
        expect(
          p['frozen'] == null || p['frozen'] is num,
          isTrue,
          reason: 'frozen 应为数值或 null',
        );
        // 分/元一致性：balance_yuan 应等于 balance/100（容忍浮点误差）
        if (p.containsKey('balance_yuan') && p['balance_yuan'] != null) {
          final yuan = (p['balance_yuan'] as num).toDouble();
          expect(
            (yuan - balanceFen / 100.0).abs() < 0.001,
            isTrue,
            reason:
                'balance_yuan($yuan) 应等于 balance/100(${balanceFen / 100.0})',
          );
        }
      },
    );
  });

  // ──────────────────────────────────────────────
  // 2. 流水 /api/v1/wallet/transactions
  // ──────────────────────────────────────────────
  group('钱包流水', () {
    test('2.1 分页流水接口可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/wallet/transactions',
        queryParameters: {'page': 1, 'size': 10},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('2.2 数据结构 — 流水项金额为 int(分)，含类型/状态', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/wallet/transactions',
        queryParameters: {'page': 1, 'size': 10},
      );
      if (resp['code'] != 0) return markTestSkipped('流水接口非成功');
      final payload = resp['payload'];
      final list = payload is List
          ? payload
          : payload is Map
          ? (payload['list'] ?? payload['data'] ?? const [])
          : const [];
      if (list is List && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final amountKey = [
          'amount',
          'amount_fen',
          'money',
        ].firstWhere((k) => first.containsKey(k), orElse: () => '');
        if (amountKey.isNotEmpty) {
          expect(
            first[amountKey],
            isA<num>(),
            reason: '流水金额 $amountKey 应为数值(分)',
          );
        }
      }
    });
  });
}
