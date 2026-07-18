/// MegolmProtocol —— Megolm 套件的 [E2eeSessionProtocol] 实现（ADR 02 / B.2）。
///
/// 薄适配器：委托已验证的 [GroupSessionService]（vodozemac GroupSession）。
/// 群聊（C2G，context.gid 非空）与「对端不支持 Olm 的单聊降级」（C2C，gid 空）
/// 均走 Megolm。room key 分发是 GroupSessionService 的独立机制
/// （buildRoomKeyPayload / handleRoomKeyMessage），本适配器只负责消息体加解密，
/// 故 [encrypt] 的 recipients 是「虚拟接收方」（群会话），不逐设备 fan-out。
library;

import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/group_session_service.dart';

class MegolmProtocol implements E2eeSessionProtocol {
  MegolmProtocol();

  @override
  ProtocolSuite get suite => ProtocolSuite.megolm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {
    // Megolm 无设备级初始化（按群/会话域懒创建），ADR 02 §2.1 no-op。
    await GroupSessionService.to.ensureInitialized();
  }

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    final gid = context.gid;
    if (gid != null && gid.isNotEmpty) {
      final res = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: plaintext,
      );
      return E2eeCiphertext(res.ciphertext, _meta(res.sessionId, gid: gid));
    }
    // C2C Megolm 降级路径（对端不支持 Olm）
    final peerUid = context.peerUid;
    if (peerUid == null || peerUid.isEmpty) {
      throw ArgumentError('MegolmProtocol c2c encrypt needs context.peerUid');
    }
    final res = await GroupSessionService.to.encryptC2CMessage(
      peerUid: peerUid,
      plaintext: plaintext,
    );
    return E2eeCiphertext(res.ciphertext, _meta(res.sessionId));
  }

  Map<String, dynamic> _meta(String sessionId, {String? gid}) {
    final m = <String, dynamic>{
      'protocol': suite.protocol,
      'version': suite.version,
      'e2ee_suite': suite.legacyWire, // 双写兼容旧客户端（'MEGOLM.V1'）
      'session_id': sessionId,
    };
    if (gid != null && gid.isNotEmpty) m['gid'] = gid;
    return m;
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    final gid = metadata['gid']?.toString() ?? '';
    final sessionId = metadata['session_id']?.toString() ?? '';
    try {
      if (gid.isNotEmpty) {
        return await GroupSessionService.to.decryptGroupMessage(
          gid: gid,
          sessionId: sessionId,
          ciphertext: ciphertext,
        );
      }
      return await GroupSessionService.to.decryptC2CMessage(
        sessionId: sessionId,
        ciphertext: ciphertext,
      );
    } on E2eeDecryptException {
      rethrow;
    } catch (_) {
      throw const E2eeDecryptException('decrypt_error');
    }
  }

  @override
  Future<void> clearAll() async {
    // GroupSessionService 无统一 clearAll 入口；会话状态随全量 storage wipe 兜底。
  }
}
