import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/trust_event_canonical.dart';

import '../../vodozemac_native_lib.dart';

void main() {
  test('Ed25519 signature binds the exact decimal actor and target', () async {
    await ensureVodozemac();
    const fields = TrustEventCanonicalFields(
      actorDeviceGeneration: 1,
      actorUid: '9007199254740993',
      eventId: 'abc',
      expiresAt: 200,
      fromState: 'verified',
      issuedAt: 100,
      targetDeviceId: 'd',
      targetEd25519: 'key',
      targetIdentityVersion: 1,
      targetUid: '9007199254740995',
      toState: 'revoked',
    );
    final account = vod.Account();
    final message = utf8.decode(fields.canonicalBytes());
    final signature = account.sign(message);
    final publicKey = account.identityKeys.ed25519;
    publicKey.verify(message: message, signature: signature);
    expect(
      () => publicKey.verify(
        message: message.replaceFirst('9007199254740995', '9007199254740994'),
        signature: signature,
      ),
      throwsA(anything),
    );
  });
}
