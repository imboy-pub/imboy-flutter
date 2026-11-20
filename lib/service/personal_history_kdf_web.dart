import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

extension type _Pbkdf2Params._(JSObject _) implements JSObject {
  external _Pbkdf2Params({
    required String name,
    required JSUint8Array salt,
    required int iterations,
    required String hash,
  });
}

Future<Uint8List> derivePersonalHistoryPasswordKey(
  String password,
  Uint8List salt,
  int iterations,
) async {
  if (!web.window.isSecureContext) {
    throw StateError('Personal history requires a secure browser context');
  }
  final subtle = web.window.crypto.subtle;
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  try {
    final baseKey = await subtle
        .importKey(
          'raw',
          passwordBytes.toJS,
          'PBKDF2'.toJS,
          false,
          ['deriveBits'.toJS].toJS,
        )
        .toDart;
    final result = await subtle
        .deriveBits(
          _Pbkdf2Params(
            name: 'PBKDF2',
            salt: salt.toJS,
            iterations: iterations,
            hash: 'SHA-256',
          ),
          baseKey,
          256,
        )
        .toDart;
    return result.toDart.asUint8List();
  } finally {
    passwordBytes.fillRange(0, passwordBytes.length, 0);
  }
}
