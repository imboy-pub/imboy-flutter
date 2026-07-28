import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// Olm（X3DH + Double Ratchet）单聊 E2EE API。
///
/// 对应后端路由（`imboy/src/api/olm_handler.erl`）：
/// - POST /api/v1/e2ee/olm/identity
/// - POST /api/v1/e2ee/olm/prekeys
/// - POST /api/v1/e2ee/olm/fallback_key
/// - GET  /api/v1/e2ee/olm/get_identity
/// - POST /api/v1/e2ee/olm/claim
///
/// 零信任契约：服务端只存/转公钥侧（ed25519/curve25519/one-time/fallback 公钥），
/// 无私钥；claim 端点返回对端 prekey + identity 供客户端 X3DH 协商。
class OlmApi extends HttpClient {
  /// 上报设备 Olm 身份键（ed25519 + curve25519 + 对 curve25519 的签名）
  Future<bool> reportIdentity({
    required String deviceId,
    required String deviceType,
    required String ed25519Key,
    required String curve25519Key,
    required String signature,
  }) async {
    final IMBoyHttpResponse resp = await post(
      API.olmReportIdentity,
      data: {
        'device_id': deviceId,
        'device_type': deviceType,
        'ed25519_key': ed25519Key,
        'curve25519_key': curve25519Key,
        'signature': signature,
      },
    );
    return resp.ok;
  }

  /// 批量上报 one-time keys（全量替换式）
  /// [keys] 元素形如 `{'key_id': '...', 'key_base64': '...'}`
  Future<int> reportPrekeys({
    required String deviceId,
    required List<Map<String, String>> keys,
  }) async {
    final IMBoyHttpResponse resp = await post(
      API.olmReportPrekeys,
      data: {'device_id': deviceId, 'keys': keys},
    );
    if (!resp.ok) return 0;
    final payload = resp.payload;
    if (payload is Map) {
      final count = payload['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
    }
    return keys.length;
  }

  /// 上报 fallback key（每设备覆盖式 1 条）
  Future<bool> reportFallbackKey({
    required String deviceId,
    required String keyId,
    required String keyBase64,
  }) async {
    final IMBoyHttpResponse resp = await post(
      API.olmReportFallback,
      data: {'device_id': deviceId, 'key_id': keyId, 'key_base64': keyBase64},
    );
    return resp.ok;
  }

  /// 查询对端身份键（X3DH createInboundSession / createOutboundSession 需要）
  /// 返回字段：device_id、ed25519_key、curve25519_key、signature（均为公钥/签名）
  Future<Map<String, dynamic>> getIdentity({
    required String uid,
    required String deviceId,
  }) async {
    final IMBoyHttpResponse resp = await get(
      API.olmGetIdentity,
      queryParameters: {'uid': uid, 'device_id': deviceId},
    );
    if (!resp.ok) return <String, dynamic>{};
    final payload = resp.payload;
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return <String, dynamic>{};
  }

  /// E2EE-062：`GET /api/v1/e2ee/olm/prekey_count` 的响应解析。
  ///
  /// **`null` 表示「未知」，不是 0。** 0 是「该补传了」的有效信号；把查询失败
  /// 也报成 0 会让真正的池见底与网络/服务端故障无法区分，并据此对池执行一次
  /// 全量替换——在未知状态上做破坏性动作。后端同样拒绝把错误降级为 0
  /// （imboy `evidence/E2EE-062-prekey-count-endpoint.md` §1.3）。
  @visibleForTesting
  static int? parseCountPayload(dynamic payload) {
    if (payload is! Map) return null;
    final count = payload['count'];
    if (count is! num) return null;
    final n = count.toInt();
    // 负数不是合法余量；服务端不会返回，收到即视为未知而非「空池」——
    // 当成 0 会触发一次全量替换。
    return n < 0 ? null : n;
  }

  /// 查询**本设备**剩余 one-time key 数量（低水位补传的信号来源）。
  ///
  /// 不接受 device_id 入参：服务端只认 token 里的设备（否则该端点就成了
  /// 「探测谁的池快空了」的接口）。返回 `null` = 未知，调用方不得当 0 处理。
  Future<int?> countPrekeys() async {
    final IMBoyHttpResponse resp = await get(API.olmPrekeyCount);
    if (!resp.ok) return null;
    return parseCountPayload(resp.payload);
  }

  /// E2EE-062：claim 请求体构造。
  ///
  /// 单独抽出是为了让「`request_id` 究竟有没有进请求体」可被直接验收——
  /// 这是服务端幂等租约能否在生产流量上生效的唯一开关，靠读源码断言不算实证。
  @visibleForTesting
  static Map<String, dynamic> buildClaimBody({
    required String targetUid,
    required String deviceId,
    required String requestId,
  }) {
    return <String, dynamic>{
      'target_uid': targetUid,
      'device_id': deviceId,
      if (requestId.isNotEmpty) 'request_id': requestId,
    };
  }

  /// 领取对端一个 prekey（X3DH）。
  ///
  /// [requestId] 为幂等键（见 `OlmClaimRequestId`）：同一次建会话尝试的重投
  /// 带同一个 id，服务端只消费一条 one-time prekey。留空即旧语义（逐次消费）。
  /// 返回 `{'type': 'one_time'|'fallback', 'key_id', 'key_base64', 'identity': {...}}`
  Future<Map<String, dynamic>> claimKey({
    required String targetUid,
    required String deviceId,
    String requestId = '',
  }) async {
    final IMBoyHttpResponse resp = await post(
      API.olmClaimKey,
      data: buildClaimBody(
        targetUid: targetUid,
        deviceId: deviceId,
        requestId: requestId,
      ),
    );
    if (!resp.ok) {
      throw Exception('olm claim_key failed: ${resp.msg}');
    }
    final payload = resp.payload;
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw Exception('olm claim_key: invalid payload');
  }
}

/// Olm claim 结果的不可变快照（供 UI/测试消费）。
@immutable
class OlmClaimResult {
  const OlmClaimResult({
    required this.type,
    required this.keyId,
    required this.keyBase64,
    required this.identity,
  });

  final String type; // 'one_time' | 'fallback'
  final String keyId;
  final String keyBase64;
  final Map<String, dynamic> identity;
}
