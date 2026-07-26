/// S4: Safety Number（安全码）— Signal 风格带外身份验证
///
/// 算法（兼容 Signal FingerprintProtocol v2）：
/// 1. 将双方 (uid, identityPub) 按 uid 字典序排列（保证对称性）
/// 2. hash = SHA-512(version_byte(0x30) + entry1 + entry2)
///    其中 entry = utf8(uid) + base64Decode(identityPub)
/// 3. 迭代 5200 次：hash = SHA-512(hash)
/// 4. 取最终 64 字节 hash 的前 60 字节
/// 5. 每 5 字节 → big-endian uint40 mod 100000 → 5 位数字
/// 6. 输出 60 位数字（12 组 × 5 位）
///
/// 用途：双方各自计算安全码，通过面对面/电话/视频比对。
/// 若一致 → 无 MITM；若不一致 → 存在中间人或一方 identity 已变更。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 迭代次数（Signal 协议规定 5200，抗暴力枚举）
const int _kIterations = 5200;

/// 协议版本字节（ASCII '0'）
const int _kVersion = 0x30;

/// Safety Number 生成与格式化。
class SafetyNumber {
  SafetyNumber._();

  /// 生成 60 位数字安全码。
  ///
  /// [localUid] / [remoteUid]：双方稳定用户 ID（TSID 字符串）。
  /// [localIdentityPub] / [remoteIdentityPub]：双方 identity curve25519 公钥（base64）。
  ///
  /// 对称性保证：generate(A, B) == generate(B, A)。
  /// Fail-closed：任何参数为空则抛 [ArgumentError]。
  static String generate({
    required String localUid,
    required String localIdentityPub,
    required String remoteUid,
    required String remoteIdentityPub,
  }) {
    if (localUid.isEmpty) {
      throw ArgumentError.value(localUid, 'localUid', '不得为空');
    }
    if (remoteUid.isEmpty) {
      throw ArgumentError.value(remoteUid, 'remoteUid', '不得为空');
    }
    if (localIdentityPub.isEmpty) {
      throw ArgumentError.value(localIdentityPub, 'localIdentityPub', '不得为空');
    }
    if (remoteIdentityPub.isEmpty) {
      throw ArgumentError.value(remoteIdentityPub, 'remoteIdentityPub', '不得为空');
    }

    // 按 uid 字典序排列（保证双方计算结果一致）
    final List<(String, String)> entries;
    if (localUid.compareTo(remoteUid) <= 0) {
      entries = [(localUid, localIdentityPub), (remoteUid, remoteIdentityPub)];
    } else {
      entries = [(remoteUid, remoteIdentityPub), (localUid, localIdentityPub)];
    }

    // 构建初始 hash 输入：version + entry1 + entry2
    final builder = BytesBuilder();
    builder.addByte(_kVersion);
    for (final (uid, pub) in entries) {
      builder.add(utf8.encode(uid));
      builder.add(base64Decode(pub));
    }

    // 迭代 SHA-512
    var hash = sha512.convert(builder.toBytes()).bytes;
    for (var i = 1; i < _kIterations; i++) {
      hash = sha512.convert(hash).bytes;
    }

    // 取前 60 字节 → 12 组 × 5 字节 → 12 × 5 位数字 = 60 位
    final digits = StringBuffer();
    for (var offset = 0; offset < 60; offset += 5) {
      final chunk = Uint8List.fromList(hash.sublist(offset, offset + 5));
      // big-endian uint40
      var value = 0;
      for (final b in chunk) {
        value = (value << 8) | b;
      }
      final group = value % 100000;
      digits.write(group.toString().padLeft(5, '0'));
    }

    return digits.toString();
  }

  /// 将 60 位安全码格式化为 12 组 × 5 位（便于人类比对）。
  ///
  /// 例：`"12345 67890 11111 22222 ..."`
  static List<String> formatGroups(String safetyNumber) {
    if (safetyNumber.length != 60) {
      throw ArgumentError.value(safetyNumber, 'safetyNumber', '必须为 60 位数字');
    }
    return List.generate(12, (i) => safetyNumber.substring(i * 5, i * 5 + 5));
  }
}
