/// 发送模式决策 —— 纯函数(零外部依赖)
///
/// slice-C-3a:从 `chat_page.dart:_handleSendPressed` 抽出决策内核,
/// 将 muted/防抖/编辑/quote 的多分支分派与 i18n toast / WebSocket IO 解耦。
///
/// 决策优先级(从高到低):
///   1. isMuted → [SendDenyMuted](压过所有其他分支)
///   2. 防抖窗口内(`now - lastSendTime < debounce`,严格小于) → [SendDenyDebounced]
///   3. editingMessageId 非空非空串 → [SendAsEdit]
///   4. hasQuoteMessage=true → [SendAsQuote]
///   5. 否则 → [SendAsNewText]
library;

sealed class SendDecision {
  const SendDecision();
}

/// 当前用户已被禁言,拒绝发送(调用方通常 toast + return false)。
final class SendDenyMuted extends SendDecision {
  const SendDenyMuted();
}

/// 距离上次发送不足 debounce 窗口,拒绝发送(调用方通常 log + return false)。
final class SendDenyDebounced extends SendDecision {
  const SendDenyDebounced();
}

/// 编辑已有消息,携带目标 messageId。
final class SendAsEdit extends SendDecision {
  const SendAsEdit(this.messageId);
  final String messageId;
}

/// 发送新文本消息(无 quote)。
final class SendAsNewText extends SendDecision {
  const SendAsNewText();
}

/// 发送 quote 引用消息。
final class SendAsQuote extends SendDecision {
  const SendAsQuote();
}

/// 决策纯函数。
///
/// - [isMuted] 当前会话是否被禁言
/// - [now] 当前时戳(注入以便 fake time)
/// - [lastSendTime] 上次成功发送的时戳(未发过传 `null`)
/// - [debounce] 防抖窗口
/// - [editingMessageId] 正在编辑的消息 id(无则 `null` 或空串)
/// - [hasQuoteMessage] 是否携带引用消息
SendDecision decideSendMode({
  required bool isMuted,
  required DateTime now,
  required DateTime? lastSendTime,
  required Duration debounce,
  required String? editingMessageId,
  required bool hasQuoteMessage,
}) {
  if (isMuted) {
    return const SendDenyMuted();
  }
  if (lastSendTime != null && now.difference(lastSendTime) < debounce) {
    return const SendDenyDebounced();
  }
  if (editingMessageId != null && editingMessageId.isNotEmpty) {
    return SendAsEdit(editingMessageId);
  }
  if (hasQuoteMessage) {
    return const SendAsQuote();
  }
  return const SendAsNewText();
}
