// test/api/app_version_api_test.dart
//
// App 版本检查 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   dart test test/api/app_version_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/app_version_api.dart：
//   app_version/check 为 GET 只读，可能免登录可达。
//   app_ddl/get（升/降级 DDL）为只读，无有效 vsn 时仅验存活。

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

void main() {
  late ApiTestClient client;

  setUpAll(() {
    // 版本检查可能免登录：仅建立 client，不强制登录
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 版本检查 GET /api/v1/app_version/check
  // ──────────────────────────────────────────────
  group('版本检查', () {
    test('1.1 免登录可达 — 返回含 code 的 JSON', () async {
      final resp = await client.get(
        '/api/v1/app_version/check',
        queryParameters: {'vsn': '0.8.0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.2 成功时 payload 含升级判定字段', () async {
      final resp = await client.get(
        '/api/v1/app_version/check',
        queryParameters: {'vsn': '0.8.0'},
      );
      if (resp['code'] != 0) return markTestSkipped('app_version/check 非成功');
      final payload = resp['payload'];
      if (payload is! Map) return markTestSkipped('payload 非 Map');
      // 实测契约：{updatable: bool, upgrade_type: 'none'|...}
      // 当有更新时通常还附版本号/下载地址字段。
      const versionKeys = [
        'updatable',
        'upgrade_type',
        'vsn',
        'version',
        'url',
        'download_url',
        'force',
      ];
      final hasVersionField = versionKeys.any(payload.containsKey);
      expect(
        hasVersionField || payload.isEmpty,
        isTrue,
        reason: '版本检查 payload 应含升级判定字段之一: $payload',
      );
      if (payload.containsKey('updatable')) {
        expect(payload['updatable'], isA<bool>(), reason: 'updatable 应为 bool');
      }
    });
  });

  // ──────────────────────────────────────────────
  // 2. SQLite 升级 DDL GET /api/v1/app_ddl/get
  // ──────────────────────────────────────────────
  group('SQLite 升级 DDL', () {
    test('2.1 接口可达 — 含 code', () async {
      final resp = await client.get(
        '/api/v1/app_ddl/get',
        queryParameters: {'type': 'upgrade', 'old_vsn': 1, 'new_vsn': 2},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('2.2 成功时 payload.ddl 为 List（若存在）', () async {
      final resp = await client.get(
        '/api/v1/app_ddl/get',
        queryParameters: {'type': 'upgrade', 'old_vsn': 1, 'new_vsn': 2},
      );
      if (resp['code'] != 0) return markTestSkipped('app_ddl/get 非成功');
      final payload = resp['payload'];
      if (payload is Map && payload.containsKey('ddl')) {
        expect(payload['ddl'], isA<List>(), reason: 'ddl 应为 List');
      }
    });
  });
}
