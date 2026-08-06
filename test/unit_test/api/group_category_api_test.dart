// test/api/group_category_api_test.dart
//
// 群分组 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_category_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/group_category_api.dart（经 lib/config/const.dart 解出真实路径）。
// 只测只读 GET：group/category/list（payload.categories）。
// 写端点（create/rename/delete/sort/move_group）绝不真实调用。

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
  // 1. 分组列表 /api/v1/group/category/list (GET, 无参)
  // ──────────────────────────────────────────────
  group('群分组列表', () {
    test('1.1 获取群分组列表 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/group/category/list');
      ApiAssert.success(resp, context: 'group/category/list');
    });

    test('1.2 数据结构 — payload.categories 为 List（可空）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/group/category/list');
      if (resp['code'] != 0) return markTestSkipped('category/list 非成功');
      final payload = resp['payload'];
      // 客户端 GroupCategoryApi.getCategories 读 payload['categories']
      expect(payload, isA<Map>(), reason: 'payload 应为 Map，实际=$payload');
      final categories = (payload as Map)['categories'];
      expect(
        categories == null || categories is List,
        isTrue,
        reason: 'categories 应为 List 或 null，实际=$categories',
      );
    });

    test('1.3 数据结构 — 分组项含 id 与 name/category_name（若非空）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get('/api/v1/group/category/list');
      if (resp['code'] != 0) return markTestSkipped('category/list 非成功');
      final payload = resp['payload'];
      final categories = payload is Map ? payload['categories'] : null;
      if (categories is! List || categories.isEmpty) {
        return markTestSkipped('测试账号无群分组');
      }
      final first = categories.first as Map<String, dynamic>;
      expect(first.containsKey('id'), isTrue, reason: '分组项缺少 id: $first');
      expect(
        first.containsKey('name') || first.containsKey('category_name'),
        isTrue,
        reason: '分组项缺少 name/category_name: $first',
      );
    });
  });
}
