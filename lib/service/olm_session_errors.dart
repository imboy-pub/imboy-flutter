part of 'olm_session_service.dart';

/// Olm 密文认证失败（MAC 校验失败 / ciphertext 无效）。
///
/// 语义上区别于「会话不可用」（无 session / 身份查不到 / prekey 建会话失败）：
/// - 会话不可用 → 调用方可安全回退到其它包裹通道（如 room key 的 RSA `ek`）；
/// - **认证失败 → 调用方必须拒绝，禁止降级**——密文已到解密阶段却校验失败，
///   意味着被篡改或遭 downgrade 注入，降级会打开 downgrade attack surface（ADR 13 §4）。
class OlmAuthenticationException implements Exception {
  OlmAuthenticationException(this.message);
  final String message;
  @override
  String toString() => 'OlmAuthenticationException: $message';
}

/// E2EE-030: 密码学状态无法**原子持久化**（事务性 CryptoStore 不可用）。
///
/// ADR 14 §4.2 不变量 7：密码学状态更新要么与消息状态同时提交，要么全部回滚；
/// 不得出现「密文已发送但 ratchet 状态未持久化」的可重复密钥状态。因此
/// CryptoStore 不可用时必须 fail-closed 拒绝加/解密，**不得**退化成只写
/// FlutterSecureStorage——那样一次 DB 不可用窗口 + 进程重启就会让 ratchet
/// 回滚到旧状态并重用已消费的 message key（PFS 失效）。
class OlmStateCommitException implements Exception {
  OlmStateCommitException(this.message);
  final String message;
  @override
  String toString() => 'OlmStateCommitException: $message';
}

/// S2.3: 入站消息重复投递（dedupe 命中）。
///
/// 调用方应捕获此异常并静默跳过（消息已处理过），不视为错误。
class DuplicateMessageException implements Exception {
  DuplicateMessageException(this.messageId);
  final String messageId;
  @override
  String toString() => 'DuplicateMessageException: $messageId';
}

/// S3: 对端 identity key 发生变化（TOFU 比对失败）。
///
/// 可能原因：对端换机/重装、或 MITM 攻击。UI 层应提示用户确认。
class IdentityChangedException implements Exception {
  IdentityChangedException({
    required this.peerUid,
    required this.peerDeviceId,
    required this.oldFingerprint,
    required this.newFingerprint,
  });
  final String peerUid;
  final String peerDeviceId;
  final String oldFingerprint;
  final String newFingerprint;
  @override
  String toString() =>
      'IdentityChangedException: $peerUid:$peerDeviceId '
      'old=${oldFingerprint.substring(0, 8)}… new=${newFingerprint.substring(0, 8)}…';
}
