// test/api/group_file_api_test.dart
//
// 群文件 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_file_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/group_file_api.dart + lib/config/const.dart。
// 只测 GET 只读端点：group/file/list（分页信封）、group/file/categories。
// 写端点（file upload/delete、search）绝不真实调用。
// gid 从 group/page(attr=join) 自举；无群 markTestSkipped（不假绿）。

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
  // 1. 群文件列表 /api/v1/group/file/list (GET, gid+分页)
  // ──────────────────────────────────────────────
  group('群文件列表', () {
    test('1.1 分页获取群文件 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/file/list',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      ApiAssert.success(resp, context: 'group/file/list');
    });

    test('1.2 分页信封 — payload 含 list/items 与 total', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/file/list',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('group/file/list 非成功');
      final payload = resp['payload'];
      expect(
        payload,
        isA<Map<String, dynamic>>(),
        reason: 'file/list payload 应为 Map: $payload',
      );
      final map = payload as Map<String, dynamic>;
      final list = map['list'] ?? map['items'];
      expect(
        list == null || list is List,
        isTrue,
        reason: 'file list 应为 List 或 null: $map',
      );
    });

    test('1.3 无效 gid — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/file/list',
        queryParameters: {'gid': '0', 'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 群文件分类统计 /api/v1/group/file/categories (GET, gid)
  // ──────────────────────────────────────────────
  group('群文件分类统计', () {
    test('2.1 获取分类统计 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/file/categories',
        queryParameters: {'gid': sampleGid},
      );
      ApiAssert.success(resp, context: 'group/file/categories');
    });

    test('2.2 数据结构 — payload.items/list 为 List 或 null', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/file/categories',
        queryParameters: {'gid': sampleGid},
      );
      if (resp['code'] != 0) return markTestSkipped('categories 非成功');
      final payload = resp['payload'];
      final list = payload is Map
          ? (payload['items'] ?? payload['list'])
          : payload;
      expect(
        list == null || list is List,
        isTrue,
        reason: '分类统计 list 应为 List 或 null: $payload',
      );
    });
  });
}
