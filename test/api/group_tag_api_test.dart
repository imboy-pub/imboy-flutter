// test/api/group_tag_api_test.dart
//
// 群标签 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_tag_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/group_tag_api.dart + lib/config/const.dart。
// 只测 GET 只读端点：group/tag/list（需 gid，自举）、group/tag/hot。
// 写端点（tag add/remove、search）绝不真实调用。
// gid 从 group/page(attr=join) 自举；无群 markTestSkipped（不假绿）。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

/// 从 group/page 的 payload 中尽力取出一个 gid（兼容 List / {list:[]} / {data:[]}）。
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
  // 1. 热门标签 /api/v1/group/tag/hot (GET, 无需 gid)
  // ──────────────────────────────────────────────
  group('热门标签', () {
    test('1.1 获取热门标签 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/tag/hot',
        queryParameters: {'limit': 20},
      );
      ApiAssert.success(resp, context: 'group/tag/hot');
    });

    test('1.2 数据结构 — payload.list 为 List 或 payload 可枚举', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/tag/hot',
        queryParameters: {'limit': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('group/tag/hot 非成功');
      final payload = resp['payload'];
      final list = payload is Map
          ? (payload['list'] ?? payload['data'])
          : payload;
      expect(
        list == null || list is List,
        isTrue,
        reason: 'hot 标签 list 应为 List 或 null: $payload',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 2. 群标签列表 /api/v1/group/tag/list (GET, gid)
  // ──────────────────────────────────────────────
  group('群标签列表', () {
    test('2.1 获取群标签列表 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/tag/list',
        queryParameters: {'gid': sampleGid},
      );
      ApiAssert.success(resp, context: 'group/tag/list');
    });

    test('2.2 数据结构 — payload.list 为 List 或 null', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/tag/list',
        queryParameters: {'gid': sampleGid},
      );
      if (resp['code'] != 0) return markTestSkipped('group/tag/list 非成功');
      final payload = resp['payload'];
      final list = payload is Map
          ? (payload['list'] ?? payload['data'])
          : payload;
      expect(
        list == null || list is List,
        isTrue,
        reason: '标签 list 应为 List 或 null: $payload',
      );
    });

    test('2.3 无效 gid — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/tag/list',
        queryParameters: {'gid': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
