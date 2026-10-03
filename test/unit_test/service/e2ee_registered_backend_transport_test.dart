import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_wire_binding.dart';
import 'e2ee_registered_wire_binding_test.dart' as bindings;
import 'e2ee_release_socket_session_test.dart' as sockets;

const sender = SynthDevice(deviceId: 'a1', platform: 'android');
const recipient = SynthDevice(deviceId: 'b1', platform: 'macos');

Uint8List incoming(Map<String, dynamic> body) => ImboyFrame.encode(
  type: FrameType.msgS2C,
  flags: 0,
  payload: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

void main() {
  late RegisteredBackendTransport adapter;
  late RealBackendTransport transport;
  late Map<String, sockets.FakeSocket> channels;
  setUp(() {
    channels = {};
    adapter = RegisteredBackendTransport(
      fixture: bindings.registered(),
      connector: (device, headers) async =>
          channels.putIfAbsent(device.alias, sockets.FakeSocket.new),
      tokenResolver: (_) async => 'synthetic-token',
      version: '1.0.0',
      timeout: const Duration(milliseconds: 100),
    );
    transport = RealBackendTransport.registered(adapter);
  });
  tearDown(() => transport.dispose());
  test('configured real interface requires matching server ACK', () async {
    await transport.start();
    await transport.connectDevice(sender);
    final sent = transport.send(bindings.wire());
    channels['a1']!.input.add(
      incoming({'id': 'xid', 'type': 'C2C_SERVER_ACK', 'in_reply_to': 'xid'}),
    );
    expect(await sent, DeliveryReceipt.accepted);
    expect(transport.drainInbox('b1'), isEmpty);
    expect(transport.isDeviceConnected('b1'), isFalse);
  });
  test('local send without server ACK stays unconfirmed', () async {
    await transport.start();
    await transport.connectDevice(sender);
    await expectLater(
      transport.send(bindings.wire()),
      throwsA(isA<UnconfirmedDelivery>()),
    );
  });
  test('disconnect completes pending delivery as unconfirmed', () async {
    await transport.start();
    await transport.connectDevice(sender);
    final failure = expectLater(
      transport.send(bindings.wire()),
      throwsA(isA<UnconfirmedDelivery>()),
    );
    await transport.disconnectDevice(sender);
    await failure;
  });
  test('actual received ciphertext queues once per drain', () async {
    await transport.start();
    await transport.connectDevice(recipient);
    final body = RegisteredWireBinding(bindings.registered())
        .prepareC2c(bindings.wire());
    body['sender_did'] = 'registered-a';
    channels['b1']!.input.add(incoming(body));
    await Future<void>.delayed(Duration.zero);
    final inbox = transport.drainInbox('b1');
    expect(inbox.single.messageId, 'xid');
    expect(inbox.single.senderDid, 'a1');
    expect(transport.drainInbox('b1'), isEmpty);
  });
  test('synthetic protected identities fail before channel write', () async {
    await transport.start();
    await transport.connectDevice(sender);
    await expectLater(
      transport.send(bindings.wire(senderUid: 'a')),
      throwsFormatException,
    );
    expect(channels['a1']!.sent.length, 1);
  });
  test(
    'disconnect during token resolution prevents later connection',
    () async {
      final token = Completer<String>();
      var connectors = 0;
      final pendingAdapter = RegisteredBackendTransport(
        fixture: bindings.registered(),
        tokenResolver: (_) => token.future,
        version: '1.0.0',
        connector: (_, _) async {
          connectors++;
          return sockets.FakeSocket();
        },
      );
      await pendingAdapter.start();
      final failure = expectLater(
        pendingAdapter.connectDevice(sender),
        throwsStateError,
      );
      await pendingAdapter.disconnectDevice(sender);
      token.complete('synthetic-token');
      await failure;
      expect(connectors, 0);
      await pendingAdapter.dispose();
    },
  );
}
