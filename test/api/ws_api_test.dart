// test/api/ws_api_test.dart
//
// WebSocket API 契约测试（纯 dart test，无设备，可 CI 运行）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=+8613800138000 \
//   TEST_PASSWORD=<pwd> \
//   dart test test/api/ws_api_test.dart --concurrency=1

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'api_test_client.dart';

void main() {
  late ApiTestClient apiClient;
  String wsUrl = '';

  setUpAll(() async {
    apiClient = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);

    if (ApiTestConfig.isConfigured) {
      await apiClient.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
    }

    // 从 init_config 获取 ws_url，回退为 API URL 推导
    try {
      final resp = await apiClient.get('/v1/app/init_config');
      if (resp['code'] == 0 && resp['data'] is Map) {
        wsUrl = ((resp['data'] as Map)['ws_url'] as String?) ?? '';
      }
    } catch (_) {}

    if (wsUrl.isEmpty) {
      wsUrl = ApiTestConfig.apiBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      if (!wsUrl.endsWith('/ws')) wsUrl = '$wsUrl/ws';
    }
  });

  tearDownAll(() => apiClient.close());

  // ──────────────────────────────────────────────
  // 1. 连接建立
  // ──────────────────────────────────────────────
  group('WS 连接建立', () {
    test('1.1 有效 token 可建立并正常关闭连接', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('未登录');
        return;
      }
      final ws = await _connect(wsUrl, token: apiClient.accessToken!);
      await Future<void>.delayed(const Duration(seconds: 1));
      await ws.close();
    });

    test('1.2 连接 5 秒内不被服务端强制断开', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('未登录');
        return;
      }
      final ws = await _connect(wsUrl, token: apiClient.accessToken!);
      var disconnected = false;
      Object? wsError;
      ws.listen(
        (_) {},
        onError: (Object e) {
          wsError = e;
          disconnected = true;
        },
        onDone: () => disconnected = true,
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(disconnected, isFalse, reason: '认证连接 5 秒内不应被断开，error=$wsError');
      await ws.close();
    });
  });

  // ──────────────────────────────────────────────
  // 2. 心跳
  // ──────────────────────────────────────────────
  group('WS 心跳', () {
    test('2.1 发送 ping 后 5 秒内收到响应', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('未登录');
        return;
      }
      final ws = await _connect(wsUrl, token: apiClient.accessToken!);
      final completer = Completer<void>();
      final received = <String>[];
      ws.listen(
        (data) {
          received.add(data.toString());
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
      ws.add('ping');
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('ping 后 5 秒内未收到任何响应'),
      );
      await ws.close();
      expect(received, isNotEmpty, reason: 'ping 后应收到服务端响应');
    });
  });

  // ──────────────────────────────────────────────
  // 3. 消息格式
  // ──────────────────────────────────────────────
  group('WS 消息格式', () {
    test('3.1 收到的 String 消息是合法 JSON 或已知控制帧', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('未登录');
        return;
      }
      final ws = await _connect(wsUrl, token: apiClient.accessToken!);
      final messages = <dynamic>[];
      var disconnected = false;
      Object? wsError;
      ws.listen(
        (data) => messages.add(data),
        onError: (Object e) {
          wsError = e;
          disconnected = true;
        },
        onDone: () => disconnected = true,
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(disconnected, isFalse, reason: '认证连接不应在 5 秒内断开，error=$wsError');
      await ws.close();
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
          fail('收到无法解析的非 JSON 消息: $msg');
        }
      }
    });
  });
}

Future<WebSocket> _connect(String url, {String? token}) {
  final headers = <String, dynamic>{
    'cos': Platform.isMacOS ? 'macos' : 'linux',
    'vsn': '0.8.0',
    'pkg': 'pub.imboy.app',
    'did': 'dart-test-ws-001',
  };
  if (token != null) headers['authorization'] = 'Bearer $token';
  return WebSocket.connect(url, headers: headers);
}
