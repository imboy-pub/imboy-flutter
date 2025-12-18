
import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/foundation.dart';


// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart' as crypto;

class EncrypterService {

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


  /// AES-CBC + PKCS7 加密（与 encrypt 库完全一致）
  static String aesEncrypt(String plainText, String key, String ivStr) {
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final ivBytes = Uint8List.fromList(utf8.encode(ivStr));
    final data = Uint8List.fromList(utf8.encode(plainText));

    final cipher = CBCBlockCipher(AESEngine());

    final params = ParametersWithIV<KeyParameter>(
      KeyParameter(keyBytes),
      ivBytes,
    );

    cipher.init(true, params); // true = encrypt

    // PKCS7 padding
    final padded = _pkcs7Pad(data, cipher.blockSize);

    final encrypted = _processBlocks(cipher, padded);

    return base64.encode(encrypted);
  }

  /// AES-CBC + PKCS7 解密（与 encrypt 库完全一致）
  static String aesDecrypt(String encryptedBase64, String key, String ivStr) {
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final ivBytes = Uint8List.fromList(utf8.encode(ivStr));
    final encryptedBytes = base64.decode(encryptedBase64);

    final cipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV<KeyParameter>(
      KeyParameter(keyBytes),
      ivBytes,
    );

    cipher.init(false, params); // false = decrypt

    final decryptedPadded = _processBlocks(cipher, encryptedBytes);

    final decrypted = _pkcs7UnPad(decryptedPadded);

    return utf8.decode(decrypted);
  }



  static Uint8List _processBlocks(BlockCipher cipher, Uint8List input) {
    final output = Uint8List(input.length);

    for (int offset = 0; offset < input.length;) {
      offset += cipher.processBlock(input, offset, output, offset);
    }

    return output;
  }

  // ---------------------------------------------------------------------------
  // PKCS7 Padding（encrypt 库内部就是用 PKCS7）
  // ---------------------------------------------------------------------------

  static Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padding = List<int>.filled(padLen, padLen);
    return Uint8List.fromList([...data, ...padding]);
  }

  static Uint8List _pkcs7UnPad(Uint8List data) {
    if (data.isEmpty) throw Exception("Invalid padding");
    final padLen = data.last;
    if (padLen <= 0 || padLen > data.length) throw Exception("Invalid padding");
    return data.sublist(0, data.length - padLen);
  }

}
