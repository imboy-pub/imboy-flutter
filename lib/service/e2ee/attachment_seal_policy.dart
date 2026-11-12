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

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';

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

  /// 多图（imageMulti）payload 里承载图片元素的键名。每个图片元素是
  /// `{uri, size, width, height, file_hash256, [descriptorPayloadKey]}`。
  static const String imagesPayloadKey = 'images';

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
  ///
  /// 多图消息的 descriptor 随 `images[i]` 嵌套携带（仍整体处于 PFv3 加密
  /// payload 内），同样绝不能明文出网——漏判嵌套钥匙与漏判顶层钥匙是
  /// 同级别的失效，故在本闸门内统一检测，不交给调用点各自判断。
  static bool carriesContentKey(Object? payload) {
    if (payload is! Map) return false;
    if (payload[descriptorPayloadKey] != null) return true;
    final images = payload[imagesPayloadKey];
    if (images is! List) return false;
    return images.any((e) => e is Map && e[descriptorPayloadKey] != null);
  }

  /// 出网/重发**终检**的 bundle 感知谓词（A4FIX 复审 F3）。
  ///
  /// 单条消息的 descriptor 在 payload 顶层或 images[i] 内（[carriesContentKey]
  /// 可见）；`chat_history_bundle` wrapper 的顶层是合同字段
  /// （bundle_version/title/entries），重封装产生的新 descriptor 嵌在
  /// entries[].payload 内——顶层检测对它**不可见**。封装判定发生在 compose
  /// 期（bundle_forward_dispatcher 闸），消息真正出网在 MessageRetry 派发
  /// 时；两者之间策略可能翻成明文，出网终检（chat_network_service 明文
  /// 分支）与重发守卫（message_retry）若只做顶层检测，带新密钥的 bundle
  /// 便可在该窗口内明文出网。漏判嵌套钥匙与漏判顶层钥匙是同级别的失效，
  /// 故出网/重试终检一律走本谓词：
  ///
  /// - msgType == [HistoryBundleContract.msgType]：递归扫描
  ///   entries[].payload（含 images[] 与假想的嵌套 bundle，防御纵深）；
  /// - msgType 缺失但 payload 自带 entries 结构的脏行：同样递归
  ///   （fail-closed，不赌行的 msgType 干净）；
  /// - 其余：与 [carriesContentKey] 同口径（单条 payload 顶层 + images[]）。
  ///
  /// 递归带 [maxDepth] 深度上限（默认 8）：超出即按「带钥匙」拦截
  /// （fail-closed），病态深嵌套 payload 不能把终检推成栈溢出（DoS 点）。
  static bool isSealedPayloadDeep(
    Object? payload, {
    String? msgType,
    int maxDepth = 8,
  }) {
    if (payload is! Map) return false;
    final bool isBundleType =
        msgType != null && msgType.trim() == HistoryBundleContract.msgType;
    final bool bundleShaped = payload['entries'] is List;
    if (!isBundleType && !bundleShaped) return carriesContentKey(payload);
    return _carriesContentKeyInEntries(payload, maxDepth: maxDepth);
  }

  static bool _carriesContentKeyInEntries(
    Object? node, {
    required int maxDepth,
  }) {
    if (node is! Map) return false;
    // wrapper 自身顶层兜底检测（合同上不会有，出现即 fail-closed）。
    if (carriesContentKey(node)) return true;
    if (maxDepth <= 0) {
      // 超出深度上限：递归无界时病态深嵌套 payload 可把扫描推成栈溢出
      // （DoS 点）。无法证明不带钥匙 → 按「带钥匙」处理，fail-closed。
      return true;
    }
    final entries = node['entries'];
    if (entries is! List) return false;
    for (final entry in entries) {
      if (entry is! Map) continue;
      if (_carriesContentKeyInEntries(
        entry['payload'],
        maxDepth: maxDepth - 1,
      )) {
        return true;
      }
    }
    return false;
  }

  /// E2EE-061 Slice 7：主体与缩略图**必须同生同灭**。
  ///
  /// 设计 §3.3：缩略图是独立对象，只封装本体而让缩略图明文 = **预览即泄漏**，
  /// 拿到缩略图就看得到画面内容，ATT-04 在缩略图上直接失败。
  /// 那种状态比两个都明文更坏——它看起来像"已加密"。
  ///
  /// 返回 false 时调用方应**两个都不封装**（退回今天已知的明文行为），
  /// 而不是让其中一个裸奔。
  static bool sealTogether(Object? main, Object? thumb) =>
      (main == null) == (thumb == null);

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
  }) => decide(
    payloadWillBeEncrypted: payloadWillBeEncrypted,
    messageId: messageId,
    conversationId: conversationId,
    senderUid: senderUid,
  ) is SealApproved;
}
