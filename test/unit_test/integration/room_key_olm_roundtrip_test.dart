import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// ADR 13 T-13-04：room-key-over-Olm 真 vodozemac 密码学 round-trip。
///
/// 用裸 vodozemac（不经 OlmSessionService，避免 claim OTK 的网络依赖），验证
/// 「Megolm 导出 room key → Olm 包裹 → Olm 解包 → InboundGroupSession.import」
/// 全链路 sessionId 一致、可解群消息。
///
/// 依赖 spike 构建的 vodozemac 宿主动态库；缺失自动 skip，**不作为普通 unit
/// test 依赖**（普通 wiring 测试见 test/service/group_session_service_test.dart）。
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T-13-04 room key over Olm 真 round-trip（缺 spike 库自动 skip）', () async {
    if (!Directory(_spikeLibDir).existsSync()) {
      markTestSkipped('spike 动态库缺失：$_spikeLibDir（cargo build --release 后可跑）');
      return;
    }
    await vod.init(libraryPath: _spikeLibDir);

    // 1. 发送端建 Megolm 群会话，encrypt 前导出 room key（棘轮起点 exportAt(0)）
    final group = vod.GroupSession();
    final sessionId = group.sessionId;
    final exported = group.toInbound().exportAt(0);
    expect(exported, isNotNull);

    // 2. 双方各持 Olm Account；接收端生成 OTK 供 X3DH
    final sender = vod.Account();
    final receiver = vod.Account();
    receiver.generateOneTimeKeys(1);
    final receiverOtk = receiver.oneTimeKeys.values.first;
    final receiverIdentity = receiver.identityKeys.curve25519;
    final senderIdentity = sender.identityKeys.curve25519;

    // 3. 发送端用 Olm 出站会话包裹 room key（→ 双包线格式 olm.type/olm.body）
    final outbound = sender.createOutboundSession(
      identityKey: receiverIdentity,
      oneTimeKey: receiverOtk,
      config: legacyOlmSessionConfig(),
    );
    final wrapped = outbound.encrypt(exported!);
    expect(wrapped.messageType, 0, reason: '首条应为 prekey message（type=0）');

    // 4. 接收端用 Olm 入站会话解包，得到与原 exportedKey 逐字节一致的明文
    final inboundResult = receiver.createInboundSession(
      theirIdentityKey: senderIdentity,
      preKeyMessageBase64: wrapped.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    expect(inboundResult.plaintext, exported, reason: 'Olm 解包必须逐字节还原 room key');

    // 5. 还原的 room key import 为 Megolm inbound，sessionId 一致 → 可解群消息
    final inboundGroup = vod.InboundGroupSession.import(
      inboundResult.plaintext,
    );
    expect(inboundGroup.sessionId, sessionId);
    final ct = group.encrypt('room-key-over-olm 群消息');
    expect(inboundGroup.decrypt(ct).plaintext, 'room-key-over-olm 群消息');
  });
}
