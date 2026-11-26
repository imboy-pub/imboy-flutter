@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Stall the transport before the HTTP upgrade can finish. The real
/// WebSocketService, IOWebSocketChannel and Dart WebSocket.connect stay in use;
/// no socket or backend is needed to make channel.ready remain pending.
class _StalledHandshakeClient implements HttpClient {
  final requests = <Uri>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    expect(method, 'GET');
    expect(url.host, '127.0.0.1');
    requests.add(url);
    return Completer<HttpClientRequest>().future;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WebSocketService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    final encode = base64Url.encode;
    final token =
        '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
        '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
        '${encode(utf8.encode('synthetic-signature'))}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async {
          if (call.method == 'read' &&
              call.arguments['key'] == 'secure_token') {
            return token;
          }
          return null;
        });

    WebSocketService.resetForTest();
    service = WebSocketService.to;
    // Initialize subscriptions while logged out, so openSocket below owns the
    // first attempt instead of observing the automatic connection from init().
    service.init();
    await StorageService.to.setString(Keys.currentUid, 'synthetic-ws-owner');
  });

  tearDown(() async {
    await service.closeSocket(permanent: true);
    PersistentMessageQueue.to.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
    await StorageService.to.remove(Keys.currentUid);
  });

  test('stalled handshakes finish and advance the real retry counter', () {
    final client = _StalledHandshakeClient();
    fakeAsync((clock) {
      HttpOverrides.runZoned(() {
        var firstAttemptFinished = false;
        unawaited(
          service.openSocket(from: 'handshake-timeout-regression').then((_) {
            firstAttemptFinished = true;
          }),
        );
        clock.flushMicrotasks();
        expect(client.requests, hasLength(1));
        expect(service.status, SocketStatus.connecting);
        expect(service.getConnectionStats()['connection_attempts'], 0);

        clock.elapse(const Duration(seconds: 14));
        expect(firstAttemptFinished, isFalse);
        expect(client.requests, hasLength(1));
        expect(service.getConnectionStats()['connection_attempts'], 0);

        clock.elapse(const Duration(seconds: 1));
        expect(firstAttemptFinished, isTrue);
        expect(service.getConnectionStats()['connection_attempts'], 1);

        // The first retry's jitter is at most one second. A second actual
        // transport request proves _connecting no longer blocks reconnection.
        clock.elapse(const Duration(seconds: 1));
        expect(client.requests, hasLength(2));
        expect(service.status, SocketStatus.connecting);

        clock.elapse(const Duration(seconds: 15));
        expect(service.getConnectionStats()['connection_attempts'], 2);

        // Closing while the next handshake is pending must stop new attempts,
        // even after that stale handshake's timeout fires.
        unawaited(service.closeSocket(permanent: true));
        final attemptsAtClose = client.requests.length;
        clock.elapse(const Duration(minutes: 1));
        expect(client.requests, hasLength(attemptsAtClose));
        expect(service.status, SocketStatus.disconnected);
        expect(service.getConnectionStats()['connection_attempts'], 2);
      }, createHttpClient: (_) => client);
    });
  });
}
