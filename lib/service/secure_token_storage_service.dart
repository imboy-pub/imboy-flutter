
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show Uint8List;
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:imboy/service/secure_key_service.dart' show SecureKeyService;
import 'package:imboy/service/storage.dart' show StorageService;

/*
// 保存
await SecureTokenStorageService.saveToken("your_token_here");
await SecureTokenStorageService.saveRefreshToken("your_refresh_token_here");

// 读取
String token = await SecureTokenStorageService.getToken();
String refreshToken = await SecureTokenStorageService.getRefreshToken();

// 清空
await SecureTokenStorageService.clear();
await SecureKeyService.clear();

 */
class SecureTokenStorageService {
  static const String _tokenKey = 'secure_token';
  static const String _refreshTokenKey = 'secure_refresh_token';

  static Uint8List _decodeAesKey(String encoded) {
    try {
      return base64Url.decode(base64Url.normalize(encoded));
    } catch (_) {
      return base64.decode(base64.normalize(encoded));
    }
  }

  static Future<void> saveToken(String token) async {
    final encrypted = await _encryptData(token);
    await StorageService().setString(_tokenKey, encrypted);
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    final encrypted = await _encryptData(refreshToken);
    await StorageService().setString(_refreshTokenKey, encrypted);
  }

  static Future<String> getToken() async {
    final encrypted = StorageService().getString(_tokenKey);
    if (encrypted.isEmpty) return '';

    try {
      return await _decryptData(encrypted);
    } on Exception catch (e) {
      debugPrint("SecureTokenStorageService.getToken: 解密失败，清除损坏的令牌数据; $e");
      // 解密失败时清除损坏的数据，避免重复错误
      await StorageService().remove(_tokenKey);
      rethrow;
    }
  }

  static Future<String> getRefreshToken() async {
    final encrypted = StorageService().getString(_refreshTokenKey);
    if (encrypted.isEmpty) return '';

    try {
      return await _decryptData(encrypted);
    } on Exception catch (e) {
      debugPrint("SecureTokenStorageService.getRefreshToken: 解密失败，清除损坏的令牌数据; $e");
      // 解密失败时清除损坏的数据，避免重复错误
      await StorageService().remove(_refreshTokenKey);
      rethrow;
    }
  }

  static Future<void> clear() async {
    try {
      debugPrint("SecureTokenStorageService.clear: Removing token key: $_tokenKey");
      await StorageService().remove(_tokenKey);
      debugPrint("SecureTokenStorageService.clear: Removing refresh token key: $_refreshTokenKey");
      await StorageService().remove(_refreshTokenKey);
      debugPrint("SecureTokenStorageService.clear: All tokens cleared successfully");
    } catch (e, s) {
      debugPrint("SecureTokenStorageService.clear error: $e; $s");
      rethrow;
    }
  }


  /*
  static Future<String> _encryptData(String plainText) async {
    final base64Key = await SecureKeyService.getCurrentAesKey();
    final keyBytes = _decodeAesKey(base64Key);
    final rnd = Random.secure();

    // 生成 16 字节随机 IV
    final ivBytes = Uint8List.fromList(List<int>.generate(16, (i) => rnd.nextInt(256)));

    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String> _decryptData(String combined) async {
    final parts = combined.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid encrypted data format.');
    }

    final ivBase64 = parts[0];
    final encryptedBase64 = parts[1];
    final iv = encrypt.IV.fromBase64(ivBase64);

    final base64Keys = await SecureKeyService.getAllAesKeys();
    for (final base64Key in base64Keys) {
      try {
        final key = encrypt.Key.fromBase64(base64Key);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
        return decrypted;
      } catch (e, s) {
        // 尝试下一个key
        debugPrint("$e; $s");
        continue;
      }
    }
    throw Exception('Failed to decrypt data with any known key.');
  }
  */
  /// AES-CBC + PKCS7 加密，与 encrypt 库兼容
  static Future<String> _encryptData(String plainText) async {
    final base64Key = await SecureKeyService.getCurrentAesKey();
    final keyBytes = base64.decode(base64Key);

    // 生成 16 字节随机 IV
    final ivBytes = _secureRandomBytes(16);

    final cipherBytes =
    _aesCbcEncrypt(Utf8Encoder().convert(plainText), keyBytes, ivBytes);

    return "${base64.encode(ivBytes)}:${base64.encode(cipherBytes)}";
  }

  /// AES-CBC + PKCS7 解密，与 encrypt 库兼容
  static Future<String> _decryptData(String combined) async {
    final parts = combined.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid encrypted data format.');
    }

    final iv = base64.decode(base64.normalize(parts[0]));
    final encryptedBytes = base64.decode(base64.normalize(parts[1]));
    if (iv.length != 16) {
      throw Exception('Invalid IV length.');
    }
    if (encryptedBytes.isEmpty || encryptedBytes.length % 16 != 0) {
      throw Exception('Invalid encrypted data length.');
    }

    // 支持多 key 轮询
    final keys = await SecureKeyService.getAllAesKeys();

    for (final base64Key in keys) {
      try {
        final keyBytes = _decodeAesKey(base64Key);
        final decryptedBytes = _aesCbcDecrypt(encryptedBytes, keyBytes, iv);
        return Utf8Decoder().convert(decryptedBytes);
      } catch (e, s) {
        debugPrint("$e\n$s");
        continue;
      }
    }

    throw Exception("Failed to decrypt data with any known key.");
  }

  // ---------------------------------------------------------------------------
  // 实际 AES-CBC + PKCS7 加解密实现
  // ---------------------------------------------------------------------------

  static Uint8List _aesCbcEncrypt(
      Uint8List data,
      Uint8List key,
      Uint8List iv,
      ) {
    final cipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV<KeyParameter>(KeyParameter(key), iv);
    cipher.init(true, params); // true = 加密

    final paddedData = _pkcs7Pad(data, cipher.blockSize);
    return _processBlocks(cipher, paddedData);
  }

  static Uint8List _aesCbcDecrypt(
      Uint8List encrypted,
      Uint8List key,
      Uint8List iv,
      ) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw Exception('Invalid AES key length.');
    }
    final cipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV<KeyParameter>(KeyParameter(key), iv);
    cipher.init(false, params); // false = 解密

    if (iv.length != cipher.blockSize || encrypted.length % cipher.blockSize != 0) {
      throw Exception('Invalid encrypted data.');
    }

    final output = _processBlocks(cipher, encrypted);
    return _pkcs7Unpad(output);
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

  static Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) throw Exception("Invalid padding");
    final padLen = data.last;
    if (data.length % 16 != 0) throw Exception("Invalid padding");
    if (padLen <= 0 || padLen > 16 || padLen > data.length) throw Exception("Invalid padding");
    for (int i = data.length - padLen; i < data.length; i++) {
      if (data[i] != padLen) throw Exception("Invalid padding");
    }
    return data.sublist(0, data.length - padLen);
  }

  // ---------------------------------------------------------------------------
  // 安全随机字节
  // ---------------------------------------------------------------------------

  static Uint8List _secureRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (i) => rnd.nextInt(256)));
  }
}
