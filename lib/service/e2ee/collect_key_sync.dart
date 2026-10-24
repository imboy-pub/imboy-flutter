/// E2EE 收藏密钥分发协议（PLAN 2026-10-24-e2ee-collect §6.2/§6.3，v7.1）
///
/// 批准前置的设备入组流程：
/// ```
/// ① 新设备 → collect_key_enroll_request{device_did}（经自发 C2C 通道，
///    当前在线的全部确认设备可见）；
/// ② 可信旧设备核验目标设备身份 → 用户在【旧设备】上批准；
/// ③ 批准后旧设备【发送前重查授权】：目标仍在设备清单、未被撤销
///    （权威清单 = 服务端 user_device 域）→ 通过才以目标设备会话包裹 CK 发送
///    collect_key_sync；
/// ④ 新设备存储后回 ACK——ACK 仅代表收讫，不构成授权；
/// ⑤ 拒绝=不发送；enroll 重试每次重新执行 ②③；撤销设备不再接收新 CK。
/// ```
///
/// 本模块是**协议核心（纯逻辑+消息编解码）**：设备间传输经注入的
/// [CollectKeySyncTransport]（由通道层实现——自发 C2C + per-device Olm
/// 会话包裹；CK 明文绝不经明文通道）。重试退避由调用方承载（§6.3）。
library;

import 'dart:convert';

/// 入组协议消息（JSON 信封；body 经传输层按设备会话加密）。
class CollectKeySyncMessage {
  const CollectKeySyncMessage({
    required this.type,
    required this.deviceDid,
    this.keyVersion,
    this.ckB64,
    this.deviceFingerprint,
    this.nonce,
  });

  /// enroll_request / enroll_approve / key_delivery / key_ack / key_reject
  final String type;

  /// 发起/目标设备标识。
  final String deviceDid;

  final int? keyVersion;

  /// 仅 key_delivery：CK 的 base64（传输层必须加密承载）。
  final String? ckB64;

  /// 仅 enroll_request：设备指纹摘要（身份核验材料，§6.2②）。
  final String? deviceFingerprint;

  /// 防重放一次性值。
  final String? nonce;

  Map<String, dynamic> toJson() => {
    't': type,
    'did': deviceDid,
    if (keyVersion != null) 'kv': keyVersion,
    if (ckB64 != null) 'ck': ckB64,
    if (deviceFingerprint != null) 'fp': deviceFingerprint,
    if (nonce != null) 'n': nonce,
  };

  static CollectKeySyncMessage? fromJson(Map<String, dynamic> j) {
    final type = j['t'] as String?;
    final did = j['did'] as String?;
    if (type == null || did == null) return null;
    return CollectKeySyncMessage(
      type: type,
      deviceDid: did,
      keyVersion: j['kv'] is int ? j['kv'] as int : null,
      ckB64: j['ck'] as String?,
      deviceFingerprint: j['fp'] as String?,
      nonce: j['n'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());
}

/// 设备间传输适配（由通道层实现：自发 C2C + per-device 加密会话）。
abstract class CollectKeySyncTransport {
  /// 向指定设备发送密文消息（body 已由实现方按设备会话包裹）。
  Future<bool> sendToDevice(String deviceDid, String envelopeJson);

  /// 服务端权威设备清单重查（§6.2③ 发送前重查）：目标仍在清单且未撤销。
  Future<bool> deviceStillAuthorized(String deviceDid);
}

/// 协议决策（纯函数，可测）。
class CollectKeySyncProtocol {
  static const String typeEnrollRequest = 'enroll_request';
  static const String typeKeyDelivery = 'key_delivery';
  static const String typeKeyAck = 'key_ack';
  static const String typeKeyReject = 'key_reject';

  /// §6.2②③ 批准前置 + 发送前重查：两者都通过才允许发送 key_delivery。
  ///
  /// [userApproved] = 用户已在**本（旧）设备**上批准（UI 动作）；
  /// [identityVerified] = 设备指纹/登录来源比对通过（核验材料来自
  /// enroll_request 的 deviceFingerprint）；
  /// 传输层在 send 前还会以 [CollectKeySyncTransport.deviceStillAuthorized]
  /// 重查服务端清单——本函数的 authorizedNow 参数即该结果。
  static bool mayDeliverKey({
    required bool userApproved,
    required bool identityVerified,
    required bool authorizedNow,
  }) => userApproved && identityVerified && authorizedNow;

  /// §6.2④ ACK 语义：仅代表收讫——返回的 [KeyAckOutcome] 不携带任何
  /// 授权位；调用方不得据 ACK 提升任何权限。
  static KeyAckOutcome onAck(CollectKeySyncMessage msg) =>
      KeyAckOutcome(receivedOnly: true, deviceDid: msg.deviceDid);

  /// §6.2⑤ enroll 重试语义：每次重试都要重新走批准+重查（旧批准作废）。
  static bool retryRequiresReapproval() => true;

  /// 构造 key_delivery（CK 字节仅在此时进入协议层；立即交传输层加密）。
  static CollectKeySyncMessage keyDelivery({
    required String targetDid,
    required int keyVersion,
    required String ckB64,
    required String nonce,
  }) => CollectKeySyncMessage(
    type: typeKeyDelivery,
    deviceDid: targetDid,
    keyVersion: keyVersion,
    ckB64: ckB64,
    nonce: nonce,
  );
}

/// ACK 处理结果：receivedOnly 恒 true（§6.2④；结构上杜绝"ACK=授权"误用）。
class KeyAckOutcome {
  const KeyAckOutcome({required this.receivedOnly, required this.deviceDid});

  final bool receivedOnly;
  final String deviceDid;
}
