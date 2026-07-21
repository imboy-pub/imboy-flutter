import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/trust_event_canonical.dart';
import 'package:imboy/service/e2ee/trust_event_client.dart';

const _validEventId = '3b1e0c4a-5f2d-4a1b-9c3e-7d8f0a1b2c3d';

TrustEventCanonicalFields _fields({
  String fromState = 'unverified',
  String toState = 'verified',
  int issuedAt = 1700000000000,
  int expiresAt = 1700000060000,
}) => TrustEventCanonicalFields(
  actorDeviceGeneration: 1,
  actorUid: 100,
  eventId: _validEventId,
  expiresAt: expiresAt,
  fromState: fromState,
  issuedAt: issuedAt,
  targetDeviceId: 'phone-b',
  targetEd25519: 'ZWQtYg==',
  targetIdentityVersion: 1,
  targetUid: 200,
  toState: toState,
);

void main() {
  group('isValidTrustTransition (§3.2 whitelist mirror)', () {
    test('accepts exactly the 5 backend-allowed transitions', () {
      expect(isValidTrustTransition('unverified', 'verified'), isTrue);
      expect(isValidTrustTransition('verified', 'unverified'), isTrue);
      expect(isValidTrustTransition('unverified', 'revoked'), isTrue);
      expect(isValidTrustTransition('verified', 'revoked'), isTrue);
      expect(isValidTrustTransition('revoked', 'unverified'), isTrue);
    });

    test('rejects non-whitelisted transitions', () {
      expect(isValidTrustTransition('revoked', 'verified'), isFalse);
      expect(isValidTrustTransition('verified', 'verified'), isFalse);
      expect(isValidTrustTransition('unverified', 'unverified'), isFalse);
      expect(isValidTrustTransition('bogus', 'verified'), isFalse);
    });
  });

  group('isFreshTrustEvent (fresh/2 mirror)', () {
    const now = 1700000000000;
    test('accepts in-window event', () {
      expect(isFreshTrustEvent(now, now + 60000, nowMs: now), isTrue);
    });
    test('rejects issued_at too far in past (> 5min)', () {
      expect(
        isFreshTrustEvent(now - kFreshPastMs - 1, now, nowMs: now),
        isFalse,
      );
    });
    test('rejects issued_at too far in future (> 2min skew)', () {
      final issued = now + kFreshFutureMs + 1;
      expect(isFreshTrustEvent(issued, issued + 1000, nowMs: now), isFalse);
    });
    test('rejects ttl beyond 5min', () {
      expect(isFreshTrustEvent(now, now + kMaxTtlMs + 1, nowMs: now), isFalse);
    });
    test('rejects expires_at <= issued_at', () {
      expect(isFreshTrustEvent(now, now, nowMs: now), isFalse);
    });
    test('rejects already-expired event (now > expires_at)', () {
      expect(isFreshTrustEvent(now - 1000, now - 1, nowMs: now), isFalse);
    });
  });

  group('buildTrustRecordRequest', () {
    test('builds 13-field body without actor_uid (server injects it)', () {
      final body = buildTrustRecordRequest(
        fields: _fields(),
        actorDeviceId: 'phone-a',
        method: 'qr_scan',
        actorSignatureB64: 'c2ln',
      );
      expect(body.containsKey('actor_uid'), isFalse);
      expect(body.length, 13);
      expect(body['actor_device_id'], 'phone-a');
      expect(body['target_uid'], 200);
      expect(body['from_state'], 'unverified');
      expect(body['to_state'], 'verified');
      expect(body['method'], 'qr_scan');
      expect(body['event_id'], _validEventId);
      expect(body['actor_signature'], 'c2ln');
      expect(body['actor_device_generation'], 1);
      expect(body['target_identity_version'], 1);
    });

    test('rejects invalid method', () {
      expect(
        () => buildTrustRecordRequest(
          fields: _fields(),
          actorDeviceId: 'phone-a',
          method: 'telepathy',
          actorSignatureB64: 'c2ln',
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-whitelisted transition', () {
      expect(
        () => buildTrustRecordRequest(
          fields: _fields(fromState: 'revoked', toState: 'verified'),
          actorDeviceId: 'phone-a',
          method: 'qr_scan',
          actorSignatureB64: 'c2ln',
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty actorDeviceId and empty signature', () {
      expect(
        () => buildTrustRecordRequest(
          fields: _fields(),
          actorDeviceId: '',
          method: 'qr_scan',
          actorSignatureB64: 'c2ln',
        ),
        throwsArgumentError,
      );
      expect(
        () => buildTrustRecordRequest(
          fields: _fields(),
          actorDeviceId: 'phone-a',
          method: 'qr_scan',
          actorSignatureB64: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('TrustChangedEvent.fromBroadcast', () {
    Map<String, dynamic> validPayload() => {
      'actor_uid': 100,
      'target_uid': 200,
      'target_device_id': 'phone-b',
      'to_state': 'verified',
      'method': 'qr_scan',
      'event_id': _validEventId,
      'issued_at': 1700000000000,
    };

    test('parses valid broadcast', () {
      final e = TrustChangedEvent.fromBroadcast(validPayload());
      expect(e.actorUid, 100);
      expect(e.targetUid, 200);
      expect(e.targetDeviceId, 'phone-b');
      expect(e.toState, 'verified');
      expect(e.method, 'qr_scan');
      expect(e.eventId, _validEventId);
      expect(e.issuedAt, 1700000000000);
    });

    test('throws FormatException on missing field', () {
      final p = validPayload()..remove('to_state');
      expect(() => TrustChangedEvent.fromBroadcast(p), throwsFormatException);
    });

    test('throws FormatException on wrong int type', () {
      final p = validPayload()..['actor_uid'] = '100';
      expect(() => TrustChangedEvent.fromBroadcast(p), throwsFormatException);
    });

    test('throws FormatException on unknown method', () {
      final p = validPayload()..['method'] = 'telepathy';
      expect(() => TrustChangedEvent.fromBroadcast(p), throwsFormatException);
    });

    test('throws FormatException on empty string field', () {
      final p = validPayload()..['target_device_id'] = '';
      expect(() => TrustChangedEvent.fromBroadcast(p), throwsFormatException);
    });
  });
}
