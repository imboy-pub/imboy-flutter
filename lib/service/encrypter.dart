import 'package:encrypt/encrypt.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:convert/convert.dart';
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart' as crypto;

class EncrypterService {
  /// EncrypterService.aesEncrypt
  static String aesEncrypt(String plainText, String key, String ivStr) {
    final k = Key.fromUtf8(key);
    final iv = IV.fromUtf8(ivStr);

    final encryptor = Encrypter(AES(k, mode: AESMode.cbc));
    return encryptor.encrypt(plainText, iv: iv).base64;
  }

  /// EncrypterService.aesDecrypt
  static String aesDecrypt(String encrypted, String key, String ivStr) {
    final k = Key.fromUtf8(key);
    final iv = IV.fromUtf8(ivStr);

    final encryptor = Encrypter(AES(k, mode: AESMode.cbc));
    return encryptor.decrypt(Encrypted.fromBase64(encrypted), iv: iv);
  }

  /// EncrypterService.sha256
  static String sha256(String str, String k) {
    List<int> messageBytes = utf8.encode(str);
    List<int> key = utf8.encode(k);
    crypto.Hmac hMac = crypto.Hmac(crypto.sha256, key);
    crypto.Digest digest = hMac.convert(messageBytes);
    return base64.encode(digest.bytes);
  }

  /// EncrypterService.sha512
  static String sha512(String str, String k) {
    List<int> messageBytes = utf8.encode(str);
    List<int> key = utf8.encode(k);
    crypto.Hmac hMac = crypto.Hmac(crypto.sha512, key);
    crypto.Digest digest = hMac.convert(messageBytes);
    return base64.encode(digest.bytes);
  }

  /// md5 加密
  /// EncrypterService.md5
  static String md5(String data) {
    // var content = Utf8Encoder().convert(data);
    // var digest = md5.convert(content);
    var digest = crypto.md5.convert(utf8.encode(data));
    // 这里其实就是 digest.toString()
    return hex.encode(digest.bytes);
  }
}
