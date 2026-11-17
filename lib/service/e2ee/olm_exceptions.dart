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

/// AC-16：判定出站会话建立失败是否为**瞬态基础设施错误**。
///
/// fan-out 场景下，瞬态失败（网络/HTTP/超时——典型是离线设备 claim 不上
/// OTK）允许**该设备明确跳过 + 后续补投**，不阻塞其他设备；而安全/能力类
/// 错误必须 fail-closed 拒发整条：
/// - [OlmAuthenticationException]：密文/签名认证失败（疑似篡改或 MITM）；
/// - [IdentityChangedException]：TOFU 指纹失配（换钥或 MITM）；
/// - [OlmStateCommitException]：密码学状态无法持久化（PFS 不变量）。
///
/// 白名单方向刻意向「少跳过」倾斜：未知异常类型一律按**非瞬态**处理
/// （rethrow 拒发）——把可疑错误放行成「跳过」会打开静默丢投面。
/// 用 runtimeType 名字匹配以避免为分类函数引入 dio/socket 跨包 import。
bool isTransientSessionFailure(Object e) {
  if (e is OlmAuthenticationException ||
      e is IdentityChangedException ||
      e is OlmStateCommitException) {
    return false;
  }
  final name = e.runtimeType.toString();
  final transientTypes = const {
    'DioException',
    'SocketException',
    'HttpException',
    'HandshakeException',
    'TimeoutException',
    'ClientException',
    'MissingPluginException',
  };
  if (transientTypes.contains(name)) return true;

  // OlmApi 网络层包装（`Exception('olm claim_key failed: <msg>')` /
  // `Exception('olm claim_key: invalid payload')`）。msg 的网络失败文案
  // 随 locale 变化（'网络错误'/'无网络'/…），故按**固定前缀**识别 claim
  // 层失败；明确的授权/设备拒绝不是网络故障，必须拒发整条。
  // 注：`Exception('...')` 字面量的 runtimeType 是私有实现类 `_Exception`。
  if (name == 'Exception' || name == '_Exception') {
    final msg = e.toString();
    if (msg.contains('device_not_registered') ||
        msg.contains('device_not_found') ||
        msg.contains('claim_not_authorized') ||
        msg.contains('device_revoked')) {
      return false;
    }
    return msg.contains('olm claim_key failed:') ||
        msg.contains('olm claim_key: invalid payload');
  }
  return false;
}
