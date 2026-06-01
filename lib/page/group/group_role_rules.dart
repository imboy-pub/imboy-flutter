// 群角色权限纯函数（跨页面共用）。
//
// 角色值与后端 `imboy/src/logic/group_role.hrl` 保持一致：
//   1 = member, 2 = guest, 3 = admin, 4 = owner, 5 = vice_owner
//
// T2.5：判定委托领域层 `GroupRole` 值对象（权威权限矩阵），不再就地
// 硬编码白名单 / 角色码比较，消除散落判定漂移风险。函数签名保持不变，
// 6 处调用点（mention_model / group_detail / group_member 等）无需改动。

import 'package:imboy/modules/group_collab/domain/value/group_role.dart';

/// 是否具备群管理权限（admin / owner / vice_owner）。
///
/// 用于控制：移除成员、发布公告、禁言成员 等管理操作的入口可见性。
/// 委托 [GroupRole.isAdmin]（code∈[3,5]）；未知 / 非法 code 安全默认 false。
bool isGroupAdmin(int role) => GroupRole(role).isAdmin;

/// 是否是群主（role == 4）。
///
/// 用于区分"解散群"与"退出群"等仅群主可执行的操作。
/// 委托 [GroupRole.isOwner]。
bool isGroupOwner(int role) => GroupRole(role).isOwner;
