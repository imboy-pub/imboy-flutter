// test/api/mention_api_test.dart
//
// @提及 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/mention_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/mention_api.dart + lib/config/const.dart：
//   mention/list、mention/unread、mention/suggest 均为 POST（非 GET）。
// 仅覆盖只读端点；mark_read 为写端点，不真实调用。

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
  // 1. @提及列表 POST /api/v1/mention/list
  // ──────────────────────────────────────────────
  group('@提及列表', () {
    test('1.1 分页拉取 — 返回含 code 的 JSON', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.post(
        '/api/v1/mention/list',
        data: {'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload 为分页信封（Map/List/null）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.post(
        '/api/v1/mention/list',
        data: {'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('mention/list 非成功');
      final payload = resp['payload'];
      expect(
        payload == null || payload is Map || payload is List,
        isTrue,
        reason: '@提及列表 payload 应为 Map/List/null',
      );
    });

    test('1.3 传无效 group_id 不崩溃（仍返回结构化 JSON）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.post(
        '/api/v1/mention/list',
        data: {'page': 1, 'size': 20, 'group_id': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 未读 @提及数量 POST /api/v1/mention/unread
  // ──────────────────────────────────────────────
  group('未读@提及数量', () {
    test('2.1 接口可达 — 含 code', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.post('/api/v1/mention/unread', data: {});
      expect(resp, containsPair('code', isA<int>()));
    });

    test('2.2 成功时 count 为整数（若存在）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.post('/api/v1/mention/unread', data: {});
      if (resp['code'] != 0) return markTestSkipped('mention/unread 非成功');
      final payload = resp['payload'];
      if (payload is Map && payload.containsKey('count')) {
        expect(payload['count'], isA<int>(), reason: '未读数 count 应为整数');
      }
    });
  });

  // ──────────────────────────────────────────────
  // 3. 未授权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('3.1 无 token 访问 mention/list — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.post(
          '/api/v1/mention/list',
          data: {'page': 1, 'size': 20},
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的 @提及数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
