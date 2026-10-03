import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import '../../../integration_test/e2ee_release/harness/registered_group_binding.dart';
import '../../../integration_test/e2ee_release/fixture_contract.dart';
import 'e2ee_registered_fixture_test.dart' as fixtures;
import '../../../integration_test/e2ee_release/harness/registered_fixture.dart';

Map<String, dynamic> body({
  String gid = '9223372036854775807',
  String id = 'gid',
}) => {
  'id': id,
  'type': 'C2G',
  'payload': '',
  'e2ee': ProtectedFrameV3.encodeOuterEnvelope(
    context: FrameContext(
      messageId: id,
      scope: FrameScope.group,
      conversationId: gid,
      destination: gid,
      senderUid: '9007199254740993',
      senderDid: 'a1',
      messageType: 'text',
      action: 'message',
      createdAtMs: 123,
      protocol: 'megolm',
      protocolVersion: 1,
      sessionRef: 'session',
      epochOrCounter: 1,
    ),
    ciphertext: Uint8List.fromList([1, 2, 3]),
    protocolMetadata: const {'session_id': 'session'},
  ),
};

void main() {
  final fixture = RegisteredFixture.bind(
    fixture: fixtures.fixture(),
    runTag: 'abc234',
    devices: fixtures.devices(),
    groupIds: {'group': '9223372036854775807'},
  );
  final binding = RegisteredGroupBinding(fixture);
  Map<String, dynamic> prepare(
    Map<String, dynamic> value, {
    String group = 'group',
    String sender = 'a1',
    String id = 'gid',
  }) => binding.prepare(
    messageId: id,
    senderAlias: sender,
    groupAlias: group,
    body: value,
  );
  Map<String, dynamic> downlink(String time) => body()
    ..['from'] = '9007199254740993'
    ..['to'] = '9223372036854775807'
    ..['sender_did'] = 'a1'
    ..['created_at'] = time;
  test('received RFC3339 offsets bind the same exact protected instant', () {
    for (final time in [
      '1970-01-01T00:00:00.123Z',
      '1970-01-01T08:00:00.123+08:00',
      '1969-12-31T19:00:00.123-05:00',
    ]) {
      final result = binding.receive('b1', downlink(time));
      expect(result.body['created_at'], time);
    }
  });
  test('received timestamps reject calendar overflow missing zone and precision loss', () {
    for (final time in [
      '1969-12-32T00:00:00.123Z',
      '1970-01-01T00:00:00.123',
      '1970-01-01T00:00:00.1231Z',
      '1970-01-01T00:00:00.123+24:00',
    ]) {
      expect(
        () => binding.receive('b1', downlink(time)),
        throwsFormatException,
      );
    }
  });
  test('received group frames reject unregistered receiver aliases', () {
    expect(
      () => binding.receive('unknown', downlink('1970-01-01T00:00:00.123Z')),
      throwsFormatException,
    );
  });
  test('outgoing group numeric context rejects floating point values', () {
    for (final entry in {
      'from': 9007199254740993,
      'to': 9223372036854775807,
      'created_at': 123,
    }.entries) {
      final frame = body();
      frame[entry.key] = entry.value.toDouble();
      expect(() => prepare(frame), throwsFormatException);
    }
  });
  test('binds group IDs and snapshots original encrypted envelope', () {
    final original = body();
    final result = prepare(original);
    expect(result['to'], 9223372036854775807);
    expect(result['from'], 9007199254740993);
    expect(original.containsKey('to'), isFalse);
    original['e2ee'].clear();
    expect((result['e2ee'] as Map).isNotEmpty, isTrue);
  });
  test('rejects unregistered group and device aliases', () {
    expect(() => prepare(body(), group: 'unknown'), throwsFormatException);
    expect(() => prepare(body(), sender: 'unknown'), throwsFormatException);
  });
  test('rejects cross-group protected context and outer context mismatch', () {
    expect(() => prepare(body(gid: '2')), throwsFormatException);
    expect(() => prepare(body()..['to'] = 2), throwsFormatException);
  });
  test('rejects mismatched sender session and empty ciphertext', () {
    final wrongSender = body();
    wrongSender['from'] = 9007199254740994;
    expect(() => prepare(wrongSender), throwsFormatException);
    final wrongSession = body();
    wrongSession['e2ee']['protocol_metadata'] = {'session_id': 'other'};
    expect(() => prepare(wrongSession), throwsFormatException);
    for (final value in ['', null, 1, true]) {
      final empty = body();
      empty['e2ee']['ciphertext'] = value;
      expect(() => prepare(empty), throwsFormatException);
    }
    final missing = body();
    missing['e2ee'].remove('ciphertext');
    expect(() => prepare(missing), throwsFormatException);
  });
  test('rejects registered sender outside initial group membership', () {
    final baseline = fixtures.fixture();
    final restricted = RegisteredFixture.bind(
      fixture: FixtureSet(
        runTag: baseline.runTag,
        accounts: baseline.accounts,
        groups: [
          const SynthGroup(gid: 'group', memberUids: ['b']),
        ],
      ),
      runTag: baseline.runTag,
      devices: fixtures.devices(),
      groupIds: {'group': '9223372036854775807'},
    );
    expect(
      () => RegisteredGroupBinding(restricted).prepare(
        messageId: 'gid',
        senderAlias: 'a1',
        groupAlias: 'group',
        body: body(),
      ),
      throwsFormatException,
    );
  });
  test('rejects C2C fanout and UTF8 message ID overflow', () {
    final fanout = body();
    fanout['e2ee']['fan_out'] = 'per_device';
    expect(() => prepare(fanout), throwsFormatException);
    final id = List.filled(14, '群').join();
    expect(() => prepare(body(id: id), id: id), throwsFormatException);
  });
}
