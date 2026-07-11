// test/api/group_member_api_test.dart
//
// 群成员 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_member_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/group_member_api.dart（经 lib/config/const.dart 解出真实路径）。
// 只测只读 GET：group_member/page、group_member/same_group。
// 写端点（join/leave/alias/role/mute/unmute）绝不真实调用。
// gid 从 group/page 自举，缺失时 markTestSkipped（不假绿）。

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

List _asList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    return (payload['list'] ?? payload['items'] ?? payload['data'] ?? const [])
        as List;
  }
  return const [];
}

String? _firstGid(dynamic payload) {
  final list = _asList(payload);
  if (list.isEmpty) return null;
  final first = list.first as Map<String, dynamic>;
  final key = [
    'group_id',
    'gid',
    'id',
  ].firstWhere(first.containsKey, orElse: () => '');
  return key.isEmpty ? null : '${first[key]}';
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
  // 1. 群成员分页 /api/v1/group_member/page (GET, gid)
  // ──────────────────────────────────────────────
  group('群成员分页', () {
    test('1.1 分页获取群成员 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      ApiAssert.success(resp, context: 'group_member/page');
    });

    test('1.2 数据结构 — 成员项含可解析 uid(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('member/page 非成功');
      final list = _asList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('样本群无成员数据');
      final first = list.first as Map<String, dynamic>;
      final key = [
        'uid',
        'user_id',
        'id',
      ].firstWhere(first.containsKey, orElse: () => '');
      expect(key.isNotEmpty, isTrue, reason: '成员项缺少 uid: $first');
      expectTsid(first[key], field: '成员.$key');
    });

    test('1.3 无效 gid — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': '0', 'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 同群判定 /api/v1/group_member/same_group (GET, uid1, uid2)
  // ──────────────────────────────────────────────
  group('同群判定', () {
    test('2.1 与自身同群查询 — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final uid = client.currentUid ?? '';
      if (uid.isEmpty) return markTestSkipped('无 currentUid');
      final resp = await client.get(
        '/api/v1/group_member/same_group',
        queryParameters: {'uid1': uid, 'uid2': uid},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('2.2 无效 uid — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group_member/same_group',
        queryParameters: {'uid1': '0', 'uid2': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
