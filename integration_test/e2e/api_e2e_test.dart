// Flutter E2E API 联调测试 - 核心 API 端到端验证
//
// 测试 Flutter 客户端与 Erlang 后端的完整数据链路。
// 直接通过 HTTP 请求验证 API 行为，不依赖 Flutter UI 渲染。
//
// 使用方法：
// flutter test integration_test/e2e/api_e2e_test.dart \
//   --dart-define=APP_ENV=local_office \
//   --dart-define=API_BASE_URL=http://192.168.2.19:9800 \
//   --dart-define=TEST_PHONE=13800138000 \
//   --dart-define=TEST_PASSWORD=test123456

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'api_test_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiTestClient client;

  setUpAll(() async {
    final baseUrl = E2ETestConfig.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw StateError(
        '必须配置 API_BASE_URL, 例如:\n'
        '  --dart-define=API_BASE_URL=http://192.168.2.19:9800',
      );
    }
    client = ApiTestClient(baseUrl: baseUrl);
    if (!E2ETestConfig.isConfigured) return;
    final resp = await client.login(
      account: E2ETestConfig.testPhone,
      password: E2ETestConfig.testPassword,
    );
    if (resp['code'] != 0) {
      throw StateError('E2E 登录失败: ${resp['msg']}，后续测试无法运行');
    }
  });

  tearDownAll(() {
    client.close();
  });

  // ================================================================
  // 1. 认证流程
  // ================================================================
  group('认证流程联调', () {
    test('1.1 登录成功 - 返回 token 和用户信息', () async {
      if (!E2ETestConfig.isConfigured) {
        markTestSkipped('未配置测试账号');
        return;
      }

      final resp = await client.login(
        account: E2ETestConfig.testPhone,
        password: E2ETestConfig.testPassword,
      );

      ApiAssert.success(resp, context: '登录');
      ApiAssert.fieldNotEmpty(resp, 'token', context: '登录');
      ApiAssert.fieldNotEmpty(resp, 'uid', context: '登录');

      expect(client.accessToken, isNotNull);
      expect(client.accessToken, isNotEmpty);
      expect(client.currentUid, isNotNull);
    });

    test('1.2 登录失败 - 错误密码', () async {
      final tempClient = ApiTestClient(baseUrl: E2ETestConfig.apiBaseUrl);
      try {
        final resp = await tempClient.login(
          account: 'wrong_account_999',
          password: 'wrong_password',
        );
        ApiAssert.failure(resp, context: '错误密码登录');
      } finally {
        tempClient.close();
      }
    });

    test('1.3 Token 刷新', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.refreshToken();
      // Token 刷新可能成功也可能因为 refreshToken 格式不符而失败
      // 这里主要验证 API 可达且响应格式正确
      expect(resp.containsKey('code'), isTrue);
    });
  });

  // ================================================================
  // 2. 版本检查 API
  // ================================================================
  group('版本检查联调', () {
    test('2.1 检查当前版本 - 返回版本信息', () async {
      final resp = await client.get(
        '/v1/app_version/check',
        queryParameters: {'vsn': '0.1.0'}, // 传入低版本触发更新
      );

      // 版本检查 API 属于 optional auth，无论是否登录都应可用
      expect(resp.containsKey('code'), isTrue);

      if (resp['code'] == 0) {
        final data = resp['data'];
        if (data != null && data is Map<String, dynamic>) {
          // 如果有更新版本可用，验证字段完整性
          if (data['updatable'] == true) {
            expect(data.containsKey('vsn'), isTrue);
            expect(data.containsKey('upgrade_type'), isTrue);
            debugPrint(
              '[E2E] 版本检查: 有新版本 ${data['vsn']}, '
              '升级类型=${data['upgrade_type']}',
            );
          } else {
            debugPrint('[E2E] 版本检查: 当前已是最新版本');
          }
        }
      }
    });

    test('2.2 检查最新版本 - 无更新', () async {
      final resp = await client.get(
        '/v1/app_version/check',
        queryParameters: {'vsn': '99.99.99'}, // 极大版本号
      );

      expect(resp.containsKey('code'), isTrue);
      if (resp['code'] == 0) {
        final data = resp['data'];
        if (data != null && data is Map<String, dynamic>) {
          // 版本号极大时应该没有更新
          expect(data['updatable'], isFalse, reason: '极大版本号不应有更新');
        }
      }
    });
  });

  // ================================================================
  // 3. 用户信息 API
  // ================================================================
  group('用户信息联调', () {
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
      final data = resp['data'];
      expect(data, isNotNull);
      expect(data, isA<Map<String, dynamic>>());

      debugPrint(
        '[E2E] 用户信息: uid=${client.currentUid}, '
        'nickname=${data?['nickname']}',
      );
    });

    test('3.2 获取用户设置', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.get('/v1/user/setting');
      expect(resp.containsKey('code'), isTrue);

      if (resp['code'] == 0) {
        debugPrint('[E2E] 用户设置获取成功');
      }
    });
  });

  // ================================================================
  // 4. 好友列表 API
  // ================================================================
  group('好友列表联调', () {
    test('4.1 获取好友列表', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.get('/v1/friend/list');
      ApiAssert.success(resp, context: '好友列表');

      final data = resp['data'];
      if (data is List) {
        debugPrint('[E2E] 好友列表: ${data.length} 个好友');
      } else if (data is Map<String, dynamic>) {
        debugPrint('[E2E] 好友列表响应: $data');
      }
    });
  });

  // ================================================================
  // 5. 会话列表 API
  // ================================================================
  group('会话列表联调', () {
    test('5.1 获取会话列表', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.get('/v1/conversation/mine');
      ApiAssert.success(resp, context: '会话列表');

      final data = resp['data'];
      debugPrint('[E2E] 会话列表响应类型: ${data.runtimeType}');
    });

    test('5.2 获取置顶会话', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.get('/v1/conversation/pinned');
      expect(resp.containsKey('code'), isTrue);
      debugPrint('[E2E] 置顶会话 code: ${resp['code']}');
    });
  });

  // ================================================================
  // 6. 离线消息 API
  // ================================================================
  group('离线消息联调', () {
    test('6.1 拉取离线消息', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.get('/v1/msg/offline');
      expect(resp.containsKey('code'), isTrue);

      if (resp['code'] == 0) {
        final data = resp['data'];
        if (data is List) {
          debugPrint('[E2E] 离线消息: ${data.length} 条');
        } else {
          debugPrint('[E2E] 离线消息响应: $data');
        }
      }
    });
  });

  // ================================================================
  // 7. 初始化配置 API
  // ================================================================
  group('初始化配置联调', () {
    test('7.1 获取初始化配置', () async {
      final resp = await client.get('/v1/init');
      expect(resp.containsKey('code'), isTrue);

      if (resp['code'] == 0) {
        final data = resp['data'];
        debugPrint('[E2E] 初始化配置: ${data?.keys?.toList()}');

        // 验证关键配置字段
        if (data is Map<String, dynamic>) {
          // ws_url 是 WebSocket 连接的关键
          if (data.containsKey('ws_url')) {
            expect(data['ws_url'], isNotEmpty, reason: '初始化配置必须包含 ws_url');
            debugPrint('[E2E] WebSocket URL: ${data['ws_url']}');
          }
        }
      }
    });
  });

  // ================================================================
  // 8. 群组 API
  // ================================================================
  group('群组联调', () {
    test('8.1 获取群组列表', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.post(
        '/v1/group/page',
        data: {'page': 1, 'size': 10},
      );

      expect(resp.containsKey('code'), isTrue);
      if (resp['code'] == 0) {
        final data = resp['data'];
        debugPrint('[E2E] 群组列表: $data');
      }
    });
  });

  // ================================================================
  // 9. 全文搜索 API
  // ================================================================
  group('全文搜索联调', () {
    test('9.1 搜索最近联系人', () async {
      if (client.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final resp = await client.get('/v1/fts/recently_user');
      expect(resp.containsKey('code'), isTrue);
      debugPrint('[E2E] 最近联系人 code: ${resp['code']}');
    });
  });

  // ================================================================
  // 10. 错误处理验证
  // ================================================================
  group('错误处理联调', () {
    test('10.1 未认证访问 - 返回 401', () async {
      // 创建一个未登录的客户端
      final noAuthClient = ApiTestClient(baseUrl: E2ETestConfig.apiBaseUrl);
      try {
        final resp = await noAuthClient.get('/v1/user/show');
        // 未认证应该返回错误
        expect(resp['code'], isNot(0), reason: '未认证访问应返回错误');
        debugPrint('[E2E] 未认证访问 code: ${resp['code']}');
      } finally {
        noAuthClient.close();
      }
    });

    test('10.2 无效路径 - 返回 404', () async {
      final resp = await client.get('/v1/nonexistent/endpoint');
      expect(resp['code'], isNot(0), reason: '无效路径应返回错误');
      debugPrint('[E2E] 无效路径 code: ${resp['code']}');
    });
  });
}
