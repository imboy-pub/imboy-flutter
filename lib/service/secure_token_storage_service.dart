import 'package:flutter/foundation.dart' show debugPrint;
import 'package:imboy/service/storage_secure.dart' show StorageSecureService;

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

/// Token 安全存储服务
///
/// 使用 flutter_secure_storage（iOS Keychain / Android EncryptedSharedPreferences）
/// 直接存储 JWT Token，移除了之前基于 SharedPreferences + 自研 AES-CBC 的实现。
class SecureTokenStorageService {
  static const String _tokenKey = 'secure_token';
  static const String _refreshTokenKey = 'secure_refresh_token';

  static Future<void> saveToken(String token) async {
    await StorageSecureService.to.write(key: _tokenKey, value: token);
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    await StorageSecureService.to.write(
      key: _refreshTokenKey,
      value: refreshToken,
    );
  }

  static Future<String> getToken() async {
    try {
      final token = await StorageSecureService.to.read(key: _tokenKey);
      return token ?? '';
    } on Exception catch (e) {
      debugPrint('SecureTokenStorageService.getToken: 读取失败; $e');
      rethrow;
    }
  }

  static Future<String> getRefreshToken() async {
    try {
      final refreshToken = await StorageSecureService.to.read(
        key: _refreshTokenKey,
      );
      return refreshToken ?? '';
    } on Exception catch (e) {
      debugPrint('SecureTokenStorageService.getRefreshToken: 读取失败; $e');
      rethrow;
    }
  }

  static Future<void> clear() async {
    try {
      debugPrint(
        'SecureTokenStorageService.clear: Removing token key: $_tokenKey',
      );
      await StorageSecureService.to.delete(key: _tokenKey);
      debugPrint(
        'SecureTokenStorageService.clear: Removing refresh token key: $_refreshTokenKey',
      );
      await StorageSecureService.to.delete(key: _refreshTokenKey);
      debugPrint(
        'SecureTokenStorageService.clear: All tokens cleared successfully',
      );
    } on Exception catch (e, s) {
      debugPrint('SecureTokenStorageService.clear error: $e; $s');
      rethrow;
    }
  }
}
