/// Capability Negotiation（ADR 04，协商算法与 fallback 顺序冻结）。
///
/// 发送方拉取对端每设备的 capabilities（签名过），按固定 fallback 顺序选择
/// 「双方都支持的最高安全级别套件」，逐设备 fan-out。服务端仅存储转发，不参与决策。
///
/// 冻结项（ADR 04 §10）：[securityRank] fallback 顺序、协商算法（纯函数）、
/// 签名验证在协商第一步。
///
/// 签名验证以**依赖注入**接入（[negotiateOneDevice] 的 `verifySignature` 回调）：
/// ADR 04 §4.2 定义了「验什么」（`protocols || device_id || capabilities_ts`）
/// 但未精确定义 canonical 字节编码，且与 ADR 03 §4.1 identity_signature
/// （已覆盖签名 capabilities）存在潜在冗余。真实 Ed25519 验证实现待架构确认，
/// 本文件不擅定编码。
library;

/// 对端设备能力声明（ADR 04 §3）。
class PeerCapability {
  const PeerCapability({
    required this.deviceId,
    required this.signingKey,
    required this.protocols,
    required this.protocolsSig,
    required this.capabilitiesTs,
  });

  final String deviceId;

  /// 用于校验 [protocolsSig] 的 Ed25519 公钥（base64），即 ADR 03 device
  /// identity signing key。
  final String signingKey;

  /// 该设备支持的协议套件短名（无序；安全级别由 [CapabilityNegotiator.securityRank]
  /// 决定，非列表顺序，防服务端重排）。
  final List<String> protocols;

  /// 对 (protocols, device_id, capabilities_ts) 的 Ed25519 签名（base64）。
  final String protocolsSig;

  /// 客户端声明时间戳（用于异常降级检测）。
  final int capabilitiesTs;
}

/// 单设备协商结果分类（ADR 04 §4.3）。
enum NegotiationOutcome {
  /// 协商出可用套件。
  ok,

  /// 双方无交集，不降级明文（策略层按 e2ee_mode 处理，ADR 04 §6）。
  noCommonSuite,

  /// 签名校验失败 / 空能力：该设备不投递（ADR 04 §4.4 + §8.1）。
  unsupported,
}

/// 单设备协商决策（fan-out plan 的一项）。
class DeviceNegotiation {
  const DeviceNegotiation(this.deviceId, this.outcome, this.suite);

  final String deviceId;
  final NegotiationOutcome outcome;

  /// 选中的套件短名；仅 [outcome] == [NegotiationOutcome.ok] 时非空。
  final String? suite;
}

/// 签名校验失败（ADR 04 §4.2 第 1 步）。触发 TOFU 告警，拒用该设备。
class CapVerificationFailed implements Exception {
  const CapVerificationFailed(this.deviceId);
  final String deviceId;

  @override
  String toString() => 'CapVerificationFailed($deviceId)';
}

/// 协商算法（ADR 04 §4）。纯静态方法，无 I/O，可复现验证。
class CapabilityNegotiator {
  const CapabilityNegotiator._();

  /// 全局 fallback 顺序（ADR 04 §4.1，冻结）。由高到低。
  /// mls 实现后插入 olm 之前；当前占位不参与协商。
  static const List<String> securityRank = ['olm', 'megolm', 'rsa-oaep'];

  /// 单设备协商（ADR 04 §4.2）。
  ///
  /// 第 1 步校验 [peer] 的签名（通过 [verifySignature] 注入）；失败抛
  /// [CapVerificationFailed]。随后取交集，按 [securityRank] 返回最高共同套件；
  /// 无交集返回 `null`（NO_COMMON_SUITE）。
  static String? negotiateOneDevice(
    Set<String> myProtocols,
    PeerCapability peer, {
    required bool Function(PeerCapability) verifySignature,
  }) {
    if (!verifySignature(peer)) {
      throw CapVerificationFailed(peer.deviceId);
    }
    final peerSet = peer.protocols.toSet();
    for (final suite in securityRank) {
      if (myProtocols.contains(suite) && peerSet.contains(suite)) {
        return suite;
      }
    }
    return null;
  }

  /// 多设备 fan-out（ADR 04 §4.3）。签名失败的设备标记
  /// [NegotiationOutcome.unsupported] 且不中断其他设备。返回 deviceId → 决策。
  static Map<String, DeviceNegotiation> negotiatePeer(
    Set<String> myProtocols,
    List<PeerCapability> peerDevices, {
    required bool Function(PeerCapability) verifySignature,
  }) {
    final plan = <String, DeviceNegotiation>{};
    for (final device in peerDevices) {
      try {
        final suite = negotiateOneDevice(
          myProtocols,
          device,
          verifySignature: verifySignature,
        );
        plan[device.deviceId] = suite == null
            ? DeviceNegotiation(
                device.deviceId,
                NegotiationOutcome.noCommonSuite,
                null,
              )
            : DeviceNegotiation(device.deviceId, NegotiationOutcome.ok, suite);
      } on CapVerificationFailed {
        plan[device.deviceId] = DeviceNegotiation(
          device.deviceId,
          NegotiationOutcome.unsupported,
          null,
        );
      }
    }
    return plan;
  }
}
