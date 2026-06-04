// Flutter 真机冒烟测试
//
// 极简端到端验证：后端可达 → 登录 API 成功 → App 启动 → 主界面可见。
// 所有检查点失败即 fail()，禁止 AUTO-SKIP / return / markTestSkipped。
//
// 前置条件（CI/手动运行）：
//   1. 后端已启动并可达
//   2. 已配置测试账号 --dart-define=TEST_PHONE=... TEST_PASSWORD=...
//
// 运行方法：
//   flutter test integration_test/smoke/smoke_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     -d <real_device_id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;

import '../e2e/api_test_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 可空：setUpAll 在 ApiTestClient 构造前若 fail() 退出，tearDownAll 应安全跳过
  ApiTestClient? client;

  setUpAll(() async {
    final baseUrl = E2ETestConfig.apiBaseUrl;
    if (baseUrl.isEmpty) {
      fail(
        '冒烟测试要求配置 API_BASE_URL，'
        '例如: --dart-define=API_BASE_URL=http://127.0.0.1:9800',
      );
    }

    client = ApiTestClient(baseUrl: baseUrl);

    // 验证后端可达（init 接口无需认证）
    final Map<String, dynamic> initResp;
    try {
      initResp = await client!.get('/v1/init');
    } on Exception catch (e) {
      fail('冒烟测试要求后端可达，当前不可达: $baseUrl — $e');
    }

    if (initResp['code'] == null) {
      fail('后端响应格式异常，无 code 字段: $initResp');
    }

    // 验证登录 API
    if (!E2ETestConfig.isConfigured) {
      fail(
        '冒烟测试要求配置测试账号: '
        '--dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=...',
      );
    }

    final loginResp = await client!.login(
      account: E2ETestConfig.testPhone,
      password: E2ETestConfig.testPassword,
    );

    if (loginResp['code'] != 0) {
      fail('冒烟测试登录失败 (code=${loginResp['code']}): ${loginResp['msg']}');
    }
  });

  tearDownAll(() => client?.close());

  group('冒烟测试：App 基础流程', () {
    setUp(() {
      // app.main() 只调用一次，避免 Flutter 绑定重复初始化
      app.main();
    });

    testWidgets('App 启动 — Scaffold 与 MaterialApp 均可见', (tester) async {
      // 等待启动动画和路由初始化完成（单帧超时 5s 足够宽松）
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: '启动后应有 Scaffold，实际未找到 — App 可能崩溃',
      );
      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'MaterialApp 应唯一存在，未找到则启动流程异常',
      );
    });
  });
}
