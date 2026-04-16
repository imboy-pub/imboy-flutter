// 群公告管理权限纯函数（slice-F3-perm）。
//
// 语义委托给 group_role_rules.dart 的 isGroupAdmin：
// admin(3) / owner(4) / vice_owner(5) 可发布、删除群公告。

import 'package:imboy/page/group/group_role_rules.dart';

export 'package:imboy/page/group/group_role_rules.dart'
    show isGroupAdmin, isGroupOwner;

/// 返回 [true] 表示该角色可以发布 / 删除群公告。
///
/// 等价于 [isGroupAdmin]，保留独立名称以提升调用侧可读性。
bool canManageAnnouncement(int role) => isGroupAdmin(role);
