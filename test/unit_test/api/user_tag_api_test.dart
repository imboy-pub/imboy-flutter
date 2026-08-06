// test/api/user_tag_api_test.dart
//
// 用户标签 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/user_tag_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/user_tag_api.dart + lib/config/const.dart。
// 仅覆盖只读 GET 端点（page / relation friend_page）；
// add / delete / change_name / relation add|set|remove 等写端点不真实调用。

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

/// 分页信封取 list：payload 可能为 List 或 {list:[...]} / {data:[...]}
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
  // 1. 标签分页 /api/v1/user_tag/page
  // ──────────────────────────────────────────────
  group('标签分页', () {
    test('1.1 friend 场景分页 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user_tag/page',
        queryParameters: {'page': 1, 'size': 10, 'scene': 'friend', 'kwd': ''},
      );
      ApiAssert.success(resp, context: 'user_tag/page');
    });

    test('1.2 数据结构 — 标签项含可解析 tag_id(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/user_tag/page',
        queryParameters: {'page': 1, 'size': 10, 'scene': 'friend', 'kwd': ''},
      );
      if (resp['code'] != 0) return markTestSkipped('user_tag/page 非成功');
      final list = _extractList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('标签列表为空');
      final first = list.first as Map<String, dynamic>;
      final idKey = [
        'tag_id',
        'tagId',
        'id',
      ].firstWhere((k) => first.containsKey(k), orElse: () => '');
      expect(idKey.isNotEmpty, isTrue, reason: '标签项缺少 tag_id 字段: $first');
      expectTsid(first[idKey], field: '标签.$idKey');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 标签关系分页 /api/v1/user_tag_relation/friend_page
  // ──────────────────────────────────────────────
  group('标签关系分页', () {
    test('2.1 friend_page 可达（需真实 tag_id 时诚实 skip）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      // 从标签列表取一个真实 tag_id，避免瞎猜导致契约结论失真
      final tagResp = await client.get(
        '/api/v1/user_tag/page',
        queryParameters: {'page': 1, 'size': 10, 'scene': 'friend', 'kwd': ''},
      );
      final list = _extractList(tagResp['payload']);
      if (list.isEmpty) return markTestSkipped('无标签，跳过关系分页');
      final first = list.first as Map<String, dynamic>;
      final idKey = [
        'tag_id',
        'tagId',
        'id',
      ].firstWhere((k) => first.containsKey(k), orElse: () => '');
      if (idKey.isEmpty) return markTestSkipped('标签无 id 字段');
      final resp = await client.get(
        '/api/v1/user_tag_relation/friend_page',
        queryParameters: {
          'page': 1,
          'size': 10,
          'scene': 'friend',
          'tag_id': first[idKey],
        },
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 3. 鉴权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('3.1 无 token 访问 user_tag/page — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get(
          '/api/v1/user_tag/page',
          queryParameters: {'page': 1, 'size': 10, 'scene': 'friend'},
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的标签数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
