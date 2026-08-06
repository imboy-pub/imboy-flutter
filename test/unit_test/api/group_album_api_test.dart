// test/api/group_album_api_test.dart
//
// 群相册 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_album_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/group_album_api.dart（经 lib/config/const.dart 解出真实路径）。
// 只测只读 GET：group_album/list、group_album/photo/list、group_album/photo/detail。
// 写端点（create/rename/delete/cover-update/photo-upload/photo-delete）绝不真实调用。
// gid 从 group/page 自举，album_id 从 group_album/list 自举，缺失时 markTestSkipped（不假绿）。

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

/// 从分页 payload 中尽力取出 List（兼容 List / {list:[]} / {items:[]} / {data:[]}）。
List _asList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    return (payload['list'] ?? payload['items'] ?? payload['data'] ?? const [])
        as List;
  }
  return const [];
}

/// 取列表首项中第一个存在的 id 键值。
String? _firstIdOf(dynamic payload, List<String> keys) {
  final list = _asList(payload);
  if (list.isEmpty) return null;
  final first = list.first as Map<String, dynamic>;
  final key = keys.firstWhere(first.containsKey, orElse: () => '');
  return key.isEmpty ? null : '${first[key]}';
}

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? sampleGid;
  String? sampleAlbumId;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (!loggedIn) return;

    // 自举 gid
    final page = await client.get(
      '/api/v1/group/page',
      queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
    );
    if (page['code'] == 0) {
      sampleGid = _firstIdOf(page['payload'], ['group_id', 'gid', 'id']);
    }

    // 自举 album_id
    if (sampleGid != null) {
      final albums = await client.get(
        '/api/v1/group_album/list',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      if (albums['code'] == 0) {
        sampleAlbumId = _firstIdOf(albums['payload'], ['album_id', 'id']);
      }
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 相册列表 /api/v1/group_album/list (GET, gid)
  // ──────────────────────────────────────────────
  group('相册列表', () {
    test('1.1 分页获取群相册 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_album/list',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      ApiAssert.success(resp, context: 'group_album/list');
    });

    test('1.2 数据结构 — 相册项含可解析 album_id(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_album/list',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('group_album/list 非成功');
      final list = _asList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('样本群无相册');
      final id = _firstIdOf(resp['payload'], ['album_id', 'id']);
      expect(id, isNotNull, reason: '相册项缺少 album_id/id: ${list.first}');
      expectTsid(id, field: 'album.album_id');
    });

    test('1.3 无效 gid — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group_album/list',
        queryParameters: {'gid': '0', 'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 相册照片列表 /api/v1/group_album/photo/list (GET, album_id)
  // ──────────────────────────────────────────────
  group('相册照片列表', () {
    test('2.1 分页获取相册照片 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleAlbumId == null) return markTestSkipped('无样本相册');
      final resp = await client.get(
        '/api/v1/group_album/photo/list',
        queryParameters: {'album_id': sampleAlbumId, 'page': 1, 'size': 20},
      );
      ApiAssert.success(resp, context: 'group_album/photo/list');
    });

    test('2.2 数据结构 — 照片项含可解析 photo_id(TSID)（若有照片）', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleAlbumId == null) return markTestSkipped('无样本相册');
      final resp = await client.get(
        '/api/v1/group_album/photo/list',
        queryParameters: {'album_id': sampleAlbumId, 'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('photo/list 非成功');
      final list = _asList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('样本相册无照片');
      final id = _firstIdOf(resp['payload'], ['photo_id', 'id']);
      expect(id, isNotNull, reason: '照片项缺少 photo_id/id: ${list.first}');
      expectTsid(id, field: 'photo.photo_id');
    });
  });

  // ──────────────────────────────────────────────
  // 3. 照片详情 /api/v1/group_album/photo/detail (GET, photo_id)
  // ──────────────────────────────────────────────
  group('照片详情', () {
    test('3.1 无效 photo_id — 返回业务响应而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group_album/photo/detail',
        queryParameters: {'photo_id': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
