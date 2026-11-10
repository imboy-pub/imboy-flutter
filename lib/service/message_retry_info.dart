part of 'message_retry.dart';

/// 消息重试信息类
/// Message retry information class.
class MessageRetryInfo {
  final String messageId;
  final String type;
  final int sessionGeneration;
  final String ownerUid;
  int retryCount;

  /// 上次重试的单调毫秒（AppClock 单调轴，R20-A；非墙钟时间戳，
  /// 测试 `-= interval` 模拟流逝仍有效）。持久化 deadline 请用
  /// `appClock.nowMs()`（epoch 合同）。
  int lastRetryTime;

  MessageRetryInfo({
    required this.messageId,
    required this.type,
    required this.retryCount,
    required this.lastRetryTime,
    int? sessionGeneration,
    String? ownerUid,
  }) : sessionGeneration =
           sessionGeneration ?? UserRepoLocal.to.sessionGeneration,
       ownerUid = ownerUid ?? UserRepoLocal.to.currentUid;
}

/// AC-06：重发路径的**降级密文**闸门（纯函数，与
/// `retry_plaintext_guard.dart` 的明文闸门互补）。
///
/// 明文闸门拦「该加密却是明文」；本闸门拦「加密必需策略下行带 e2ee 元数据、
/// 但套件不是该 scope 的固定 required 套件」——典型是策略升级前的存量
/// RSA legacy 密文行：发送侧已不再产生新 RSA 密文（decrypt-only，ADR 02
/// §5.2），重发路径若原样投递，等于让弱套件密文经重试通道继续出网，
/// 旁路发送侧的固定套件策略（C02 FixedSuitePolicy）。
///
/// fail-closed：元数据在但**无法判读套件**（protocol/e2ee_suite 均缺失）
/// 一律拦截——无法证明合规 = 不合规。
bool isDowngradedCipherRetryBlocked({
  required bool encryptionRequired,
  required String chatType,
  required Map<String, dynamic>? e2ee,
}) {
  if (!encryptionRequired) return false;
  if (e2ee == null || e2ee.isEmpty) return false; // 明文行由明文闸门处理

  // 与发送链同源的固定套件判定（C02）：c2c→olm / c2g→megolm。
  final required = FixedSuitePolicy.requiredSuiteFor(
    chatType.toUpperCase() == 'C2G' ? 'c2g' : 'c2c',
  );

  var protocol = e2ee['protocol']?.toString() ?? '';
  if (protocol.isEmpty &&
      (e2ee['e2ee_suite']?.toString() ?? '').isEmpty &&
      e2ee['meta_version'] == 3) {
    final verified = ProtectedFrameV3.verifyOuterEnvelope(e2ee);
    if (!verified.isValid) return true;
    protocol = verified.decodedHeader?['protocol']?.toString() ?? '';
  }
  if (protocol.isNotEmpty) {
    return protocol != required;
  }

  final suite = e2ee['e2ee_suite']?.toString() ?? '';
  if (suite.isEmpty) {
    // 有元数据但无任何套件标识：无法证明合规 → fail-closed。
    return true;
  }
  // legacy wire 形态：'OLM.V1' / 'MEGOLM.V1' / 'RSA-OAEP-256+AES-256-GCM'
  return suite.toLowerCase() != '$required.v1';
}
