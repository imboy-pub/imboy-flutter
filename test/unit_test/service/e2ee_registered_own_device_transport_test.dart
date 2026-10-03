import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_wire_binding.dart';
import 'e2ee_registered_fanout_binding_test.dart' as fanout;
import 'e2ee_registered_wire_binding_test.dart' as bindings;
import 'e2ee_registered_backend_transport_test.dart' as frames;
import 'e2ee_release_socket_session_test.dart' as sockets;

WireFrame fullFrame({String receiver = 'a2'}) {
  final frame = bindings.wire();
  final devices = frame.body['e2ee']['devices'] as Map<String, dynamic>;
  for (final did in ['registered-b2', 'registered-a2']) {
    devices[did] = jsonDecode(jsonEncode(devices['registered-b']));
  }
  return WireFrame(
    messageId: frame.messageId,
    senderUid: 'a',
    senderDid: 'a1',
    recipientUid: 'b',
    recipientDid: receiver,
    body: frame.body,
  );
}

void main() {
  test(
    'physical self receiver preserves logical peer protected destination',
    () {
      final fixture = fanout.multi(ownDevice: true);
      final body = RegisteredWireBinding(fixture).prepareC2c(fullFrame());
      expect(body['to'], 9007199254740994);
      expect(
        () =>
            RegisteredWireBinding(fixture)
                .prepareC2c(fullFrame(receiver: 'a1')),
        throwsFormatException,
      );
      expect(
        () =>
            RegisteredWireBinding(fixture)
                .prepareC2c(fullFrame(receiver: 'unknown')),
        throwsFormatException,
      );
    },
  );
  test(
    'self-device stream queues ciphertext under physical device alias',
    () async {
      final fixture = fanout.multi(ownDevice: true);
      final channel = sockets.FakeSocket();
      final adapter = RegisteredBackendTransport(
        fixture: fixture,
        connector: (_, _) async => channel,
        tokenResolver: (_) async => 'synthetic-token',
        version: '1.0.0',
      );
      final transport = RealBackendTransport.registered(adapter);
      addTearDown(transport.dispose);
      await transport.start();
      await transport.connectDevice(
        const SynthDevice(deviceId: 'a2', platform: 'macos'),
      );
      final body = RegisteredWireBinding(fixture).prepareC2c(fullFrame());
      body['sender_did'] = 'registered-a';
      channel.input.add(frames.incoming(body));
      await Future<void>.delayed(Duration.zero);
      final received = transport.drainInbox('a2').single;
      expect(received.recipientUid, 'b');
      expect(received.recipientDid, 'a2');
      expect(received.body['to'], 9007199254740994);
      expect(transport.drainInbox('b1'), isEmpty);
      expect(channel.sent.length, 1); // heartbeat only, no automatic receipt
    },
  );
}
