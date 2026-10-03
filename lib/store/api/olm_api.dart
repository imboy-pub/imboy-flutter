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
    // 请求失败必须上抛：调用方（OlmSessionService.publishIdentityAndPrekeys）
    // 不检查返回值，false 会被吞成「身份已上报」——对端永远建不了会话且无任何信号。
    resp.throwIfFailed();
    return true;
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
    // 失败必须上抛：调用方得手后无条件 markKeysAsPublished()，
    // 返回 0 会把「上传失败」伪装成「上传了 0 条」并照标已发布。
    resp.throwIfFailed();
    final payload = resp.payload;
    if (payload is Map) {
      final count = payload['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
    }
    return keys.length;
  }

  /// 上报 fallback key（每设备覆盖式 1 条）
  /// E2EE-062：fallback 上报请求体构造。
  ///
  /// 单独抽出是为了让「签名究竟有没有进请求体」可被直接验收——
  /// 这是服务端验签能否在生产流量上生效的唯一开关。
  @visibleForTesting
  static Map<String, dynamic> buildFallbackBody({
    required String deviceId,
    required String keyId,
    required String keyBase64,
    required String signature,
  }) {
    if (signature.isEmpty) {
      // fail-closed：本端两个调用点（registerDevice / maybeRotateFallbackKey）
      // 都必然能签名，空签名只可能来自**新增调用点漏签**。
      // 静默上传一把未签名的 fallback key，正好把服务端验签那一刀整个绕过去
      // ——服务端为兼容旧客户端仍会接受未签名上传（两阶段推进的第一阶段）。
      throw ArgumentError.value(
        signature,
        'signature',
        'fallback key must be signed by the device identity key',
      );
    }
    return <String, dynamic>{
      'device_id': deviceId,
      'key_id': keyId,
      'key_base64': keyBase64,
      'signature': signature,
    };
  }

  /// 上报 fallback key。
  ///
  /// [signature] 为设备 ed25519 身份键对 `fallbackKeyCanonical` 的签名（base64）。
  /// 留空即旧语义（服务端接受但计入 `olm_fallback_unsigned_total`）。
  /// ⚠️ [signature] **无默认值**：本会话已两次踩到「参数默认值与调用点现实不符」
  /// 这一类缺陷（另一处是 `_refillOneTimeKeys` 的 `seed`）。
  /// 安全相关参数一律强制调用方显式决定，漏签在**编译期**即不可表达。
  Future<bool> reportFallbackKey({
    required String deviceId,
    required String keyId,
    required String keyBase64,
    required String signature,
  }) async {
    final IMBoyHttpResponse resp = await post(
      API.olmReportFallback,
      data: buildFallbackBody(
        deviceId: deviceId,
        keyId: keyId,
        keyBase64: keyBase64,
        signature: signature,
      ),
    );
    // 失败必须上抛：调用方（fallback 轮换链）不检查返回值，
    // false 会被吞成「fallback 已上报」——OTK 耗尽后无兜底键可用且无信号。
    resp.throwIfFailed();
    return true;
  }

  /// 查询对端身份键（X3DH createInboundSession / createOutboundSession 需要）
  /// 返回字段：device_id、ed25519_key、curve25519_key、signature（均为公钥/签名）
  ///
  /// C17b 复审 gap 收口：响应属服务端可控内容，与 [parseClaimPayload] 同型
  /// 走严格解析——结构损坏（非 map / 非 String key / 字段类型混淆）抛带
  /// `olm get_identity: invalid payload` 前缀的 Exception，而非让
  /// `Map<String, dynamic>.from` 的 TypeError 或消费点（`_lookupPeerIdentity`
  /// 的 `as String` 硬 cast）以非契约异常炸进建会话路径。
  /// `!resp.ok`（HTTP 层失败/对端无身份）保持既有空 map 语义——上层
  /// `verifyIdentitySignature` 对空 identity 会 fail-closed 拒收。
  Future<Map<String, dynamic>> getIdentity({
    required String uid,
    required String deviceId,
  }) async {
    final IMBoyHttpResponse resp = await get(
      API.olmGetIdentity,
      queryParameters: {'uid': uid, 'device_id': deviceId},
    );
    if (!resp.ok) return <String, dynamic>{};
    return parseIdentityPayload(resp.payload);
  }

  /// `GET /api/v1/e2ee/devices?uid=` — 列出对端全部活跃 Olm 设备。
  ///
  /// 返回 `{user_id, devices: [{device_id, device_type, trust_state,
  /// device_generation, identity_version, ed25519_key, curve25519_key, ...}]}`。
  /// `device_generation`/`identity_version` 供 trust/record 上报（审计阶段 B）：
  /// 本端设备代数与对端身份版本必须在事件签名中被服务端核验。
  Future<List<Map<String, dynamic>>> listDevices({required String uid}) async {
    final IMBoyHttpResponse resp = await get(
      API.olmDevices,
      queryParameters: {'uid': uid},
    );
    if (!resp.ok) return const [];
    final payload = resp.payload;
    final devices = payload is Map ? payload['devices'] : null;
    if (devices is List) {
      return devices.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return const [];
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
    return parseClaimPayload(resp.payload);
  }

  /// C17b 复审 m2：把 key 类型未知的 Map 显式转写为 `Map<String, dynamic>`。
  ///
  /// `Map<String, dynamic>.from(m)` 遇非 String key 会抛 **TypeError** 泄出
  /// 解析层（生产 jsonDecode 不可达，但 fuzz oracle 契约要求解析失败一律走
  /// 带前缀的拒收 Exception）。改为逐 entry 检查 key 类型，违规即调用
  /// [reject]（各 parse 函数自己的 fail-closed 前缀）。
  static Map<String, dynamic> _asStringKeyMap(
    Map<dynamic, dynamic> m,
    String field,
    Never Function(String why) reject,
  ) {
    final out = <String, dynamic>{};
    for (final e in m.entries) {
      if (e.key is! String) {
        reject('$field 含非 String key（${e.key.runtimeType}）');
      }
      out[e.key as String] = e.value;
    }
    return out;
  }

  /// C17b（AC-35 前置）：claim 响应严格解析（fail-closed）。
  ///
  /// E2EE 威胁模型内服务端不可信（零密码学契约靠客户端守门），claim 响应
  /// 属服务端可控内容。此前 `_establishOutboundSession` 直接
  /// `claim['identity'] as Map<String, dynamic>` 硬 cast——恶意/损坏响应
  /// （如 `identity` 为字符串、`key_base64` 为整数）会抛 **TypeError**，
  /// 绕过 `isTransientClaimFailure` 的前缀识别，以非契约异常炸进发送路径。
  ///
  /// 此处把结构校验收口到唯一入口：字段缺失/类型混淆一律抛带
  /// `olm claim_key: invalid payload` 前缀的 Exception（与既有失败前缀
  /// 体系一致，重投/降级语义不变）。密码学校验（签名/TOFU/base64 密钥
  /// 解码）不在本层，仍由 `OlmSessionService` 负责。
  ///
  /// 供 fuzz harness（`parser_fuzz_harness_test.dart`）作确定性 oracle。
  @visibleForTesting
  static Map<String, dynamic> parseClaimPayload(dynamic payload) {
    Never reject(String why) =>
        throw Exception('olm claim_key: invalid payload: $why');

    if (payload is! Map) {
      reject('顶层不是 map（${payload.runtimeType}）');
    }
    // reject 返回 Never：上面分支不可达，此处 payload 已提升为 Map。
    final map = payload;

    final identity = map['identity'];
    if (identity is! Map) {
      reject('identity 不是 map（${identity.runtimeType}）');
    }
    final identityMap = _asStringKeyMap(identity, 'identity', reject);

    // X3DH 消费方（_establishOutboundSession）逐字段硬 cast，
    // 这里必须先证明每个 cast 目标类型成立。
    for (final key in const ['type', 'key_id', 'key_base64']) {
      final v = map[key];
      if (v is! String || v.isEmpty) {
        reject('字段 "$key" 须为非空 String（${v.runtimeType}）');
      }
    }
    for (final key in const ['ed25519_key', 'curve25519_key', 'signature']) {
      final v = identityMap[key];
      if (v is! String || v.isEmpty) {
        reject('identity."$key" 须为非空 String（${v.runtimeType}）');
      }
    }

    return {..._asStringKeyMap(map, '顶层', reject), 'identity': identityMap};
  }

  /// C17b 复审 gap：get_identity 响应严格解析（fail-closed），与
  /// [parseClaimPayload] 同模式。
  ///
  /// 消费方（`OlmSessionService._lookupPeerIdentity`）在 Ed25519 验签后对
  /// `curve25519_key` 做 `as String` 硬 cast——响应字段类型混淆（如整数）
  /// 会以 TypeError 泄漏。此处先证明结构成立：顶层 map、全 String key、
  /// 四个契约字段（后端 `olm_identity_repo:find_identity` 的 SELECT 列）
  /// 均为非空 String。违规一律抛 `olm get_identity: invalid payload` 前缀
  /// Exception。签名/base64 密码学校验仍在 `OlmSessionService` 层。
  ///
  /// 供 fuzz harness（`parser_fuzz_harness_test.dart`）作确定性 oracle。
  @visibleForTesting
  static Map<String, dynamic> parseIdentityPayload(dynamic payload) {
    Never reject(String why) =>
        throw Exception('olm get_identity: invalid payload: $why');

    if (payload is! Map) {
      reject('顶层不是 map（${payload.runtimeType}）');
    }
    final map = _asStringKeyMap(payload, '顶层', reject);

    for (final key in const [
      'device_id',
      'ed25519_key',
      'curve25519_key',
      'signature',
    ]) {
      final v = map[key];
      if (v is! String || v.isEmpty) {
        reject('字段 "$key" 须为非空 String（${v.runtimeType}）');
      }
    }
    return map;
  }

  /// `POST /api/v1/e2ee/trust/record` — 上报一条信任决策事件（ADR 16）。
  ///
  /// [body] 为 [buildTrustRecordRequest] 的 13 字段产物。成功返回 true；
  /// 服务端拒绝（签名/新鲜度/状态机/版本单调）返回 false。
  Future<bool> recordTrust(Map<String, dynamic> body) async {
    final IMBoyHttpResponse resp = await post(API.e2eeTrustRecord, data: body);
    return resp.ok;
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
