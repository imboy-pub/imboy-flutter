import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encrypter.dart';

void main() {
  const iv = "1234567890abcdef";
  const rawKey = "test-sign-key";
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    const input = "abc123456";
    final key = EncrypterService.md5(rawKey);
    final encrypted = EncrypterService.aesEncrypt(input, key, iv);
    final plainText = EncrypterService.aesDecrypt(encrypted, key, iv);
    debugPrint("plainText: $plainText");
    expect(plainText, equals(input));

    // String hash512 =
    //     sha512("C5931370-BDCC-55FE-AB9C-8E2B39DC5018|0.1.11", hashKey);
    // debugPrint("sha512: $hash512");
    //
    // String hash256 =
    //     sha256("C5931370-BDCC-55FE-AB9C-8E2B39DC5018|0.1.11", hashKey);
    // debugPrint("sha512: $hash256");
    // [        ] test 0: Waiting for test harness or tests to finish
    // encrypted1: 2HwyxeasA0pwwpN2cEY5ug==
    // encrypted2: abc123456
  });
}
