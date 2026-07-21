/// E2EE-014 Trust Event canonical 编码器（ADR 16 §3.3.1，scoped waiver 子集）。
///
/// 「A 信任 B」的 trust-event 签名负载。客户端用 Ed25519 私钥对本编码器产出的
/// 规范字节流签名，服务端 `e2ee_trust_logic:canonical_payload/1` 逐字节复算验签
/// （imboy/src/logic/e2ee_trust_logic.erl）。两端**必须**产出完全相同的字节，
/// 否则验签全拒（wire 双端契约）。
///
/// 编码收敛（§3.3.1，不采用 CBOR）：
/// - 11 个签名字段按 ASCII 字典序排列；
/// - 每字段 `key=value`，字段间以 `\n` 连接，**末字段无尾随换行**；
/// - 整数十进制、UTF-8。
///
/// 范围：仅 trust-event 子集；cross-signing（§5）/ master key / manifest
/// account_signature / transparency inclusion proof 仍 Proposed，未实现。
///
/// ⚠️ 本文件只做 canonical 编码 + 签名封装，**未做 wire 往返验证**（需运行后端
/// + 真机逐字节比对）。golden 向量取自后端 `canonical_payload/1` 真实输出，见
/// `test/service/e2ee/trust_event_canonical_test.dart`。
library;

import 'dart:convert';
import 'dart:typed_data';

/// event_id 格式约束（§3.3.1）：`[0-9a-f-]{1,64}`。该正则天然排除会破坏
/// canonical 结构的 `\n` / `=`，是防注入的边界校验。
final RegExp _eventIdPattern = RegExp(r'^[0-9a-f-]{1,64}$');

/// fail-closed 拒收含 `\n`/`\r` 的 canonical 字段值（破坏单射，见 [canonicalBytes]）。
void _rejectNewline(String name, String value) {
  if (value.contains('\n') || value.contains('\r')) {
    throw ArgumentError.value(
      value,
      name,
      'must not contain newline (breaks canonical)',
    );
  }
}

/// Ed25519 签名器：入参为 canonical UTF-8 字节，返回 64 字节原始签名。
/// 生产实现由 vodozemac `Account.sign` 在调用点注入（wire slice 接线）。
typedef Ed25519Signer = List<int> Function(List<int> message);

/// trust-event 的 11 个签名字段（不可变）。字段名与后端 canonical key 一一对应。
class TrustEventCanonicalFields {
  const TrustEventCanonicalFields({
    required this.actorDeviceGeneration,
    required this.actorUid,
    required this.eventId,
    required this.expiresAt,
    required this.fromState,
    required this.issuedAt,
    required this.targetDeviceId,
    required this.targetEd25519,
    required this.targetIdentityVersion,
    required this.targetUid,
    required this.toState,
  });

  /// actor 设备重注册代数，防旧设备重放。
  final int actorDeviceGeneration;

  /// 决策发起方 uid。
  final int actorUid;

  /// 客户端生成的全局唯一幂等键，`[0-9a-f-]{1,64}`。
  final String eventId;

  /// 事件有效期上界（毫秒）。
  final int expiresAt;

  /// 原信任态。
  final String fromState;

  /// 签发时刻（毫秒），freshness 下界。
  final int issuedAt;

  /// 对端设备 id。
  final String targetDeviceId;

  /// 决策时对端 Ed25519 身份键快照（base64）。
  final String targetEd25519;

  /// 对端身份键版本，防回退。
  final int targetIdentityVersion;

  /// 对端 uid。
  final int targetUid;

  /// 目标信任态。
  final String toState;

  /// 产出与后端逐字节一致的 canonical 字节流。
  ///
  /// 抛 [ArgumentError]（fail-closed）当 [eventId] 不匹配 §3.3.1 格式——非法
  /// event_id 会破坏 `key=value\n` 结构或被后端拒签，提前拒绝好过静默产出坏包。
  Uint8List canonicalBytes() {
    if (!_eventIdPattern.hasMatch(eventId)) {
      throw ArgumentError.value(
        eventId,
        'eventId',
        'must match [0-9a-f-]{1,64} (ADR 16 §3.3.1)',
      );
    }
    // canonical 唯一分隔符是 \n；相邻自由文本字段（target_device_id/target_ed25519）
    // 值内含 \n/\r 会使编码非单射（同一签名可对应多组字段拆分→信任伪造）。fail-closed
    // 拒收。from/to_state 一并守卫（后端亦拒）。event_id 已由上方 hex 正则排除换行。
    _rejectNewline('targetDeviceId', targetDeviceId);
    _rejectNewline('targetEd25519', targetEd25519);
    _rejectNewline('fromState', fromState);
    _rejectNewline('toState', toState);
    // ASCII 字典序，末字段无尾随换行。顺序须与后端 canonical_payload/1 完全一致。
    final payload =
        'actor_device_generation=$actorDeviceGeneration\n'
        'actor_uid=$actorUid\n'
        'event_id=$eventId\n'
        'expires_at=$expiresAt\n'
        'from_state=$fromState\n'
        'issued_at=$issuedAt\n'
        'target_device_id=$targetDeviceId\n'
        'target_ed25519=$targetEd25519\n'
        'target_identity_version=$targetIdentityVersion\n'
        'target_uid=$targetUid\n'
        'to_state=$toState';
    return Uint8List.fromList(utf8.encode(payload));
  }

  /// 对 canonical 字节签名，返回 base64 签名（wire 上的 `actor_signature`）。
  /// [signer] 注入真实 Ed25519 私钥签名（生产=vodozemac `Account.sign`）。
  String sign(Ed25519Signer signer) {
    return base64.encode(signer(canonicalBytes()));
  }
}
