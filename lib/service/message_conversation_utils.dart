import 'package:imboy/store/model/model_parse_utils.dart';

/// Resolve conversation peer ID for different message types.
///
/// For C2C, always returns the counterparty UID:
/// - incoming from other user: `from`
/// - self echo from current user: `to`
String resolveConversationPeerId({
  required String chatType,
  required Map<String, dynamic> data,
  required String currentUid,
}) {
  if (chatType == 'C2G') {
    return parseModelString(data['to']);
  }

  final from = parseModelString(data['from']);
  final to = parseModelString(data['to']);

  if (chatType == 'C2C') {
    if (from == currentUid && to.isNotEmpty) {
      return to;
    }
    if (from.isNotEmpty) {
      return from;
    }
    return to;
  }

  if (from.isNotEmpty) {
    return from;
  }
  return to;
}

/// Compute unread increment for one received message.
///
/// Unread increases only when:
/// - message is not sent by current user
/// - user is not currently inside the target conversation
int computeConversationUnreadIncrement({
  required bool isFromCurrentUser,
  required bool isUserInChat,
}) {
  return (!isFromCurrentUser && !isUserInChat) ? 1 : 0;
}

/// C7-β：Extract the mention uid list from an incoming message payload.
///
/// Wire format (see chat_page._sendTextMessage):
///   payload['mentions'] = a list of uid strings; may include the sentinel
///                         'all' for @everyone.
/// Returns null when the payload is absent or has no mentions field.
List<String>? extractMentionIdsFromPayload(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final raw = payload['mentions'];
  if (raw is List) {
    return raw.map((e) => e.toString()).toList(growable: false);
  }
  return null;
}

/// C7-β：Compute the @-mention unread increment for one received message.
///
/// Mirrors [computeConversationUnreadIncrement]: a message that does NOT
/// bump the regular unread (self-sent, or user already in chat) must also
/// NOT bump mention_unread. Otherwise, the delta is 1 when the payload
/// mentions the current user either explicitly (by uid) or via the group
/// "all" sentinel; 0 otherwise.
///
/// Empty [currentUid] is treated defensively: no match, even if the
/// incoming [mentionIds] happens to contain an empty string.
int computeMentionUnreadIncrement({
  required bool isFromCurrentUser,
  required bool isUserInChat,
  required List<String>? mentionIds,
  required String currentUid,
}) {
  if (isFromCurrentUser || isUserInChat) return 0;
  if (mentionIds == null || mentionIds.isEmpty) return 0;
  if (mentionIds.contains('all')) return 1;
  if (currentUid.isEmpty) return 0;
  if (mentionIds.contains(currentUid)) return 1;
  return 0;
}

/// C7-α-2: Whether to suppress the local notification pop-up for a given
/// conversation, based on its persisted DND flag ([ConversationModel.isMuted]).
///
/// Convention:
///   - 0       → notify (default)
///   - any > 0 → suppress (user enabled DND)
///   - negative (corrupted/legacy data) → notify (defensive)
///
/// Unread counts and mention_unread are NOT affected; only the
/// user-visible notification pop-up is suppressed.
///
/// ## slice-8 (C6 接线) — `@` 穿透
///
/// [isMentioned] 可选参数（默认 false，保持向后兼容）。
/// 当用户被定向 `@`（含 `@所有人`）时，DND 应被**穿透** → 正常通知。
/// 语义对齐微信 / TG / Slack 行业共识（原注释引用的
/// `shouldNotifyGroupMessage`（slice-5）从未实现，见 [isGroupDndActive]）。
///
/// 判定顺序：
///   1. `isMentioned == true` → 不抑制（穿透）
///   2. `isMuted > 0` → 抑制
///   3. 否则 → 不抑制
bool shouldSuppressNotification({
  required int isMuted,
  bool isMentioned = false,
}) {
  if (isMentioned) return false;
  return isMuted > 0;
}

/// Q09/G1（AC22 免打扰）：C2G 群会话的 DND 判定源合并（纯函数）。
///
/// ## 断点背景（2026-10-07 Q09 调查）
///
/// 群免打扰在此前存在**两套未打通的存储**：
///   - `conversation.is_muted` 列（C7-α-1）：通知管线（本文件
///     [shouldSuppressNotification] 在 `message.dart` 的接线）与会话列表
///     免打扰角标读这里；C2C 单聊设置页（chat_setting_page）写这里；
///   - KV `group_notice_disabled:<gid>`（slice-6，`group_notice_config.dart`）：
///     群详情页开关**只写这里**。
///
/// 结果：用户在群详情页开启免打扰后，管线读到的 `isMuted` 恒为 0，
/// **通知照常弹出**（DND 失效）——这就是 App 侧 DND 未接线的断点。
///
/// ## 接线语义
///
/// 任一源命中即抑制（OR 合并）：
///   - [isMutedColumn]：`conversation.is_muted` 列（主源，C2C/C2G 共用）；
///   - [kvNoticeDisabled]：KV 开关值（群详情页真源）。
///
/// KV 参与合并还覆盖两个「列缺失」场景：
///   1. slice-6 存量记录（只写过 KV，列从未同步）；
///   2. 「先设免打扰、会话行后建」——群会话行由首条消息 upsert 创建，
///      新行 `isMuted` 默认 0。
///
/// 注意：本函数只回答「DND 是否命中」；`@` 穿透仍由
/// [shouldSuppressNotification] 统一裁决（命中 DND 但被 @ 时不抑制）。
bool isGroupDndActive({
  required int isMutedColumn,
  required bool kvNoticeDisabled,
}) {
  return isMutedColumn > 0 || kvNoticeDisabled;
}
