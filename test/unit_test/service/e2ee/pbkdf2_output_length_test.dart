import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'package:imboy/service/e2ee_crypto_service.dart';

// Reproduce the pre-fix 256-byte derivation exactly, including truncation.
Uint8List _legacyKey((String, List<int>, int) input) {
  final (password, salt, iterations) = input;
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, 256));
  return Uint8List.fromList(
    derivator.process(Uint8List.fromList(utf8.encode(password))).sublist(0, 32),
  );
}

void main() {
  // Independent vectors: Python hashlib.pbkdf2_hmac('sha256', UTF8(password),
  // bytes(salt), iterations, dklen=32). Include legacy/v2 iteration counts.
  final cases = <(String, String, List<int>, int, String)>[
    (
      "ascii",
      "password",
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      1,
      "e1b08f92be8174d9f442d95d89aa4ccdc311231a4d70d0b854d1548de8fabdfd",
    ),
    (
      "unicode",
      "密码🔐é",
      [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
      2,
      "af7751b0f31eee90d6d5d6e40b32c27ca526aea16f1fdce57c8172e28720f25e",
    ),
    (
      "nul-long",
      "long-passphrase-long-passphrase-long-passphrase-long-passphrase-long-passphrase-long-passphrase-\x00end",
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      4096,
      "25bee035846375ffae815ce083f3f792e07acbbedefb70522bed9a41ee110832",
    ),
    (
      "v1-310k",
      "correct-horse-battery-staple",
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      310000,
      "721ae75360a174a162d045911113778ad7ec5baee2bc406f8e04311f0d808ef4",
    ),
    (
      "v2-600k",
      "correct-horse-battery-staple",
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      600000,
      "8adaee041a94ff37b7d210e7dfed1d1256f4ee9b1d9339c29ba2957a1e719847",
    ),
  ];
  for (final (name, password, salt, iterations, expectedHex) in cases) {
    test('32-byte KDF preserves legacy prefix and decryption: $name', () async {
      final legacy = await compute(_legacyKey, (password, salt, iterations));
      final current = await E2EECryptoService.deriveKey(
        password,
        Uint8List.fromList(salt),
        iterations: iterations,
      );
      expect(current, hasLength(32));
      expect(current, orderedEquals(legacy));
      expect(E2EECryptoService.toHex(current), expectedHex);

      final plaintext = Uint8List.fromList(
        utf8.encode('synthetic legacy $name'),
      );
      final iv = Uint8List.fromList(List<int>.generate(12, (i) => i));
      final encrypted = await E2EECryptoService.encryptAesGcm(
        plaintext,
        legacy,
        iv,
      );
      final restored = await E2EECryptoService.decryptAesGcm(
        encrypted['ciphertext']!,
        encrypted['authTag']!,
        current,
        iv,
      );
      expect(restored, orderedEquals(plaintext));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
