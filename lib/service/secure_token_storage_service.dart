
import 'package:encrypt/encrypt.dart' as encrypt;
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

    return await _decryptData(encrypted);
  }

  static Future<String> getRefreshToken() async {
    final encrypted = StorageService().getString(_refreshTokenKey);
    if (encrypted.isEmpty) return '';

    return await _decryptData(encrypted);
  }

  static Future<void> clear() async {
    await StorageService().remove(_tokenKey);
    await StorageService().remove(_refreshTokenKey);
  }

  static Future<String> _encryptData(String plainText) async {
    final base64Key = await SecureKeyService.getCurrentAesKey();
    final key = encrypt.Key.fromBase64(base64Key);
    final iv = encrypt.IV.fromSecureRandom(16);
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
}
