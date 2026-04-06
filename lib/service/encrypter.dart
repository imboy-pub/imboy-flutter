import 'dart:convert';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/foundation.dart';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart' as crypto;

/// 加密服务
/// 提供 AES、SHA、MD5 等加密算法
///
/// 优化：
/// - 密钥缓存：避免重复的 UTF-8 编码
/// - 使用 Uint8List：减少内存分配
class EncrypterService {
  /// 密钥缓存（避免重复编码）
  static final Map<String, Uint8List> _keyCache = {};

  /// 最大缓存数量
  static const _maxKeyCacheSize = 50;

  /// AES-CBC + PKCS7 加密（与 encrypt 库完全一致）
  static String aesEncrypt(String plainText, String key, String ivStr) {
    final keyBytes = _getOrCreateCachedKey(key);
    final ivBytes = _getOrCreateCachedKey(ivStr);
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
    try {
      final keyBytes = _getOrCreateCachedKey(key);
      final ivBytes = _getOrCreateCachedKey(ivStr);
      final encryptedBytes = base64.decode(encryptedBase64);

      // 🔍 调试日志：显示密钥和 IV 的 MD5（避免泄露真实值）
      debugPrint('🔐 [AES_DECRYPT] Key MD5: ${md5(key)}, IV MD5: ${md5(ivStr)}');
      debugPrint('🔐 [AES_DECRYPT] Encrypted length: ${encryptedBytes.length} bytes');

      final cipher = CBCBlockCipher(AESEngine());
      final params = ParametersWithIV<KeyParameter>(
        KeyParameter(keyBytes),
        ivBytes,
      );

      cipher.init(false, params); // false = decrypt

      final decryptedPadded = _processBlocks(cipher, encryptedBytes);

      final decrypted = _pkcs7UnPad(decryptedPadded);

      debugPrint('🔐 [AES_DECRYPT] Decrypted length: ${decrypted.length} bytes');

      // 尝试解码为 UTF-8，失败则尝试其他编码
      try {
        return utf8.decode(decrypted);
      } on FormatException catch (e) {
        // UTF-8 解码失败，输出十六进制用于调试
        debugPrint('❌ [AES_DECRYPT] UTF-8 解码失败: $e');
        debugPrint('🔍 [AES_DECRYPT] Decrypted bytes (hex): ${bytesToHex(decrypted)}');

        // 尝试 Latin-1 编码（不会失败，但可能显示乱码）
        final latin1Result = String.fromCharCodes(decrypted);
        debugPrint('⚠️ [AES_DECRYPT] Latin-1 解码结果（可能乱码）: $latin1Result');

        // 重新抛出异常
        throw FormatException(
          'AES 解密后的数据无法解码为 UTF-8。请检查密钥和 IV 是否与服务端匹配。\n'
          'Key MD5: ${md5(key)}\n'
          'IV MD5: ${md5(ivStr)}\n'
          '解密结果 (hex): ${bytesToHex(decrypted).substring(0, 100)}...',
        );
      }
    } catch (e) {
      debugPrint('❌ [AES_DECRYPT] 解密异常: $e');
      rethrow;
    }
  }

  /// 将字节数组转换为十六进制字符串（用于调试）
  static String bytesToHex(Uint8List bytes, {bool uppercase = false}) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(uppercase ? '' : '')
        .toUpperCase();
  }

  /// EncrypterService.sha256
  static String sha256(String str, String k) {
    final key = _getOrCreateCachedKey(k);
    final messageBytes = Uint8List.fromList(utf8.encode(str));
    final hMac = crypto.Hmac(crypto.sha256, key);
    final digest = hMac.convert(messageBytes);
    return base64.encode(digest.bytes);
  }

  /// EncrypterService.sha512
  static String sha512(String str, String k) {
    final key = _getOrCreateCachedKey(k);
    final messageBytes = Uint8List.fromList(utf8.encode(str));
    final hMac = crypto.Hmac(crypto.sha512, key);
    final digest = hMac.convert(messageBytes);
    return base64.encode(digest.bytes);
  }

  /// md5 加密
  /// EncrypterService.md5
  static String md5(String data) {
    final digest = crypto.md5.convert(utf8.encode(data));
    return hex.encode(digest.bytes);
  }

  /// SHA256 哈希
  /// EncrypterService.sha256Hash
  static String sha256Hash(String data) {
    final digest = crypto.sha256.convert(utf8.encode(data));
    return hex.encode(digest.bytes);
  }

  /// AES-GCM 加密（自动生成 IV）
  static Map<String, String> aesGcmEncryptBytes(
    Uint8List plainBytes,
    Uint8List keyBytes, {
    Uint8List? aad,
  }) {
    final iv = _secureRandomBytes(12);
    return aesGcmEncryptBytesWithIV(plainBytes, keyBytes, iv, aad: aad);
  }

  /// AES-GCM 加密（使用自定义 IV）
  ///
  /// 当需要使用预生成的 nonce/IV 时使用此方法（例如 E2EE v2.0）
  static Map<String, String> aesGcmEncryptBytesWithIV(
    Uint8List plainBytes,
    Uint8List keyBytes,
    Uint8List iv, {
    Uint8List? aad,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(keyBytes),
      128,
      iv,
      aad ?? Uint8List(0),
    );
    cipher.init(true, params);
    final out = cipher.process(plainBytes);
    return {'iv': base64.encode(iv), 'ct': base64.encode(out)};
  }

  static Uint8List aesGcmDecryptBytes(
    String ivBase64,
    String ctBase64,
    Uint8List keyBytes, {
    Uint8List? aad,
  }) {
    final iv = base64.decode(base64.normalize(ivBase64));
    final cipherBytes = base64.decode(base64.normalize(ctBase64));
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(keyBytes),
      128,
      iv,
      aad ?? Uint8List(0),
    );
    cipher.init(false, params);
    return cipher.process(cipherBytes);
  }

  /// 获取或创建缓存的密钥
  static Uint8List _getOrCreateCachedKey(String key) {
    // 直接从缓存获取
    final cached = _keyCache[key];
    if (cached != null) {
      return cached;
    }

    // 编码并缓存
    final encoded = Uint8List.fromList(utf8.encode(key));

    // 如果缓存已满，移除最旧的条目（简单的 LRU）
    if (_keyCache.length >= _maxKeyCacheSize && _keyCache.isNotEmpty) {
      final firstKey = _keyCache.keys.first;
      _keyCache.remove(firstKey);
    }

    _keyCache[key] = encoded;
    return encoded;
  }

  /// 清除密钥缓存（在内存紧张时调用）
  static void clearKeyCache() {
    _keyCache.clear();
  }

  /// 获取缓存统计
  static Map<String, int> getKeyCacheStats() {
    return {
      'cached_keys': _keyCache.length,
      'max_cache_size': _maxKeyCacheSize,
    };
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
    if (data.isEmpty) {
      throw FormatException('Empty input: cannot unpad empty data');
    }
    final padLen = data.last;
    if (padLen <= 0 || padLen > data.length) throw Exception("Invalid padding");
    return data.sublist(0, data.length - padLen);
  }

  static Uint8List _secureRandomBytes(int length) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return Uint8List.fromList(bytes);
  }
}
