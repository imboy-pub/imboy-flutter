import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/domain/cs_delivery_ack_ledger.dart';
import 'package:imboy/service/auth_session_scope.dart';

import 'cs_session_auth_scope_test.dart' show SyntheticAuthReader;

const AuthSessionScope first = (
  uid: 'synthetic-a',
  generation: 1,
  transitioning: false,
);
const scope = 'org/ws/session/conversation/identity-a';

class _LedgerAuthReader extends SyntheticAuthReader {
  _LedgerAuthReader(super.current);
  bool get observed => hasListeners;
}

void main() {
  late _LedgerAuthReader auth;
  late CsDeliveryAckLedger ledger;
  setUp(() {
    auth = _LedgerAuthReader(first);
    ledger = CsDeliveryAckLedger.forAuth(auth);
  });
  tearDown(() {
    ledger.dispose();
    auth.dispose();
  });

  test('same auth shares successful ACK across page ownership', () {
    ledger.record(first, scope, '101');
    final nextPage = CsDeliveryAckLedger.forAuth(auth);
    expect(nextPage, same(ledger));
    expect(nextPage.contains(first, scope, '101'), isTrue);
    expect(nextPage.contains(first, scope, '102'), isFalse);
  });
  test('different reader and recipient scope never share ACKs', () {
    ledger.record(first, scope, '101');
    expect(
      ledger.contains(first, 'org/ws/session/conversation/identity-b', '101'),
      isFalse,
    );
    final other = SyntheticAuthReader(first);
    final separate = CsDeliveryAckLedger.forAuth(other);
    try {
      expect(separate.contains(first, scope, '101'), isFalse);
    } finally {
      separate.dispose();
      other.dispose();
    }
  });
  for (final next in <AuthSessionScope>[
    (uid: 'synthetic-a', generation: 2, transitioning: false),
    (uid: 'synthetic-b', generation: 1, transitioning: false),
    (uid: '', generation: 2, transitioning: true),
    (uid: 'synthetic-a', generation: 1, transitioning: true),
  ]) {
    test('auth change $next clears old authority and rejects stale record', () {
      ledger.record(first, scope, '101');
      auth.publish(next);
      expect(ledger.contains(first, scope, '101'), isFalse);
      ledger.record(first, scope, '102');
      auth.publish(first);
      expect(ledger.contains(first, scope, '101'), isFalse);
      expect(ledger.contains(first, scope, '102'), isFalse);
    });
  }
  test('scope invalidation preserves other conversations', () {
    ledger.record(first, scope, '101');
    ledger.record(first, 'org/ws/other/conversation/identity-a', '101');
    ledger.invalidateScope(scope);
    expect(ledger.contains(first, scope, '101'), isFalse);
    expect(
      ledger.contains(first, 'org/ws/other/conversation/identity-a', '101'),
      isTrue,
    );
  });
  test('2048 exact entries FIFO; duplicates do not extend retention', () {
    for (var i = 1; i <= 2048; i++) {
      ledger.record(first, scope, '$i');
    }
    ledger.record(first, scope, '1');
    ledger.record(first, scope, '2049');
    expect(ledger.contains(first, scope, '1'), isFalse);
    expect(ledger.contains(first, scope, '2'), isTrue);
    expect(ledger.contains(first, scope, '2049'), isTrue);
  });
  test(
    'invalid current auth cannot record; disposed ledger removes listener',
    () {
      auth.publish((uid: '', generation: 1, transitioning: false));
      ledger.record(auth.current, scope, '101');
      auth.publish(first);
      expect(ledger.contains(first, scope, '101'), isFalse);
      ledger.dispose();
      expect(auth.observed, isFalse);
      ledger.record(first, scope, '102');
      expect(ledger.contains(first, scope, '102'), isFalse);
      final replacement = CsDeliveryAckLedger.forAuth(auth);
      expect(replacement, isNot(same(ledger)));
      replacement.dispose();
    },
  );
}
