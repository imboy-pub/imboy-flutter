import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:pointycastle/export.dart' as pg;
import 'package:pointycastle/pointycastle.dart';

import 'package:imboy/config/init.dart' as init_config;
import 'e2ee_crypto_service.dart';
import 'storage_secure.dart';

// 👇 条件导入：Web 平台使用真实实现
import 'rsa_web_stub.dart' if (dart.library.html) 'rsa_web.dart';

/// Temporary compatibility service for the security_privacy module shell.
/// New upper-layer imports should prefer
/// `package:imboy/modules/security_privacy/public.dart`.
/// RSA 密钥大小（位）- 用于 isolate
const int _rsaKeySize = 2048;

/// 公钥指数 - 用于 isolate
const int _publicExponent = 65537;

/// Isolate 中运行的 RSA 密钥生成函数
///
/// 这个函数在单独的 isolate 中运行，避免阻塞主线程
AsymmetricKeyPair<pg.PublicKey, pg.PrivateKey> _generateRSAKeyPairIsolate(
  dynamic _,
) {
  try {
    // 创建安全的随机数生成器（使用 FortunaRandom）
    final secureRandom = pg.FortunaRandom();

    // 使用安全熵源
    final seed = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }
    secureRandom.seed(pg.KeyParameter(seed));

    // 创建 RSA 密钥参数
    final keyParams = pg.RSAKeyGeneratorParameters(
      BigInt.from(_publicExponent),
      _rsaKeySize,
      64, // 确定性参数
    );

    // 创建密钥生成器
    final keyGen = pg.RSAKeyGenerator()
      ..init(
        pg.ParametersWithRandom<pg.RSAKeyGeneratorParameters>(
          keyParams,
          secureRandom,
        ),
      );

    // 生成密钥对
    return keyGen.generateKeyPair();
  } catch (e) {
    throw Exception('生成 RSA 密钥对失败: $e');
  }
}

/// RSA 加密 OID (1.2.840.113549.1.1.1)
const _rsaEncryptionOid = [1, 2, 840, 113549, 1, 1, 1];

/// E2EE 密钥生成服务
///
/// 提供 E2EE 密钥对的生成、存储和管理功能：
/// - 生成 RSA-2048 密钥对
/// - 生成设备 ID 和密钥 ID
/// - 保存到安全存储
/// - 检索密钥信息
///
/// @author Imboy Team
/// @since 2026-01-31
class E2EEKeyService {
  /// RSA 密钥大小（位）
  static const int rsaKeySize = 2048;

  /// 公钥指数（F4 = 65537，RSA 标准值）
  static const int publicExponent = 65537;

  /// 生成新的 E2EE 密钥对
  ///
  /// @returns 密钥信息 Map
  ///
  /// @throws Exception 如果密钥生成失败
  ///
  /// @example
  /// ```dart
  /// try {
  ///   final keyInfo = await E2EEKeyService.generateKeyPair();
  ///   print('密钥已生成');
  ///   print('设备 ID: ${keyInfo['device_id']}');
  ///   print('密钥 ID: ${keyInfo['key_id']}');
  /// } catch (e) {
  ///   print('密钥生成失败: $e');
  /// }
  /// ```
  static Future<Map<String, dynamic>> generateKeyPair() async {
    try {
      String publicKeyPem;
      String privateKeyPem;

      // 🔧 Web 平台优化：使用 Web Crypto API（非阻塞）
      if (kIsWeb) {
        final keyPairWeb = await generateRSAKeyPairWeb();
        publicKeyPem = keyPairWeb['publicKey']!;
        privateKeyPem = keyPairWeb['privateKey']!;
      } else {
        // 移动端/桌面端：使用 pointycastle
        // 在 isolate 中运行以避免阻塞主线程
        final keyPair = await compute(_generateRSAKeyPairIsolate, null);

        // 编码为 PEM 格式
        publicKeyPem = _encodePublicKeyToPem(keyPair.publicKey);
        privateKeyPem = _encodePrivateKeyToPem(keyPair.privateKey);
      }

      // 使用全局 deviceId 而不是生成新的随机 ID
      // 这确保加密/解密时使用相同的设备 ID
      final deviceId = init_config.deviceId.isNotEmpty
          ? init_config.deviceId
          : _generateDeviceId(); // 仅作为备用
      final keyId = _generateKeyId();
      final createdAt = DateTime.now().toUtc().toIso8601String();

      // 保存到安全存储
      final storage = StorageSecureService.to;
      await Future.wait([
        storage.savePrivateKey(privateKeyPem),
        storage.savePublicKey(publicKeyPem),
        storage.setDeviceId(deviceId),
        storage.setKeyId(keyId),
        storage.setKeyCreatedAt(createdAt),
      ]);

      // 返回密钥信息
      return {
        'device_id': deviceId,
        'key_id': keyId,
        'created_at': createdAt,
        'key_size': rsaKeySize,
        'algorithm': 'RSA-$rsaKeySize',
      };
    } catch (e) {
      throw Exception('生成 E2EE 密钥对失败: $e');
    }
  }

  /// 获取当前密钥信息
  ///
  /// @returns 密钥信息 Map，如果密钥不存在则返回 null
  ///
  /// @example
  /// ```dart
  /// final keyInfo = await E2EEKeyService.getKeyInfo();
  /// if (keyInfo != null) {
  ///   print('设备 ID: ${keyInfo['device_id']}');
  ///   print('密钥 ID: ${keyInfo['key_id']}');
  /// } else {
  ///   print('未找到密钥');
  /// }
  /// ```
  static Future<Map<String, dynamic>?> getKeyInfo() async {
    final storage = StorageSecureService.to;

    final privateKey = await storage.getPrivateKey();
    final publicKey = await storage.getPublicKey();
    final deviceId = await storage.getDeviceId();
    final keyId = await storage.getKeyId();
    final createdAt = await storage.getKeyCreatedAt();

    // 检查密钥是否存在
    if (privateKey == null || publicKey == null) {
      return null;
    }

    return {
      'device_id': deviceId ?? 'unknown',
      'key_id': keyId ?? 'unknown',
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
      'key_size': rsaKeySize,
      'algorithm': 'RSA-$rsaKeySize',
      'has_private_key': privateKey.isNotEmpty,
      'has_public_key': publicKey.isNotEmpty,
    };
  }

  /// 检查是否存在有效的 E2EE 密钥
  ///
  /// @returns true 如果密钥存在，否则 false
  static Future<bool> hasKey() async {
    final storage = StorageSecureService.to;
    return await storage.hasE2EEKeys();
  }

  /// 删除当前 E2EE 密钥
  ///
  /// @throws Exception 如果删除失败
  ///
  /// @example
  /// ```dart
  /// await E2EEKeyService.deleteKey();
  /// print('密钥已删除');
  /// ```
  static Future<void> deleteKey() async {
    final storage = StorageSecureService.to;
    await storage.deleteAllE2EEKeys();
  }

  // ================================================================
  // 内部方法 - RSA 密钥对生成
  // ================================================================

  /// 生成安全的随机种子
  ///
  /// 使用平台提供的安全熵源，而不是时间戳
  /// 确保密钥生成的不可预测性
  static Uint8List _generateSecureSeed() {
    final seed = Uint8List(32);

    // 使用 Dart 的安全随机数生成器
    // Random.secure() 使用平台提供的加密安全熵源
    final random = Random.secure();
    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }

    // 额外混合一些熵（可选，增加安全性）
    // 注意：这不依赖时间戳作为主要熵源
    final extraEntropy = <int>[
      DateTime.now().microsecondsSinceEpoch % 256,
      DateTime.now().hashCode % 256,
      // 使用对象实例的 hashCode
      Object().hashCode % 256,
    ];
    for (int i = 0; i < extraEntropy.length && i < 3; i++) {
      seed[i] ^= extraEntropy[i];
    }

    return seed;
  }

  /// 将公钥编码为 PEM 格式
  static String _encodePublicKeyToPem(pg.PublicKey publicKey) {
    try {
      if (publicKey is! pg.RSAPublicKey) {
        throw ArgumentError('Only RSA public keys are supported');
      }

      final rsaPublicKey = publicKey;

      // 创建 ASN.1 SubjectPublicKeyInfo 结构
      // 1. AlgorithmIdentifier
      final algorithmSeq = ASN1Sequence();
      algorithmSeq.add(ASN1ObjectIdentifier(_rsaEncryptionOid));
      algorithmSeq.add(ASN1Null());

      // 2. RSAPublicKey (BIT STRING)
      final publicKeySeq = ASN1Sequence();
      publicKeySeq.add(ASN1Integer(rsaPublicKey.modulus!));
      publicKeySeq.add(ASN1Integer(rsaPublicKey.exponent!));

      final publicKeyBitString = ASN1BitString(
        stringValues: Uint8List.fromList(publicKeySeq.encode()),
      );

      // 3. 顶层序列
      final topLevelSeq = ASN1Sequence();
      topLevelSeq.add(algorithmSeq);
      topLevelSeq.add(publicKeyBitString);

      // 4. Base64 编码并添加 PEM 头尾
      final base64Str = base64.encode(topLevelSeq.encode());
      final chunks = _chunkString(base64Str, 64);

      return '-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----';
    } catch (e) {
      throw Exception('编码公钥失败: $e');
    }
  }

  /// 将私钥编码为 PEM 格式
  static String _encodePrivateKeyToPem(pg.PrivateKey privateKey) {
    try {
      if (privateKey is! pg.RSAPrivateKey) {
        throw ArgumentError('Only RSA private keys are supported');
      }

      final rsaPrivateKey = privateKey;

      // 创建 ASN.1 PrivateKeyInfo (PKCS#8) 结构
      // 1. Version
      final version = ASN1Integer(BigInt.zero);

      // 2. AlgorithmIdentifier
      final algorithmSeq = ASN1Sequence();
      algorithmSeq.add(ASN1ObjectIdentifier(_rsaEncryptionOid));
      algorithmSeq.add(ASN1Null());

      // 3. RSAPrivateKey (OCTET STRING)
      final privateKeySeq = ASN1Sequence();
      privateKeySeq.add(version); // version
      privateKeySeq.add(ASN1Integer(rsaPrivateKey.modulus!)); // n
      privateKeySeq.add(ASN1Integer(BigInt.from(publicExponent))); // e
      privateKeySeq.add(ASN1Integer(rsaPrivateKey.privateExponent!)); // d
      privateKeySeq.add(ASN1Integer(rsaPrivateKey.p!)); // p
      privateKeySeq.add(ASN1Integer(rsaPrivateKey.q!)); // q
      privateKeySeq.add(
        ASN1Integer(
          rsaPrivateKey.privateExponent! % (rsaPrivateKey.p! - BigInt.one),
        ),
      ); // d mod (p-1)
      privateKeySeq.add(
        ASN1Integer(
          rsaPrivateKey.privateExponent! % (rsaPrivateKey.q! - BigInt.one),
        ),
      ); // d mod (q-1)
      privateKeySeq.add(
        ASN1Integer(rsaPrivateKey.q!.modInverse(rsaPrivateKey.p!)),
      ); // q^-1 mod p

      final privateKeyOctetString = ASN1OctetString(
        octets: Uint8List.fromList(privateKeySeq.encode()),
      );

      // 4. 顶层序列
      final topLevelSeq = ASN1Sequence();
      topLevelSeq.add(version);
      topLevelSeq.add(algorithmSeq);
      topLevelSeq.add(privateKeyOctetString);

      // 5. Base64 编码并添加 PEM 头尾
      final base64Str = base64.encode(topLevelSeq.encode());
      final chunks = _chunkString(base64Str, 64);

      return '-----BEGIN PRIVATE KEY-----\n${chunks.join('\n')}\n-----END PRIVATE KEY-----';
    } catch (e) {
      throw Exception('编码私钥失败: $e');
    }
  }

  // ================================================================
  // 内部方法 - 辅助函数
  // ================================================================

  /// 将字符串分割成指定长度的块
  static List<String> _chunkString(String str, int chunkSize) {
    final chunks = <String>[];
    for (int i = 0; i < str.length; i += chunkSize) {
      final end = (i + chunkSize < str.length) ? i + chunkSize : str.length;
      chunks.add(str.substring(i, end));
    }
    return chunks;
  }

  // ================================================================
  // 内部方法 - ID 生成
  // ================================================================

  /// 生成设备 ID
  ///
  /// 格式: {8位十六进制}-{8位十六进制}-{8位十六进制}
  /// 例如: a1b2c3d4-e5f67890-a1b2c3d4
  ///
  /// 安全说明：使用安全熵源，不再依赖时间戳
  static String _generateDeviceId() {
    final random = pg.FortunaRandom();
    // 🔒 安全修复：使用安全熵源
    random.seed(pg.KeyParameter(_generateSecureSeed()));

    final bytes = random.nextBytes(16);

    // 转换为十六进制字符串
    final hex = E2EECryptoService.toHex(bytes);

    // 格式化为 XXXXXXXX-XXXXXXXX-XXXXXXXX
    return '${hex.substring(0, 8)}-${hex.substring(8, 16)}-${hex.substring(16, 24)}';
  }

  /// 生成密钥 ID
  ///
  /// 格式: kid_{8位十六进制}
  /// 例如: kid_a1b2c3d4
  ///
  /// 安全说明：使用安全熵源，不再依赖时间戳
  static String _generateKeyId() {
    final random = pg.FortunaRandom();
    // 🔒 安全修复：使用安全熵源
    random.seed(pg.KeyParameter(_generateSecureSeed()));

    final bytes = random.nextBytes(8);

    // 转换为十六进制字符串
    final hex = E2EECryptoService.toHex(bytes);

    return 'kid_$hex';
  }
}
