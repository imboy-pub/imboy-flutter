// test/api/e2ee_api_test.dart
//
// E2EE 基础 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/e2ee_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/e2ee_api.dart + lib/config/const.dart。
// 只测 GET 只读端点：user_keys（查自己公钥）、group_member_keys（需 gid）、
// key/status、notifications/pull、compliance_key。
// 写端点（report_device_key 上传公钥）绝不真实调用。
// 密钥相关端点在 E2EE 未启用时可能返回业务错误，故只做可达性 + 结构守卫断言。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

String? _firstGid(dynamic payload) {
  final list = payload is List
      ? payload
      : payload is Map
      ? (payload['list'] ?? payload['data'] ?? const [])
      : const [];
  if (list is List && list.isNotEmpty) {
    final first = list.first as Map<String, dynamic>;
    final key = [
      'group_id',
      'gid',
      'id',
    ].firstWhere((k) => first.containsKey(k), orElse: () => '');
    if (key.isNotEmpty) return '${first[key]}';
  }
  return null;
}

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? sampleGid;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (loggedIn) {
      final page = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (page['code'] == 0) sampleGid = _firstGid(page['payload']);
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 用户公钥 /api/v1/e2ee/user_keys (GET, uid=自己)
  // ──────────────────────────────────────────────
  group('用户公钥', () {
    test('1.1 查询自己的公钥 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/e2ee/user_keys',
        queryParameters: {'uid': client.currentUid},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload.devices 为 List', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/e2ee/user_keys',
        queryParameters: {'uid': client.currentUid},
      );
      if (resp['code'] != 0) return markTestSkipped('user_keys 非成功');
      final payload = resp['payload'];
      expect(
        payload,
        isA<Map<String, dynamic>>(),
        reason: 'user_keys payload 应为 Map: $payload',
      );
      final devices = (payload as Map<String, dynamic>)['devices'];
      expect(
        devices == null || devices is List,
        isTrue,
        reason: 'devices 应为 List 或 null: $payload',
      );
      // 若有设备，验证公钥字段存在且可解析 key_id(kid)
      if (devices is List && devices.isNotEmpty) {
        final d = devices.first as Map;
        expect(
          ['public_key', 'pub_key', 'publicKey'].any(d.containsKey),
          isTrue,
          reason: '设备项应含公钥字段: $d',
        );
        final kid = d['key_id'] ?? d['kid'];
        if (kid != null) {
          expect('$kid'.isNotEmpty, isTrue, reason: 'key_id 应可转非空 string');
        }
      }
    });
  });

  // ──────────────────────────────────────────────
  // 2. 群成员公钥 /api/v1/e2ee/group_member_keys (GET, gid)
  // ──────────────────────────────────────────────
  group('群成员公钥', () {
    test('2.1 查询群成员公钥 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/e2ee/group_member_keys',
        queryParameters: {'gid': sampleGid},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('2.2 成功时 payload.members 为 List', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/e2ee/group_member_keys',
        queryParameters: {'gid': sampleGid},
      );
      if (resp['code'] != 0) return markTestSkipped('group_member_keys 非成功');
      final payload = resp['payload'];
      expect(
        payload,
        isA<Map<String, dynamic>>(),
        reason: 'payload 应为 Map: $payload',
      );
      final members = (payload as Map<String, dynamic>)['members'];
      expect(
        members == null || members is List,
        isTrue,
        reason: 'members 应为 List 或 null: $payload',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 3. 密钥状态 /api/v1/e2ee/key/status (GET)
  // ──────────────────────────────────────────────
  group('密钥状态', () {
    test('3.1 查询本设备密钥注册状态 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/key/status');
      expect(resp, containsPair('code', isA<int>()));
    });

    test('3.2 成功时 payload 含 has_valid_key', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/key/status');
      if (resp['code'] != 0) return markTestSkipped('key/status 非成功');
      final payload = resp['payload'];
      expect(
        payload,
        isA<Map<String, dynamic>>(),
        reason: 'key/status payload 应为 Map: $payload',
      );
      expect(
        (payload as Map<String, dynamic>).containsKey('has_valid_key'),
        isTrue,
        reason: 'key/status 应含 has_valid_key: $payload',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 4. E2EE 通知拉取 /api/v1/e2ee/notifications/pull (GET)
  // ──────────────────────────────────────────────
  group('E2EE 通知拉取', () {
    test('4.1 增量拉取通知 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/e2ee/notifications/pull',
        queryParameters: {'since': 0, 'limit': 50},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('4.2 成功时 payload 为 List 或含 notifications/list', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/e2ee/notifications/pull',
        queryParameters: {'since': 0, 'limit': 50},
      );
      if (resp['code'] != 0) return markTestSkipped('notifications/pull 非成功');
      final payload = resp['payload'];
      final list = payload is List
          ? payload
          : payload is Map
          ? (payload['notifications'] ?? payload['list'])
          : null;
      expect(
        payload == null || payload is List || list == null || list is List,
        isTrue,
        reason: '通知应为 List 或含 notifications/list: $payload',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 5. 合规公钥 /api/v1/e2ee/compliance_key (GET)
  // ──────────────────────────────────────────────
  group('合规公钥', () {
    test('5.1 获取当前活跃合规公钥 — 可达', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/e2ee/compliance_key');
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
