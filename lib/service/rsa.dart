import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/src/platform_check/platform_check.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';

/// RSA加密解密服务工具类
/// 优化要点：
/// 1. 增加内存缓存状态管理
/// 2. 优化PEM格式处理
/// 3. 增强错误处理
/// 4. 提高加解密性能
/// 5. 保持原有接口不变
class RSAService {
  // region 常量定义
  static const _beginPrivateKey = '-----BEGIN PRIVATE KEY-----';
  static const _endPrivateKey = '-----END PRIVATE KEY-----';
  static const _beginPublicKey = '-----BEGIN PUBLIC KEY-----';
  static const _endPublicKey = '-----END PUBLIC KEY-----';

  // 默认密钥参数
  static const _defaultKeySize = 2048;
  static final _defaultPublicExponent = BigInt.from(65537);
  // endregion

  // region 内存缓存管理
  static String? _cachedPublicKey;
  static String? _cachedPrivateKey;
  static bool _isInitialized = false;
  // endregion

  // region 公共接口 - 保持原有接口不变

  /// 获取公钥(PEM格式)
  /// 如果内存中没有则从安全存储中读取，如果安全存储中也没有则生成新密钥对
  static Future<String> publicKey() async {
    if (_cachedPublicKey != null) {
      return _cachedPublicKey!;
    }

    try {
      // 尝试从安全存储读取
      String? key = await StorageSecureService().read(key: Keys.publicKey);
      if (strNoEmpty(key)) {
        _cachedPublicKey = key;
        return key!;
      }

      // 初始化密钥对
      await _initialize();
      return _cachedPublicKey!;
    } catch (e) {
      // 错误处理
      throw Exception('获取公钥失败: $e');
    }
  }

  /// 获取私钥(PEM格式)
  /// 如果内存中没有则从安全存储中读取，如果安全存储中也没有则生成新密钥对
  static Future<String?> privateKey() async {
    if (_cachedPrivateKey != null) {
      return _cachedPrivateKey;
    }

    try {
      // 尝试从安全存储读取
      String? key = await StorageSecureService().read(key: Keys.privateKey);
      if (strNoEmpty(key)) {
        _cachedPrivateKey = key;
        return key;
      }

      // 初始化密钥对
      await _initialize();
      return _cachedPrivateKey;
    } catch (e) {
      // 错误处理
      throw Exception('获取私钥失败: $e');
    }
  }
  // endregion

  // region 密钥对初始化

  /// 初始化RSA密钥对
  /// 1. 生成密钥对
  /// 2. 编码为PEM格式
  /// 3. 存储到安全存储
  /// 4. 缓存到内存
  static Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // 生成RSA密钥对
      final keyPair = _generateRSAKeyPair();

      // 编码为PEM格式
      _cachedPublicKey = _encodePublicKeyToPem(keyPair.publicKey);
      _cachedPrivateKey = _encodePrivateKeyToPem(keyPair.privateKey);

      // 存储到安全存储
      await Future.wait([
        StorageSecureService().write(
          key: Keys.publicKey,
          value: _cachedPublicKey!,
        ),
        StorageSecureService().write(
          key: Keys.privateKey,
          value: _cachedPrivateKey!,
        ),
      ]);

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      _cachedPublicKey = null;
      _cachedPrivateKey = null;
      rethrow;
    }
  }

  /// 生成RSA密钥对
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateRSAKeyPair({
    int bitLength = _defaultKeySize,
  }) {
    try {
      final secureRandom = _createSecureRandom();

      final keyParams = RSAKeyGeneratorParameters(
        _defaultPublicExponent,
        bitLength,
        64, // 确定性参数
      );

      final keyGen = RSAKeyGenerator()
        ..init(ParametersWithRandom(keyParams, secureRandom));

      return keyGen.generateKeyPair();
    } catch (e) {
      throw Exception('生成RSA密钥对失败: $e');
    }
  }

  /// 创建安全的随机数生成器
  static SecureRandom _createSecureRandom() {
    try {
      final entropySource = Platform.instance.platformEntropySource();
      final secureRandom = SecureRandom('Fortuna')
        ..seed(KeyParameter(entropySource.getBytes(32)));
      return secureRandom;
    } catch (e) {
      throw Exception('创建安全随机数生成器失败: $e');
    }
  }
  // endregion

  // region PEM格式编码解码

  /// 将RSA公钥编码为PEM格式
  static String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    try {
      // 创建ASN.1序列
      final algorithmSeq = ASN1Sequence();
      algorithmSeq.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
      algorithmSeq.add(ASN1Null());

      final publicKeySeq = ASN1Sequence();
      publicKeySeq.add(ASN1Integer(publicKey.modulus));
      publicKeySeq.add(ASN1Integer(publicKey.exponent));

      final publicKeyBitString = ASN1BitString(
        stringValues: Uint8List.fromList(publicKeySeq.encode()),
      );

      final topLevelSeq = ASN1Sequence();
      topLevelSeq.add(algorithmSeq);
      topLevelSeq.add(publicKeyBitString);

      return _formatAsPem(topLevelSeq.encode(), _beginPublicKey, _endPublicKey);
    } catch (e) {
      throw Exception('编码公钥为PEM格式失败: $e');
    }
  }

  /// 将RSA私钥编码为PEM格式
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    try {
      final version = ASN1Integer(BigInt.zero);

      final algorithmSeq = ASN1Sequence();
      algorithmSeq.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
      algorithmSeq.add(ASN1Null());

      final privateKeySeq = ASN1Sequence();
      privateKeySeq.add(version);
      privateKeySeq.add(ASN1Integer(privateKey.modulus));
      privateKeySeq.add(ASN1Integer(_defaultPublicExponent));
      privateKeySeq.add(ASN1Integer(privateKey.privateExponent!));
      privateKeySeq.add(ASN1Integer(privateKey.p!));
      privateKeySeq.add(ASN1Integer(privateKey.q!));
      privateKeySeq.add(
        ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
      );
      privateKeySeq.add(
        ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
      );
      privateKeySeq.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));

      final privateKeyOctetString = ASN1OctetString(
        octets: Uint8List.fromList(privateKeySeq.encode()),
      );

      final topLevelSeq = ASN1Sequence();
      topLevelSeq.add(version);
      topLevelSeq.add(algorithmSeq);
      topLevelSeq.add(privateKeyOctetString);

      return _formatAsPem(
        topLevelSeq.encode(),
        _beginPrivateKey,
        _endPrivateKey,
      );
    } catch (e) {
      throw Exception('编码私钥为PEM格式失败: $e');
    }
  }

  /// 将ASN.1编码后的数据格式化为PEM格式
  static String _formatAsPem(
    List<int> derEncoded,
    String beginMarker,
    String endMarker,
  ) {
    final base64Str = base64.encode(derEncoded);
    final chunks = StringHelper.chunk(base64Str, 64);
    return '$beginMarker\n${chunks.join('\n')}\n$endMarker';
  }

  /// 从PEM字符串中提取字节数据
  static Uint8List getBytesFromPEMString(
    String pem, {
    bool checkHeader = true,
  }) {
    try {
      var lines = LineSplitter.split(
        pem,
      ).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

      String base64Data;
      if (checkHeader) {
        if (lines.length < 2 ||
            !lines.first.startsWith('-----BEGIN') ||
            !lines.last.startsWith('-----END')) {
          throw ArgumentError('无效的PEM格式: 缺少开始/结束标记');
        }
        base64Data = lines.sublist(1, lines.length - 1).join('');
      } else {
        base64Data = lines.join('');
      }

      return Uint8List.fromList(base64.decode(base64Data));
    } catch (e) {
      throw Exception('从PEM字符串提取字节数据失败: $e');
    }
  }
  // endregion

  // region 加密解密操作

  /// RSA加密
  Uint8List rsaEncrypt(RSAPublicKey publicKey, Uint8List dataToEncrypt) {
    try {
      final encryptor = OAEPEncoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      return _processInBlocks(encryptor, dataToEncrypt);
    } catch (e) {
      throw Exception('RSA加密失败: $e');
    }
  }

  /// RSA解密
  Uint8List rsaDecrypt(RSAPrivateKey privateKey, Uint8List cipherText) {
    try {
      final decryptor = OAEPEncoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      return _processInBlocks(decryptor, cipherText);
    } catch (e) {
      throw Exception('RSA解密失败: $e');
    }
  }

  /// 分块处理数据
  Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    try {
      final output = Uint8List(
        engine.outputBlockSize *
            ((input.length / engine.inputBlockSize).ceil()),
      );

      var inputOffset = 0;
      var outputOffset = 0;

      while (inputOffset < input.length) {
        final chunkSize = min(
          engine.inputBlockSize,
          input.length - inputOffset,
        );
        outputOffset += engine.processBlock(
          input,
          inputOffset,
          chunkSize,
          output,
          outputOffset,
        );
        inputOffset += chunkSize;
      }

      return output.sublist(0, outputOffset);
    } catch (e) {
      throw Exception('分块处理数据失败: $e');
    }
  }
  // endregion

  // region 签名验签

  /// RSA签名
  Uint8List rsaSign(RSAPrivateKey privateKey, Uint8List dataToSign) {
    try {
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
        ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final sig = signer.generateSignature(dataToSign);
      return sig.bytes;
    } catch (e) {
      throw Exception('RSA签名失败: $e');
    }
  }

  /// RSA验签
  bool rsaVerify(
    RSAPublicKey publicKey,
    Uint8List signedData,
    Uint8List signature,
  ) {
    try {
      final sig = RSASignature(signature);
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201')
        ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      return verifier.verifySignature(signedData, sig);
    } on ArgumentError {
      return false;
    } catch (e) {
      throw Exception('RSA验签失败: $e');
    }
  }

  // endregion
}
