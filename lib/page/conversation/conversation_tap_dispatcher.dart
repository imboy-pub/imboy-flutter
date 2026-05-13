/// Step 1 — 会话列表点击派发决策（Web vs Mobile）
///
/// 纯函数，零外部依赖：
/// - 不 import flutter / riverpod / go_router
/// - 调用方根据返回的 sealed action 执行实际副作用（switch dispatch）
///
/// 设计目标：
/// - **Web 端不离开 Web Shell**：派发 [WebSelectChat] → 调用方
///   `webShellProvider.notifier.selectItem(ChatSelection(...))`，右栏内嵌渲染
/// - **Mobile 端保持原行为**：派发 [MobilePushChat] 携带全 metadata，调用方
///   `context.push('/chat/${peerId}', extra: {...})`
/// - **type 兜底为 C2C**：与 `conversation_page.dart:365-367` 既有 `strEmpty` 兜底语义对齐
library;

/// 会话点击决策结果（穷尽两个变体）
sealed class ConversationTapAction {
  const ConversationTapAction();
}

/// Web 平台：派发到 Web Shell 内嵌右栏
final class WebSelectChat extends ConversationTapAction {
  /// 对端 ID（C2C uid 或 C2G groupId，TSID 字符串）
  final String peerId;

  /// 'C2C' / 'C2G'
  final String chatType;

  const WebSelectChat({required this.peerId, required this.chatType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSelectChat &&
          other.peerId == peerId &&
          other.chatType == chatType;

  @override
  int get hashCode => Object.hash(peerId, chatType);

  @override
  String toString() => 'WebSelectChat(peerId: $peerId, chatType: $chatType)';
}

/// Mobile 平台：跳转到独立 ChatPage，携带 metadata 减少首屏闪烁
final class MobilePushChat extends ConversationTapAction {
  /// 对端 ID
  final String peerId;

  /// 'C2C' / 'C2G'
  final String chatType;

  /// 对端昵称 / 群名（可选，路由 extra 透传供 ChatPage 首屏渲染用）
  final String? title;

  /// 头像 URL（可选）
  final String? avatar;

  /// 个性签名 / 群公告（可选）
  final String? sign;

  const MobilePushChat({
    required this.peerId,
    required this.chatType,
    this.title,
    this.avatar,
    this.sign,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobilePushChat &&
          other.peerId == peerId &&
          other.chatType == chatType &&
          other.title == title &&
          other.avatar == avatar &&
          other.sign == sign;

  @override
  int get hashCode => Object.hash(peerId, chatType, title, avatar, sign);

  @override
  String toString() =>
      'MobilePushChat(peerId: $peerId, chatType: $chatType, title: $title)';
}

/// 决策函数：根据平台类型和屏幕宽度派发不同 action
///
/// [type] 为 null 或空字符串时默认 'C2C'（与 `conversation_page.dart:365-367` 既有
/// `strEmpty(model.type) ? 'C2C' : model.type` 兜底语义对齐）。
ConversationTapAction resolveConversationTap({
  required bool useSplitView,
  required String peerId,
  required String? type,
  String? title,
  String? avatar,
  String? sign,
}) {
  final chatType = (type == null || type.isEmpty) ? 'C2C' : type;

  if (useSplitView) {
    return WebSelectChat(peerId: peerId, chatType: chatType);
  }
  return MobilePushChat(
    peerId: peerId,
    chatType: chatType,
    title: title,
    avatar: avatar,
    sign: sign,
  );
}
