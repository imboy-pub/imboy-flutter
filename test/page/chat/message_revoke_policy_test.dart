/// Tests for canRevokeMessage (S1 — message revoke 2-min window policy).
///
/// Pure function: given a message's createdAt timestamp and the current time,
/// decide whether the message is still within the revoke window. Used to
/// short-circuit the revoke API call and give immediate UX feedback when the
/// user taps revoke on an expired message.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/message_revoke_policy.dart';

void main() {
  const window = 2 * 60 * 1000; // 120_000 ms

  group('canRevokeMessage — basic window', () {
    test('within window returns true (0ms since createdAt)', () {
      expect(canRevokeMessage(createdAtMs: 10_000, nowMs: 10_000), isTrue);
    });

    test('within window returns true (1 second ago)', () {
      expect(canRevokeMessage(createdAtMs: 10_000, nowMs: 11_000), isTrue);
    });

    test('just at the boundary (now == createdAt + window) → true', () {
      expect(
        canRevokeMessage(createdAtMs: 10_000, nowMs: 10_000 + window),
        isTrue,
        reason: 'boundary is inclusive (UX-friendly)',
      );
    });

    test('one ms past the window returns false', () {
      expect(
        canRevokeMessage(createdAtMs: 10_000, nowMs: 10_000 + window + 1),
        isFalse,
      );
    });

    test('well past the window returns false', () {
      expect(
        canRevokeMessage(createdAtMs: 10_000, nowMs: 10_000 + 10 * window),
        isFalse,
      );
    });
  });

  group('canRevokeMessage — clock drift tolerance', () {
    test('future createdAt (clock skew) still revokable', () {
      // Message stamped 30 s in the "future" vs device clock — still fresh.
      expect(
        canRevokeMessage(createdAtMs: 50_000, nowMs: 20_000),
        isTrue,
        reason: 'clock drift should not block revoke',
      );
    });
  });

  group('canRevokeMessage — defensive against bad data', () {
    test('createdAtMs = 0 (missing / uninitialized) → false', () {
      expect(canRevokeMessage(createdAtMs: 0, nowMs: 1_000_000), isFalse);
    });

    test('createdAtMs negative (corrupted) → false', () {
      expect(canRevokeMessage(createdAtMs: -1, nowMs: 1_000_000), isFalse);
    });

    test('windowMs = 0 → always false (safety)', () {
      expect(
        canRevokeMessage(createdAtMs: 10_000, nowMs: 10_000, windowMs: 0),
        isFalse,
        reason: 'zero window = no revoke ever',
      );
    });

    test('windowMs negative → always false', () {
      expect(
        canRevokeMessage(createdAtMs: 10_000, nowMs: 10_000, windowMs: -1),
        isFalse,
      );
    });
  });

  group('canRevokeMessage — custom window override', () {
    test('caller can shrink window to 60 s', () {
      // use createdAtMs > 0 to avoid the "bad data" defensive branch
      const t0 = 1_000_000;
      expect(
        canRevokeMessage(
          createdAtMs: t0,
          nowMs: t0 + 60_000,
          windowMs: 60_000,
        ),
        isTrue,
      );
      expect(
        canRevokeMessage(
          createdAtMs: t0,
          nowMs: t0 + 60_001,
          windowMs: 60_000,
        ),
        isFalse,
      );
    });

    test('caller can expand window to 5 min', () {
      const t0 = 1_000_000;
      expect(
        canRevokeMessage(
          createdAtMs: t0,
          nowMs: t0 + 5 * 60 * 1000,
          windowMs: 5 * 60 * 1000,
        ),
        isTrue,
      );
    });
  });

  group('canRevokeMessage — large values (no overflow)', () {
    test('realistic millis timestamps around year 2026', () {
      final createdAt = DateTime(2026, 4, 14).millisecondsSinceEpoch;
      final now = createdAt + 30_000; // 30s later
      expect(canRevokeMessage(createdAtMs: createdAt, nowMs: now), isTrue);
    });

    test('3 minutes later → false', () {
      final createdAt = DateTime(2026, 4, 14).millisecondsSinceEpoch;
      final now = createdAt + 3 * 60 * 1000;
      expect(canRevokeMessage(createdAtMs: createdAt, nowMs: now), isFalse);
    });
  });
}
