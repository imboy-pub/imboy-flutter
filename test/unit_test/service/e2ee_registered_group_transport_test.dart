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
