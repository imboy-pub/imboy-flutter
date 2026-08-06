// test/api/user_api_test.dart
//
// 用户/账号 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/user_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/user_api.dart。仅覆盖只读/幂等端点；
// change_password / apply_logout 等破坏性端点不在契约冒烟内（避免污染共享账号）。

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
  // 1. 用户设置 /api/v1/user/setting
  // ──────────────────────────────────────────────
  group('用户设置', () {
    test('1.1 获取用户设置 — 返回含 code 的 JSON', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/user/setting');
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 本人资料 /api/v1/user/show
  // ──────────────────────────────────────────────
  group('本人资料', () {
    test('2.1 查看本人资料 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user/show',
        queryParameters: {'id': client.currentUid},
      );
      ApiAssert.success(resp, context: 'user/show');
    });

    test('2.2 uid 一致性 — 返回 uid 与登录 uid 相同', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user/show',
        queryParameters: {'id': client.currentUid},
      );
      if (resp['code'] != 0) return markTestSkipped('user/show 非成功');
      final payload = resp['payload'] as Map<String, dynamic>;
      final idKey = [
        'uid',
        'id',
      ].firstWhere((k) => payload.containsKey(k), orElse: () => '');
      if (idKey.isEmpty) return markTestSkipped('无 uid 字段');
      expect(
        '${payload[idKey]}',
        equals(client.currentUid),
        reason: '本人资料 uid 应与登录 uid 一致',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 3. 最近注册用户 /api/v1/fts/recently_user
  // ──────────────────────────────────────────────
  group('最近注册用户', () {
    test('3.1 接口可达 — 含 code', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/fts/recently_user',
        queryParameters: {'page': 1, 'size': 10, 'keyword': ''},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 4. 未授权保护 — 无 token 应被拒绝
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('4.1 无 token 访问 user/setting — code≠0', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get('/api/v1/user/setting');
        // 未授权应返回非 0 业务码或 401，而非泄露数据
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的用户设置数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
