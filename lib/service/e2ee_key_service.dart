import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pg;
import 'package:pointycastle/pointycastle.dart';

import 'e2ee_crypto_service.dart';
import 'storage_secure.dart';

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
      // 1. 生成 RSA 密钥对
      final keyPair = _generateRSAKeyPair();

      // 2. 编码为 PEM 格式
      final publicKeyPem = _encodePublicKeyToPem(keyPair.publicKey);
      final privateKeyPem = _encodePrivateKeyToPem(keyPair.privateKey);

      // 3. 生成设备 ID 和密钥 ID
      final deviceId = _generateDeviceId();
      final keyId = _generateKeyId();
      final createdAt = DateTime.now().toUtc().toIso8601String();

      // 4. 保存到安全存储
      final storage = StorageSecure();
      await Future.wait([
        storage.savePrivateKey(privateKeyPem),
        storage.savePublicKey(publicKeyPem),
        storage.setDeviceId(deviceId),
        storage.setKeyId(keyId),
        storage.setKeyCreatedAt(createdAt),
      ]);

      // 5. 返回密钥信息
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
    final storage = StorageSecure();

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
    final storage = StorageSecure();
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
    final storage = StorageSecure();
    await storage.deleteAllE2EEKeys();
  }

  // ================================================================
  // 内部方法 - RSA 密钥对生成
  // ================================================================

  /// 生成 RSA 密钥对
  static AsymmetricKeyPair<pg.PublicKey, pg.PrivateKey> _generateRSAKeyPair() {
    try {
      // 创建安全的随机数生成器（使用 FortunaRandom）
      final secureRandom = pg.FortunaRandom();
      final seed = Uint8List(32);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 8; i++) {
        seed[i] = (timestamp >> (i * 8)) & 0xFF;
      }
      secureRandom.seed(pg.KeyParameter(seed));

      // 创建 RSA 密钥参数
      final keyParams = pg.RSAKeyGeneratorParameters(
        BigInt.from(publicExponent),
        rsaKeySize,
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
  static String _generateDeviceId() {
    final random = pg.FortunaRandom();
    // 使用时间作为种子
    final seed = Uint8List(32);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      seed[i] = (timestamp >> (i * 8)) & 0xFF;
    }
    random.seed(pg.KeyParameter(seed));

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
  static String _generateKeyId() {
    final random = pg.FortunaRandom();
    // 使用时间作为种子（与设备 ID 不同）
    final seed = Uint8List(32);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      seed[i + 8] = (timestamp >> (i * 8)) & 0xFF;
    }
    random.seed(pg.KeyParameter(seed));

    final bytes = random.nextBytes(8);

    // 转换为十六进制字符串
    final hex = E2EECryptoService.toHex(bytes);

    return 'kid_$hex';
  }
}
