import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';

import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';
import '../../../integration_test/e2ee_release/harness/release_socket_session.dart';

class FakeSocket implements ReleaseSocket {
  final input = StreamController<Object>.broadcast();
  final sent = <Object>[];
  bool closed = false;
  bool reply = true;
  @override
  String? protocol = 'imboy.v2';
  @override
  Future<void> get ready async {}
  @override
  Stream<Object> get messages => input.stream;
  @override
  void send(Object data) {
    sent.add(data);
    if (sent.length == 1 && reply) {
      input.add(protocol == 'imboy.v2' ? ImboyFrame.heartbeatPong(1) : 'pong');
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await input.close();
  }
}

const device = RegisteredDevice(
  alias: 'a',
  accountAlias: 'a',
  accountId: '1',
  did: 'device-a',
  platform: 'android',
  tokenReference: 'C11_TOKEN',
);

void main() {
  late ReleaseSocketSession session;
  late FakeSocket socket;
  late List<Object> frames;
  late int closedCount;
  setUp(() {
    socket = FakeSocket();
    frames = [];
    closedCount = 0;
    session = ReleaseSocketSession(
      onFrame: frames.add,
      onClosed: () => closedCount++,
    );
  });
  tearDown(() => session.disconnect());
  Future<void> connect({
    Duration timeout = const Duration(seconds: 1),
    Future<ReleaseSocket> Function(Map<String, String>)? connector,
  }) => session.connect(
    connector: connector ?? (_) async => socket,
    device: device,
    token: 'synthetic-token',
    version: '1.0.0',
    timeout: timeout,
  );

  test(
    'old pending connector failure cannot cancel new pending connector',
    () async {
      final oldConnector = Completer<ReleaseSocket>();
      final newConnector = Completer<ReleaseSocket>();
      final old = connect(connector: (_) => oldConnector.future);
      final oldFailure = expectLater(old, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      final newer = connect(connector: (_) => newConnector.future);
      await Future<void>.delayed(Duration.zero);
      oldConnector.completeError(StateError('old connector failed'));
      await oldFailure;
      newConnector.complete(socket);
      await newer;
      expect(session.connected, isTrue);
      expect(socket.closed, isFalse);
    },
  );
  test('late connector after timeout is closed', () async {
    final delayed = Completer<ReleaseSocket>();
    final future = connect(
      connector: (_) => delayed.future,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(future, throwsStateError);
    delayed.complete(socket);
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isTrue);
    expect(session.connected, isFalse);
  });
  test('unsupported protocol closes socket', () async {
    socket.protocol = 'unknown';
    await expectLater(connect(), throwsStateError);
    expect(socket.closed, isTrue);
  });
  test('requires session-validating pong before send', () async {
    expect(() => session.send({'id': 'x', 'type': 'C2C'}), throwsStateError);
    Map<String, String>? headers;
    await connect(
      connector: (value) async {
        headers = value;
        return socket;
      },
    );
    expect(headers, {
      'authorization': 'Bearer synthetic-token',
      'did': 'device-a',
      'cos': 'android',
      'vsn': '1.0.0',
    });
    expect(session.connected, isTrue);
    session.send({'id': 'x', 'type': 'C2C'});
    expect(socket.sent.length, 2);
  });
  test('legacy negotiated protocol uses text heartbeat', () async {
    socket.protocol = 'text';
    await connect();
    expect(socket.sent.first, 'ping');
    expect(session.connected, isTrue);
  });
  test('wrong pong never confirms and timeout closes channel', () async {
    socket.reply = false;
    final future = connect(timeout: const Duration(milliseconds: 20));
    await Future<void>.delayed(Duration.zero);
    socket.input.add(ImboyFrame.heartbeatPong(2));
    await expectLater(future, throwsStateError);
    expect(session.connected, isFalse);
    expect(socket.closed, isTrue);
  });
  test(
    'early authentication error fails without leaking server payload',
    () async {
      socket.reply = false;
      final future = connect();
      await Future<void>.delayed(Duration.zero);
      socket.input.add('{"code":401,"msg":"private"}');
      await expectLater(future, throwsStateError);
      expect(socket.closed, isTrue);
    },
  );
  test('close after validation invalidates session', () async {
    await connect();
    socket.input.addError(StateError('private transport detail'));
    await Future<void>.delayed(Duration.zero);
    expect(session.connected, isFalse);
    expect(closedCount, 1);
    await session.cleanup;
    expect(socket.closed, isTrue);
    expect(() => session.send({'id': 'x', 'type': 'C2C'}), throwsStateError);
  });
  test(
    'superseded connector is closed and cannot replace newer connection',
    () async {
      final delayed = Completer<ReleaseSocket>();
      final old = connect(connector: (_) => delayed.future);
      await Future<void>.delayed(Duration.zero);
      final newer = FakeSocket();
      await connect(connector: (_) async => newer);
      delayed.complete(socket);
      await expectLater(old, throwsStateError);
      expect(socket.closed, isTrue);
      expect(session.connected, isTrue);
      expect(newer.closed, isFalse);
    },
  );
}
