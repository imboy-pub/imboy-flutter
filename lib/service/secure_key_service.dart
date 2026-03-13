import 'dart:convert';
import 'dart:math';

import 'package:imboy/component/helper/datetime.dart';
import 'storage_secure.dart';

class SecureKeyService {
  static const _currentKeyStorageKey = 'secure_storage_current_aes_key';
  static const _oldKeysStorageKey = 'secure_storage_old_aes_keys';
  static const _keyExpireAtStorageKey = 'secure_storage_key_expire_at';

  static String? _currentAesKey;
  static List<String>? _oldAesKeys;
  static DateTime? _expireAt;

  /// 密钥有效期（天）
  static const int keyValidDays = 60;

  /// 获取当前加密用的AES密钥
  static Future<String> getCurrentAesKey() async {
    await _loadKeys();

    if (_currentAesKey == null || _isKeyExpired()) {
      await _rotateKey();
    }

    return _currentAesKey!;
  }

  /// 获取所有可用于解密的密钥（当前+历史）
  static Future<List<String>> getAllAesKeys() async {
    await _loadKeys();
    final keys = <String>[];
    if (_currentAesKey != null) keys.add(_currentAesKey!);
    if (_oldAesKeys != null) keys.addAll(_oldAesKeys!);
    return keys;
  }

  static bool _isKeyExpired() {
    if (_expireAt == null) return true;
    return DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    ).isAfter(_expireAt!);
  }

  static Future<void> _rotateKey() async {
    final newKey = _generateRandomKey();

    if (_currentAesKey != null) {
      final oldKeys = _oldAesKeys ?? [];
      oldKeys.add(_currentAesKey!);
      await StorageSecureService.to.write(
        key: _oldKeysStorageKey,
        value: jsonEncode(oldKeys),
      );
    }

    _currentAesKey = newKey;
    _expireAt = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    ).add(Duration(days: keyValidDays));

    await StorageSecureService.to.write(
      key: _currentKeyStorageKey,
      value: _currentAesKey!,
    );
    await StorageSecureService.to.write(
      key: _keyExpireAtStorageKey,
      value: _expireAt!.toIso8601String(),
    );
  }

  static Future<void> _loadKeys() async {
    if (_currentAesKey != null) return;

    _currentAesKey = await StorageSecureService.to.read(
      key: _currentKeyStorageKey,
    );

    final oldKeysStr = await StorageSecureService.to.read(
      key: _oldKeysStorageKey,
    );
    if (oldKeysStr != null && oldKeysStr.isNotEmpty) {
      _oldAesKeys = List<String>.from(jsonDecode(oldKeysStr));
    } else {
      _oldAesKeys = [];
    }

    final expireAtStr = await StorageSecureService.to.read(
      key: _keyExpireAtStorageKey,
    );
    if (expireAtStr != null && expireAtStr.isNotEmpty) {
      _expireAt = DateTime.tryParse(expireAtStr);
    }
  }

  static String _generateRandomKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// 清空所有密钥
  static Future<void> clear() async {
    _currentAesKey = null;
    _oldAesKeys = null;
    _expireAt = null;

    await StorageSecureService.to.delete(key: _currentKeyStorageKey);
    await StorageSecureService.to.delete(key: _oldKeysStorageKey);
    await StorageSecureService.to.delete(key: _keyExpireAtStorageKey);
  }
}
