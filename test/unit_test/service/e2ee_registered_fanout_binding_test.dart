import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';
import '../../../integration_test/e2ee_release/harness/registered_wire_binding.dart';
import 'e2ee_registered_wire_binding_test.dart' as helpers;

RegisteredFixture multi({bool ownDevice = false}) => RegisteredFixture.bind(
  fixture: FixtureSet(
    runTag: 'abc234',
    accounts: [
      SynthAccount(
        uid: 'a',
        role: 'a',
        devices: [
          const SynthDevice(deviceId: 'a1', platform: 'android'),
          if (ownDevice) const SynthDevice(deviceId: 'a2', platform: 'macos'),
        ],
      ),
      SynthAccount(
        uid: 'b',
        role: 'b',
        devices: [
          SynthDevice(deviceId: 'b1', platform: 'macos'),
          SynthDevice(deviceId: 'b2', platform: 'android'),
        ],
      ),
    ],
    groups: [],
  ),
  runTag: 'abc234',
  groupIds: {},
  devices: [
    ...helpers.registered().devices.values,
    if (ownDevice)
      const RegisteredDevice(
        alias: 'a2',
        accountAlias: 'a',
        accountId: '9007199254740993',
        did: 'registered-a2',
        platform: 'macos',
        tokenReference: 'A2_TOKEN',
      ),
    const RegisteredDevice(
      alias: 'b2',
      accountAlias: 'b',
      accountId: '9007199254740994',
      did: 'registered-b2',
      platform: 'android',
      tokenReference: 'B2_TOKEN',
    ),
  ],
);

void main() {
  final binding = RegisteredWireBinding(multi());
  test('requires sender other device but excludes current sender device', () {
    final ownBinding = RegisteredWireBinding(multi(ownDevice: true));
    final frame = helpers.wire();
    final devices = frame.body['e2ee']['devices'] as Map<String, dynamic>;
    devices['registered-b2'] = jsonDecode(jsonEncode(devices['registered-b']));
    expect(() => ownBinding.prepareC2c(frame), throwsFormatException);
    devices['registered-a2'] = jsonDecode(jsonEncode(devices['registered-b']));
    expect(ownBinding.prepareC2c(frame)['to'], 9007199254740994);
    devices['registered-a'] = jsonDecode(jsonEncode(devices['registered-b']));
    expect(() => ownBinding.prepareC2c(frame), throwsFormatException);
  });
  for (final mutation in <String, Object>{
    'message_type': 'image',
    'action': 'edit',
    'created_at_ms': 124,
  }.entries) {
    test('rejects independently valid different ${mutation.key}', () {
      final frame = helpers.wire();
      final devices = frame.body['e2ee']['devices'] as Map<String, dynamic>;
      final original = {
        'meta_version': 3,
        ...devices['registered-b'] as Map<String, dynamic>,
      };
      final header = Map<String, dynamic>.from(
        ProtectedFrameV3.verifyOuterEnvelope(original).decodedHeader!,
      )..[mutation.key] = mutation.value;
      devices['registered-b2'] = ProtectedFrameV3.encodeOuterEnvelope(
        context: FrameContext.fromHeader(header),
        ciphertext: Uint8List.fromList([4, 5, 6]),
        protocolMetadata: const {'session_id': 'session'},
      )..remove('meta_version');
      expect(() => binding.prepareC2c(frame), throwsFormatException);
    });
  }
  test('requires both registered recipient envelopes', () {
    final frame = helpers.wire();
    expect(() => binding.prepareC2c(frame), throwsFormatException);
    final devices = frame.body['e2ee']['devices'] as Map<String, dynamic>;
    // Structural oracle only; identical fixture ciphertext is not crypto proof.
    devices['registered-b2'] = jsonDecode(jsonEncode(devices['registered-b']));
    expect(binding.prepareC2c(frame)['to'], 9007199254740994);
  });
  test('validates every envelope instead of only selected receiver', () {
    final frame = helpers.wire();
    final devices = frame.body['e2ee']['devices'] as Map<String, dynamic>;
    devices['registered-b2'] = jsonDecode(jsonEncode(devices['registered-b']));
    devices['registered-b2']['header_hash'] = 'bad';
    expect(() => binding.prepareC2c(frame), throwsFormatException);
  });
  test('rejects unknown target and explicitly skipped targets', () {
    final frame = helpers.wire();
    final e2ee = frame.body['e2ee'];
    final devices = e2ee['devices'] as Map<String, dynamic>;
    devices['unknown'] = jsonDecode(jsonEncode(devices['registered-b']));
    expect(() => binding.prepareC2c(frame), throwsFormatException);
    devices['registered-b2'] = devices.remove('unknown');
    e2ee['skipped_devices'] = {'registered-b2': 'transient'};
    expect(() => binding.prepareC2c(frame), throwsFormatException);
  });
}
