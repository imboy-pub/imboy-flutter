import 'package:encrypt/encrypt.dart';

String aesEncrypt(String plainText, String key, String ivStr) {
  final k = Key.fromUtf8(key);
  final iv = IV.fromUtf8(ivStr);

  final encryptor = Encrypter(AES(k, mode: AESMode.cbc));
  return encryptor.encrypt(plainText, iv: iv).base64;
}

String aesDecrypt(String encrypted, String key, String ivStr) {
  final k = Key.fromUtf8(key);
  final iv = IV.fromUtf8(ivStr);

  final encryptor = Encrypter(AES(k, mode: AESMode.cbc));
  return encryptor.decrypt(Encrypted.fromBase64(encrypted), iv: iv);
}
