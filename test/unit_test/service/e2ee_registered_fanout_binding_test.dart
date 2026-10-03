import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';
import '../../../integration_test/e2ee_release/harness/registered_wire_binding.dart';
import 'e2ee_registered_wire_binding_test.dart' as helpers;

RegisteredFixture multi() => RegisteredFixture.bind(
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
