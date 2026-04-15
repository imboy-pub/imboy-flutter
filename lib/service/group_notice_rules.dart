/// 群消息免打扰的通知决策纯函数 —— slice-5 (C6) GREEN-19。
///
/// 本切片只锁死**决策内核**，不涉及持久化。持久化（`group_notice_disabled`
/// 字段 / StorageService key）由后续子切片引入。
///
/// ## 契约（优先级从高到低）
///
///   1. `fromSelf == true` → `false`
///      自己发的消息不提醒自己。**优先级最高**，压过 @ 定向。
///   2. `noticeDisabled == true` 且 `isMentioned == false` → `false`
///      免打扰生效，屏蔽非定向消息。
///   3. `noticeDisabled == true` 且 `isMentioned == true` → `true`
///      **定向 @ 呼叫穿透免打扰**（对齐微信 / Telegram / Slack 行业共识）。
///   4. 其余 → `true`（正常通知）
///
/// ## 调用侧用法（伪代码）
///
/// ```dart
/// final shouldPush = shouldNotifyGroupMessage(
///   noticeDisabled: group.noticeDisabled,  // 来自用户本地配置
///   fromSelf: msg.fromId == currentUid,
///   isMentioned: msg.mentions?.contains(currentUid) ?? false,
/// );
/// if (shouldPush) NotificationService.show(msg);
/// ```
///
/// ## 为什么是纯函数
///
/// - 单元可测，零 Flutter / sqflite / 平台通道依赖
/// - 组合逻辑穷尽（真值表 2^3 = 8 组合全覆盖），避免散落 if 分支
/// - 调用方可在任意层（消息落库后、通知分派前、未读数计算时）复用
library;

/// 给定群消息上下文，判断是否应触发本地通知。
///
/// - [noticeDisabled] 用户是否为该群开启了消息免打扰
/// - [fromSelf] 消息发送者是否是当前登录用户
/// - [isMentioned] 当前用户是否在该消息的 @ 列表中（含 `@所有人`）
bool shouldNotifyGroupMessage({
  required bool noticeDisabled,
  required bool fromSelf,
  required bool isMentioned,
}) {
  if (fromSelf) return false;
  if (noticeDisabled && !isMentioned) return false;
  return true;
}
