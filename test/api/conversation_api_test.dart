// test/api/conversation_api_test.dart
//
// IM 核心链路 API 契约测试（纯 dart test，无设备，可 CI 运行）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=+8613800138000 \
//   TEST_PASSWORD=<pwd> \
//   dart test test/api/conversation_api_test.dart --concurrency=1

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
  // 1. 会话列表
  // ──────────────────────────────────────────────
  group('会话列表', () {
    test('1.1 获取会话列表 — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/conversation/mine');
      ApiAssert.success(resp, context: '会话列表');
    });

    test('1.2 置顶会话接口可达', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/conversation/pinned');
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 离线消息
  // ──────────────────────────────────────────────
  group('离线消息', () {
    test('2.1 拉取离线消息 — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/msg/offline');
      ApiAssert.success(resp, context: '离线消息');
    });

    test('2.2 离线消息 data 为 List 或 null', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/msg/offline');
      if (resp['code'] != 0) return;
      expect(
        resp['data'] == null || resp['data'] is List,
        isTrue,
        reason: '离线消息 data 应为 List 或 null',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 3. 好友列表
  // ──────────────────────────────────────────────
  group('好友列表', () {
    test('3.1 获取好友列表 — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/friend/list');
      ApiAssert.success(resp, context: '好友列表');
    });
  });

  // ──────────────────────────────────────────────
  // 4. 群组列表
  // ──────────────────────────────────────────────
  group('群组列表', () {
    test('4.1 分页获取群组列表', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.post(
        '/v1/group/page',
        data: {'page': 1, 'size': 10},
      );
      expect(resp, containsPair('code', isA<int>()));
      if (resp['code'] == 0) {
        expect(
          resp['data'] == null || resp['data'] is List || resp['data'] is Map,
          isTrue,
          reason: '群组列表 data 应为 List/Map/null',
        );
      }
    });
  });

  // ──────────────────────────────────────────────
  // 5. 全文搜索
  // ──────────────────────────────────────────────
  group('全文搜索', () {
    test('5.1 最近联系人接口可达', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/fts/recently_user');
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 6. 用户设置
  // ──────────────────────────────────────────────
  group('用户设置', () {
    test('6.1 获取用户设置接口可达', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/v1/user/setting');
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 7. 消息发送存活性
  // ──────────────────────────────────────────────
  group('消息发送 API', () {
    test('7.1 C2C 发送接口可达（无效接收方返回业务错误，不崩溃）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      // 用无效 to_uid 触发业务错误，验证接口存在且响应格式正确
      final resp = await client.post(
        '/v1/msg/c2c/send',
        data: {
          'to_uid': '0',
          'msg_type': 'text',
          'content': '{"body":"e2e-api-test"}',
        },
      );
      expect(
        resp,
        containsPair('code', isA<int>()),
        reason: 'C2C 发送接口应返回包含 code 的 JSON 响应',
      );
    });
  });
}
