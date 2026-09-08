import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:vodozemac/vodozemac.dart' as vod;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await fvod.init();

    final alice = vod.Account();
    final bob = vod.Account()..generateOneTimeKeys(1);
    final aliceSession = alice.createOutboundSession(
      identityKey: bob.identityKeys.curve25519,
      oneTimeKey: bob.oneTimeKeys.values.single,
    );
    final first = aliceSession.encrypt('olm-native');
    final inbound = bob.createInboundSession(
      theirIdentityKey: alice.identityKeys.curve25519,
      preKeyMessageBase64: first.ciphertext,
    );
    if (inbound.plaintext != 'olm-native') {
      throw StateError('Olm decrypt failed');
    }

    final group = vod.GroupSession();
    final inboundGroup = group.toInbound();
    if (inboundGroup.decrypt(group.encrypt('megolm-native')).plaintext !=
        'megolm-native') {
      throw StateError('Megolm decrypt failed');
    }

    debugPrint('VODOZEMAC_NATIVE_SMOKE=PASS');
    runApp(const _ResultApp('PASS Olm Megolm Native'));
  } catch (error, stackTrace) {
    debugPrint('VODOZEMAC_NATIVE_SMOKE=FAIL $error\n$stackTrace');
    runApp(_ResultApp('FAIL $error'));
  }
}

class _ResultApp extends StatelessWidget {
  const _ResultApp(this.result);

  final String result;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text(result))),
  );
}
