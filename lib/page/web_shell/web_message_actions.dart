/// Phase 2.1.b-5a — Web Shell 长按消息动作决策（纯函数）
///
/// 把"消息能否复制 / 复制什么"的决策从 widget 层（_WebChatPanel.onMessageLongPress
/// 内的 BottomSheet 渲染）剥离，便于单测覆盖各种 Message 子类型契约。
///
/// 设计约束：
/// - 零副作用（不调 Clipboard / showSnackBar / 路由）
/// - 仅 import flutter_chat_core，避免拉 sqflite/dio 等重链
/// - **保留原始空白**：trim 仅用于"是否为空"判断，复制内容透传给用户
///
/// 后续切片可扩展：
/// - resolveRecallable(message, currentUid) → bool（撤回权限）
/// - resolveForwardable(message) → ForwardPayload?（转发载荷）
/// - resolveCollectable(message) → CollectPayload?（收藏载荷）
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/page/chat/chat/message_revoke_policy.dart';

/// 决定消息能否被复制以及复制什么内容
///
/// 返回值：
/// - 非 null → UI 显示"复制"菜单项，点击调 Clipboard.setData(ClipboardData(text: 返回值))
/// - null → UI 不显示"复制"菜单项
///
/// 当前仅 [TextMessage] 支持复制；其他类型（图片 / 文件 / 自定义）暂不支持。
String? resolveCopyableText(Message message) {
  if (message is! TextMessage) return null;
  if (message.text.trim().isEmpty) return null;
  return message.text;
}

/// Phase 2.1.b-5c — 决定长按菜单是否显示"撤回"项
///
/// 复用项目既有 [canRevokeMessage] 时间窗策略 + 加 author 判断。
/// 撤回的实际网络请求由 [MessageActionHandler.revokeMessage] 处理（本函数不调用）。
///
/// 条件（与 mobile 保持一致）：
/// - `currentUserId` 非空且 == `message.authorId`（只能撤回自己的消息）
/// - 仍在撤回时间窗内（默认 2 分钟，可通过 [windowMs] 覆写）
bool canShowRecallAction({
  required Message message,
  required String currentUserId,
  required int nowMs,
  int windowMs = kDefaultRevokeWindowMs,
}) {
  if (currentUserId.isEmpty) return false;
  if (message.authorId != currentUserId) return false;
  return canRevokeMessage(
    createdAtMs: message.createdAt?.millisecondsSinceEpoch ?? 0,
    nowMs: nowMs,
    windowMs: windowMs,
  );
}
