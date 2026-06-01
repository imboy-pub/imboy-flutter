import 'package:imboy/modules/group_collab/domain/value/group_id.dart';
import 'package:imboy/modules/group_collab/domain/value/group_role.dart';

/// 群组充血实体 / Group rich entity（T2.4）。
///
/// 成员上限 / 角色 / 转让·解散不变量内聚于实体，语义对齐后端权威
/// `group_agg`（成员上限 500、解散终态、转让仅群主）与 `group_role.hrl`
/// 权限矩阵。聚合只权威 owner 身份与成员计数；细粒度成员角色由成员表
/// 提供（同后端 group_agg:role_of 的局限）。
///
/// 不可变：判定方法为纯查询，不修改状态。纯 Dart——禁止 import
/// flutter/* 与 repository/*。
class Group {
  const Group({
    required this.id,
    required this.ownerId,
    this.memberCount = 0,
    this.dissolved = false,
  });

  /// 从（可能脏的）持久化计数构造，负值规整为 0，守 memberCount>=0。
  factory Group.fromCounts({
    required GroupId id,
    required String ownerId,
    required int memberCount,
    bool dissolved = false,
  }) => Group(
    id: id,
    ownerId: ownerId,
    memberCount: memberCount > 0 ? memberCount : 0,
    dissolved: dissolved,
  );

  /// 成员数上限（对齐后端 group_agg ?MAX_MEMBERS）。
  static const int maxMembers = 500;

  final GroupId id;

  /// 群主 uid（TSID 字符串）。
  final String ownerId;

  /// 成员数，不变量 0 <= memberCount <= maxMembers。
  final int memberCount;

  /// 是否已解散（终态）。
  final bool dissolved;

  /// 是否满员。
  bool get isFull => memberCount >= maxMembers;

  /// 是否可新增成员（未解散且未满员）—— 镜像后端 add_member 不变量。
  bool get canAddMember => !dissolved && !isFull;

  /// 某 uid 在本群的角色：群主→owner VO，其余→member VO
  /// （对齐后端 group_agg:role_of；精确角色需成员表查询）。
  GroupRole roleOf(String uid) => uid == ownerId
      ? const GroupRole(GroupRole.owner)
      : const GroupRole(GroupRole.member);

  /// actor 是否可转让群主（未解散且 actor 为群主）—— 镜像 transfer_owner。
  bool canTransferBy(String actorUid) =>
      !dissolved && roleOf(actorUid).canTransfer;

  /// actor 是否可解散群（未解散且 actor 为群主）—— 镜像 dissolve。
  bool canDissolveBy(String actorUid) =>
      !dissolved && roleOf(actorUid).canDissolve;
}
