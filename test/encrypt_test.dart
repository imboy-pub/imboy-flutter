import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';

String aesEncrypt(String plainText, String key, String ivStr) {
  final k = encrypt.Key.fromUtf8(key);
  final iv = encrypt.IV.fromUtf8(ivStr);

  final encryptor =
      encrypt.Encrypter(encrypt.AES(k, mode: encrypt.AESMode.cbc));
  return encryptor.encrypt(plainText, iv: iv).base64;
}

String aesDecrypt(String encrypted, String key, String ivStr) {
  final k = encrypt.Key.fromUtf8(key);
  final iv = encrypt.IV.fromUtf8(ivStr);

  final encryptor =
      encrypt.Encrypter(encrypt.AES(k, mode: encrypt.AESMode.cbc));
  return encryptor.decrypt(encrypt.Encrypted.fromBase64(encrypted), iv: iv);
}

void main() {
  String iv = "";
  String key = "";
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    String encrypted = aesEncrypt("abc123456", key, iv);
    debugPrint("encrypted1: $encrypted");
    String plainText = aesDecrypt(encrypted, key, iv);
    debugPrint("encrypted2: $plainText");

    // [        ] test 0: Waiting for test harness or tests to finish
    // encrypted1: 2HwyxeasA0pwwpN2cEY5ug==
    // encrypted2: abc123456
  });
}
