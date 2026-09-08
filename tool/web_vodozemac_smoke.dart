import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:web/web.dart' as web;

Future<void> main() async {
  try {
    await fvod.init(wasmPath: './pkg/');

    final alice = vod.Account();
    final bob = vod.Account()..generateOneTimeKeys(1);
    final aliceSession = alice.createOutboundSession(
      identityKey: bob.identityKeys.curve25519,
      oneTimeKey: bob.oneTimeKeys.values.single,
    );
    final first = aliceSession.encrypt('olm-web');
    final inbound = bob.createInboundSession(
      theirIdentityKey: alice.identityKeys.curve25519,
      preKeyMessageBase64: first.ciphertext,
    );
    if (inbound.plaintext != 'olm-web') throw StateError('Olm decrypt failed');
    final reply = inbound.session.encrypt('olm-reply');
    if (aliceSession.decrypt(
          messageType: reply.messageType,
          ciphertext: reply.ciphertext,
        ) !=
        'olm-reply') {
      throw StateError('Olm reply decrypt failed');
    }

    final group = vod.GroupSession();
    final inboundGroup = group.toInbound();
    final groupCiphertext = group.encrypt('megolm-web');
    if (inboundGroup.decrypt(groupCiphertext).plaintext != 'megolm-web') {
      throw StateError('Megolm decrypt failed');
    }

    web.document.body?.textContent = 'PASS Olm Megolm Web';
  } catch (error, stackTrace) {
    web.document.body?.textContent = 'FAIL $error\n$stackTrace';
  }
}
