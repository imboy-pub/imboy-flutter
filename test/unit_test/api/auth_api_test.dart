// test/unit_test/api/auth_api_test.dart
//
// 认证 API 契约测试（无设备；真实网络由本目录就近的
// flutter_test_config.dart 恢复，运行器须用 flutter test——dart test 会被
// pubspec 的 patrol 等 Flutter-only 依赖阻断）
//
// 运行方式：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=+8613800138000 \
//   TEST_PASSWORD=<pwd> \
//   flutter test test/unit_test/api/auth_api_test.dart --concurrency=1

@TestOn('vm')
library;

import 'package:test/test.dart';

import 'api_test_client.dart';

void main() {
  // 网络 HttpOverrides 仍被 mock 时（api/flutter_test_config.dart 未生效的
  // 异常场景）整文件跳过而非假失败。详见 ApiTestConfig.isNetworkMocked。
  final networkSkip = ApiTestConfig.skipReasonIfNoRealNetwork;

  // 签名密钥不可得（IMBOY_SOLIDIFIED_KEY / IMBOY_ENV_PRO 指向文件均未
  // 提供）时同样整文件跳过：本文件全部用例都发真实请求，签名头比登录
  // 更底层——包括无需登录凭证的 init_config/版本检查/无效路径用例。
  // 与 app_version_api_test 的 hasSigningKey 逐用例保护同一语义。
  final signingSkip = ApiTestConfig.hasSigningKey
      ? null
      : 'API 契约测试需要签名密钥（设置 IMBOY_SOLIDIFIED_KEY，或 '
            'IMBOY_ENV_PRO 指向含 SOLIDIFIED_KEY 的配置文件），跳过';

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
        final resp = await noAuthClient.get('/api/v1/user/show');
        expect(resp['code'], isNot(0), reason: '未认证访问受保护接口应返回错误 code');
      } finally {
        noAuthClient.close();
      }
    });
  }, skip: networkSkip ?? signingSkip);

  group('App 初始化配置', () {
    test('2.1 init_config 无需认证可达，返回 code=0', () async {
      final resp = await client.get('/api/v1/init');
      expect(resp, containsPair('code', 0), reason: 'init_config 应返回 code=0');
    });

    test('2.2 版本检查响应包含 updatable 字段', () async {
      final resp = await client.get(
        '/api/v1/app_version/check',
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
        '/api/v1/app_version/check',
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
  }, skip: networkSkip ?? signingSkip);

  group('用户信息', () {
    test('3.1 获取当前用户信息', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/user/show',
        queryParameters: {
          'id': client.currentUid,
        }, // backend uses 'id', not 'uid'
      );
      ApiAssert.success(resp, context: '获取用户信息');
      expect(resp['payload'], isA<Map<String, dynamic>>());
    });
  }, skip: networkSkip ?? signingSkip);

  group('错误处理', () {
    test('4.1 无效路径 — 返回非 0 code', () async {
      final resp = await client.get('/api/v1/nonexistent_e2e_endpoint_xyz');
      expect(resp['code'], isNot(0), reason: '无效路径应返回错误');
    });
  }, skip: networkSkip ?? signingSkip);
}
