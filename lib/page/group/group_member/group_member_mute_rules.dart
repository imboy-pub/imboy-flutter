/// 群成员禁言 UI 的纯函数规则 —— slice-2（+ slice-2 补丁：role=5 副群主）。
///
/// 不依赖 Widget / Provider / Repo，便于在单元测试中穷尽分支。
///
/// 角色常量（与后端 `include/group_role.hrl` 对齐）：
///   - 1 = 普通成员 (ROLE_MEMBER)
///   - 2 = 嘉宾 (ROLE_GUEST)
///   - 3 = 管理员 (ROLE_ADMIN)
///   - 4 = 群主 (ROLE_OWNER)
///   - 5 = 副群主 (ROLE_VICE_OWNER)
///
/// **关键**：数值顺序 ≠ 权威顺序。
/// 权威排序：member(1) < guest(2) < admin(3) < vice_owner(5) < owner(4)
/// 通过 [_authorityRank] 显式归一化，避免用原始 role 做数值比较出错。
library;

import 'package:imboy/i18n/strings.g.dart';

const int _roleMember = 1;
const int _roleAdmin = 3;

/// 将原始 role 映射为严格单调的**权威等级**（越大权威越高）。
///
/// 未知/非法角色返回 0，配合上层校验等同于"拒绝"。
int _authorityRank(int role) {
  switch (role) {
    case 1: // member
      return 1;
    case 2: // guest
      return 2;
    case 3: // admin
      return 3;
    case 5: // vice_owner
      return 4;
    case 4: // owner
      return 5;
    default:
      return 0;
  }
}

/// 判断当前用户是否可对 `targetUser` 发起禁言操作。
///
/// 规则：
///   1. 当前用户权威必须 >= 管理员（rank >= 3）
///   2. 不可禁言自己
///   3. 仅当当前用户**权威严格高于**目标时允许（同级或更高都拒绝）
///   4. 任一非法参数（空 id / role < 1 / 未知 role）一律拒绝 —— 安全默认
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

  final currentRank = _authorityRank(currentRole);
  final targetRank = _authorityRank(targetRole);

  // 未知角色（rank=0）一律拒绝
  if (currentRank == 0 || targetRank == 0) return false;

  // 仅管理员及以上（admin / vice_owner / owner）可操作
  if (currentRank < _authorityRank(_roleAdmin)) return false;

  // 权威严格高于目标
  return currentRank > targetRank;
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
  if (seconds < 60) return t.muteUnitSeconds(count: seconds);

  final minutes = seconds ~/ 60;
  if (minutes < 60) return t.muteUnitMinutes(count: minutes);

  final hours = minutes ~/ 60;
  if (hours < 24) return t.muteUnitHours(count: hours);

  final days = hours ~/ 24;
  return t.muteUnitDays(count: days);
}
