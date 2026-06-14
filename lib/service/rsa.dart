// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/src/platform_check/platform_check.dart';
import 'package:asn1lib/asn1lib.dart' as asn1;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';

// 👇 条件导入：Web 平台使用真实实现，非 Web 平台使用存根
import 'rsa_web_stub.dart' if (dart.library.html) 'rsa_web.dart';

/// RSA加密解密服务工具类
/// 优化要点：
/// 1. 增加内存缓存状态管理
/// 2. 优化PEM格式处理
/// 3. 增强错误处理
/// 4. 提高加解密性能
/// 5. 保持原有接口不变
class RSAService {
  // region 常量定义
  static const _beginPrivateKey =
      '-----BEGIN PRIVATE KEY-----'; // gitleaks:allow
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
      String? key = await StorageSecureService.to.read(key: Keys.publicKey);
      if (strNoEmpty(key)) {
        _cachedPublicKey = key;
        return key!;
      }

      // 👇 Web 平台备用实现
      if (kIsWeb) {
        return await _initializeWeb();
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
      String? key = await StorageSecureService.to.read(key: Keys.privateKey);
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
      _cachedPublicKey = _encodePublicKeyToPem(
        keyPair.publicKey as RSAPublicKey,
      );
      _cachedPrivateKey = _encodePrivateKeyToPem(
        keyPair.privateKey as RSAPrivateKey,
      );

      // 存储到安全存储
      await Future.wait([
        StorageSecureService.to.write(
          key: Keys.publicKey,
          value: _cachedPublicKey!,
        ),
        StorageSecureService.to.write(
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

  /// 重置 RSA 服务状态（仅用于测试）
  ///
  /// 清除缓存的密钥和初始化状态，强制下次访问时重新生成/读取密钥
  static void resetForTest() {
    _isInitialized = false;
    _cachedPublicKey = null;
    _cachedPrivateKey = null;
  }

  /// 生成RSA密钥对
  static AsymmetricKeyPair<PublicKey, PrivateKey> _generateRSAKeyPair({
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
      final secureRandom = SecureRandom('Fortuna');

      if (kIsWeb) {
        // Web 平台：使用 Random.secure() 生成种子
        final random = Random.secure();
        final seed = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          seed[i] = random.nextInt(256);
        }
        secureRandom.seed(KeyParameter(seed));
      } else {
        // 移动端：使用平台熵源
        final entropySource = Platform.instance.platformEntropySource();
        secureRandom.seed(KeyParameter(entropySource.getBytes(32)));
      }

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

  /// RSA 加密（使用 RSA-OAEP-SHA256 填充）
  ///
  /// 🔒 安全标准：统一使用 RSA-OAEP-SHA256
  /// - 用于 E2EE 端对端加密
  /// - 与 Web Crypto API 和登录密码加密保持一致
  /// - 抗选择密文攻击（CCA）
  ///
  /// ⚠️ 破坏性变更：从 OAEP-SHA1 升级到 OAEP-SHA256
  /// 旧的 E2EE 消息将无法解密，需要重新交换密钥
  static Uint8List rsaEncrypt(RSAPublicKey publicKey, Uint8List dataToEncrypt) {
    try {
      // 🔒 使用 RSA-OAEP-SHA256（统一安全标准）
      final encryptor = OAEPEncoding.withSHA256(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      return _processInBlocks(encryptor, dataToEncrypt);
    } catch (e) {
      throw Exception('RSA加密失败: $e');
    }
  }

  /// RSA 解密（使用 RSA-OAEP-SHA256 填充）
  ///
  /// 🔒 安全标准：统一使用 RSA-OAEP-SHA256
  /// - 用于 E2EE 端对端加密
  /// - 与加密方法保持一致
  ///
  /// ⚠️ 破坏性变更：只能解密使用 OAEP-SHA256 加密的数据
  static Uint8List rsaDecrypt(RSAPrivateKey privateKey, Uint8List cipherText) {
    try {
      // 🔒 使用 RSA-OAEP-SHA256（统一安全标准）
      final decryptor = OAEPEncoding.withSHA256(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      return _processInBlocks(decryptor, cipherText);
    } catch (e) {
      throw Exception('RSA解密失败: $e');
    }
  }

  /// 分块处理数据
  static Uint8List _processInBlocks(
    AsymmetricBlockCipher engine,
    Uint8List input,
  ) {
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
  static Uint8List rsaSign(RSAPrivateKey privateKey, Uint8List dataToSign) {
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
  static bool rsaVerify(
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

  /// 将字节数组转换为大整数
  static BigInt bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  static RSAPublicKey parsePublicKeyFromPem(String pem) {
    try {
      final cleaned = pem
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '');

      final derBytes = base64.decode(cleaned);

      // 使用 asn1lib 解析，更兼容各种ASN.1标签
      final asn1Parser = asn1.ASN1Parser(derBytes);
      final topLevelSeq = asn1Parser.nextObject() as asn1.ASN1Sequence;

      // SubjectPublicKeyInfo 结构
      // AlgorithmIdentifier + SubjectPublicKey
      final subjectPublicKey = topLevelSeq.elements[1] as asn1.ASN1BitString;

      // 解析 SubjectPublicKey (BIT STRING) 中的 RSAPublicKey
      final publicKeyBytes = subjectPublicKey.stringValue;
      final publicKeyParser = asn1.ASN1Parser(
        Uint8List.fromList(publicKeyBytes),
      );
      final rsaPublicKeySeq = publicKeyParser.nextObject() as asn1.ASN1Sequence;

      // RSAPublicKey ::= SEQUENCE {
      //   modulus           INTEGER,  -- n
      //   publicExponent    INTEGER   -- e
      // }
      final modulusAsn1 = rsaPublicKeySeq.elements[0] as asn1.ASN1Integer;
      final exponentAsn1 = rsaPublicKeySeq.elements[1] as asn1.ASN1Integer;

      final modulus = bytesToBigInt(
        Uint8List.fromList(modulusAsn1.valueBytes()),
      );
      final exponent = bytesToBigInt(
        Uint8List.fromList(exponentAsn1.valueBytes()),
      );

      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      throw Exception('解析RSA公钥失败: $e');
    }
  }

  static RSAPrivateKey parsePrivateKeyFromPem(String pem) {
    try {
      final cleaned = pem
          .replaceAll('-----BEGIN PRIVATE KEY-----', '')
          .replaceAll('-----END PRIVATE KEY-----', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '');

      final derBytes = base64.decode(cleaned);

      final asn1Parser = asn1.ASN1Parser(derBytes);
      final topLevelSeq = asn1Parser.nextObject() as asn1.ASN1Sequence;

      final privateKeyOctetString =
          topLevelSeq.elements[2] as asn1.ASN1OctetString;
      final privateKeyBytes = privateKeyOctetString.valueBytes();

      final privateKeyParser = asn1.ASN1Parser(
        Uint8List.fromList(privateKeyBytes),
      );
      final rsaPrivateKeySeq =
          privateKeyParser.nextObject() as asn1.ASN1Sequence;

      final modulusAsn1 = rsaPrivateKeySeq.elements[1] as asn1.ASN1Integer;
      final privateExponentAsn1 =
          rsaPrivateKeySeq.elements[3] as asn1.ASN1Integer;
      final pAsn1 = rsaPrivateKeySeq.elements[4] as asn1.ASN1Integer;
      final qAsn1 = rsaPrivateKeySeq.elements[5] as asn1.ASN1Integer;

      final modulus = bytesToBigInt(
        Uint8List.fromList(modulusAsn1.valueBytes()),
      );
      final privateExponent = bytesToBigInt(
        Uint8List.fromList(privateExponentAsn1.valueBytes()),
      );
      final p = bytesToBigInt(Uint8List.fromList(pAsn1.valueBytes()));
      final q = bytesToBigInt(Uint8List.fromList(qAsn1.valueBytes()));

      return RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      throw Exception('解析RSA私钥失败: $e');
    }
  }

  static Future<RSAPrivateKey> privateKeyObject() async {
    final pem = await privateKey();
    if (pem == null || pem.isEmpty) {
      throw Exception('私钥不存在');
    }
    return parsePrivateKeyFromPem(pem);
  }

  /// RSA 加密（使用 RSA-OAEP-SHA256 填充）
  ///
  /// 🔒 安全升级：从 PKCS#1 v1.5 升级到 RSA-OAEP
  /// - OAEP 是可证明安全的填充方案
  /// - 使用 SHA-256 作为哈希算法（与 Web Crypto API 一致）
  /// - 抗选择密文攻击（CCA）
  ///
  /// 注意：后端必须使用相同的 RSA-OAEP-SHA256 进行解密
  static String rsaEncryptWithPointyCastle(String plaintext, String pubKeyPem) {
    if (kIsWeb) {
      // Web 平台：使用真正的 RSA 加密（Web Crypto API）
      // 注意：这是一个同步函数，但 Web Crypto API 是异步的
      // 我们需要特殊处理这种情况
      throw UnsupportedError(
        'Web 平台请使用 rsaEncryptWithPointyCastleAsync 方法进行 RSA 加密',
      );
    }

    // 移动端/桌面端：使用 pointycastle
    final publicKey = parsePublicKeyFromPem(pubKeyPem);

    // 🔒 使用 RSA-OAEP-SHA256 填充（与 Web Crypto API 一致）
    // pointycastle 4.0.0: 使用 withSHA256 构造函数
    final engine = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = engine.process(input);

    return base64.encode(encrypted); // 输出保持不变
  }

  /// Web 平台 RSA 加密（异步版本）
  ///
  /// 🔒 统一使用 pointycastle（纯 Dart 实现）
  /// - 绕过 Web Crypto API 的限制
  /// - 与移动端使用相同的加密库
  /// - 保证跨平台一致性
  static Future<String> rsaEncryptWithPointyCastleAsync(
    String plaintext,
    String pubKeyPem,
  ) async {
    // 所有平台统一使用 pointycastle（纯 Dart 实现）
    // 这样可以保证跨平台一致性，避免 Web Crypto API 兼容性问题
    try {
      final publicKey = parsePublicKeyFromPem(pubKeyPem);

      // 🔒 使用 RSA-OAEP-SHA256 填充
      final engine = OAEPEncoding.withSHA256(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      final input = Uint8List.fromList(utf8.encode(plaintext));

      final encrypted = engine.process(input);

      final result = base64.encode(encrypted);
      return result;
    } catch (e) {
      throw Exception('RSA 加密失败: $e');
    }
  }

  // region Web 平台备用实现

  /// Web 平台初始化 RSA 密钥对
  ///
  /// 🔒 安全修复 (S3): 使用 Web Crypto API 为每个用户生成唯一的密钥对
  /// 不再使用固定的测试密钥
  static Future<String> _initializeWeb() async {
    if (_isInitialized) return _cachedPublicKey!;

    try {
      // 检查浏览器是否支持 Web Crypto API
      if (!kIsWeb) {
        throw UnsupportedError('非 Web 平台不能使用此方法');
      }

      // 检查是否已有存储的密钥对
      final storage = webWindow.localStorage;
      final storedPublicKey = storage.getItem('rsa_public_key');
      final storedPrivateKey = storage.getItem('rsa_private_key');

      if (storedPublicKey != null &&
          storedPrivateKey != null &&
          storedPrivateKey.isNotEmpty) {
        _cachedPublicKey = storedPublicKey;
        _cachedPrivateKey = storedPrivateKey;
        _isInitialized = true;
        return storedPublicKey;
      }

      // 🔒 安全修复：使用 Web Crypto API 为每个用户生成唯一的密钥对
      // 不再使用固定的测试密钥（安全漏洞 S3）

      final keyPair = await generateRSAKeyPairWeb();

      _cachedPublicKey = keyPair['publicKey'];
      _cachedPrivateKey = keyPair['privateKey'];
      _isInitialized = true;

      // 存储到 localStorage（每个用户有唯一的密钥）
      storage.setItem('rsa_public_key', _cachedPublicKey!);
      storage.setItem('rsa_private_key', _cachedPrivateKey!);

      return _cachedPublicKey!;
    } catch (e) {
      _isInitialized = false;
      _cachedPublicKey = null;
      _cachedPrivateKey = null;
      throw Exception('Web 平台初始化 RSA 密钥对失败: $e');
    }
  }

  // endregion
}
