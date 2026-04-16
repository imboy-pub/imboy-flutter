/// 引用消息发送方显示名解析 —— 纯函数（零外部依赖）
///
/// slice-C-4: `_sendQuoteMessage`（比较 `authorId == peerId`）与
/// `QuoteTipsWidget.title`（比较 `authorId == currentUid`）两处语义相同但枢轴不同，
/// 提取后注入 `currentUid` / `myNickname` / `peerTitle`，可独立单测钉死矩阵契约。
///
/// **契约：**
///   - `quoteAuthorId == currentUid` → [myNickname]
///   - 其他（含 null / 空串 / 陌生 uid）→ [peerTitle]
library;

/// 解析引用消息的发送方显示名。
///
/// - [quoteAuthorId]  被引用消息的 authorId（可能为 null，如旧格式消息）
/// - [currentUid]     当前登录用户 id（注入以避免 UserRepoLocal.to 单例）
/// - [myNickname]     当前用户的昵称（当引用消息为自己发送时展示）
/// - [peerTitle]      聊天对方的显示名（其他情况展示）
String resolveQuoteAuthorName({
  required String? quoteAuthorId,
  required String currentUid,
  required String myNickname,
  required String peerTitle,
}) =>
    quoteAuthorId == currentUid ? myNickname : peerTitle;
