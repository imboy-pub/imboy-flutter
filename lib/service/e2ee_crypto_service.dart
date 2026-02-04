import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/api.dart' as api;

/// E2EE 备份加密核心服务
///
/// 提供以下加密功能：
/// - PBKDF2-HMAC-SHA256 密钥派生（310,000 次迭代）
/// - AES-256-GCM 加密/解密
/// - SHA-256 校验和计算
///
/// 安全参数：
/// - PBKDF2 迭代次数: 310,000（OWASP 2021 推荐）
/// - AES 密钥长度: 256 bits
/// - Salt 长度: 128 bits (16 bytes)
/// - IV 长度: 96 bits (12 bytes)
/// - GCM Auth Tag 长度: 128 bits (16 bytes)
///
/// @author Imboy Team
/// @since 2026-01-31
class E2EECryptoService {
  // ================================================================
  // 常量定义
  // ================================================================

  /// PBKDF2 迭代次数（OWASP 2021 推荐）
  static const int pbkdf2Iterations = 310000;

  /// Salt 长度（bytes）
  static const int saltLength = 16;

  /// IV 长度（AES-GCM 推荐，bytes）
  static const int ivLength = 12;

  /// GCM Auth Tag 长度（bytes）
  static const int authTagLength = 16;

  /// 派生密钥长度（AES-256，bytes）
  static const int derivedKeyLength = 32;

  /// 备份文件 Magic Number
  static const String magicNumber = 'IMBOYBKP';

  /// 备份文件格式版本
  static const int formatVersion = 1;

  /// 加密算法 ID
  static const int algorithmId = 0x0001;

  // ================================================================
  // PBKDF2 密钥派生
  // ================================================================

  /// 使用 PBKDF2-HMAC-SHA256 派生密钥
  ///
  /// @param password 用户输入的密码（UTF-8 字符串）
  /// @param salt 随机 Salt（16 bytes）
  /// @param iterations 迭代次数（默认 310,000）
  /// @returns 派生的密钥（32 bytes for AES-256）
  ///
  /// @example
  /// ```dart
  /// final salt = E2EECryptoService.generateSalt();
  /// final derivedKey = await E2EECryptoService.deriveKey('myPassword', salt);
  /// ```
  static Future<Uint8List> deriveKey(
    String password,
    Uint8List salt, {
    int iterations = pbkdf2Iterations,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (salt.length != saltLength) {
      throw ArgumentError('Salt must be $saltLength bytes');
    }

    // 将密码转换为字节
    final passwordBytes = Uint8List.fromList(utf8.encode(password));

    // 创建 HMAC-SHA256 (block size of SHA-256 is 64 bytes)
    final hmac = HMac(SHA256Digest(), 64);

    // 创建 PBKDF2 密钥派生器
    final derivator = PBKDF2KeyDerivator(hmac);

    // 创建参数（keySize in bits）
    final params = Pbkdf2Parameters(
      salt,
      iterations,
      derivedKeyLength * 8, // 32 bytes * 8 = 256 bits
    );

    derivator.init(params);

    // 派生密钥并截取到所需长度
    final derivedKeyFull = derivator.process(passwordBytes);
    final derivedKey = Uint8List(derivedKeyLength);
    derivedKey.setRange(0, derivedKeyLength, derivedKeyFull);

    return derivedKey;
  }

  // ================================================================
  // AES-256-GCM 加密
  // ================================================================

  /// 使用 AES-256-GCM 加密数据
  ///
  /// @param plaintext 明文数据
  /// @param key 加密密钥（32 bytes for AES-256）
  /// @param iv 初始化向量（12 bytes）
  /// @returns 加密结果 Map 包含 ciphertext 和 authTag
  ///
  /// @example
  /// ```dart
  /// final iv = E2EECryptoService.generateIV();
  /// final result = await E2EECryptoService.encryptAesGcm(plaintext, key, iv);
  /// final ciphertext = result['ciphertext'];
  /// final authTag = result['authTag'];
  /// ```
  static Future<Map<String, Uint8List>> encryptAesGcm(
    Uint8List plaintext,
    Uint8List key,
    Uint8List iv,
  ) async {
    if (key.length != derivedKeyLength) {
      throw ArgumentError('Key must be $derivedKeyLength bytes for AES-256');
    }
    if (iv.length != ivLength) {
      throw ArgumentError('IV must be $ivLength bytes for GCM');
    }

    // 创建 AES-GCM 加密器
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // 加密模式
        api.ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
      );

    // 加密数据
    final ciphertext = cipher.process(plaintext);

    // GCM 模式返回：密文 + auth tag
    // 提取 auth tag（最后 16 字节）
    final authTag = Uint8List(authTagLength);
    final tagOffset = ciphertext.length - authTagLength;
    authTag.setRange(0, authTagLength, ciphertext.sublist(tagOffset));

    // 截取实际的密文（不含 auth tag）
    final actualCiphertext = Uint8List.sublistView(ciphertext, 0, tagOffset);

    return {'ciphertext': actualCiphertext, 'authTag': authTag};
  }

  /// 使用 AES-256-GCM 解密数据
  ///
  /// @param ciphertext 密文数据
  /// @param authTag 认证标签（16 bytes）
  /// @param key 解密密钥（32 bytes）
  /// @param iv 初始化向量（12 bytes）
  /// @returns 解密后的明文数据
  ///
  /// @throws ArgumentError 如果参数无效
  /// @throws ArgumentError 如果认证失败（数据被篡改或密钥错误）
  ///
  /// @example
  /// ```dart
  /// try {
  ///   final plaintext = await E2EECryptoService.decryptAesGcm(
  ///     ciphertext,
  ///     authTag,
  ///     key,
  ///     iv,
  ///   );
  /// } catch (e) {
  ///   print('解密失败: $e');
  /// }
  /// ```
  static Future<Uint8List> decryptAesGcm(
    Uint8List ciphertext,
    Uint8List authTag,
    Uint8List key,
    Uint8List iv,
  ) async {
    if (key.length != derivedKeyLength) {
      throw ArgumentError(
        'Key must be $derivedKeyLength bytes for AES-256, got ${key.length}',
      );
    }
    if (iv.length != ivLength) {
      throw ArgumentError(
        'IV must be $ivLength bytes for GCM, got ${iv.length}',
      );
    }
    if (authTag.length != authTagLength) {
      throw ArgumentError(
        'Auth Tag must be $authTagLength bytes, got ${authTag.length}',
      );
    }
    if (ciphertext.isEmpty) {
      throw ArgumentError('Ciphertext cannot be empty');
    }

    try {
      // 合并密文和 auth tag（GCM 格式：密文在前，auth tag 在后）
      final combined = Uint8List(ciphertext.length + authTag.length);
      combined.setRange(0, ciphertext.length, ciphertext);
      combined.setRange(ciphertext.length, combined.length, authTag);

      // 创建 AES-GCM 解密器
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false, // 解密模式
          api.ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
        );

      // 解密数据
      final plaintext = cipher.process(combined);

      if (plaintext.isEmpty) {
        throw ArgumentError('Decryption resulted in empty plaintext');
      }

      return plaintext;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw ArgumentError(
        'Decryption failed: ${e.toString()}\n'
        'Possible causes:\n'
        '1. Wrong password\n'
        '2. Corrupted backup file\n'
        '3. Invalid file format',
      );
    }
  }

  // ================================================================
  // SHA-256 校验和
  // ================================================================

  /// 计算数据的 SHA-256 校验和
  ///
  /// @param data 输入数据
  /// @returns SHA-256 校验和（十六进制字符串，不带 "0x" 前缀）
  ///
  /// @example
  /// ```dart
  /// final checksum = E2EECryptoService.calculateChecksum(plaintext);
  /// print(checksum); // "a1b2c3d4..."
  /// ```
  static String calculateChecksum(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// 验证数据的 SHA-256 校验和
  ///
  /// @param data 输入数据
  /// @param expectedChecksum 期望的校验和
  /// @returns true 如果校验和匹配，否则 false
  ///
  /// @example
  /// ```dart
  /// final isValid = E2EECryptoService.verifyChecksum(plaintext, 'abc123...');
  /// ```
  static bool verifyChecksum(Uint8List data, String expectedChecksum) {
    final actualChecksum = calculateChecksum(data);
    return actualChecksum == expectedChecksum;
  }

  // ================================================================
  // 随机数生成
  // ================================================================

  /// 生成随机 Salt（16 bytes）
  ///
  /// @returns 随机 Salt
  static Uint8List generateSalt() {
    // 使用加密安全的随机数生成器
    final random = FortunaRandom();
    // 使用更强的种子源
    final seed = Uint8List(32);
    final secure = Random.secure();
    for (int i = 0; i < seed.length; i++) {
      seed[i] = secure.nextInt(256);
    }
    random.seed(KeyParameter(seed));
    return random.nextBytes(saltLength);
  }

  /// 生成随机 IV（12 bytes，适用于 AES-GCM）
  ///
  /// @returns 随机 IV
  static Uint8List generateIV() {
    // 使用加密安全的随机数生成器
    final random = FortunaRandom();
    // 使用更强的种子源（与 Salt 不同）
    final seed = Uint8List(32);
    final secure = Random.secure();
    for (int i = 0; i < seed.length; i++) {
      seed[i] = secure.nextInt(256);
    }
    random.seed(KeyParameter(seed));
    return random.nextBytes(ivLength);
  }

  // ================================================================
  // 辅助函数
  // ================================================================

  /// 将 Uint8List 转换为十六进制字符串
  static String toHex(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 从十六进制字符串解析为 Uint8List
  static Uint8List fromHex(String hex) {
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, (i + 1) * 2), radix: 16),
      ),
    );
  }

  /// 将 Uint8List 转换为 Base64
  static String toBase64(Uint8List data) {
    return base64.encode(data);
  }

  /// 从 Base64 解析为 Uint8List
  static Uint8List fromBase64(String base64Str) {
    return base64Decode(base64Str);
  }
}
