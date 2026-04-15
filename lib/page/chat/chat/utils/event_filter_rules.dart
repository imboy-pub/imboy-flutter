/// 聊天页事件过滤决策 —— 纯函数(零外部依赖)
///
/// slice-C-3b: 从 `chat_page.dart:_setupEventListeners` 抽出两个内联过滤判定,
/// 与 EventBus / Widget 生命周期完全解耦,以便单测钉死契约。
///
/// **isRelevantChatError** — AppErrorEvent 显示判定:
///   - errorType 为已知的聊天错误类型（优先级最高）
///   - 或 message 包含中文关键词（后端老版本无 errorType 时的 fallback）
///
/// **muteEventMatchesConversation** — 禁言/解禁事件会话作用域匹配:
///   - eventConversationId 为 null 或空串 → 广播型禁言（无作用域限制）
///   - eventConversationId 等于 currentConversationId → 精确匹配当前会话
///   - 其他 → 属于其他会话，忽略
library;

/// 判断 AppErrorEvent 是否应在当前聊天页显示 Toast。
///
/// - [errorType] 错误类型字符串（来自 AppErrorEvent.errorType）
/// - [message]   错误消息文本（来自 AppErrorEvent.message，用于 fallback 匹配）
bool isRelevantChatError({
  required String errorType,
  required String message,
}) {
  return errorType == 'not_a_friend' ||
      errorType == 'in_denylist' ||
      message.contains('非好友') ||
      message.contains('黑名单');
}

/// 判断 UserMutedEvent / UserUnmutedEvent 是否作用于当前会话。
///
/// 返回 `true` 时，调用方应继续处理（applyMuteState / clearMuteState）；
/// 返回 `false` 时，调用方应 `return`（该事件属于其他会话，忽略）。
///
/// - [eventConversationId]   事件携带的会话 id（可 null，表示广播型）
/// - [currentConversationId] 当前聊天页的会话 uk3 key
bool muteEventMatchesConversation({
  required String? eventConversationId,
  required String currentConversationId,
}) {
  return eventConversationId == null ||
      eventConversationId.isEmpty ||
      eventConversationId == currentConversationId;
}
