// 群公告管理权限纯函数（slice-F3-perm）。
//
// T2.5：判定委托领域层 `GroupRole.canAnnounce`（权威权限矩阵）：
// admin(3) / owner(4) / vice_owner(5) 可发布、删除群公告。
// 仍 re-export group_role_rules 的 isGroupAdmin / isGroupOwner 供调用侧复用。

import 'package:imboy/modules/group_collab/domain/value/group_role.dart';

export 'package:imboy/page/group/group_role_rules.dart'
    show isGroupAdmin, isGroupOwner;

/// 返回 [true] 表示该角色可以发布 / 删除群公告。
///
/// 委托 [GroupRole.canAnnounce]（管理员级）；未知 / 非法 code 安全默认 false。
bool canManageAnnouncement(int role) => GroupRole(role).canAnnounce;
