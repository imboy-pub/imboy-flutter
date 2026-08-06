// test/api/user_device_api_test.dart
//
// 用户设备 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/user_device_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/user_device_api.dart + lib/config/const.dart。
// ⚠️ 仅覆盖只读 GET 端点（page / sessions）。
//   写/危险端点绝不真实调用：change_name / delete / check_login /
//   kick / kick-others（force_offline 会把当前设备踢下线）。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

/// TSID 字段合理性：JSON integer 传输，值应可无损转 string 且非空。
void expectTsid(dynamic v, {required String field}) {
  expect(v, isNotNull, reason: '$field 不应为 null');
  final s = '$v';
  expect(s.isNotEmpty, isTrue, reason: '$field 应可转非空 string');
  expect(
    BigInt.tryParse(s) != null || v is String,
    isTrue,
    reason: '$field 应为可解析的 TSID，实际=$v (${v.runtimeType})',
  );
}

List _extractList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    final l = payload['list'] ?? payload['data'] ?? payload['rows'];
    if (l is List) return l;
  }
  return const [];
}

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
  // 1. 设备分页 /api/v1/user_device/page
  // ──────────────────────────────────────────────
  group('设备分页', () {
    test('1.1 分页可达 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user_device/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      ApiAssert.success(resp, context: 'user_device/page');
    });

    test('1.2 数据结构 — 设备项含可解析 device_id(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user_device/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      if (resp['code'] != 0) return markTestSkipped('user_device/page 非成功');
      final list = _extractList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('设备列表为空');
      final first = list.first as Map<String, dynamic>;
      final idKey = [
        'device_id',
        'deviceId',
        'did',
        'id',
      ].firstWhere((k) => first.containsKey(k), orElse: () => '');
      expect(idKey.isNotEmpty, isTrue, reason: '设备项缺少 device_id 字段: $first');
      expectTsid(first[idKey], field: '设备.$idKey');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 活跃会话 /api/v1/user_device/sessions
  // ──────────────────────────────────────────────
  group('活跃会话', () {
    test('2.1 sessions 可达 — 含 code', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/user_device/sessions');
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 3. 鉴权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('3.1 无 token 访问 user_device/page — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get(
          '/api/v1/user_device/page',
          queryParameters: {'page': 1, 'size': 10},
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的设备数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
