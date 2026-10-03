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
  for (final attack in ['sender-did', 'sender-account', 'missing-device']) {
    test(
      'inbound $attack mismatch closes connection without queuing',
      () async {
        await transport.start();
        await transport.connectDevice(recipient);
        final body = RegisteredWireBinding(bindings.registered())
            .prepareC2c(bindings.wire());
        body['sender_did'] = 'registered-a';
        if (attack == 'sender-did') {
          body['sender_did'] = 'unknown-device';
        } else if (attack == 'sender-account') {
          body['from'] = 999;
        } else {
          (body['e2ee']['devices'] as Map).clear();
        }
        channels['b1']!.input.add(incoming(body));
        await Future<void>.delayed(Duration.zero);
        expect(transport.drainInbox('b1'), isEmpty);
        expect(transport.isDeviceConnected('b1'), isFalse);
        expect(channels['b1']!.closed, isTrue);
        // Only the handshake ping was sent; no automatic consumer ACK.
        expect(channels['b1']!.sent.length, 1);
      },
    );
  }
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
    expect(channels['b1']!.sent.length, 1); // no automatic ACK
    final confirmation = transport.acknowledgeReceived(inbox.single);
    final encoded = channels['b1']!.sent.last as Uint8List;
    final decoded = ImboyFrame.tryDecode(encoded)!;
    expect(decoded.frame.type, FrameType.msgC2S);
    expect(
      utf8.decode(decoded.frame.payload),
      'CLIENT_ACK,C2C,xid,registered-b',
    );
    channels['b1']!.input.add(
      incoming({
        'id': 'xid',
        'type': 'CLIENT_ACK_CONFIRM',
        'action': 'CLIENT_ACK_CONFIRM',
        'in_reply_to': 'xid',
      }),
    );
    await confirmation;
    expect(() => transport.acknowledgeReceived(inbox.single), throwsStateError);
  });
  for (final event in ['error', 'disconnect']) {
    test('receipt $event cannot become success', () async {
      await transport.start();
      await transport.connectDevice(recipient);
      final body = RegisteredWireBinding(bindings.registered())
          .prepareC2c(bindings.wire());
      body['sender_did'] = 'registered-a';
      channels['b1']!.input.add(incoming(body));
      await Future<void>.delayed(Duration.zero);
      final frame = transport.drainInbox('b1').single;
      final failure = expectLater(
        transport.acknowledgeReceived(frame),
        throwsA(isA<UnconfirmedDelivery>()),
      );
      if (event == 'error') {
        channels['b1']!.input.add(
          incoming({
            'id': 'xid',
            'type': 'CLIENT_ACK_ERROR',
            'action': 'CLIENT_ACK_ERROR',
            'in_reply_to': 'xid',
          }),
        );
      } else {
        await transport.disconnectDevice(recipient);
      }
      await failure;
      if (event == 'error') {
        expect(() => transport.acknowledgeReceived(frame), throwsStateError);
        channels['b1']!.input.add(
          incoming({
            'id': 'xid',
            'type': 'CLIENT_ACK_CONFIRM',
            'action': 'CLIENT_ACK_CONFIRM',
            'in_reply_to': 'xid',
          }),
        );
        await Future<void>.delayed(Duration.zero);
      }
    });
  }
  test('cannot acknowledge a locally generated outgoing frame', () {
    expect(
      () => transport.acknowledgeReceived(bindings.wire()),
      throwsStateError,
    );
  });
  test('receipt timeout and wrong confirmation remain unconfirmed', () async {
    await transport.start();
    await transport.connectDevice(recipient);
    final body = RegisteredWireBinding(bindings.registered())
        .prepareC2c(bindings.wire());
    body['sender_did'] = 'registered-a';
    channels['b1']!.input.add(incoming(body));
    await Future<void>.delayed(Duration.zero);
    final frame = transport.drainInbox('b1').single;
    final failure = expectLater(
      transport.acknowledgeReceived(frame),
      throwsA(isA<UnconfirmedDelivery>()),
    );
    channels['b1']!.input.add(
      incoming({
        'id': 'other',
        'type': 'CLIENT_ACK_CONFIRM',
        'action': 'CLIENT_ACK_CONFIRM',
        'in_reply_to': 'other',
      }),
    );
    await failure;
    expect(() => transport.acknowledgeReceived(frame), throwsStateError);
    channels['b1']!.input.add(
      incoming({
        'id': 'xid',
        'type': 'CLIENT_ACK_CONFIRM',
        'action': 'CLIENT_ACK_CONFIRM',
        'in_reply_to': 'xid',
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await transport.disconnectDevice(recipient);
    channels.remove('b1');
    await transport.connectDevice(recipient);
    final retried = transport.acknowledgeReceived(frame);
    channels['b1']!.input.add(
      incoming({
        'id': 'xid',
        'type': 'CLIENT_ACK_CONFIRM',
        'action': 'CLIENT_ACK_CONFIRM',
        'in_reply_to': 'xid',
      }),
    );
    await retried;
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
