/// OlmProtocol —— Olm 套件的 [E2eeSessionProtocol] 实现（ADR 02 §2.1 / B.1）。
///
/// 薄适配器：委托已验证的 [OlmSessionService] 单例（vodozemac X3DH + Double
/// Ratchet、pickle 持久化、per-peer 锁），不重写密码学核心。职责仅：
/// - 把 ADR 02 抽象接口参数（recipients / context / metadata）翻译成
///   OlmSessionService 的 (peerUid, peerDeviceId, messageType) 参数；
/// - 组装 / 解析写入消息顶层 `e2ee` 字段的 metadata（含双写 + peer 视角）。
///
/// **peer 视角关键约定**：Olm 会话按 `(peerUid, peerDeviceId)` 索引。接收方 B
/// 解密时的 peer 是发送方 A。故 [encrypt] 写入的 metadata `peer_uid` /
/// `peer_device_id` 必须是**发送方自身身份**（`_selfUid` + 全局 `deviceId`），
/// 这样 B 读 metadata 得到的 peer 恰是 A。
library;

import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/olm_session_service.dart';

class OlmProtocol implements E2eeSessionProtocol {
  OlmProtocol();

  /// 发送方自身 uid（initialize 注入）。写入 metadata 供接收方定位 peer。
  String? _selfUid;

  @override
  ProtocolSuite get suite => ProtocolSuite.olm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {
    _selfUid = userId;
    // 幂等：OlmSessionService 内部按 pickle 是否存在决定是否重建身份。
    await OlmSessionService.to.publishIdentityAndPrekeys();
  }

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    // Olm 是 per-device 会话：一次 encrypt 恰好一个对端设备。
    // 多设备 fan-out 由上层（CapabilityNegotiator + 循环调用）驱动，ADR 04 §5。
    if (recipients.length != 1) {
      throw ArgumentError(
        'OlmProtocol.encrypt requires exactly one recipient device '
        '(per-device session); got ${recipients.length}',
      );
    }
    final peerUid = context.peerUid;
    if (peerUid == null || peerUid.isEmpty) {
      throw ArgumentError('OlmProtocol.encrypt needs context.peerUid');
    }
    final selfUid = _selfUid;
    if (selfUid == null || selfUid.isEmpty) {
      throw StateError('OlmProtocol not initialized (missing self uid)');
    }

    final res = await OlmSessionService.to.encryptC2CMessage(
      peerUid: peerUid,
      peerDeviceId: recipients.first.deviceId,
      plaintext: plaintext,
    );

    return E2eeCiphertext(res.ciphertext, {
      // v2 三元组（fromMetadata 优先读，路由回 OlmProtocol）
      'protocol': suite.protocol,
      'version': suite.version,
      // v1 双写：旧客户端按 'OLM.V1' 比对（ADR 02 §7.2，用 legacyWire 而非 wire）
      'e2ee_suite': suite.legacyWire,
      // peer 视角：填发送方自身身份，接收方据此定位「对端=发送方」
      'peer_uid': selfUid,
      'peer_device_id': deviceId,
      'message_type': res.messageType,
      'session_id': res.sessionId,
    });
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    final peerUid = metadata['peer_uid']?.toString() ?? '';
    final peerDeviceId = metadata['peer_device_id']?.toString() ?? '';
    if (peerUid.isEmpty || peerDeviceId.isEmpty) {
      throw const E2eeDecryptException('no_device_key');
    }
    final messageType =
        int.tryParse(metadata['message_type']?.toString() ?? '1') ?? 1;
    // S2.3c: 透传 message_id 供 CryptoStore dedupe
    final messageId = metadata['message_id']?.toString();
    try {
      return await OlmSessionService.to.decryptC2CMessage(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        messageType: messageType,
        ciphertext: ciphertext,
        messageId: (messageId != null && messageId.isNotEmpty)
            ? messageId
            : null,
      );
    } on E2eeDecryptException {
      rethrow;
    } on DuplicateMessageException {
      rethrow; // S2.3: 重复投递信号，调用方静默跳过
    } catch (_) {
      throw const E2eeDecryptException('decrypt_error');
    }
  }

  @override
  Future<void> clearAll() => OlmSessionService.to.clearAll();
}
