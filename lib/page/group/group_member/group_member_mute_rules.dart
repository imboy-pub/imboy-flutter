/// 群成员禁言 UI 的纯函数规则 —— slice-2。
///
/// 不依赖 Widget / Provider / Repo，便于在单元测试中穷尽分支。
///
/// 角色常量（与 `GroupMemberRepo` 一致）：
///   - 1 = 普通成员
///   - 2 = 嘉宾
///   - 3 = 管理员
///   - 4 = 群主
library;

const int _roleMember = 1;
// const int _roleGuest = 2;
const int _roleAdmin = 3;
const int _roleOwner = 4;

/// 判断当前用户是否可对 `targetUser` 发起禁言操作。
///
/// 规则：
///   1. 当前用户必须是管理员（3）或群主（4）
///   2. 不可禁言自己
///   3. 管理员只能禁言**严格低于自己**的角色（普通成员 / 嘉宾）
///   4. 群主可禁言任何**非自身**角色
///   5. 任一非法参数（空 id / role < 1）一律拒绝 —— 安全默认
bool canMuteGroupMember({
  required String currentUserId,
  required int currentRole,
  required String targetUserId,
  required int targetRole,
}) {
  // 安全默认：任一参数非法即拒绝
  if (currentUserId.isEmpty || targetUserId.isEmpty) return false;
  if (currentRole < _roleMember || targetRole < _roleMember) return false;

  // 不能禁言自己
  if (currentUserId == targetUserId) return false;

  // 仅管理员或群主可操作
  if (currentRole < _roleAdmin) return false;

  // 群主无限制（除自身，已在上面拦截）
  if (currentRole == _roleOwner) return true;

  // 管理员仅能禁言**严格低于自己**的角色
  return targetRole < currentRole;
}

/// 将禁言剩余时间格式化为人类可读的短标签。
///
/// 返回值：
///   - `muteUntilMs == null` 或 `muteUntilMs <= nowMs` → `''`（表示「未禁言」）
///   - 剩余 < 60s → `'X 秒'`
///   - 剩余 < 60min → `'X 分钟'`
///   - 剩余 < 24h → `'X 小时'`
///   - 剩余 ≥ 24h → `'X 天'`
///
/// 与后端 `format_duration/1`（`group_member_logic.erl:275-287`）保持相似
/// 的向下截断策略：用整数除法取最大单位的整数部分。
String muteRemainingLabel({
  required int? muteUntilMs,
  required int nowMs,
}) {
  if (muteUntilMs == null) return '';
  final remainingMs = muteUntilMs - nowMs;
  if (remainingMs <= 0) return '';

  final seconds = remainingMs ~/ 1000;
  if (seconds < 60) return '$seconds 秒';

  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes 分钟';

  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours 小时';

  final days = hours ~/ 24;
  return '$days 天';
}
