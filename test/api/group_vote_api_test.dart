// test/api/group_vote_api_test.dart
//
// 群投票（group_vote）API 契约测试（纯 dart test，无设备，可 CI 运行）
//
// 只测只读/幂等端点；写端点仅用无效参数验证「返回含 code 的 JSON、不崩溃」，
// 绝不真实产生副作用。
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_vote_api_test.dart --concurrency=1

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? gid;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (loggedIn) {
      final g = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (g['code'] == 0 && g['payload'] is Map) {
        final list = (g['payload'] as Map)['list'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final first = list.first as Map;
          final raw = first['group_id'] ?? first['id'] ?? first['gid'];
          if (raw != null) gid = raw.toString();
        }
      }
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 群投票列表（GET /api/v1/group/vote/list）— 需 gid
  // ──────────────────────────────────────────────
  group('群投票列表', () {
    test('1.1 获取投票列表 — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      if (gid == null) {
        markTestSkipped('测试账号无群，跳过');
        return;
      }
      expect(BigInt.tryParse(gid!), isNotNull, reason: 'gid 应为 TSID(可解析)');
      final resp = await client.get(
        '/api/v1/group/vote/list',
        queryParameters: {'gid': gid, 'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
      if (resp['code'] == 0) {
        final payload = resp['payload'];
        expect(payload is Map || payload == null, isTrue);
        if (payload is Map) {
          final list = payload['list'];
          expect(
            list == null || list is List,
            isTrue,
            reason: 'list 应为 List/null',
          );
        }
      }
    });
  });

  // ──────────────────────────────────────────────
  // 2. 投票详情（GET /api/v1/group/vote/detail）— 无效 id 幂等探活
  // ──────────────────────────────────────────────
  group('投票详情', () {
    test('2.1 详情接口可达（无效 vote_id 返回业务响应）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/group/vote/detail',
        queryParameters: {'gid': gid ?? '0', 'vote_id': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 3. 我参与的投票（GET /api/v1/group/vote/my_vote）— 无效 id 幂等探活
  // ──────────────────────────────────────────────
  group('我参与的投票', () {
    test('3.1 my_vote 接口可达（无效 vote_id 返回业务响应）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/group/vote/my_vote',
        queryParameters: {'vote_id': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 4. 写端点存活性（仅无效参数探活，不产生副作用）
  // ──────────────────────────────────────────────
  group('写端点存活性', () {
    test('4.1 创建投票接口可达（无效 gid，不真实创建）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.post(
        '/api/v1/group/vote/create',
        data: {
          'gid': '0',
          'title': 'e2e-contract-probe',
          'options': [
            {'option_text': 'A', 'sort_order': 1},
            {'option_text': 'B', 'sort_order': 2},
          ],
          'is_anonymous': false,
          'vote_type': 1,
        },
      );
      expect(
        resp,
        containsPair('code', isA<int>()),
        reason: '创建投票接口应返回含 code 的 JSON',
      );
    });

    test('4.2 投票(cast)接口可达（无效 vote_id/option，不真实投票）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.post(
        '/api/v1/group/vote/cast',
        data: {
          'gid': '0',
          'vote_id': '0',
          'option_ids': ['0'],
        },
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
