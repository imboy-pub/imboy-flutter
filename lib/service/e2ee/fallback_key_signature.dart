/// E2EE-062：fallback prekey 的**签名载荷**。
///
/// 服务端 `olm_identity_logic:report_fallback_key/5` 要求 fallback key 由设备
/// **已注册的 ed25519 身份键**签名。威胁：E2EE-013 用 token 绑定设备所有权，
/// 但 token 在网络上传输、identity 私钥不会——持被盗 token 者可以给该设备上传
/// 自己控制的 fallback prekey，此后凡该设备 OTK 耗尽、对端回退 fallback 的会话
/// 用的都是攻击者的预密钥。
///
/// ⚠️ 本函数的输出必须与服务端 `fallback_canonical/4` **逐字节一致**。
/// 不一致的后果不是"少一层防护"，而是**验签必然失败 → 该设备发布不了 fallback
/// key → 每次 OTK 耗尽都变成 `no_prekey_available`**，是一次生产可用性事故。
/// 两侧各自钉死同一条 golden vector（见本目录测试与 imboy
/// `test/logic/e2ee_fallback_signature_tests.erl` 的 `canonical_golden_vector`）。
library;

/// `key=value\n`，ASCII 字典序，**末字段无尾随换行**。
/// 字段序 device_id < key_base64 < key_id < user_id 已是字典序。
///
/// 与 `trust_event_canonical.dart` 同一方案——项目不发明第三套编码。
String fallbackKeyCanonical({
  required String userId,
  required String deviceId,
  required String keyId,
  required String keyBase64,
}) {
  return 'device_id=$deviceId\n'
      'key_base64=$keyBase64\n'
      'key_id=$keyId\n'
      'user_id=$userId';
}
