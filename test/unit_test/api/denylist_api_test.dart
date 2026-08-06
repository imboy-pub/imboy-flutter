// test/api/denylist_api_test.dart
//
// 黑名单 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/denylist_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/denylist_api.dart + lib/config/const.dart。
// 仅覆盖只读 GET 端点（page）；add / remove 等写端点不真实调用。

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
  // 1. 黑名单分页 /api/v1/friend/denylist/page
  // ──────────────────────────────────────────────
  group('黑名单分页', () {
    test('1.1 分页可达 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/friend/denylist/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      ApiAssert.success(resp, context: 'denylist/page');
    });

    test('1.2 数据结构 — 黑名单项含可解析 uid(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/friend/denylist/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      if (resp['code'] != 0) return markTestSkipped('denylist/page 非成功');
      final list = _extractList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('黑名单为空');
      final first = list.first as Map<String, dynamic>;
      final idKey = [
        'uid',
        'denied_user_id',
        'denied_uid',
        'user_id',
        'id',
      ].firstWhere((k) => first.containsKey(k), orElse: () => '');
      expect(idKey.isNotEmpty, isTrue, reason: '黑名单项缺少 uid 字段: $first');
      expectTsid(first[idKey], field: '黑名单.$idKey');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 鉴权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('2.1 无 token 访问 denylist/page — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get(
          '/api/v1/friend/denylist/page',
          queryParameters: {'page': 1, 'size': 10},
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的黑名单数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
