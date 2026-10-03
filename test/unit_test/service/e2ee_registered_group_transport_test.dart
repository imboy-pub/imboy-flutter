import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';
import 'e2ee_registered_fixture_test.dart' as fixtures;
import 'e2ee_registered_group_binding_test.dart' as envelopes;
import 'e2ee_registered_backend_transport_test.dart' as frames;
import 'e2ee_release_socket_session_test.dart' as sockets;

void main() {
  late RealBackendTransport transport;
  late sockets.FakeSocket socket;
  setUp(() {
    socket = sockets.FakeSocket();
    final fixture = RegisteredFixture.bind(
      fixture: fixtures.fixture(),
      runTag: 'abc234',
      devices: fixtures.devices(),
      groupIds: {'group': '9223372036854775807'},
    );
    transport = RealBackendTransport.registered(
      RegisteredBackendTransport(
        fixture: fixture,
        connector: (_, _) async => socket,
        tokenResolver: (_) async => 'synthetic-token',
        version: '1.0.0',
        timeout: const Duration(milliseconds: 100),
      ),
    );
  });
  tearDown(() => transport.dispose());
  Future<DeliveryReceipt> send({String group = 'group'}) => transport.sendGroup(
    messageId: 'gid',
    senderAlias: 'a1',
    groupAlias: group,
    body: envelopes.body(),
  );
  Future<void> connect() async {
    await transport.start();
    await transport.connectDevice(
      const SynthDevice(deviceId: 'a1', platform: 'android'),
    );
  }

  Future<void> connectReceiver() async {
    await transport.start();
    await transport.connectDevice(
      const SynthDevice(deviceId: 'b1', platform: 'android'),
    );
  }

  Map<String, dynamic> downlink() => envelopes.body()
    ..['from'] = '9007199254740993'
    ..['to'] = '9223372036854775807'
    ..['sender_did'] = 'a1'
    ..['created_at'] = '1970-01-01T00:00:00.123Z';
  test(
    'C2G incoming ciphertext uses a separate group queue and retains raw time',
    () async {
      await connectReceiver();
      socket.input.add(frames.incoming(downlink()));
      await Future<void>.delayed(Duration.zero);
      final received = transport.drainGroupInbox('b1');
      expect(received.single.groupAlias, 'group');
      expect(received.single.senderAlias, 'a1');
      expect(received.single.receiverAlias, 'b1');
      expect(received.single.body['created_at'], '1970-01-01T00:00:00.123Z');
      expect(transport.drainInbox('b1'), isEmpty);
      expect(transport.drainGroupInbox('b1'), isEmpty);
      expect(
        () => (received.single.body['e2ee'] as Map).clear(),
        throwsUnsupportedError,
      );
      expect(socket.sent.length, 1); // no automatic consumer ACK
    },
  );
  for (final attack in ['group', 'sender', 'timestamp', 'float']) {
    test('C2G $attack mismatch closes without queuing', () async {
      await connectReceiver();
      final frame = downlink();
      if (attack == 'group') frame['to'] = '2';
      if (attack == 'sender') frame['sender_did'] = 'unknown';
      if (attack == 'timestamp') {
        frame['created_at'] = '1970-01-01T00:00:00.124Z';
      }
      if (attack == 'float') frame['from'] = 9007199254740993.0;
      socket.input.add(frames.incoming(frame));
      await Future<void>.delayed(Duration.zero);
      expect(transport.drainGroupInbox('b1'), isEmpty);
      expect(transport.isDeviceConnected('b1'), isFalse);
      expect(socket.closed, isTrue);
    });
  }
  test('registered C2G requires its matching server ACK', () async {
    await connect();
    final result = send();
    socket.input.add(
      frames.incoming({
        'id': 'gid',
        'type': 'C2G_SERVER_ACK',
        'in_reply_to': 'gid',
      }),
    );
    expect(await result, DeliveryReceipt.accepted);
    expect(transport.drainInbox('b1'), isEmpty);
  });
  test('C2C ACK cannot confirm C2G even with matching message ID', () async {
    await connect();
    final result = expectLater(send(), throwsA(isA<UnconfirmedDelivery>()));
    socket.input.add(
      frames.incoming({
        'id': 'gid',
        'type': 'C2C_SERVER_ACK',
        'in_reply_to': 'gid',
      }),
    );
    await result;
  });
  test('no server ACK remains unconfirmed after local write', () async {
    await connect();
    await expectLater(send(), throwsA(isA<UnconfirmedDelivery>()));
  });
  test('unknown group fails before writing a group frame', () async {
    await connect();
    await expectLater(send(group: 'unknown'), throwsFormatException);
    expect(socket.sent.length, 1);
  });
}
