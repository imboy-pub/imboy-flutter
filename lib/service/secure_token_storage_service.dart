import 'package:imboy/service/storage_secure.dart' show StorageSecureService;

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
    } on Exception {
      rethrow;
    }
  }

  static Future<String> getRefreshToken() async {
    try {
      final refreshToken = await StorageSecureService.to.read(
        key: _refreshTokenKey,
      );
      return refreshToken ?? '';
    } on Exception {
      rethrow;
    }
  }

  static Future<void> clear() async {
    try {
      await StorageSecureService.to.delete(key: _tokenKey);
      await StorageSecureService.to.delete(key: _refreshTokenKey);
    } on Exception {
      rethrow;
    }
  }
}
