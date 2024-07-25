import 'package:get/get.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';

class GroupMemberModel {
  int? id; // 自增长ID 服务端
  String groupId; // 群组ID
  String userId; // 群组成员用户ID
  String nickname; // 群组成员用户信息
  String avatar; // 群组成员用户信息
  String sign; // 群组成员用户信息a
  String account; // 群组成员用户信息
  String inviteCode; // 入群邀请码
  String alias; // 群内别名
  String description; // 群内描述
  int role; // 角色: 1 成员  2 嘉宾  3  管理员 4 群主
  int isJoin; // 是否加入的群： 1 是 0 否 （0 是群创建者或者拥有者; 1 是 成员 嘉宾 管理员等）
  // 进群方式 :  invite_[uid]_[nickname] <a>leeyi</a>邀请进群  scan_qr_code 扫描二维码加入 face2face_join 面对面建群
  String joinMode; // 进群方式
  int status;
  int updatedAt;
  int createdAt;

  // 计算量
  RxBool selected = false.obs;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.account,
    this.inviteCode = '',
    required this.alias,
    this.description = '',
    this.role = 1,
    this.isJoin = 1,
    this.joinMode = '',
    this.status = 1, // '状态: -1 删除  0 禁用  1 启用
    this.updatedAt = 0,
    required this.createdAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    // iPrint("GroupMemberModel.fromJson ${json.toString()}");
    return GroupMemberModel(
      id: json[GroupMemberRepo.id] ?? 0,
      groupId: json[GroupMemberRepo.groupId],
      userId: json[GroupMemberRepo.userId],
      nickname: "${json[GroupMemberRepo.nickname]}",
      avatar: json[GroupMemberRepo.avatar],
      sign: "${json[GroupMemberRepo.sign] ?? ''}",
      account: json[GroupMemberRepo.account].toString(),
      inviteCode: json[GroupMemberRepo.inviteCode],
      alias: "${json[GroupMemberRepo.alias]}",
      description: "${json[GroupMemberRepo.description]}",
      role: json[GroupMemberRepo.role],
      isJoin: json[GroupMemberRepo.isJoin],
      joinMode: json[GroupMemberRepo.joinMode] ?? '',
      status: json[GroupMemberRepo.status] ?? 1,
      updatedAt: json[GroupMemberRepo.updatedAt] ?? 0,
      createdAt: json[GroupMemberRepo.createdAt],
    );
  }

  Map<String, dynamic> toJson() => {
        GroupMemberRepo.id: id,
        GroupMemberRepo.groupId: groupId,
        GroupMemberRepo.userId: userId,
        GroupMemberRepo.inviteCode: inviteCode,
        GroupMemberRepo.alias: alias,
        GroupMemberRepo.description: description,
        GroupMemberRepo.role: role,
        GroupMemberRepo.isJoin: isJoin,
        GroupMemberRepo.joinMode: joinMode,
        GroupMemberRepo.status: status,
        GroupMemberRepo.updatedAt: updatedAt,
        GroupMemberRepo.createdAt: createdAt,
      };
}
