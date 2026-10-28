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
    apiClient = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'dart-test-ws-001',
    );

    if (ApiTestConfig.isConfigured) {
      await apiClient.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
    }

    // 与后端唯一 canonical route 一致；init payload 为加密配置，不能读作 data。
    final base = Uri.parse(ApiTestConfig.apiBaseUrl);
    wsUrl = base
        .replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '/api/v1/ws',
          query: null,
          fragment: null,
        )
        .toString();
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
      final ws = await _connect(wsUrl, headers: apiClient.authenticatedHeaders);
      await Future<void>.delayed(const Duration(seconds: 1));
      await ws.close();
    });

    test('1.2 连接 5 秒内不被服务端强制断开', () async {
      if (apiClient.accessToken == null) {
        markTestSkipped('未登录');
        return;
      }
      final ws = await _connect(wsUrl, headers: apiClient.authenticatedHeaders);
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

    test('1.3 有效签名但无 token 的握手返回 412', () async {
      if (!ApiTestConfig.isConfigured) {
        return markTestSkipped('真实 WS 契约需要测试账号、签名密钥和可用后端');
      }
      expect(apiClient.accessToken, isNotNull, reason: '已配置的测试账号必须登录成功');
      // 先确认同一签名和服务端可建立认证连接，避免把其他错误当成鉴权拒绝。
      final authenticated = await _connect(
        wsUrl,
        headers: apiClient.authenticatedHeaders,
      ).timeout(const Duration(seconds: 5));
      await authenticated.close();

      final headers = apiClient.authenticatedHeaders..remove('authorization');
      try {
        final ws = await _connect(
          wsUrl,
          headers: headers,
        ).timeout(const Duration(seconds: 5));
        await ws.close();
        fail('无 token 的 WebSocket 握手不应成功');
      } on WebSocketException catch (error) {
        expect(error.httpStatusCode, HttpStatus.preconditionFailed);
      }
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
      final ws = await _connect(wsUrl, headers: apiClient.authenticatedHeaders);
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

      // JSON 子协议的应用层文本心跳必须返回精确 pong。
      const deadline = Duration(seconds: 5);
      final start = DateTime.now();
      while (!allMessages.skip(countBeforePing).contains('pong')) {
        if (DateTime.now().difference(start) >= deadline) {
          fail('ping 后 5 秒内未收到精确 pong');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      await ws.close();
      expect(
        allMessages.skip(countBeforePing),
        contains('pong'),
        reason: 'imboy-json 文本 ping 必须收到 pong，业务消息不能替代心跳',
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
      final ws = await _connect(wsUrl, headers: apiClient.authenticatedHeaders);
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

Future<WebSocket> _connect(
  String url, {
  required Map<String, String> headers,
}) async {
  final ws = await WebSocket.connect(
    url,
    headers: headers,
    protocols: ['imboy-json'],
  );
  addTearDown(ws.close);
  expect(ws.protocol, 'imboy-json', reason: '必须协商真实 JSON 子协议');
  return ws;
}
