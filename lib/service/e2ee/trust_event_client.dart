/// E2EE-014 Trust Event 客户端逻辑（ADR 16 §3.3.1/§3.2，scoped waiver 子集）。
///
/// 在 [TrustEventCanonicalFields] canonical 编码之上，提供三件纯逻辑：
/// 1. [buildTrustRecordRequest]：组装 POST `/e2ee/trust/record` 请求体（13 字段）；
/// 2. [isFreshTrustEvent]：客户端 freshness 预检，镜像后端 `e2ee_trust_logic:fresh/2`；
/// 3. [TrustChangedEvent.fromBroadcast]：解析并校验 `e2ee_trust_changed` 广播。
///
/// 白名单/时窗常量与后端 `e2ee_trust_logic.erl` 逐一对齐（§3.2 转换、§3.3.1 method、
/// freshness TTL/skew）。任一漂移都会导致后端拒收，故改动须同步两端。
///
/// ⚠️ 纯逻辑，**未做 wire 往返 + 真机验证**（actor_signature 的真实 Ed25519 签名需
/// vodozemac，host 测试不跑 FFI）。请求体里的 `actor_signature` 由调用方传入。
library;

import 'trust_event_canonical.dart';

/// 合法 method（后端 `?VALID_METHODS`，ADR 06 §8.2.2）。
const Set<String> kTrustMethods = {
  'qr_scan',
  'manual_number',
  'revoke',
  'device_destroyed',
};

/// 合法信任态（后端状态机三态）。
const Set<String> kTrustStates = {'unverified', 'verified', 'revoked'};

/// 合法状态转换白名单（后端 `valid_transition/2`，§3.2）。键格式 `from>to`。
const Set<String> _validTransitions = {
  'unverified>verified',
  'verified>unverified',
  'unverified>revoked',
  'verified>revoked',
  'revoked>unverified',
};

/// freshness 时窗（ms），与后端 `?FRESH_PAST_MS/?FRESH_FUTURE_MS/?MAX_TTL_MS` 对齐。
const int kFreshPastMs = 300000;
const int kFreshFutureMs = 120000;
const int kMaxTtlMs = 300000;

/// 状态转换是否合法（§3.2 白名单）。
bool isValidTrustTransition(String fromState, String toState) =>
    _validTransitions.contains('$fromState>$toState');

/// 客户端 freshness 预检，镜像后端 `fresh/2`：
/// `issued_at ∈ [now-past, now+future]`，`expires_at ∈ (issued_at, issued_at+ttl]`
/// 且 `now ≤ expires_at`。[nowMs] 由调用方注入（便于测试，避免隐式取时钟）。
bool isFreshTrustEvent(int issuedAt, int expiresAt, {required int nowMs}) {
  return issuedAt >= nowMs - kFreshPastMs &&
      issuedAt <= nowMs + kFreshFutureMs &&
      expiresAt > issuedAt &&
      expiresAt <= issuedAt + kMaxTtlMs &&
      nowMs <= expiresAt;
}

/// 组装 POST `/e2ee/trust/record` 请求体（13 字段，不含 `actor_uid`——服务端由
/// 已认证 current_uid 权威注入）。
///
/// [fields] 提供 canonical 11 字段（其 `actorUid` 仅用于本地签名，不进请求体）。
/// [actorDeviceId] 发起方设备 id；[method] 决策方式；[actorSignatureB64] 对
/// `fields.canonicalBytes()` 的 Ed25519 签名（base64，调用方注入真实签名）。
///
/// fail-closed：非法 [method] / 非白名单转换 / 空 [actorDeviceId] / 空签名 →
/// [ArgumentError]（本地编程错误，提前拒绝好过发出必被后端拒的坏包）。
/// [fields] 的 event_id 格式校验由 [TrustEventCanonicalFields.canonicalBytes] 兜底。
Map<String, dynamic> buildTrustRecordRequest({
  required TrustEventCanonicalFields fields,
  required String actorDeviceId,
  required String method,
  required String actorSignatureB64,
}) {
  if (!kTrustMethods.contains(method)) {
    throw ArgumentError.value(method, 'method', 'not a valid trust method');
  }
  if (!isValidTrustTransition(fields.fromState, fields.toState)) {
    throw ArgumentError.value(
      '${fields.fromState}>${fields.toState}',
      'transition',
      'not a valid trust state transition (§3.2)',
    );
  }
  if (actorDeviceId.isEmpty) {
    throw ArgumentError.value(
      actorDeviceId,
      'actorDeviceId',
      'must not be empty',
    );
  }
  if (actorSignatureB64.isEmpty) {
    throw ArgumentError.value(
      actorSignatureB64,
      'actorSignatureB64',
      'must not be empty',
    );
  }
  return {
    'actor_device_id': actorDeviceId,
    'target_uid': fields.targetUid,
    'target_device_id': fields.targetDeviceId,
    'target_ed25519': fields.targetEd25519,
    'from_state': fields.fromState,
    'to_state': fields.toState,
    'method': method,
    'event_id': fields.eventId,
    'issued_at': fields.issuedAt,
    'expires_at': fields.expiresAt,
    'actor_device_generation': fields.actorDeviceGeneration,
    'target_identity_version': fields.targetIdentityVersion,
    'actor_signature': actorSignatureB64,
  };
}

/// 解析后的 `e2ee_trust_changed` 广播（后端 `broadcast_trust_changed/1` 的 7 字段）。
class TrustChangedEvent {
  const TrustChangedEvent({
    required this.actorUid,
    required this.targetUid,
    required this.targetDeviceId,
    required this.toState,
    required this.method,
    required this.eventId,
    required this.issuedAt,
  });

  final int actorUid;
  final int targetUid;
  final String targetDeviceId;
  final String toState;
  final String method;
  final String eventId;
  final int issuedAt;

  /// 从广播 payload 解析并校验。外部数据不可信：字段缺失/类型错/非法枚举 →
  /// [FormatException]，绝不静默产出半初始化对象。
  factory TrustChangedEvent.fromBroadcast(Map<String, dynamic> payload) {
    final actorUid = _requireInt(payload, 'actor_uid');
    final targetUid = _requireInt(payload, 'target_uid');
    final targetDeviceId = _requireNonEmptyStr(payload, 'target_device_id');
    final toState = _requireNonEmptyStr(payload, 'to_state');
    final method = _requireNonEmptyStr(payload, 'method');
    final eventId = _requireNonEmptyStr(payload, 'event_id');
    final issuedAt = _requireInt(payload, 'issued_at');
    if (!kTrustMethods.contains(method)) {
      throw FormatException('e2ee_trust_changed: unknown method "$method"');
    }
    if (!kTrustStates.contains(toState)) {
      throw FormatException('e2ee_trust_changed: unknown to_state "$toState"');
    }
    return TrustChangedEvent(
      actorUid: actorUid,
      targetUid: targetUid,
      targetDeviceId: targetDeviceId,
      toState: toState,
      method: method,
      eventId: eventId,
      issuedAt: issuedAt,
    );
  }
}

int _requireInt(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is int) return v;
  throw FormatException(
    'e2ee_trust_changed: "$key" must be int, got ${v.runtimeType}',
  );
}

String _requireNonEmptyStr(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is String && v.isNotEmpty) return v;
  throw FormatException('e2ee_trust_changed: "$key" must be non-empty string');
}
