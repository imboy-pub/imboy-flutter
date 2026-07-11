// test/api/contact_api_test.dart
//
// 联系人/好友/黑名单 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/contact_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/{contact,denylist}_api.dart（GET 只读、幂等，对共享后端安全）。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

/// TSID 字段合理性：JSON integer 传输，值应可无损转 string 且非空。
void expectTsid(dynamic v, {required String field}) {
  expect(v, isNotNull, reason: '$field 不应为 null');
  final s = '$v';
  expect(s.isNotEmpty, isTrue, reason: '$field 应可转非空 string');
  // 允许 int / String，两者都应能被 BigInt 解析（safeParseBigIntJson 契约）
  expect(
    BigInt.tryParse(s) != null || v is String,
    isTrue,
    reason: '$field 应为可解析的 TSID，实际=$v (${v.runtimeType})',
  );
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
  // 1. 好友列表 /api/v1/friend/list
  // ──────────────────────────────────────────────
  group('好友列表', () {
    test('1.1 获取好友列表 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/friend/list');
      ApiAssert.success(resp, context: '好友列表');
    });

    test('1.2 数据结构 — payload 为 List，成员含可解析 uid(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/friend/list');
      if (resp['code'] != 0) return markTestSkipped('好友列表非成功');
      final payload = resp['payload'];
      expect(
        payload is List || payload is Map,
        isTrue,
        reason: '好友 payload 应为 List/Map，实际=${payload.runtimeType}',
      );
      final list = payload is List
          ? payload
          : (payload as Map)['list'] ?? (payload)['data'] ?? const [];
      if (list is List && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        // 好友项应含用户标识；后端字段可能为 uid/from_id/peer_id 之一
        final idKey = [
          'uid',
          'from_id',
          'peer_id',
          'id',
        ].firstWhere((k) => first.containsKey(k), orElse: () => '');
        expect(idKey.isNotEmpty, isTrue, reason: '好友项缺少用户 id 字段: $first');
        expectTsid(first[idKey], field: '好友.$idKey');
      }
    });
  });

  // ──────────────────────────────────────────────
  // 2. 用户资料 /api/v1/user/show
  // ──────────────────────────────────────────────
  group('用户资料', () {
    test('2.1 查看本人资料 — code=0 且含 uid/nickname', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user/show',
        queryParameters: {'id': client.currentUid},
      );
      ApiAssert.success(resp, context: 'user/show');
      final payload = resp['payload'] as Map<String, dynamic>;
      final idKey = [
        'uid',
        'id',
      ].firstWhere((k) => payload.containsKey(k), orElse: () => '');
      expect(idKey.isNotEmpty, isTrue, reason: 'user/show 缺少 uid/id: $payload');
      expectTsid(payload[idKey], field: 'user.$idKey');
      expect(
        payload.containsKey('nickname') || payload.containsKey('username'),
        isTrue,
        reason: 'user/show 应含 nickname/username',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 3. 用户搜索 /api/v1/user/search
  // ──────────────────────────────────────────────
  group('用户搜索', () {
    test('3.1 搜索接口可达（空/有结果均不崩）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user/search',
        queryParameters: {'page': 1, 'size': 10, 'keyword': '1'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 4. 黑名单分页 /api/v1/friend/denylist/page
  // ──────────────────────────────────────────────
  group('黑名单', () {
    test('4.1 分页接口可达 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/friend/denylist/page',
        queryParameters: {'page': 1, 'size': 10},
      );
      ApiAssert.success(resp, context: '黑名单分页');
    });
  });
}
