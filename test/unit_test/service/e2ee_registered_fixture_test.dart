import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/e2ee_release/fixture_contract.dart';
import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';

FixtureSet fixture() => const FixtureSet(
  runTag: 'abc234',
  accounts: [
    SynthAccount(
      uid: 'a',
      role: 'a',
      devices: [
        SynthDevice(deviceId: 'a1', platform: 'android'),
        SynthDevice(deviceId: 'a2', platform: 'macos'),
      ],
    ),
    SynthAccount(
      uid: 'b',
      role: 'b',
      devices: [SynthDevice(deviceId: 'b1', platform: 'android')],
    ),
  ],
  groups: [
    SynthGroup(gid: 'group', memberUids: ['a', 'b']),
  ],
);

RegisteredDevice device(
  String alias,
  String owner,
  String id, {
  String? did,
  String? platform,
  String token = 'C11_TOKEN',
}) => RegisteredDevice(
  alias: alias,
  accountAlias: owner,
  accountId: id,
  did: did ?? alias,
  platform: platform ?? (alias == 'a2' ? 'macos' : 'android'),
  tokenReference: token,
);

List<RegisteredDevice> devices() => [
  device('a1', 'a', '9007199254740993'),
  device('a2', 'a', '9007199254740993'),
  device('b1', 'b', '9007199254740994'),
];

void main() {
  RegisteredFixture bind(
    List<RegisteredDevice> input, {
    String run = 'abc234',
    Map<String, String>? groups,
  }) => RegisteredFixture.bind(
    fixture: fixture(),
    runTag: run,
    devices: input,
    groupIds: groups ?? {'group': '9223372036854775807'},
  );

  test('keeps exact large IDs and snapshots immutable maps', () {
    final input = devices();
    final groups = {'group': '9223372036854775807'};
    final result = bind(input, groups: groups);
    input.clear();
    groups.clear();
    expect(result.devices['a1']!.accountId, '9007199254740993');
    expect(result.groupIds.length, 1);
    expect(() => result.devices.clear(), throwsUnsupportedError);
    expect(() => result.groupIds.clear(), throwsUnsupportedError);
  });
  test('rejects wrong run and incomplete binding', () {
    expect(() => bind(devices(), run: 'abc235'), throwsFormatException);
    expect(() => bind(devices()..removeLast()), throwsFormatException);
  });
  final invalid = <String, RegisteredDevice>{
    'unknown alias': device('other', 'a', '1'),
    'wrong owner': device('a1', 'b', '1'),
    'platform mismatch': device('a1', 'a', '1', platform: 'macos'),
    'simulated platform': device('a1', 'a', '1', platform: 'host-simulated'),
    'empty DID': device('a1', 'a', '1', did: ''),
    'DID whitespace': device('a1', 'a', '1', did: ' a1'),
    'token value': device('a1', 'a', '1', token: 'Bearer secret'),
    'overflow ID': device('a1', 'a', '9223372036854775808'),
    'leading zero ID': device('a1', 'a', '01'),
    'alias as ID': device('a1', 'a', 'c11-a'),
    'conflicting account': device('a1', 'a', '2'),
    'duplicate DID': device('a1', 'a', '9007199254740993', did: 'b1'),
    'reused account ID': device('a1', 'a', '9007199254740994'),
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      expect(() => bind(devices()..[0] = entry.value), throwsFormatException);
    });
  }
  test('rejects duplicate device and missing or unknown group', () {
    expect(() => bind(devices()..add(devices().first)), throwsFormatException);
    expect(() => bind(devices(), groups: {}), throwsFormatException);
    expect(
      () => bind(devices(), groups: {'other': '1'}),
      throwsFormatException,
    );
    expect(
      () => bind(devices(), groups: {'group': '0'}),
      throwsFormatException,
    );
  });
}
