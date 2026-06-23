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
      final resp = await apiClient.get('/api/v1/init');
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

    test('1.3 无 token 连接 — 5 秒内被服务端断开或拒绝建立', () async {
      var rejected = false;
      try {
        final ws = await _connect(wsUrl); // 无 token
        var serverClosed = false;
        ws.listen(
          (_) {},
          onError: (_) {
            serverClosed = true;
          },
          onDone: () {
            serverClosed = true;
          },
        );
        await Future<void>.delayed(const Duration(seconds: 5));
        rejected = serverClosed;
        if (!serverClosed) await ws.close();
      } on WebSocketException {
        rejected = true;
      } on SocketException {
        rejected = true;
      }
      expect(
        rejected,
        isTrue,
        reason: '无 token 的 WebSocket 连接应在 5 秒内被服务端拒绝或断开',
      );
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
      final allMessages = <String>[];

      ws.listen(
        (data) => allMessages.add(data.toString()),
        onError: (_) {},
        onDone: () {},
      );

      // 短暂等待，排空服务端在连接建立时可能推送的初始化消息，
      // 避免 completer 被初始化消息而非 pong 触发。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final countBeforePing = allMessages.length;

      ws.add('ping');

      // 轮询等待 ping 之后收到新消息（最多 5 秒）
      const deadline = Duration(seconds: 5);
      final start = DateTime.now();
      while (allMessages.length == countBeforePing) {
        if (DateTime.now().difference(start) >= deadline) {
          fail('ping 后 5 秒内未收到任何响应');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      await ws.close();
      expect(
        allMessages.length,
        greaterThan(countBeforePing),
        reason: 'ping 后应收到服务端响应（pong 或业务消息）',
      );
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
