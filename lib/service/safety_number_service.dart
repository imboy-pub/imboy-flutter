/// Safety Number（安全码）计算服务（审计 P1-2 接线 + 多设备聚合）。
///
/// 把 [SafetyNumber]（Signal FingerprintProtocol v2 兼容，纯函数）接进产品：
/// - 本端 identity 取 [OlmSessionService.localCurve25519Identity]（权威副本）；
/// - 对端 identity 取 [E2EEService.getUserDevicePublicKeys] 返回的**全部设备**；
/// - 双方全部设备 identity key 参与聚合计算（Signal 跨设备指纹语义）：
///   任一新设备加入/移除，聚合码都会变化。
library;

import 'package:imboy/service/e2ee/safety_number.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 安全码计算结果。
class SafetyNumberResult {
  /// 60 位安全码（12 组 × 5 位）。
  final String number;

  /// 本端参与聚合的设备数量。
  final int localDeviceCount;

  /// 对端参与聚合的设备数量。
  final int remoteDeviceCount;

  /// 首个远程设备 ID（用于 trust/record 上报，阶段 B 扩展点）。
  final String remoteDeviceId;

  const SafetyNumberResult({
    required this.number,
    required this.localDeviceCount,
    required this.remoteDeviceCount,
    required this.remoteDeviceId,
  });
}

/// Safety Number 计算服务。
class SafetyNumberService {
  SafetyNumberService._();

  /// 计算本端与 [peerUid] 之间的多设备聚合安全码。
  ///
  /// 双方全部已注册设备均参与计算。返回值包含设备数量，供 UI 展示。
  ///
  /// 抛错语义：
  /// - 对端无任何设备 / 设备无 Olm identity → [ArgumentError]（页面提示"对方
  ///   尚未启用端到端加密"）；
  /// - 对端 identity 签名校验失败 / TOFU 失配 → [OlmAuthenticationException]
  ///   （与建会话同款 fail-closed，页面提示"对方身份密钥已变更"）。
  static Future<SafetyNumberResult> generateForPeer({
    required String peerUid,
  }) async {
    final localUid = UserRepoLocal.to.currentUid.toString();
    final localKeys = await OlmSessionService.to.localCurve25519Identity();
    // localKeys 是本端当前设备的 key；多设备场景需从本地 CryptoStore 读取
    // 全部已注册设备的 identity key。当前简化：仅取本设备。
    // TODO: 从 CryptoStore 读取本端全部设备 identity key
    final localDevices = [DeviceIdentity(deviceId: '', identityPub: localKeys)];

    final devices = await E2EEService.getUserDevicePublicKeys(peerUid);
    final didToPem = devices['didToPem'] ?? <String, String>{};
    if (didToPem.isEmpty) {
      throw ArgumentError('no_recipient_devices');
    }

    final remoteDevices = didToPem.entries.map((e) {
      final kid = devices['didToKid']?[e.key]?.toString() ?? e.key;
      return DeviceIdentity(deviceId: kid, identityPub: e.value);
    }).toList();

    // 按 deviceId 排序
    remoteDevices.sort((a, b) => a.deviceId.compareTo(b.deviceId));

    final number = SafetyNumber.generateAggregate(
      localUid: localUid,
      localDevices: localDevices,
      remoteUid: peerUid,
      remoteDevices: remoteDevices,
    );
    return SafetyNumberResult(
      number: number,
      localDeviceCount: localDevices.length,
      remoteDeviceCount: remoteDevices.length,
      remoteDeviceId: remoteDevices.first.deviceId,
    );
  }
}
