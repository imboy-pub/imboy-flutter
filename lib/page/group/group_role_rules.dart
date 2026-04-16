// 群角色权限纯函数（跨页面共用）。
//
// 角色值与后端 `imboy/src/logic/group_role.hrl` 保持一致：
//   1 = member, 2 = guest, 3 = admin, 4 = owner, 5 = vice_owner
//
// 使用显式白名单，防止未来未知角色被误放行。

/// 管理员角色白名单（admin / owner / vice_owner）。
const Set<int> _kAdminRoles = {3, 4, 5};

/// 是否具备群管理权限（admin / owner / vice_owner）。
///
/// 用于控制：移除成员、发布公告、禁言成员 等管理操作的入口可见性。
bool isGroupAdmin(int role) => _kAdminRoles.contains(role);

/// 是否是群主（role == 4）。
///
/// 用于区分"解散群"与"退出群"等仅群主可执行的操作。
bool isGroupOwner(int role) => role == 4;
