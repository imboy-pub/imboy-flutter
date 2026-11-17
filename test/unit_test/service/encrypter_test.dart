import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:imboy/service/encrypter.dart';

void main() {
  const key = '0123456789abcdef';
  const iv = 'fedcba9876543210';
  tearDown(EncrypterService.clearKeyCache);

  test('AES-CBC retains UTF-8 roundtrip', () {
    const plaintext = 'synthetic 中文 🔑';
    final encrypted = EncrypterService.aesEncrypt(plaintext, key, iv);
    expect(EncrypterService.aesDecrypt(encrypted, key, iv), plaintext);
  });

  test(
    'invalid UTF-8 decryption error contains no key, IV or fingerprints',
    () {
      // Valid padding, invalid UTF-8: this reaches the real decoding failure.
      final cipher = CBCBlockCipher(AESEngine())
        ..init(
          true,
          ParametersWithIV<KeyParameter>(
            KeyParameter(Uint8List.fromList(utf8.encode(key))),
            Uint8List.fromList(utf8.encode(iv)),
          ),
        );
      final padded = Uint8List.fromList([0xff, ...List.filled(15, 15)]);
      final encrypted = Uint8List(16);
      cipher.processBlock(padded, 0, encrypted, 0);
      expect(
        () => EncrypterService.aesDecrypt(base64Encode(encrypted), key, iv),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'sanitized error',
            allOf(
              isNot(contains(key)),
              isNot(contains(iv)),
              isNot(contains(EncrypterService.md5(key))),
              isNot(contains(EncrypterService.md5(iv))),
              isNot(contains('255')),
            ),
          ),
        ),
      );
    },
  );
}
