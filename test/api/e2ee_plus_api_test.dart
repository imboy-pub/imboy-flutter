// test/api/e2ee_plus_api_test.dart
//
// E2EE+ API 契约测试（设备间传输 / 社交恢复）（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/e2ee_plus_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/e2ee_plus_api.dart + lib/config/const.dart。
// 只测 GET 只读端点：transfer/pending、transfer/info（无效 session 验不崩溃）、
// social/contacts、social/shards、social/proxy_shards。
// 写端点（transfer create/accept/confirm、contacts add/remove、
// create_shards、recover、decrypt_shard 密钥分片操作）绝不真实调用。

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
  // 1. 待处理传输 /api/v1/e2ee/transfer/pending (GET)
  // ──────────────────────────────────────────────
  group('设备间传输', () {
    test('1.1 获取待处理传输列表 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/transfer/pending');
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload.transfers 为 List', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/transfer/pending');
      if (resp['code'] != 0) return markTestSkipped('transfer/pending 非成功');
      final payload = resp['payload'];
      final transfers = payload is Map ? payload['transfers'] : payload;
      expect(
        transfers == null || transfers is List,
        isTrue,
        reason: 'transfers 应为 List 或 null: $payload',
      );
    });

    test('1.3 无效 session_id 查询 — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/e2ee/transfer/info',
        queryParameters: {'session_id': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 可信联系人 /api/v1/e2ee/social/contacts (GET)
  // ──────────────────────────────────────────────
  group('社交恢复 - 可信联系人', () {
    test('2.1 列出可信联系人 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/social/contacts');
      expect(resp, containsPair('code', isA<int>()));
    });

    test('2.2 成功时 payload.contacts 为 List', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/social/contacts');
      if (resp['code'] != 0) return markTestSkipped('social/contacts 非成功');
      final payload = resp['payload'];
      final contacts = payload is Map ? payload['contacts'] : payload;
      expect(
        contacts == null || contacts is List,
        isTrue,
        reason: 'contacts 应为 List 或 null: $payload',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 3. 密钥分片（只读查询）
  //    /api/v1/e2ee/social/shards、/proxy_shards (GET)
  // ──────────────────────────────────────────────
  group('社交恢复 - 分片查询', () {
    test('3.1 获取用户分片 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/e2ee/social/shards',
        queryParameters: {'key_version': 'latest'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('3.2 获取代理分片 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/social/proxy_shards');
      expect(resp, containsPair('code', isA<int>()));
    });

    test('3.3 成功时 shards 为 List', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/social/proxy_shards');
      if (resp['code'] != 0) return markTestSkipped('proxy_shards 非成功');
      final payload = resp['payload'];
      final shards = payload is Map ? payload['shards'] : payload;
      expect(
        shards == null || shards is List,
        isTrue,
        reason: 'shards 应为 List 或 null: $payload',
      );
    });
  });
}
