// test/api/moment_api_test.dart
//
// 朋友圈 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/moment_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/moment_api.dart。
// 仅覆盖只读端点（moments/feed、moment/:id）。create/like/comment/delete 等写端点不在契约冒烟内。
// 数据结构重点：游标分页信封（list/next_cursor/has_more）+ 动态项 TSID。

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
  // 1. 朋友圈信息流 /api/v1/moments/feed
  // ──────────────────────────────────────────────
  group('朋友圈信息流', () {
    test('1.1 拉取 feed — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/moments/feed',
        queryParameters: {'limit': 10},
      );
      ApiAssert.success(resp, context: 'moments/feed');
    });

    test('1.2 数据结构 — 游标分页信封含 list，has_more 为 bool', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/moments/feed',
        queryParameters: {'limit': 10},
      );
      if (resp['code'] != 0) return markTestSkipped('feed 非成功');
      final payload = resp['payload'];
      expect(payload, isA<Map>(), reason: 'feed payload 应为 Map(游标分页信封)');
      final map = payload as Map;
      expect(map.containsKey('list'), isTrue, reason: 'feed 应含 list 字段');
      expect(map['list'] is List, isTrue, reason: 'feed.list 应为 List');
      if (map.containsKey('has_more')) {
        expect(map['has_more'], isA<bool>(), reason: 'has_more 应为 bool');
      }
    });

    test('1.3 动态项 — 含可解析 moment id', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/moments/feed',
        queryParameters: {'limit': 10},
      );
      if (resp['code'] != 0) return markTestSkipped('feed 非成功');
      final list = (resp['payload'] as Map)['list'];
      if (list is! List || list.isEmpty) {
        return markTestSkipped('测试账号朋友圈为空');
      }
      final first = list.first as Map<String, dynamic>;
      final idKey = [
        'id',
        'moment_id',
        'feed_id',
      ].firstWhere((k) => first.containsKey(k), orElse: () => '');
      expect(idKey.isNotEmpty, isTrue, reason: '动态项缺少 id: $first');
      expect('${first[idKey]}'.isNotEmpty, isTrue, reason: '动态 id 应非空');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 动态详情 /api/v1/moment/:id
  // ──────────────────────────────────────────────
  group('动态详情', () {
    test('2.1 无效 id — 返回业务错误而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/moment/0');
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
