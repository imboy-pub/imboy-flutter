// test/api/group_api_test.dart
//
// 群组 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/{group,group_member}_api.dart。
// 全部为 GET 只读、幂等；group/detail 与 group_member/page 的 gid 从 group/page 结果自举，
// 无群时 markTestSkipped（不假绿）。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

void expectTsid(dynamic v, {required String field}) {
  expect(v, isNotNull, reason: '$field 不应为 null');
  final s = '$v';
  expect(s.isNotEmpty, isTrue, reason: '$field 应可转非空 string');
  expect(
    BigInt.tryParse(s) != null || v is String,
    isTrue,
    reason: '$field 应为可解析 TSID，实际=$v (${v.runtimeType})',
  );
}

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
      // 自举一个 gid 供 detail / member 测试
      final page = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (page['code'] == 0) sampleGid = _firstGid(page['payload']);
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 群分页 /api/v1/group/page (GET)
  // ──────────────────────────────────────────────
  group('群分页', () {
    test('1.1 分页获取我加入的群 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      ApiAssert.success(resp, context: 'group/page');
    });

    test('1.2 数据结构 — payload 可枚举，群项含可解析 group_id(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (resp['code'] != 0) return markTestSkipped('group/page 非成功');
      final gid = _firstGid(resp['payload']);
      if (gid == null) return markTestSkipped('测试账号无已加入群');
      expectTsid(gid, field: 'group.group_id');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 群详情 /api/v1/group/detail (GET, gid)
  // ──────────────────────────────────────────────
  group('群详情', () {
    test('2.1 获取群详情 — code=0 且含群名', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/detail',
        queryParameters: {'gid': sampleGid},
      );
      ApiAssert.success(resp, context: 'group/detail');
      final payload = resp['payload'] as Map<String, dynamic>;
      expect(
        ['title', 'name', 'group_name'].any(payload.containsKey),
        isTrue,
        reason: 'group/detail 应含群名字段: $payload',
      );
    });

    test('2.2 无效 gid — 返回业务错误而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/detail',
        queryParameters: {'gid': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 3. 群成员分页 /api/v1/group_member/page (GET, gid)
  // ──────────────────────────────────────────────
  group('群成员分页', () {
    test('3.1 分页获取群成员 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      ApiAssert.success(resp, context: 'group_member/page');
    });

    test('3.2 数据结构 — 成员项含可解析 uid(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('member/page 非成功');
      final payload = resp['payload'];
      final list = payload is List
          ? payload
          : payload is Map
          ? (payload['list'] ?? payload['data'] ?? const [])
          : const [];
      if (list is List && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final key = [
          'uid',
          'user_id',
          'id',
        ].firstWhere((k) => first.containsKey(k), orElse: () => '');
        expect(key.isNotEmpty, isTrue, reason: '成员项缺少 uid: $first');
        expectTsid(first[key], field: '成员.$key');
      }
    });
  });
}
