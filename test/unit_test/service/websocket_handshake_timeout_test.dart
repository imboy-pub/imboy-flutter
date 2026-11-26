@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_connection_io.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _HandshakeEnv implements Env {
  _HandshakeEnv(this.port);
  final int port;

  @override
  String get apiBaseUrl => 'http://127.0.0.1:$port';

  @override
  String get wsUrl => 'ws://127.0.0.1:$port/ws';

  @override
  String get solidifiedKey => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Real HTTP for this fixture only; all other hosts and ports remain forbidden.
class _LoopbackHttpOverrides extends HttpOverrides {
  _LoopbackHttpOverrides(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionFactory = (uri, proxyHost, proxyPort) {
        if (uri.scheme != 'http' ||
            uri.host != '127.0.0.1' ||
            uri.port != port ||
            proxyHost != null ||
            proxyPort != null) {
          throw StateError('Only the loopback handshake fixture is allowed');
        }
        return Socket.startConnect(InternetAddress.loopbackIPv4, port);
      };
  }
}

/// Let real loopback I/O finish without advancing the handshake deadline.
Future<void> _waitForIo(FakeAsync clock, bool Function() completed) async {
  final waiting = Stopwatch()..start();
  while (!completed() && waiting.elapsed < const Duration(seconds: 5)) {
    clock.elapse(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  clock.elapse(Duration.zero);
  expect(completed(), isTrue);
}

Future<void> _waitForRequests(
  FakeAsync clock,
  List<HttpRequest> requests,
  int count,
) async {
  await _waitForIo(clock, () => requests.length >= count);
  expect(requests, hasLength(count));
  expect(requests.every(WebSocketTransformer.isUpgradeRequest), isTrue);
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

  test(
    'stalled handshakes release each connection and advance the retry counter',
    () async {
      // Parse the real upgrade, then retain its raw socket without replying.
      // Peer EOF proves client cleanup independently of HttpResponse.done.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <HttpRequest>[];
      final sockets = <Socket>[];
      final closedSockets = <Socket>{};
      server.listen((request) async {
        final socket = await request.response.detachSocket(writeHeaders: false);
        sockets.add(socket);
        socket.listen(
          (_) {},
          onDone: () {
            closedSockets.add(socket);
            socket.destroy();
          },
        );
        requests.add(request);
      });
      final environment = currentEnv;
      final previousEnv = envMap[environment];
      envMap[environment] = _HandshakeEnv(server.port);
      final clock = FakeAsync();
      var firstAttemptFinished = false;
      try {
        clock.run(
          (_) => HttpOverrides.runWithHttpOverrides(
            () => unawaited(
              service.openSocket(from: 'handshake-timeout-regression').then((
                _,
              ) {
                firstAttemptFinished = true;
              }),
            ),
            _LoopbackHttpOverrides(server.port),
          ),
        );
        await _waitForRequests(clock, requests, 1);
        expect(clock.elapsed, Duration.zero);
        expect(service.status, SocketStatus.connecting);
        expect(service.getConnectionStats()['connection_attempts'], 0);

        clock.elapse(const Duration(seconds: 14));
        expect(firstAttemptFinished, isFalse);
        expect(requests, hasLength(1));
        expect(service.getConnectionStats()['connection_attempts'], 0);

        clock.elapse(const Duration(seconds: 1));
        expect(firstAttemptFinished, isTrue);
        expect(service.getConnectionStats()['connection_attempts'], 1);
        await _waitForIo(clock, () => closedSockets.contains(sockets.first));
        expect(clock.elapsed, const Duration(seconds: 15));
        expect(sockets.length - closedSockets.length, lessThanOrEqualTo(1));

        // The first retry's jitter is at most one second. A second actual
        // transport request proves _connecting no longer blocks reconnection.
        clock.elapse(const Duration(seconds: 1));
        await _waitForRequests(clock, requests, 2);
        expect(service.status, SocketStatus.connecting);

        clock.elapse(const Duration(seconds: 15));
        expect(service.getConnectionStats()['connection_attempts'], 2);
        await _waitForIo(clock, () => closedSockets.contains(sockets[1]));
        expect(sockets.length - closedSockets.length, lessThanOrEqualTo(1));
        clock.elapse(const Duration(seconds: 2));
        await _waitForRequests(clock, requests, 3);
        expect(service.status, SocketStatus.connecting);

        // Closing while the next handshake is pending must stop new attempts,
        // even after that stale handshake's timeout fires.
        clock.run((_) => unawaited(service.closeSocket(permanent: true)));
        final attemptsAtClose = requests.length;
        clock.elapse(const Duration(minutes: 1));
        await _waitForIo(clock, () => closedSockets.length == sockets.length);
        expect(requests, hasLength(attemptsAtClose));
        expect(closedSockets, hasLength(attemptsAtClose));
        expect(service.status, SocketStatus.disconnected);
        expect(service.getConnectionStats()['connection_attempts'], 2);
      } finally {
        clock.run((_) => unawaited(service.closeSocket(permanent: true)));
        clock.elapse(const Duration(minutes: 1));
        try {
          for (final socket in sockets) {
            socket.destroy();
          }
        } finally {
          await server.close(force: true);
          await pumpEventQueue();
          clock.elapse(Duration.zero);
          if (previousEnv == null) {
            envMap.remove(environment);
          } else {
            envMap[environment] = previousEnv;
          }
        }
      }
    },
  );

  test(
    'native upgrade remains usable after its HTTP client is released',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      WebSocket? peer;
      WebSocketChannel? channel;
      StreamIterator<dynamic>? messages;
      server.listen((request) async {
        expect(
          request.headers.value(Keys.tokenKey),
          'synthetic-handshake-token',
        );
        final socket = await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (_) => kSubProtocolV2,
        );
        peer = socket;
        socket.listen(socket.add);
      });
      try {
        final connected = await HttpOverrides.runWithHttpOverrides(
          () => connectNativeWebSocket(
            'ws://127.0.0.1:${server.port}/ws',
            headers: {Keys.tokenKey: 'synthetic-handshake-token'},
            protocols: [kSubProtocolV2],
          ),
          _LoopbackHttpOverrides(server.port),
        );
        channel = connected;
        expect(connected.protocol, kSubProtocolV2);
        messages = StreamIterator<dynamic>(connected.stream);

        connected.sink.add('after-handshake-client-cleanup');
        expect(
          await messages.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(messages.current, 'after-handshake-client-cleanup');
        connected.sink.add(<int>[1, 2, 3]);
        expect(
          await messages.moveNext().timeout(const Duration(seconds: 5)),
          isTrue,
        );
        expect(messages.current, <int>[1, 2, 3]);
        expect(peer?.readyState, WebSocket.open);
      } finally {
        await channel?.sink.close();
        await messages?.cancel();
        await peer?.close();
        await server.close(force: true);
      }
    },
  );
}
