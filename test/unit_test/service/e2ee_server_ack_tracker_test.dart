import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/e2ee_release/harness/server_ack_tracker.dart';

void main() {
  late ServerAckTracker tracker;
  setUp(() => tracker = ServerAckTracker());
  PendingServerAck request({
    String device = 'a',
    String type = 'C2C',
    int generation = 1,
  }) => PendingServerAck(device, 'xid', type, 100, generation);
  Map<String, dynamic> ack([String type = 'C2C']) => {
    'id': 'xid',
    'in_reply_to': 'xid',
    'type': '${type}_SERVER_ACK',
  };
  ServerAckResult? receive(
    Map<String, dynamic> message, {
    String device = 'a',
    int generation = 1,
    int now = 99,
  }) => tracker.receive(
    deviceAlias: device,
    connectionGeneration: generation,
    now: now,
    message: message,
  );

  for (final type in ['C2C', 'C2G']) {
    test('$type ACK only completes exact matching request once', () {
      tracker.register(request(type: type));
      expect(receive(ack(type))!.outcome, ServerAckOutcome.accepted);
      expect(receive(ack(type)), isNull);
      expect(() => tracker.register(request(type: type)), throwsStateError);
    });
  }
  final invalid = <String, Map<String, dynamic>>{
    'different ID': {...ack(), 'id': 'other'},
    'different reply': {...ack(), 'in_reply_to': 'other'},
    'missing reply': {'id': 'xid', 'type': 'C2C_SERVER_ACK'},
    'numeric ID': {...ack(), 'id': 123},
    'wrong direction': ack('C2G'),
    'client confirmation': {...ack(), 'type': 'CLIENT_ACK_CONFIRM'},
    'business error': {...ack(), 'type': 'S2C', 'action': 'permission_denied'},
  };
  for (final entry in invalid.entries) {
    test('does not accept ${entry.key}', () {
      tracker.register(request());
      expect(receive(entry.value), isNull);
      expect(receive(ack())!.outcome, ServerAckOutcome.accepted);
    });
  }
  test('other devices and stale connections cannot complete pending send', () {
    tracker.register(request());
    expect(receive(ack(), device: 'b'), isNull);
    expect(receive(ack(), generation: 0), isNull);
    expect(receive(ack())!.outcome, ServerAckOutcome.accepted);
  });
  test('deadline and late ACK remain unconfirmed', () {
    tracker.register(request());
    expect(receive(ack(), now: 100)!.outcome, ServerAckOutcome.unconfirmed);
    expect(receive(ack(), now: 101), isNull);
    expect(() => tracker.register(request()), throwsStateError);
  });
  test('expiry is exact and does not imply rejection or offline recipient', () {
    tracker.register(request());
    expect(tracker.expire(99), isEmpty);
    final expired = tracker.expire(100);
    expect(expired.single.outcome, ServerAckOutcome.unconfirmed);
    expect(() => expired.clear(), throwsUnsupportedError);
    expect(tracker.expire(101), isEmpty);
  });
  test('disconnect drains only its generation and device', () {
    tracker.register(request());
    tracker.register(request(device: 'b', generation: 2));
    expect(tracker.disconnect('a', 0), isEmpty);
    expect(
      tracker.disconnect('a', 1).single.outcome,
      ServerAckOutcome.unconfirmed,
    );
    expect(
      receive(ack(), device: 'b', generation: 2)!.outcome,
      ServerAckOutcome.accepted,
    );
  });
  test('rejects malformed registrations and negative clock', () {
    expect(() => tracker.register(request(type: 'S2C')), throwsFormatException);
    expect(
      () => tracker.register(request(generation: -1)),
      throwsFormatException,
    );
    expect(() => tracker.expire(-1), throwsFormatException);
    expect(() => receive(ack(), now: -1), throwsFormatException);
  });
}
