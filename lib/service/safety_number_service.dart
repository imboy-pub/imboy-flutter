/// Safety Number（安全码）计算服务（审计 P1-2 接线）。
///
/// 把 [SafetyNumber]（Signal FingerprintProtocol v2 兼容，纯函数）接进产品：
/// - 本端 identity 取 [OlmSessionService.localCurve25519Identity]（权威副本）；
/// - 对端 identity 取 [OlmSessionService.peerCurve25519Identity]（已验证路径：
///   Ed25519 自签核验 + TOFU pin，禁止裸调 API）；
/// - 对端设备取 [E2EEService.getUserDevicePublicKeys] 返回的设备列表中的
///   **主设备**（第一个；多设备聚合属后续扩展，见类注释局限）。
///
/// 局限（明示）：当前实现是"单设备对单设备"安全码（Signal v2 是每侧聚合全部
/// 设备 identity）。多设备用户需约定以双方主设备为准，比对前先确认对端设备。
library;

import 'package:imboy/service/e2ee/safety_number.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 安全码计算结果。
class SafetyNumberResult {
  /// 60 位安全码（12 组 × 5 位）。
  final String number;

  /// 对端设备 id（本次计算基于的设备）。
  final String peerDeviceId;

  const SafetyNumberResult({required this.number, required this.peerDeviceId});
}

/// Safety Number 计算服务。
class SafetyNumberService {
  SafetyNumberService._();

  /// 计算本端与 [peerUid] 之间的安全码（基于对端主设备）。
  ///
  /// 抛错语义：
  /// - 对端无任何设备 / 设备无 Olm identity → [ArgumentError]（页面提示"对方
  ///   尚未启用端到端加密"）；
  /// - 对端 identity 签名校验失败 / TOFU 失配 → [OlmAuthenticationException]
  ///   （与建会话同款 fail-closed，页面提示"对方身份密钥已变更"）。
  static Future<SafetyNumberResult> generateForPeer({
    required String peerUid,
    String? peerDeviceId,
  }) async {
    final localUid = UserRepoLocal.to.currentUid.toString();
    final localPub = await OlmSessionService.to.localCurve25519Identity();

    String did = peerDeviceId ?? '';
    if (did.isEmpty) {
      final devices = await E2EEService.getUserDevicePublicKeys(peerUid);
      final dids = devices['didToPem']?.keys.toList() ?? const <String>[];
      if (dids.isEmpty) {
        throw ArgumentError('no_recipient_devices');
      }
      did = dids.first;
    }

    final peerPub = await OlmSessionService.to.peerCurve25519Identity(
      peerUid,
      did,
    );
    final number = SafetyNumber.generate(
      localUid: localUid,
      localIdentityPub: localPub,
      remoteUid: peerUid,
      remoteIdentityPub: peerPub,
    );
    return SafetyNumberResult(number: number, peerDeviceId: did);
  }
}
