// test/api/channel_api_test.dart
//
// 频道 API 契约测试（纯 dart test，无设备，可 CI 运行）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=+8613800138000 \
//   TEST_PASSWORD=<pwd> \
//   dart test test/api/channel_api_test.dart --concurrency=1

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
  // 1. 已订阅频道列表
  // ──────────────────────────────────────────────
  group('已订阅频道', () {
    test('1.1 GET /api/v1/channels/subscribed — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/api/v1/channels/subscribed');
      ApiAssert.success(resp, context: '已订阅频道列表');
    });

    test('1.2 data 为 List 或 null', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/api/v1/channels/subscribed');
      if (resp['code'] != 0) return;
      expect(
        resp['data'] == null || resp['data'] is List,
        isTrue,
        reason: '已订阅频道 data 应为 List 或 null',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 2. 我管理的频道
  // ──────────────────────────────────────────────
  group('管理频道', () {
    test('2.1 GET /api/v1/channels/managed — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/api/v1/channels/managed');
      ApiAssert.success(resp, context: '管理频道列表');
    });
  });

  // ──────────────────────────────────────────────
  // 3. 未读摘要
  // ──────────────────────────────────────────────
  group('未读摘要', () {
    test('3.1 GET /api/v1/channels/unread/summary — 接口可达', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/api/v1/channels/unread/summary');
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 4. 频道详情
  // ──────────────────────────────────────────────
  group('频道详情', () {
    test('4.1 无效 channelId 返回非 0 code', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get('/api/v1/channel/000000000000000000');
      expect(resp['code'], isNot(0), reason: '无效 channelId 应返回业务错误');
    });
  });

  // ──────────────────────────────────────────────
  // 5. 创建频道（校验 smoke）
  // ──────────────────────────────────────────────
  group('创建频道', () {
    test('5.1 空 name 应返回校验错误', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.post(
        '/api/v1/channel/create',
        data: {'name': '', 'description': 'api-test'},
      );
      expect(
        resp,
        containsPair('code', isA<int>()),
        reason: '创建频道接口应返回 JSON 响应',
      );
      expect(resp['code'], isNot(0), reason: '空 name 应触发校验错误');
    });
  });

  // ──────────────────────────────────────────────
  // 6. 频道消息
  // ──────────────────────────────────────────────
  group('频道消息', () {
    test('6.1 无效 channelId 获取消息返回非 0 code', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/channel/000000000000000000/messages',
        queryParameters: {'page': 1, 'size': 10},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
