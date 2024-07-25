import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class GroupRepo {
  static String tableName = 'group';

  static String groupId = 'id'; //
  static String type = 'type'; // 类型: 1 公开群组  2 私有群组
  static String joinLimit = 'join_limit'; //  加入限制: 1 不需审核  2 需要审核  3 只允许邀请加入
  static String contentLimit =
      'content_limit'; // 内部发布限制: 1 圈内不需审核  2 圈内需要审核  3 圈外需要审核
  static String userIdSum =
      'user_id_sum'; // 主要用于添加群聊的时候排重；还可以用于校验客户端memberCount是否应该增加
  static String ownerUid = 'owner_uid'; //  群组拥有者ID
  static String creatorUid = 'creator_uid'; //群组创建者ID
  static String memberMax = 'member_max'; // 允许最大成员数量
  static String memberCount = 'member_count'; // 成员数量
  static String introduction = 'introduction'; // 简介
  static String avatar = 'avatar';
  static String title = 'title';
  static String status = 'status';
  static String updatedAt = 'updated_at';
  static String createdAt = 'created_at';

  final SqliteService _db = SqliteService.to;

  Future<List<GroupModel>> page({
    int limit = 1000,
    int offset = 0,
    String where = "",
    List<Object?>? whereArgs,
    String orderBy = '',
  }) async {
    if (where.isEmpty) {
      where = "${GroupRepo.ownerUid} = ?";
      whereArgs = [UserRepoLocal.to.currentUid];
    }
    if (orderBy.isEmpty) {
      orderBy = "${GroupRepo.createdAt} desc";
    }
    List<Map<String, dynamic>> maps = await _db.query(
      GroupRepo.tableName,
      columns: [
        GroupRepo.groupId,
        GroupRepo.type,
        GroupRepo.joinLimit,
        GroupRepo.contentLimit,
        GroupRepo.userIdSum,
        GroupRepo.ownerUid,
        GroupRepo.creatorUid,
        GroupRepo.memberMax,
        GroupRepo.memberCount,
        GroupRepo.introduction,
        GroupRepo.avatar,
        GroupRepo.title,
        GroupRepo.status,
        GroupRepo.updatedAt,
        GroupRepo.createdAt,
      ],
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    debugPrint(
        "GroupRepo_page repo ${maps.length} $where, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<GroupModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(GroupModel.fromJson(maps[i]));
    }
    return items;
  }

  Future<List<GroupModel>> search({
    required String kwd,
    int limit = 1000,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      GroupRepo.tableName,
      columns: [
        GroupRepo.groupId,
        GroupRepo.type,
        GroupRepo.joinLimit,
        GroupRepo.contentLimit,
        GroupRepo.userIdSum,
        GroupRepo.ownerUid,
        GroupRepo.creatorUid,
        GroupRepo.memberMax,
        GroupRepo.memberCount,
        GroupRepo.introduction,
        GroupRepo.avatar,
        GroupRepo.title,
        GroupRepo.status,
        GroupRepo.updatedAt,
        GroupRepo.createdAt,
      ],
      where: '${GroupRepo.ownerUid}=? and ('
          '${GroupRepo.title} like "%$kwd%" or ${GroupRepo.introduction} like "%$kwd%"'
          ')',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${GroupRepo.createdAt} desc",
      limit: limit,
    );
    debugPrint("> on search ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<GroupModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(GroupModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<GroupModel> insert(GroupModel obj) async {
    Map<String, dynamic> insert = {
      GroupRepo.groupId: obj.groupId,
      GroupRepo.type: obj.type,
      GroupRepo.joinLimit: obj.joinLimit,
      GroupRepo.contentLimit: obj.contentLimit,
      GroupRepo.userIdSum: obj.userIdSum,
      GroupRepo.ownerUid: obj.ownerUid,
      GroupRepo.creatorUid: obj.creatorUid,
      GroupRepo.memberMax: obj.memberMax,
      GroupRepo.memberCount: obj.memberCount,
      GroupRepo.introduction: obj.introduction,
      GroupRepo.avatar: obj.avatar,
      GroupRepo.title: obj.title,
      GroupRepo.status: obj.status,
      GroupRepo.updatedAt: obj.updatedAt,
      GroupRepo.createdAt: obj.createdAt,
    };
    debugPrint("GroupRepo/insert/1 $insert");
    await _db.insert(GroupRepo.tableName, insert);
    return obj;
  }

  // 根据ID删除信息
  Future<int> delete(String gid) async {
    return await _db.delete(
      GroupRepo.tableName,
      where: '${GroupRepo.ownerUid} = ? and ${GroupRepo.groupId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, gid],
    );
  }

  // 更新信息
  Future<int> update(String gid, Map<String, dynamic> json) async {
    Map<String, Object?> data = {};
    String? title = json[GroupRepo.title];
    if (title != null) {
      data[GroupRepo.title] = json[GroupRepo.title];
    }
    // data[GroupRepo.title] = '';

    String? avatar = json[GroupRepo.avatar];
    if (avatar != null) {
      data[GroupRepo.avatar] = json[GroupRepo.avatar];
    }
    String? introduction = json[GroupRepo.introduction];
    if (introduction != null) {
      data[GroupRepo.introduction] = json[GroupRepo.introduction];
    }

    int memberCount = json[GroupRepo.memberCount] ?? 0;
    if (memberCount > 0) {
      data[GroupRepo.memberCount] = memberCount;
    }
    int userIdSum = json[GroupRepo.userIdSum] ?? 0;
    if (userIdSum > 0) {
      data[GroupRepo.userIdSum] = userIdSum;
    }

    int updatedAt = json[GroupRepo.updatedAt] ?? 0;
    if (updatedAt > 0) {
      data[GroupRepo.updatedAt] = updatedAt;
    }
    if (gid.isEmpty) {
      gid =
          json[GroupRepo.groupId] ?? (json['group_id'] ?? (json['gid'] ?? ''));
    }
    iPrint("GroupRepo_update ${data.toString()};");
    if (gid.isNotEmpty) {
      return await _db.update(
        GroupRepo.tableName,
        data,
        where: '${GroupRepo.groupId} = ?',
        whereArgs: [gid],
      );
    } else {
      return 0;
    }
  }

  Future<GroupModel> save(String gid, Map<String, dynamic> json) async {
    if (gid.isEmpty) {
      gid =
          json[GroupRepo.groupId] ?? (json['group_id'] ?? (json['gid'] ?? ''));
    }
    // iPrint("GroupRepo_save $tagId");
    GroupModel? old = await findById(gid);
    iPrint("GroupRepo_save $gid, ${old?.toJson().toString()};");
    if (old == null) {
      GroupModel model = GroupModel.fromJson(json);
      await insert(model);
      return model;
    } else {
      await update(gid, json);
      old = await findById(gid);
      return old!;
    }
  }

  Future<GroupModel?> findById(String gid) async {
    List<Map<String, dynamic>> maps = await _db.query(
      GroupRepo.tableName,
      columns: [],
      where: '${GroupRepo.groupId} = ?',
      whereArgs: [gid],
    );
    if (maps.isNotEmpty) {
      return GroupModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
