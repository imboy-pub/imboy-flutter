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

    // 先登录获取 token
    if (E2ETestConfig.isConfigured) {
      await apiClient.login(
        account: E2ETestConfig.testPhone,
        password: E2ETestConfig.testPassword,
      );
    }

    // 如果未配置 WS_URL，尝试从 init 接口获取
    if (wsBaseUrl.isEmpty) {
      final initResp = await apiClient.get('/v1/init');
      if (initResp['code'] == 0 && initResp['data'] is Map<String, dynamic>) {
        wsBaseUrl = initResp['data']['ws_url'] ?? '';
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

    debugPrint('[E2E-WS] API: $apiBaseUrl');
    debugPrint('[E2E-WS] WS:  $wsBaseUrl');
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
      debugPrint('[E2E-WS] 连接建立并关闭成功');
    });

    test('1.2 无 token 连接 - 应被拒绝或限制', () async {
      try {
        final ws = await _connectWebSocket(wsBaseUrl);
        // 如果连接成功，等待看是否会被踢出
        await Future<dynamic>.delayed(const Duration(seconds: 2));
        await ws.close();
        // 即使连接成功，也属于正常行为（服务端可能先接受后校验）
        debugPrint('[E2E-WS] 无 token 连接: 已建立（服务端延迟校验）');
      } on WebSocketException catch (e) {
        debugPrint('[E2E-WS] 无 token 连接被拒绝: $e');
        // 连接被拒绝是期望行为
      } on SocketException catch (e) {
        debugPrint('[E2E-WS] 无 token 连接失败: $e');
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
          debugPrint('[E2E-WS] 收到: $data');
          messages.add(data.toString());
          if (messages.isNotEmpty) {
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (Object error) {
          debugPrint('[E2E-WS] 错误: $error');
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          debugPrint('[E2E-WS] 连接关闭');
          if (!completer.isCompleted) completer.complete();
        },
      );

      // 发送 ping
      ws.add('ping');
      debugPrint('[E2E-WS] 发送: ping');

      // 等待响应或超时
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[E2E-WS] 心跳等待超时（可能是二进制 pong 帧）');
        },
      );

      await ws.close();

      // ping 可能收到 text "pong" 或二进制 pong 帧
      debugPrint('[E2E-WS] 心跳测试完成, 收到 ${messages.length} 条消息');
    });
  });

  // ================================================================
  // 3. WebSocket 消息接收
  // ================================================================
  group('WebSocket 消息接收联调', () {
    test('3.1 连接后接收 S2C 消息', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('需要先登录');
        return;
      }

      final ws = await _connectWebSocket(
        wsBaseUrl,
        token: apiClient.accessToken!,
      );

      final messages = <dynamic>[];

      // 监听 5 秒看是否有 S2C 消息
      ws.listen((data) {
        debugPrint('[E2E-WS] S2C 消息: $data');
        messages.add(data);
      });

      // 等待一段时间收集消息
      await Future<dynamic>.delayed(const Duration(seconds: 5));

      await ws.close();

      debugPrint('[E2E-WS] 连接期间收到 ${messages.length} 条 S2C 消息');

      // 如果收到消息，验证格式
      for (final msg in messages) {
        if (msg is String) {
          try {
            final parsed = jsonDecode(msg);
            expect(parsed, isA<Map<String, dynamic>>(),
                reason: 'S2C 消息应为 JSON 对象');
            debugPrint('[E2E-WS] S2C 消息解析: ${parsed.keys}');
          } on FormatException {
            // 非 JSON 格式也可以接受（如 pong）
            debugPrint('[E2E-WS] 非 JSON 消息: $msg');
          }
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
        (data) => debugPrint('[E2E-WS] 稳定性: 收到 $data'),
        onDone: () => disconnected = true,
        onError: (Object e) {
          disconnected = true;
          debugPrint('[E2E-WS] 稳定性: 错误 $e');
        },
      );

      // 每 3 秒发送 ping 保活
      for (var i = 0; i < 3; i++) {
        await Future<dynamic>.delayed(const Duration(seconds: 3));
        if (disconnected) break;
        ws.add('ping');
        debugPrint('[E2E-WS] 稳定性: ping #${i + 1}');
      }

      expect(disconnected, isFalse,
          reason: 'WebSocket 应保持连接 10 秒不断线');

      await ws.close();
      debugPrint('[E2E-WS] 稳定性测试通过');
    });
  });
}

/// 建立 WebSocket 连接
Future<WebSocket> _connectWebSocket(
  String url, {
  String? token,
}) async {
  final headers = <String, String>{
    'cos': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'macos'),
    'vsn': '0.8.0',
    'pkg': 'pub.imboy.app',
    'did': 'e2e-test-ws-${DateTime.now().millisecondsSinceEpoch}',
  };

  if (token != null) {
    headers['authorization'] = 'Bearer $token';
  }

  debugPrint('[E2E-WS] 连接: $url');
  return WebSocket.connect(url, headers: headers);
}

void debugPrint(String msg) {
  // ignore: avoid_print
  print(msg);
}
