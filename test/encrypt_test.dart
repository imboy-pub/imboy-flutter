import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart' as crypto;
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

String sha256(String str, String k) {
  List<int> messageBytes = utf8.encode(str);
  List<int> key = utf8.encode(k);
  crypto.Hmac hMac = crypto.Hmac(crypto.sha256, key);
  crypto.Digest digest = hMac.convert(messageBytes);
  return base64.encode(digest.bytes);
}

String sha512(String str, String k) {
  List<int> messageBytes = utf8.encode(str);
  List<int> key = utf8.encode(k);
  crypto.Hmac hMac = crypto.Hmac(crypto.sha512, key);
  crypto.Digest digest = hMac.convert(messageBytes);
  return base64.encode(digest.bytes);
}

void main() {
  String iv = "";
  String key = "";
  String hashKey = "";
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    String encrypted = aesEncrypt("abc123456", key, iv);
    debugPrint("encrypted1: $encrypted");
    String plainText = aesDecrypt(encrypted, key, iv);
    debugPrint("encrypted2: $plainText");

    String hash512 =
        sha512("C5931370-BDCC-55FE-AB9C-8E2B39DC5018|0.1.11", hashKey);
    debugPrint("sha512: $hash512");

    String hash256 =
        sha256("C5931370-BDCC-55FE-AB9C-8E2B39DC5018|0.1.11", hashKey);
    debugPrint("sha512: $hash256");
    // [        ] test 0: Waiting for test harness or tests to finish
    // encrypted1: 2HwyxeasA0pwwpN2cEY5ug==
    // encrypted2: abc123456
  });
}
