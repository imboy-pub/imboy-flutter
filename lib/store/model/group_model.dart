import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

class GroupModel {
  final String groupId; //
  final int type; // 类型: 1 公开群组  2 私有群组
  int joinLimit; //  加入限制: 1 不需审核  2 需要审核  3 只允许邀请加入
  int contentLimit; // 内部发布限制: 1 圈内不需审核  2 圈内需要审核  3 圈外需要审核
  int userIdSum; // 主要用于添加群聊的时候排重；还可以用于校验客户端memberCount是否应该增加
  String ownerUid; //  群组拥有者ID
  String creatorUid; //群组创建者ID
  int memberMax; // 允许最大成员数量
  int memberCount; // 成员数量
  String introduction; // 简介
  String avatar;
  String title;
  int status;
  int updatedAt;
  int createdAt;

  // 如果 title 为空，零时计算title
  String computeTitle = '';

  // 如果 avatar 为空，零时计算avatar
  List<String> computeAvatar = [];

  GroupModel({
    required this.groupId,
    required this.type,
    required this.joinLimit,
    required this.contentLimit,
    required this.userIdSum,
    required this.ownerUid,
    required this.creatorUid,
    required this.memberMax,
    required this.memberCount,
    this.introduction = '',
    this.avatar = '',
    this.title = '',
    this.status = 1, // '状态: -1 删除  0 禁用  1 启用
    this.updatedAt = 0,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    iPrint("GroupModel.fromJson ${json.toString()}");
    return GroupModel(
      groupId: json['group_id'] ?? (json['id'] ?? json['gid']),
      type: json['type'],
      joinLimit: json['join_limit'],
      contentLimit: json['content_limit'],
      userIdSum: json['user_id_sum'],
      ownerUid: json['owner_uid'],
      creatorUid: json['creator_uid'],
      memberMax: json['member_max'],
      memberCount: json['member_count'],
      introduction: json['introduction'] ?? '',
      avatar: json['avatar'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? 1,
      updatedAt: json['updated_at'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        GroupRepo.groupId: groupId,
        GroupRepo.type: type,
        GroupRepo.joinLimit: joinLimit,
        GroupRepo.contentLimit: contentLimit,
        GroupRepo.userIdSum: userIdSum,
        GroupRepo.ownerUid: ownerUid,
        GroupRepo.creatorUid: creatorUid,
        GroupRepo.memberMax: memberMax,
        GroupRepo.memberCount: memberCount,
        GroupRepo.introduction: introduction,
        GroupRepo.avatar: avatar,
        GroupRepo.title: title,
        GroupRepo.status: status,
        GroupRepo.updatedAt: updatedAt,
        GroupRepo.createdAt: createdAt,
      };
}
