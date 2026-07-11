// test/api/feedback_api_test.dart
//
// 用户反馈 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/feedback_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/feedback_api.dart：
//   feedback/page、feedback/page_reply 为 GET（只读）。
//   feedback/add、feedback/remove、feedback/change 为写端点，不真实调用。

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
  // 1. 反馈列表 GET /api/v1/feedback/page
  // ──────────────────────────────────────────────
  group('反馈列表', () {
    test('1.1 分页拉取 — 返回含 code 的 JSON', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/feedback/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload 为分页信封（Map/List/null）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/feedback/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      if (resp['code'] != 0) return markTestSkipped('feedback/page 非成功');
      final payload = resp['payload'];
      expect(
        payload == null || payload is Map || payload is List,
        isTrue,
        reason: '反馈列表 payload 应为 Map/List/null',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 2. 反馈回复列表 GET /api/v1/feedback/page_reply
  // ──────────────────────────────────────────────
  group('反馈回复列表', () {
    test('2.1 传无效 feedback_id 不崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      // 无有效 feedback_id 时用 0，验证接口存活且响应结构化
      final resp = await client.get(
        '/api/v1/feedback/page_reply',
        queryParameters: {'feedback_id': 0, 'page': 1, 'size': 10},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 3. 未授权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('3.1 无 token 访问 feedback/page — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get(
          '/api/v1/feedback/page',
          queryParameters: {'page': 1, 'size': 10},
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的反馈数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
