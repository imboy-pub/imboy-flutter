/// S4: Safety Number（安全码）— Signal 风格带外身份验证
///
/// 算法（兼容 Signal FingerprintProtocol v2）：
/// 1. 将双方 (uid, identityPub) 按 uid 字典序排列（保证对称性）
/// 2. hash = SHA-512(version_byte(0x30) + entry1 + entry2 + ...)
///    其中 entry = utf8(uid) + base64Decode(identityPub)
/// 3. 迭代 5200 次：hash = SHA-512(hash)
/// 4. 取最终 64 字节 hash 的前 60 字节
/// 5. 每 5 字节 → big-endian uint40 mod 100000 → 5 位数字
/// 6. 输出 60 位数字（12 组 × 5 位）
///
/// 多设备聚合：每侧的全部设备 identity key 均参与计算。条目按 (uid, deviceId)
/// 字典序排序。任一新设备加入/移除，双方聚合码都会变化——与 Signal 行为一致。
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

/// 单设备身份键描述。
class DeviceIdentity {
  /// 设备 ID（如 "did_abc123"）。
  final String deviceId;

  /// curve25519 公钥（base64 编码）。
  final String identityPub;

  const DeviceIdentity({required this.deviceId, required this.identityPub});
}

/// Safety Number 生成与格式化。
class SafetyNumber {
  SafetyNumber._();

  /// 生成多设备聚合安全码（Signal 跨设备指纹语义）。
  ///
  /// [localUid] / [remoteUid]：双方稳定用户 ID（TSID 字符串）。
  /// [localDevices] / [remoteDevices]：双方全部已注册设备的 identity key。
  ///   每侧至少应有一个设备，否则抛 [ArgumentError]。
  ///
  /// 对称性保证：generateAggregate(A, B) == generateAggregate(B, A)。
  /// Fail-closed：任何参数为空则抛 [ArgumentError]。
  static String generateAggregate({
    required String localUid,
    required List<DeviceIdentity> localDevices,
    required String remoteUid,
    required List<DeviceIdentity> remoteDevices,
  }) {
    if (localUid.isEmpty || remoteUid.isEmpty) {
      throw ArgumentError('uid 不得为空');
    }
    if (localDevices.isEmpty) {
      throw ArgumentError('localDevices 至少需要一个设备');
    }
    if (remoteDevices.isEmpty) {
      throw ArgumentError('remoteDevices 至少需要一个设备');
    }
    for (final d in [...localDevices, ...remoteDevices]) {
      if (d.deviceId.isEmpty || d.identityPub.isEmpty) {
        throw ArgumentError('deviceId 和 identityPub 不得为空');
      }
    }

    // 构建全部条目：(uid, deviceId, pubKey)，按 (uid, deviceId) 字典序排序
    final allEntries = <(String, String, String)>[
      for (final d in localDevices) (localUid, d.deviceId, d.identityPub),
      for (final d in remoteDevices) (remoteUid, d.deviceId, d.identityPub),
    ];
    allEntries.sort((a, b) {
      final uidCmp = a.$1.compareTo(b.$1);
      if (uidCmp != 0) return uidCmp;
      return a.$2.compareTo(b.$2);
    });

    // 构建 hash 输入：version + sum(utf8(uid) + base64Decode(pub))
    final builder = BytesBuilder();
    builder.addByte(_kVersion);
    for (final (uid, _, pub) in allEntries) {
      builder.add(utf8.encode(uid));
      builder.add(base64Decode(pub));
    }

    // 迭代 SHA-512
    var hash = sha512.convert(builder.toBytes()).bytes;
    for (var i = 1; i < _kIterations; i++) {
      hash = sha512.convert(hash).bytes;
    }

    // 取前 60 字节 → 12 组 × 5 字节 → 12 × 5 位数字 = 60 位
    return _formatDigits(hash);
  }

  /// 生成单设备安全码（兼容旧接口）。
  ///
  /// 内部委托给 [generateAggregate]，各包装为单设备列表。
  /// 新代码请直接使用 [generateAggregate]。
  @Deprecated('请使用 generateAggregate 以支持多设备聚合')
  static String generate({
    required String localUid,
    required String localIdentityPub,
    required String remoteUid,
    required String remoteIdentityPub,
  }) {
    return generateAggregate(
      localUid: localUid,
      localDevices: [
        DeviceIdentity(deviceId: '_', identityPub: localIdentityPub),
      ],
      remoteUid: remoteUid,
      remoteDevices: [
        DeviceIdentity(deviceId: '_', identityPub: remoteIdentityPub),
      ],
    );
  }

  /// 将 60 位安全码格式化为 12 组 × 5 位（便于人类比对）。
  ///
  /// 例：`["12345", "67890", "11111", "22222", ...]`
  static List<String> formatGroups(String safetyNumber) {
    if (safetyNumber.length != 60) {
      throw ArgumentError.value(safetyNumber, 'safetyNumber', '必须为 60 位数字');
    }
    return List.generate(12, (i) => safetyNumber.substring(i * 5, i * 5 + 5));
  }

  /// 从 64 字节 hash 中提取前 60 字节，每 5 字节转 5 位数字。
  static String _formatDigits(List<int> hash) {
    final digits = StringBuffer();
    for (var offset = 0; offset < 60; offset += 5) {
      final chunk = Uint8List.fromList(hash.sublist(offset, offset + 5));
      var value = 0;
      for (final b in chunk) {
        value = (value << 8) | b;
      }
      digits.write((value % 100000).toString().padLeft(5, '0'));
    }
    return digits.toString();
  }
}
