import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encrypter.dart';

void main() {
  String iv = "";
  String key = "";
  // String hashKey = "";
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    String encrypted = "";
    String plainText = EncrypterService.aesDecrypt(encrypted, EncrypterService.md5(key), iv);
    debugPrint("plainText: $plainText");
    // String plainText = aesDecrypt(encrypted, EncrypterService.md5(key), iv);
    // debugPrint("encrypted2: $plainText");

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
