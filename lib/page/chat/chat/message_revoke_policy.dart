/// 单聊/群聊消息撤回时间窗策略（S1）
///
/// 纯函数层：判断给定消息是否仍在撤回窗口内，便于 UI 层和
/// [MessageActionHandler.revokeMessage] 入口在发起网络请求前短路，
/// 提前给出用户反馈，避免点击超期消息后等待一轮网络才看到失败。
///
/// 默认窗口 120 秒（2 分钟），与后端常规限制对齐。调用方如需按
/// remote config 动态调整可覆写 [windowMs]。
library;

/// 默认撤回窗口（毫秒）。
const int kDefaultRevokeWindowMs = 2 * 60 * 1000;

/// 是否允许撤回给定消息。
///
/// 约定：
/// - `windowMs <= 0`：永远不允许撤回（安全阀）
/// - `createdAtMs <= 0`：数据损坏，永远不允许撤回（防御性）
/// - `createdAtMs > nowMs`（时钟漂移，消息"来自未来"）：允许撤回
///   — 通常意味着消息刚发出，设备与服务器时钟有小偏差
/// - `createdAtMs <= nowMs <= createdAtMs + windowMs`：允许（边界包含，
///   UX 倾向宽松；边界失败的撤回请求体验很差）
/// - 其他：不允许
bool canRevokeMessage({
  required int createdAtMs,
  required int nowMs,
  int windowMs = kDefaultRevokeWindowMs,
}) {
  if (windowMs <= 0) return false;
  if (createdAtMs <= 0) return false;
  // 时钟漂移：消息比本机时钟还新，视为刚发送，允许撤回。
  if (createdAtMs > nowMs) return true;
  return nowMs - createdAtMs <= windowMs;
}
