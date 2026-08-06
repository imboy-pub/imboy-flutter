// test/api/rtc_room_api_test.dart
//
// 音视频房间（LiveKit SFU）API 契约测试（纯 dart test，无设备，可 CI 运行）
//
// join 是幂等入场券签发（不建立媒体连接），可安全重复调用。
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/rtc_room_api_test.dart --concurrency=1

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? gid;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (loggedIn) {
      final g = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (g['code'] == 0 && g['payload'] is Map) {
        final list = (g['payload'] as Map)['list'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final first = list.first as Map;
          final raw = first['group_id'] ?? first['id'] ?? first['gid'];
          if (raw != null) gid = raw.toString();
        }
      }
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 加入群房间（POST /api/v1/rtc/room/join）— 需 gid
  // ──────────────────────────────────────────────
  group('加入群房间', () {
    test('1.1 群成员 join — 返回 ws_url/token/room_name 非空', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      if (gid == null) {
        markTestSkipped('测试账号无群，跳过');
        return;
      }
      final resp = await client.post(
        '/api/v1/rtc/room/join',
        data: {
          'kind': 'group',
          'target_id': int.parse(gid!),
          'did': 'e2e-dart-test-001',
        },
      );
      expect(resp, containsPair('code', isA<int>()));
      ApiAssert.success(resp, context: 'rtc/room/join');
      ApiAssert.fieldNotEmpty(resp, 'ws_url', context: 'rtc/room/join');
      ApiAssert.fieldNotEmpty(resp, 'token', context: 'rtc/room/join');
      ApiAssert.fieldNotEmpty(resp, 'room_name', context: 'rtc/room/join');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 错误路径（非法 target_id / 非成员）
  // ──────────────────────────────────────────────
  group('错误路径', () {
    test('2.1 非法 target_id — 返回业务错误（code != 0）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.post(
        '/api/v1/rtc/room/join',
        data: {'kind': 'group', 'target_id': 1},
      );
      expect(resp, containsPair('code', isA<int>()));
      ApiAssert.failure(resp, context: 'rtc/room/join 非法 target_id');
    });
  });
}
