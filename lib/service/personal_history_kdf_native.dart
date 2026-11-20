import 'dart:typed_data';

import 'e2ee_crypto_service.dart';

Future<Uint8List> derivePersonalHistoryPasswordKey(
  String password,
  Uint8List salt,
  int iterations,
) => E2EECryptoService.deriveKey(password, salt, iterations: iterations);
