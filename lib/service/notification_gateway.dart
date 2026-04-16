/// 通知网关 — 纯函数决策模块。
///
/// 职责：根据会话/消息上下文判断是否应发出系统通知。
/// 网关**不**携带通知内容（title/body），内容由调用侧根据消息补充。
///
/// 优先级（从高到低）：
///   1. isFromSelf = true → Suppressed('from_self')
///   2. isUserInChat = true → Suppressed('in_chat')
///   3. msgId 在 recentlyNotifiedMsgIds 中 → Suppressed('duplicate')
///   4. isMuted > 0 && !isMentioned → Suppressed('muted')
///   5. 其余（含 isMuted>0 + isMentioned=true 的 @ 穿透） → Allow
library;

// ─────────────────────────────────────────────────────────────────────────── //
// Sealed decision types
// ─────────────────────────────────────────────────────────────────────────── //

sealed class NotifyDecision {
  const NotifyDecision();
}

/// 允许发出系统通知。
///
/// 调用侧负责根据消息内容补充 title 和 body。
final class NotifyAllow extends NotifyDecision {
  const NotifyAllow();
}

/// 抑制系统通知。
final class NotifySuppressed extends NotifyDecision {
  const NotifySuppressed(this.reason);

  /// 抑制原因：'from_self' | 'in_chat' | 'duplicate' | 'muted'
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────── //
// Pure decision function
// ─────────────────────────────────────────────────────────────────────────── //

/// 评估是否应对该消息发出系统通知。
///
/// 参数：
/// - [msgId]：消息 ID，空字符串时跳过 duplicate 检查。
/// - [isFromSelf]：消息是否由当前用户自己发送。
/// - [isUserInChat]：用户当前是否正在查看该会话。
/// - [isMuted]：会话静音截止时间戳（ms）；> 0 表示静音中。
/// - [isMentioned]：消息中是否 @ 了当前用户（穿透免打扰）。
/// - [recentlyNotifiedMsgIds]：最近已触发过通知的 msgId 集合，用于去重。
NotifyDecision evaluateNotification({
  required String msgId,
  required bool isFromSelf,
  required bool isUserInChat,
  required int isMuted,
  required bool isMentioned,
  required Set<String> recentlyNotifiedMsgIds,
}) {
  // 优先级 1：自己发的消息永不通知
  if (isFromSelf) return const NotifySuppressed('from_self');

  // 优先级 2：用户正在查看该会话，无需系统通知
  if (isUserInChat) return const NotifySuppressed('in_chat');

  // 优先级 3：重复通知去重
  if (msgId.isNotEmpty && recentlyNotifiedMsgIds.contains(msgId)) {
    return const NotifySuppressed('duplicate');
  }

  // 优先级 4：会话静音（@ 穿透：isMentioned=true 时允许通知）
  if (isMuted > 0 && !isMentioned) return const NotifySuppressed('muted');

  // 其余情况：允许通知
  return const NotifyAllow();
}
