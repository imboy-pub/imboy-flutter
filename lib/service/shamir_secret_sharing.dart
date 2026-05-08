import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';

/// Shamir Secret Sharing 服务
///
/// 实现 (k, n) 门限秘密共享方案
/// 将秘密分割成 n 份，需要至少 k 份才能重建秘密
///
/// 安全说明：
/// - 使用 2048 位安全素数（RFC 3526 MODP Group 14）
/// - 支持分割最大 256 字节（2048 位）的秘密
/// - 适用于 RSA-2048 私钥的社交恢复
class ShamirSecretSharing {
  /// 使用 RFC 3526 2048-bit MODP Group (Group 14) 的素数
  /// 这是一个标准的安全素数，广泛用于 IKE (Internet Key Exchange)
  /// 参考：https://datatracker.ietf.org/doc/html/rfc3526#section-3
  ///
  /// 安全性：
  /// - 2048 位长度，符合 NIST 和 OWASP 安全建议
  /// - (p-1)/2 也是素数（安全素数）
  /// - 可以抵抗当前已知的数学攻击
  static final BigInt _prime = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
    '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
    '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05'
    '98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB'
    '9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718'
    '3995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF',
    radix: 16,
  );

  /// 素数的字节长度（2048 位 = 256 字节）
  static const int _primeByteLength = 256;

  /// 分割秘密
  ///
  /// [secret] 要分割的秘密（字节数组）
  /// [n] 总分片数（n > k）
  /// [k] 恢复阈值（最少需要的分片数）
  /// 返回分片列表，每个分片包含索引和值
  static List<Map<String, dynamic>> splitSecret(
    Uint8List secret,
    int n,
    int k,
  ) {
    if (n <= k) {
      throw ArgumentError('总分片数 n 必须大于阈值 k');
    }
    if (k < 2) {
      throw ArgumentError('阈值 k 必须至少为 2');
    }

    // 使用 Fortuna 安全随机数生成器
    final random = SecureRandom('Fortuna');
    // 使用加密安全随机数初始化种子（32 字节完整熵）
    final seed = Uint8List(32);
    final secureRand = Random.secure();
    for (int i = 0; i < 32; i++) {
      seed[i] = secureRand.nextInt(256);
    }
    random.seed(KeyParameter(seed));

    final coeffs = _generateCoefficients(secret, k, random);
    final shares = <Map<String, dynamic>>[];

    // 生成 n 个分片
    for (int i = 1; i <= n; i++) {
      final x = BigInt.from(i);
      final y = _evaluatePolynomial(coeffs, x);

      shares.add({'index': i, 'x': x.toInt(), 'y': y});
    }

    return shares;
  }

  /// 从分片重建秘密
  ///
  /// [shares] 分片列表，至少包含 k 个分片
  /// 返回原始秘密（字节数组）
  ///
  /// 安全验证：
  /// - 验证分片格式有效性
  /// - 验证分片索引唯一性
  /// - 验证恢复的秘密长度合理
  static Uint8List combineShares(List<Map<String, dynamic>> shares) {
    if (shares.length < 2) {
      throw ArgumentError('至少需要 2 个分片才能重建秘密');
    }

    // 安全验证 1：验证分片格式
    for (final share in shares) {
      if (!_isValidShare(share)) {
        throw ArgumentError('无效的分片格式: $share');
      }
    }

    // 安全验证 2：验证分片索引唯一性（防止重复分片攻击）
    final indices = shares.map((s) => s['x']).toSet();
    if (indices.length != shares.length) {
      throw ArgumentError('存在重复的分片索引，可能是攻击行为');
    }

    // 使用拉格朗日插值法计算 f(0)
    final secretInt = _lagrangeInterpolate(
      shares.map((s) => BigInt.from(s['x'])).toList(),
      shares.map((s) => s['y'] as BigInt).toList(),
      BigInt.zero,
    );

    // 将 BigInt 转换回字节数组
    final secretBytes = _intToBytes(secretInt);

    // 安全验证 3：验证恢复的秘密长度合理
    // 空秘密是有效的（长度为 0）
    // AES-256 密钥是 32 字节，RSA-2048 私钥最大 256 字节
    if (secretBytes.length > _primeByteLength) {
      throw ArgumentError('恢复的秘密长度异常: ${secretBytes.length} 字节');
    }

    return secretBytes;
  }

  /// 验证分片格式是否有效
  static bool _isValidShare(Map<String, dynamic> share) {
    if (!share.containsKey('x') || !share.containsKey('y')) {
      return false;
    }

    final x = share['x'];
    final y = share['y'];

    // x 必须是正整数
    if (x is! int || x <= 0) {
      return false;
    }

    // y 必须是 BigInt 且在有效范围内
    if (y is! BigInt) {
      return false;
    }

    if (y <= BigInt.zero || y >= _prime) {
      return false;
    }

    return true;
  }

  /// 生成多项式系数
  ///
  /// 第一个系数是秘密，其余 k-1 个系数是随机数
  /// 随机系数的大小与秘密大小相同，确保安全性
  static List<BigInt> _generateCoefficients(
    Uint8List secret,
    int k,
    SecureRandom random,
  ) {
    final coeffs = <BigInt>[];

    // 第一个系数是秘密
    coeffs.add(_bytesToInt(secret));

    // 生成 k-1 个随机系数
    // 使用与秘密相同大小的随机数，但不超过素数长度
    final randomSize = secret.length.clamp(32, _primeByteLength);
    for (int i = 1; i < k; i++) {
      final randomBytes = _randomBytes(randomSize, random);
      coeffs.add(_bytesToInt(randomBytes));
    }

    return coeffs;
  }

  /// 在 x 处计算多项式的值
  ///
  /// f(x) = a0 + a1*x + a2*x^2 + ... + ak-1*x^(k-1)
  static BigInt _evaluatePolynomial(List<BigInt> coeffs, BigInt x) {
    BigInt result = BigInt.zero;

    for (int i = 0; i < coeffs.length; i++) {
      final term = coeffs[i] * x.modPow(BigInt.from(i), _prime);
      result = (result + term) % _prime;
    }

    return result;
  }

  /// 拉格朗日插值法
  ///
  /// 给定点 (x_i, y_i)，计算在 x 处的值
  static BigInt _lagrangeInterpolate(
    List<BigInt> xValues,
    List<BigInt> yValues,
    BigInt x,
  ) {
    if (xValues.length != yValues.length) {
      throw ArgumentError('xValues 和 yValues 长度必须相同');
    }

    BigInt result = BigInt.zero;

    for (int i = 0; i < xValues.length; i++) {
      BigInt basis = BigInt.one;

      for (int j = 0; j < xValues.length; j++) {
        if (i != j) {
          // numerator: (x - x_j)
          final numerator = (x - xValues[j]) % _prime;

          // denominator: (x_i - x_j)
          final denominator = (xValues[i] - xValues[j]) % _prime;

          // denominator^-1 mod p
          final denominatorInverse = _modInverse(denominator, _prime);

          // basis *= numerator * denominator^-1
          basis = (basis * numerator * denominatorInverse) % _prime;
        }
      }

      // result += y_i * basis
      result = (result + yValues[i] * basis) % _prime;
    }

    return result;
  }

  /// 计算模逆元
  ///
  /// 返回 a^-1 mod m
  static BigInt _modInverse(BigInt a, BigInt m) {
    if (a == BigInt.zero) {
      throw ArgumentError('a 不能为零');
    }

    a = a % m;
    BigInt m0 = m;
    BigInt x0 = BigInt.zero;
    BigInt x1 = BigInt.one;

    if (m == BigInt.one) {
      return BigInt.zero;
    }

    while (a > BigInt.one) {
      final q = a ~/ m;
      var t = m;

      m = a % m;
      a = t;
      t = x0;

      x0 = x1 - q * x0;
      x1 = t;
    }

    if (x1 < BigInt.zero) {
      x1 += m0;
    }

    return x1;
  }

  /// 字节数组转 BigInt
  ///
  /// 空字节数组返回 BigInt.zero
  static BigInt _bytesToInt(Uint8List bytes) {
    if (bytes.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
  }

  /// BigInt 转字节数组
  ///
  /// 自动检测需要的字节数，确保能正确表示大整数
  /// 对于 2048 位素数域，最大支持 256 字节的秘密
  /// 零值返回空数组（用于空秘密）
  static Uint8List _intToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List(0); // 空秘密返回空数组
    }

    // 计算需要的字节数
    int byteLength = (value.bitLength + 7) ~/ 8;

    // 对于小于 32 字节的秘密，保持原始长度
    // 对于大于 32 字节的秘密，使用实际需要的长度
    final hex = value.toRadixString(16).padLeft(byteLength * 2, '0');
    final bytes = <int>[];

    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }

    return Uint8List.fromList(bytes);
  }

  /// 生成随机字节数组
  static Uint8List _randomBytes(int length, SecureRandom random) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextUint8();
    }
    return bytes;
  }
}
