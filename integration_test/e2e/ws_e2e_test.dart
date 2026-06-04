// Flutter E2E WebSocket 联调测试
//
// 测试 WebSocket 连接、消息收发、心跳等实时通讯链路。
//
// 使用方法：
// flutter test integration_test/e2e/ws_e2e_test.dart \
//   --dart-define=APP_ENV=local_office \
//   --dart-define=API_BASE_URL=http://192.168.2.19:9800 \
//   --dart-define=WS_URL=ws://192.168.2.19:9800/ws \
//   --dart-define=TEST_PHONE=13800138000 \
//   --dart-define=TEST_PASSWORD=test123456

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'api_test_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiTestClient apiClient;
  late String wsBaseUrl;

  setUpAll(() async {
    final apiBaseUrl = E2ETestConfig.apiBaseUrl;
    wsBaseUrl = const String.fromEnvironment('WS_URL', defaultValue: '');

    if (apiBaseUrl.isEmpty) {
      throw StateError('必须配置 API_BASE_URL');
    }

    apiClient = ApiTestClient(baseUrl: apiBaseUrl);

    // 先登录获取 token；未配置则跳过认证（1.2/观察型测试仍可运行）
    if (E2ETestConfig.isConfigured) {
      final loginResp = await apiClient.login(
        account: E2ETestConfig.testPhone,
        password: E2ETestConfig.testPassword,
      );
      if (loginResp['code'] != 0) {
        throw StateError('WS E2E 登录失败: ${loginResp['msg']}，后续测试无法运行');
      }
    }

    // 如果未配置 WS_URL，尝试从 init 接口获取
    if (wsBaseUrl.isEmpty) {
      final initResp = await apiClient.get('/v1/init');
      if (initResp['code'] == 0 && initResp['data'] is Map<String, dynamic>) {
        wsBaseUrl = (initResp['data']['ws_url'] as String?) ?? '';
      }
    }

    // 最终回退：根据 API URL 推导
    if (wsBaseUrl.isEmpty) {
      wsBaseUrl = apiBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      if (!wsBaseUrl.endsWith('/ws')) {
        wsBaseUrl = '$wsBaseUrl/ws';
      }
    }

    _wsLog('[E2E-WS] API: $apiBaseUrl');
    _wsLog('[E2E-WS] WS:  $wsBaseUrl');
  });

  tearDownAll(() {
    apiClient.close();
  });

  // ================================================================
  // 1. WebSocket 连接
  // ================================================================
  group('WebSocket 连接联调', () {
    test('1.1 建立连接 - 使用有效 token', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final ws = await _connectWebSocket(
        wsBaseUrl,
        token: apiClient.accessToken!,
      );

      expect(ws, isNotNull, reason: 'WebSocket 应连接成功');

      // 等待连接稳定
      await Future<dynamic>.delayed(const Duration(seconds: 1));

      // 发送 ping 验证连接存活
      ws.add('ping');
      await Future<dynamic>.delayed(const Duration(milliseconds: 500));

      await ws.close();
      _wsLog('[E2E-WS] 连接建立并关闭成功');
    });

    // 观察型测试：后端对无 token 连接的处理策略尚未固化
    // （可能延迟踢出也可能直接拒绝），因此不做强断言，仅记录行为。
    // 当后端明确规范后，此测试应升级为带 expect 的强验证。
    test('1.2 无 token 连接 - 记录服务端安全边界行为（观察型）', () async {
      try {
        final ws = await _connectWebSocket(wsBaseUrl);
        // 服务端可能先接受后延迟踢出，等待 2s 观察
        await Future<dynamic>.delayed(const Duration(seconds: 2));
        await ws.close();
        _wsLog('[E2E-WS] 无 token 连接: 已建立（服务端延迟校验）');
      } on WebSocketException catch (e) {
        _wsLog('[E2E-WS] 无 token 连接被拒绝: $e');
      } on SocketException catch (e) {
        _wsLog('[E2E-WS] 无 token 连接失败: $e');
      }
    });
  });

  // ================================================================
  // 2. WebSocket 心跳
  // ================================================================
  group('WebSocket 心跳联调', () {
    test('2.1 Ping/Pong 心跳保活', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final ws = await _connectWebSocket(
        wsBaseUrl,
        token: apiClient.accessToken!,
      );

      final messages = <String>[];
      final completer = Completer<void>();

      ws.listen(
        (data) {
          _wsLog('[E2E-WS] 收到: $data');
          messages.add(data.toString());
          if (messages.isNotEmpty) {
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (Object error) {
          _wsLog('[E2E-WS] 错误: $error');
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          _wsLog('[E2E-WS] 连接关闭');
          if (!completer.isCompleted) completer.complete();
        },
      );

      // 发送 ping
      ws.add('ping');
      _wsLog('[E2E-WS] 发送: ping');

      // 等待响应或超时
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('[E2E-WS] 心跳超时 5s，服务端未响应 ping'),
      );

      await ws.close();

      // ping 可能收到 text "pong" 或二进制 pong 帧
      _wsLog('[E2E-WS] 心跳测试完成, 收到 ${messages.length} 条消息');
    });
  });

  // ================================================================
  // 3. WebSocket 消息接收
  // ================================================================
  group('WebSocket 消息接收联调', () {
    test('3.1 连接 5 秒内不被服务端断开，收到的消息格式合法', () async {
      // 原测试无任何断言（永远通过）。
      // 修复：断言连接未被强制断开 + 收到的 String 消息必须是合法 JSON 或已知控制帧。
      if (apiClient.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final ws = await _connectWebSocket(
        wsBaseUrl,
        token: apiClient.accessToken!,
      );

      final messages = <dynamic>[];
      var disconnectedByServer = false;
      Object? wsError;

      ws.listen(
        (data) {
          _wsLog('[E2E-WS] S2C: $data');
          messages.add(data);
        },
        onError: (Object e) {
          wsError = e;
          disconnectedByServer = true;
        },
        onDone: () => disconnectedByServer = true,
      );

      await Future<dynamic>.delayed(const Duration(seconds: 5));

      // 断言 1：5 秒内不应被服务端强制断开
      expect(
        disconnectedByServer,
        isFalse,
        reason: '认证连接 5 秒内不应被断开，error=$wsError',
      );

      await ws.close();
      _wsLog('[E2E-WS] 收到 ${messages.length} 条 S2C 消息');

      // 断言 2：String 消息必须是合法 JSON 或已知控制帧
      for (final msg in messages) {
        if (msg is! String || msg.isEmpty || msg == 'pong') continue;
        try {
          final parsed = jsonDecode(msg);
          expect(
            parsed,
            isA<Map<String, dynamic>>(),
            reason: 'S2C 消息应为 JSON 对象，实际: $msg',
          );
        } on FormatException {
          fail('S2C 收到无法解析的非 JSON 消息: $msg');
        }
      }
    });
  });

  // ================================================================
  // 4. WebSocket 连接稳定性
  // ================================================================
  group('WebSocket 稳定性联调', () {
    test('4.1 连接保持 10 秒不断线', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final ws = await _connectWebSocket(
        wsBaseUrl,
        token: apiClient.accessToken!,
      );

      var disconnected = false;
      ws.listen(
        (data) => _wsLog('[E2E-WS] 稳定性: 收到 $data'),
        onDone: () => disconnected = true,
        onError: (Object e) {
          disconnected = true;
          _wsLog('[E2E-WS] 稳定性: 错误 $e');
        },
      );

      // 每 3 秒发送 ping 保活
      for (var i = 0; i < 3; i++) {
        await Future<dynamic>.delayed(const Duration(seconds: 3));
        if (disconnected) break;
        ws.add('ping');
        _wsLog('[E2E-WS] 稳定性: ping #${i + 1}');
      }

      expect(disconnected, isFalse, reason: 'WebSocket 应保持连接 10 秒不断线');

      await ws.close();
      _wsLog('[E2E-WS] 稳定性测试通过');
    });
  });
}

/// 建立 WebSocket 连接
Future<WebSocket> _connectWebSocket(String url, {String? token}) async {
  final headers = <String, String>{
    'cos': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'macos'),
    'vsn': '0.8.0',
    'pkg': 'pub.imboy.app',
    'did': 'e2e-test-ws-${DateTime.now().millisecondsSinceEpoch}',
  };

  if (token != null) {
    headers['authorization'] = 'Bearer $token';
  }

  _wsLog('[E2E-WS] 连接: $url');
  return WebSocket.connect(url, headers: headers);
}

void _wsLog(String msg) {
  // ignore: avoid_print
  print(msg);
}
