import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/backend_transport.dart';
import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';
import '../../../integration_test/e2ee_release/harness/registered_wire_binding.dart';

RegisteredFixture registered() => RegisteredFixture.bind(
  fixture: const FixtureSet(
    runTag: 'abc234',
    accounts: [
      SynthAccount(
        uid: 'a',
        role: 'a',
        devices: [SynthDevice(deviceId: 'a1', platform: 'android')],
      ),
      SynthAccount(
        uid: 'b',
        role: 'b',
        devices: [SynthDevice(deviceId: 'b1', platform: 'macos')],
      ),
    ],
    groups: [],
  ),
  runTag: 'abc234',
  groupIds: {},
  devices: const [
    RegisteredDevice(
      alias: 'a1',
      accountAlias: 'a',
      accountId: '9007199254740993',
      did: 'registered-a',
      platform: 'android',
      tokenReference: 'A_TOKEN',
    ),
    RegisteredDevice(
      alias: 'b1',
      accountAlias: 'b',
      accountId: '9007199254740994',
      did: 'registered-b',
      platform: 'macos',
      tokenReference: 'B_TOKEN',
    ),
  ],
);

WireFrame wire({
  String senderUid = '9007199254740993',
  String senderDid = 'registered-a',
  String destination = 'registered-b',
  String conversation = '9007199254740994',
  String id = 'xid',
}) {
  final context = FrameContext(
    messageId: id,
    scope: FrameScope.c2c,
    conversationId: conversation,
    senderUid: senderUid,
    senderDid: senderDid,
    destination: destination,
    messageType: 'text',
    action: '',
    createdAtMs: 123,
    protocol: 'olm',
    protocolVersion: 3,
    sessionRef: 'session',
    epochOrCounter: 1,
  );
  return WireFrame(
    messageId: 'xid',
    senderUid: 'a',
    senderDid: 'a1',
    recipientUid: 'b',
    recipientDid: 'b1',
    body: {
      'id': 'xid',
      'type': 'C2C',
      'payload': '',
      'e2ee': {
        'meta_version': 3,
        'fan_out': 'per_device',
        'devices': {
          'registered-b': ProtectedFrameV3.encodeOuterEnvelope(
            context: context,
            ciphertext: Uint8List.fromList([1, 2, 3]),
            protocolMetadata: const {'olm_message_type': 1},
          ),
        },
      },
    },
  );
}

void main() {
  final binding = RegisteredWireBinding(registered());
  test('binds exact registered IDs without rewriting protected header', () {
    final frame = wire();
    final result = binding.prepareC2c(frame);
    expect(result['from'], 9007199254740993);
    expect(result['to'], 9007199254740994);
    expect(result['msg_type'], 'text');
    expect(result['e2ee'], frame.body['e2ee']);
    frame.body['e2ee'] = null;
    expect(result['e2ee'], isNotNull);
  });
  final cases = <String, WireFrame>{
    'synthetic sender uid': wire(senderUid: 'a'),
    'synthetic sender DID': wire(senderDid: 'a1'),
    'synthetic destination': wire(destination: 'b1'),
    'wrong conversation': wire(conversation: '1'),
    'wrong protected ID': wire(id: 'other'),
  };
  for (final entry in cases.entries) {
    test('rejects ${entry.key} instead of rewriting cryptographic context', () {
      expect(() => binding.prepareC2c(entry.value), throwsFormatException);
    });
  }
  test('rejects conflicting outer fields', () {
    for (final entry in {
      'from': 1,
      'to': 2,
      'msg_type': 'image',
      'action': 'edit',
      'created_at': 124,
    }.entries) {
      final frame = wire();
      frame.body[entry.key] = entry.value;
      expect(() => binding.prepareC2c(frame), throwsFormatException);
    }
  });
  test('rejects plaintext in the supposedly encrypted payload', () {
    final frame = wire();
    frame.body['payload'] = 'plaintext canary';
    expect(() => binding.prepareC2c(frame), throwsFormatException);
  });
  test('rejects bad hash unknown device and wrong message type', () {
    final frame = wire();
    final e2ee = frame.body['e2ee'] as Map<String, dynamic>;
    final devices = e2ee['devices'] as Map<String, dynamic>;
    (devices['registered-b'] as Map<String, dynamic>)['header_hash'] = 'bad';
    expect(() => binding.prepareC2c(frame), throwsFormatException);
    devices['unknown'] = devices.remove('registered-b');
    expect(() => binding.prepareC2c(frame), throwsFormatException);
    frame.body['type'] = 'C2G';
    expect(() => binding.prepareC2c(frame), throwsFormatException);
  });
}
