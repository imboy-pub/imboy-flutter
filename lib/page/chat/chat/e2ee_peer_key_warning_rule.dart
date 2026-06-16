/// TOFU 对端密钥变更告警判定（纯函数，无 Flutter 依赖，可纯单测）。
///
/// 收到 S2C `e2ee_device_key_changed`（封装为 E2EEPeerKeyChangedEvent）时，
/// 仅当满足以下全部条件才在当前聊天页提示"对方安全码已变更"：
/// - 当前是 **C2C 单聊**（群聊 peerId 为群 id，与用户 uid 天然不匹配，且群成员
///   密钥变更不宜逐条打扰）；
/// - 事件 uid 非空；
/// - 事件 uid == 当前会话对端 uid。
library;

/// 返回是否应向用户提示对端安全码已变更。
bool shouldWarnPeerKeyChanged({
  required bool isGroupChat,
  required String eventUid,
  required String currentPeerId,
}) {
  if (isGroupChat) return false;
  if (eventUid.isEmpty) return false;
  return eventUid == currentPeerId;
}
