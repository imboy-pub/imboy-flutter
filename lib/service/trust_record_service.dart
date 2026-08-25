/// 信任事件上报服务（审计阶段 B：trust/record wire 接线）。
///
/// 用户在安全码页比对一致后，把「已手动验证」作为一条签名信任事件上报服务端：
/// `POST /api/v1/e2ee/trust/record`（ADR 16）。服务端用本端 ed25519 公钥
/// 逐字节复算 canonical 验签，校验新鲜度窗、状态机、设备代数匹配与
/// 对端身份版本单调性后落 `trust_audit` 并广播 `e2ee_trust_changed`。
///
/// 数据通路（本服务补齐的阶段 B 缺口）：
/// - `actor_device_generation`：本端设备代数，取自 `GET /api/v1/e2ee/devices`
///   （后端 `user_device.device_generation`，服务端在
///   `e2ee_trust_logic:actor_device_active/3` 中与库值比对，失配=拒绝）；
/// - `target_identity_version`：对端身份版本，同端点
///   （服务端做版本单调校验，防身份键回退攻击）；
/// - `target_ed25519`：对端身份快照，经 [OlmSessionService.peerIdentityKeys]
///   的**已验证路径**获取（Ed25519 自签核验 + TOFU pin）。
///
/// method 用 `manual_number`（后端白名单既有值，语义=手动比对号码）。
library;

import 'dart:convert';
import 'dart:math';

import 'package:imboy/config/init.dart';
import 'package:imboy/service/e2ee/trust_event_canonical.dart';
import 'package:imboy/service/e2ee/trust_event_client.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/store/api/olm_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 信任事件上报结果。
enum TrustRecordOutcome {
  /// 上报成功（服务端已验签并落审计）。
  recorded,

  /// 服务端拒绝（签名/新鲜度/状态机/版本/代数任一不符）。
  rejected,

  /// 客户端侧数据不足（对端无设备/无 identity/无版本字段）。
  unavailable,
}

/// 信任事件上报服务。
class TrustRecordService {
  TrustRecordService._();

  /// 组装并上报「已验证」信任事件。
  ///
  /// [peerUid]/[peerDeviceId] 为对端（安全码页比对的对象）。
  /// 成功后返回 [TrustRecordOutcome.recorded]。
  ///
  /// 幂等：同一 [eventId] 重放服务端返回幂等成功（trust_audit_repo 按
  /// event_id 去重），故调用方可用随机 UUID。
  static Future<TrustRecordOutcome> recordVerified({
    required String peerUid,
    required String peerDeviceId,
    String? eventId,
  }) async {
    final OlmApi api = OlmApi();

    // 1. 本端代数（服务端 actor_device_active 匹配校验）
    final localUid = UserRepoLocal.to.currentUid.toString();
    final myDevices = await api.listDevices(uid: localUid);
    final myGen = _intField(
      _findDevice(myDevices, deviceId),
      'device_generation',
    );
    if (myGen == null) {
      return TrustRecordOutcome.unavailable;
    }

    // 2. 对端身份快照（已验证路径）+ 身份版本
    final peerIdentity = await OlmSessionService.to.peerIdentityKeys(
      peerUid,
      peerDeviceId,
    );
    final targetEd25519 = peerIdentity['ed25519_key'] as String?;
    final peerDevices = await api.listDevices(uid: peerUid);
    final targetVer = _intField(
      _findDevice(peerDevices, peerDeviceId),
      'identity_version',
    );
    if (targetEd25519 == null || targetEd25519.isEmpty || targetVer == null) {
      return TrustRecordOutcome.unavailable;
    }

    // 3. 新鲜度窗（镜像后端 fresh/2：past 300s / future 120s / ttl 300s）
    final now = DateTime.now().millisecondsSinceEpoch;
    final issuedAt = now;
    final expiresAt = now + kMaxTtlMs;

    // 4. canonical 字段 → 签名 → 请求体
    final fields = TrustEventCanonicalFields(
      actorDeviceGeneration: myGen,
      actorUid: int.parse(localUid),
      eventId: eventId ?? _randomEventId(),
      expiresAt: expiresAt,
      fromState: 'unverified',
      issuedAt: issuedAt,
      targetDeviceId: peerDeviceId,
      targetEd25519: targetEd25519,
      targetIdentityVersion: targetVer,
      targetUid: int.parse(peerUid),
      toState: 'verified',
    );
    final signature = await OlmSessionService.to.signTrustCanonical(
      fields.canonicalBytes(),
    );
    final body = buildTrustRecordRequest(
      fields: fields,
      actorDeviceId: deviceId,
      method: 'manual_number',
      actorSignatureB64: signature,
    );

    final ok = await api.recordTrust(body);
    return ok ? TrustRecordOutcome.recorded : TrustRecordOutcome.rejected;
  }

  static Map<String, dynamic>? _findDevice(
    List<Map<String, dynamic>> devices,
    String did,
  ) {
    for (final d in devices) {
      if (d['device_id'] == did) return d;
    }
    return null;
  }

  static int? _intField(Map<String, dynamic>? device, String key) {
    if (device == null) return null;
    final v = device[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// `[0-9a-f-]{1,64}` 幂等键（canonical 契约要求，RFC 4122 UUID 形态）。
  /// event_id 是服务端幂等去重键，必须 CSPRNG 生成防碰撞/预测。
  static String _randomEventId() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16)}';
  }

  /// 解码 canonical 字节为 UTF-8 文本（调试/日志用，不上报）。
  static String canonicalDebug(List<int> bytes) => utf8.decode(bytes);
}
