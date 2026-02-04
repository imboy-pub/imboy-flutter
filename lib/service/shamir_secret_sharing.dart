import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';

/// Shamir Secret Sharing 服务
///
/// 实现 (k, n) 门限秘密共享方案
/// 将秘密分割成 n 份，需要至少 k 份才能重建秘密
class ShamirSecretSharing {
  // 使用大素数作为有限域（GF(p)）
  // 这个素数足够大，可以处理任何可能的输入
  static final BigInt _prime = BigInt.parse(
    '115792089237316195423570985008687907853269984665640564039457584007913129639747',
  );

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

    final random = SecureRandom();
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
  static Uint8List combineShares(List<Map<String, dynamic>> shares) {
    if (shares.length < 2) {
      throw ArgumentError('至少需要 2 个分片才能重建秘密');
    }

    // 使用拉格朗日插值法计算 f(0)
    final secretInt = _lagrangeInterpolate(
      shares.map((s) => BigInt.from(s['x'])).toList(),
      shares.map((s) => s['y'] as BigInt).toList(),
      BigInt.zero,
    );

    // 将 BigInt 转换回字节数组
    final secretBytes = _intToBytes(secretInt);
    return secretBytes;
  }

  /// 生成多项式系数
  ///
  /// 第一个系数是秘密，其余 k-1 个系数是随机数
  static List<BigInt> _generateCoefficients(
    Uint8List secret,
    int k,
    SecureRandom random,
  ) {
    final coeffs = <BigInt>[];

    // 第一个系数是秘密
    coeffs.add(_bytesToInt(secret));

    // 生成 k-1 个随机系数
    for (int i = 1; i < k; i++) {
      final randomBytes = _randomBytes(32, random);
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
  static BigInt _bytesToInt(Uint8List bytes) {
    return BigInt.parse(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
  }

  /// BigInt 转字节数组
  static Uint8List _intToBytes(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0'); // 确保至少 32 字节
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
