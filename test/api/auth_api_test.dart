// test/api/auth_api_test.dart
//
// 认证 API 契约测试（纯 dart test，无设备，可 CI 直接运行）
//
// 运行方式：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=+8613800138000 \
//   TEST_PASSWORD=<pwd> \
//   dart test test/api/auth_api_test.dart --concurrency=1

@TestOn('vm')
library;

import 'package:test/test.dart';

import 'api_test_client.dart';

void main() {
  late ApiTestClient client;

  setUpAll(() async {
    if (ApiTestConfig.apiBaseUrl.isEmpty) {
      throw StateError(
        '必须设置环境变量 API_BASE_URL，例如: '
        'API_BASE_URL=http://127.0.0.1:9800 dart test test/api/',
      );
    }
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
  });

  tearDownAll(() => client.close());

  group('认证流程', () {
    test('1.1 正确凭证登录 — 返回 token 和 uid', () async {
      if (!ApiTestConfig.isConfigured) {
        markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
        return;
      }

      final resp = await client.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );

      ApiAssert.success(resp, context: '登录');
      ApiAssert.fieldNotEmpty(resp, 'token', context: '登录');
      ApiAssert.fieldNotEmpty(resp, 'uid', context: '登录');
      expect(client.accessToken, isNotNull);
      expect(client.accessToken, isNotEmpty);
    });

    test('1.2 错误凭证登录 — 返回非 0 code', () async {
      final tmpClient = ApiTestClient(
        baseUrl: ApiTestConfig.apiBaseUrl,
        deviceId: 'e2e-wrong-cred-test',
      );
      try {
        final resp = await tmpClient.login(
          account: 'nonexistent_user_e2e_test',
          password: 'wrong_password_xyz',
        );
        ApiAssert.failure(resp, context: '错误凭证登录');
      } finally {
        tmpClient.close();
      }
    });

    test('1.3 Token 刷新接口可达且响应格式正确', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录获取 refreshToken');
        return;
      }
      final resp = await client.refreshToken();
      expect(resp, containsPair('code', isA<int>()));
    });

    test('1.4 未认证访问受保护接口 — 返回非 0 code', () async {
      final noAuthClient = ApiTestClient(
        baseUrl: ApiTestConfig.apiBaseUrl,
        deviceId: 'e2e-noauth-test',
      );
      try {
        final resp = await noAuthClient.get('/v1/user/show');
        expect(resp['code'], isNot(0), reason: '未认证访问受保护接口应返回错误 code');
      } finally {
        noAuthClient.close();
      }
    });
  });

  group('App 初始化配置', () {
    test('2.1 init_config 无需认证可达，返回 code=0', () async {
      final resp = await client.get('/v1/init');
      expect(resp, containsPair('code', 0), reason: 'init_config 应返回 code=0');
    });

    test('2.2 版本检查响应包含 updatable 字段', () async {
      final resp = await client.get(
        '/v1/app_version/check',
        queryParameters: {'vsn': '0.1.0'},
      );
      expect(resp, containsPair('code', isA<int>()));
      if (resp['code'] == 0 && resp['data'] is Map) {
        expect(
          (resp['data'] as Map).keys,
          contains('updatable'),
          reason: '版本检查响应缺少 updatable 字段',
        );
      }
    });

    test('2.3 极高版本号不触发更新', () async {
      final resp = await client.get(
        '/v1/app_version/check',
        queryParameters: {'vsn': '99.99.99'},
      );
      if (resp['code'] == 0 && resp['data'] is Map) {
        expect(
          (resp['data'] as Map)['updatable'],
          isFalse,
          reason: '极高版本号不应有可用更新',
        );
      }
    });
  });

  group('用户信息', () {
    test('3.1 获取当前用户信息', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }
      final resp = await client.get(
        '/v1/user/show',
        queryParameters: {'uid': client.currentUid},
      );
      ApiAssert.success(resp, context: '获取用户信息');
      expect(resp['data'], isA<Map<String, dynamic>>());
    });
  });

  group('错误处理', () {
    test('4.1 无效路径 — 返回非 0 code', () async {
      final resp = await client.get('/v1/nonexistent_e2e_endpoint_xyz');
      expect(resp['code'], isNot(0), reason: '无效路径应返回错误');
    });
  });
}
