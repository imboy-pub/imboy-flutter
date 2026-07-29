/// E2EE-061 Slice 4 —— 「这次上传该不该加密」的唯一判定点（纯函数）
///
/// ## 为什么必须有这道闸门
///
/// `attachment_descriptor` 里带着 **content key**（能解开整个附件）。
/// 它只有随 PFv3 **加密 payload** 发送才是安全的。
///
/// 若在一个 payload 不加密的会话里封装了附件，descriptor 就会**以明文出网**——
/// 那比今天「附件明文、无密钥」**更糟**：既上传了密文（用户以为受保护），
/// 又把解密钥匙贴在旁边。
///
/// 因此判定必须 **fail-closed**：任何一项拿不准就**不封装**，
/// 退回今天已知的明文行为，而不是赌一把。
///
/// ⚠️ 本文件是该判定的**唯一**入口。新增上传路径请调用它，
/// 不要在调用点各写一份 `if`——E2EE-062 第七刀的教训：
/// 判定散落在多处时，新增的那处漏判不会有任何测试变红。
library;

/// 不封装的原因。用于日志与测试断言；**不进 UI**。
enum SealSkipReason {
  /// 会话的 payload 不会被加密——**绝不能**封装（content key 会明文出网）
  payloadNotEncrypted,

  /// 缺少构造绑定值所需的输入
  missingBinding,
}

/// 判定结果。
sealed class SealDecision {
  const SealDecision();
}

/// 应当封装。
final class SealApproved extends SealDecision {
  const SealApproved();
}

/// 不封装，附原因。
final class SealSkipped extends SealDecision {
  final SealSkipReason reason;
  const SealSkipped(this.reason);
}

class AttachmentSealPolicy {
  /// descriptor 在消息 payload / metadata 里的字段名。**单一真值源**：
  /// 发送侧写入、明文闸门检测、将来 Slice 6 的读取侧都用这一个常量。
  static const String descriptorPayloadKey = 'attachment_descriptor';

  /// 这份 payload 是否带着 **content key**（即含 descriptor）。
  ///
  /// ⚠️ 用途是**明文出网闸门**：只要带着它，就绝不能以未加密形式发出去。
  /// 封装判定发生在上传时（[decide]），而消息真正出网可能在几秒甚至几小时后
  /// （重发状态机）；两个时刻之间策略可能已经翻成明文。这个谓词让
  /// 出网侧能在最后一刻自己拦一次，而不是信任上传时的判定还成立。
  ///
  /// 入参刻意是 [Object]：库里读出的 payload 常是 `Map<dynamic, dynamic>`
  /// （JSON 解码产物），要求 `Map<String, dynamic>` 会让调用点各写一次强转，
  /// 而**强转失败时静默当成「不带钥匙」正是这道闸门最怕的失效方式**。
  static bool carriesContentKey(Object? payload) =>
      payload is Map && payload[descriptorPayloadKey] != null;

  /// [payloadWillBeEncrypted] 由调用方传入
  /// （聊天侧即 `E2EEService.shouldEncryptOutgoingPayload(chatType)`）。
  /// 刻意**不在本模块内**去查——保持纯函数、可直接验收，
  /// 且让「谁决定加密」这件事留在它本来的位置。
  ///
  /// 其余三项是绑定值（方案甲）的输入，任一为空都会让绑定值算不出来
  /// 或退化成全附件共用——同样 fail-closed。
  static SealDecision decide({
    required bool payloadWillBeEncrypted,
    required String messageId,
    required String conversationId,
    required String senderUid,
  }) {
    if (!payloadWillBeEncrypted) {
      return const SealSkipped(SealSkipReason.payloadNotEncrypted);
    }
    if (messageId.isEmpty || conversationId.isEmpty || senderUid.isEmpty) {
      return const SealSkipped(SealSkipReason.missingBinding);
    }
    return const SealApproved();
  }

  /// 便捷判定。
  static bool shouldSeal({
    required bool payloadWillBeEncrypted,
    required String messageId,
    required String conversationId,
    required String senderUid,
  }) =>
      decide(
            payloadWillBeEncrypted: payloadWillBeEncrypted,
            messageId: messageId,
            conversationId: conversationId,
            senderUid: senderUid,
          )
          is SealApproved;
}
