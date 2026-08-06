// test/api/location_api_test.dart
//
// 附近的人 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/location_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/location_api.dart：
//   location/peopleNearby 为 GET 只读（需经纬度参数）。
//   makeMyselfVisible / makeMyselfUnvisible 为写/位置上报端点，绝不真实调用。

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
  // 1. 附近的人 GET /api/v1/location/peopleNearby
  // ──────────────────────────────────────────────
  group('附近的人', () {
    test('1.1 带经纬度查询 — 返回含 code 的 JSON', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/location/peopleNearby',
        queryParameters: {
          'radius': 500000,
          'unit': 'm',
          'limit': 100,
          'longitude': '113.324520',
          'latitude': '23.099994',
        },
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload 为 Map/List/null', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/location/peopleNearby',
        queryParameters: {
          'radius': 500000,
          'unit': 'm',
          'limit': 100,
          'longitude': '113.324520',
          'latitude': '23.099994',
        },
      );
      if (resp['code'] != 0) return markTestSkipped('peopleNearby 非成功');
      final payload = resp['payload'];
      expect(
        payload == null || payload is Map || payload is List,
        isTrue,
        reason: '附近的人 payload 应为 Map/List/null',
      );
    });
  });

  // ──────────────────────────────────────────────
  // 2. 未授权保护
  // ──────────────────────────────────────────────
  group('鉴权保护', () {
    test('2.1 无 token 访问 peopleNearby — 不返回成功数据', () async {
      final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
      try {
        final resp = await anon.get(
          '/api/v1/location/peopleNearby',
          queryParameters: {
            'radius': 500000,
            'unit': 'm',
            'limit': 100,
            'longitude': '113.324520',
            'latitude': '23.099994',
          },
        );
        expect(
          resp['code'] != 0 || resp['payload'] == null,
          isTrue,
          reason: '无 token 不应返回成功的附近的人数据: $resp',
        );
      } finally {
        anon.close();
      }
    });
  });
}
