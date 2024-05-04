import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/group_member_model.dart';

class GroupMemberRepo {
  static String tableName = 'group_member';

  static String id = 'id'; //
  static String groupId = 'group_id'; // 群组ID
  static String userId = 'user_id'; // 群组成员用户ID
  static String nickname = 'nickname'; // 群组成员用户信息
  static String avatar = 'avatar'; // 群组成员用户信息
  static String sign = 'sign'; // 群组成员用户信息
  static String account = 'account'; // 群组成员用户信息
  static String inviteCode = 'invite_code'; // 入群邀请码
  static String alias = 'alias'; // 群内别名
  static String description = 'description'; // 群内描述
  static String role = 'role'; // 角色: 1 成员  2 嘉宾  3  管理员 4 群主
  static String isJoin = 'is_join'; // 是否加入的群： 1 是 0 否 （0 是群创建者或者拥有者 1 是 成员 嘉宾 管理员等）
  static String joinMode = 'join_mode'; // 进群方式 :  invite_[uid]_[nickname] <a>leeyi</a>邀请进群  scan_qr_code 扫描二维码加入 face2face_join 面对面建群
  static String status = 'status'; //
  static String updatedAt = 'updated_at'; //
  static String createdAt = 'created_at'; //

  final SqliteService _db = SqliteService.to;

  Future<List<GroupMemberModel>> page({
    int limit = 1000,
    int offset = 0,
    String where = "",
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      GroupMemberRepo.tableName,
      columns: [
        GroupMemberRepo.id,
        GroupMemberRepo.groupId,
        GroupMemberRepo.userId,
        GroupMemberRepo.nickname,
        GroupMemberRepo.avatar,
        GroupMemberRepo.sign,
        GroupMemberRepo.account,
        GroupMemberRepo.inviteCode,
        GroupMemberRepo.alias,
        GroupMemberRepo.description,
        GroupMemberRepo.role,
        GroupMemberRepo.isJoin,
        GroupMemberRepo.joinMode,
        GroupMemberRepo.status,
        GroupMemberRepo.updatedAt,
        GroupMemberRepo.createdAt,
      ],
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    debugPrint(
        "GroupMemberRepo_page repo ${maps.length} $where, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<GroupMemberModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(GroupMemberModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<GroupMemberModel> insert(GroupMemberModel obj) async {
    Map<String, dynamic> insert = {
      GroupMemberRepo.id: obj.id,
      GroupMemberRepo.groupId: obj.groupId,
      GroupMemberRepo.userId: obj.userId,
      GroupMemberRepo.nickname: obj.nickname,
      GroupMemberRepo.avatar: obj.avatar,
      GroupMemberRepo.sign: obj.sign,
      GroupMemberRepo.account: obj.account,
      GroupMemberRepo.inviteCode: obj.inviteCode,
      GroupMemberRepo.alias: obj.alias,
      GroupMemberRepo.description: obj.description,
      GroupMemberRepo.role: obj.role,
      GroupMemberRepo.isJoin: obj.isJoin,
      GroupMemberRepo.joinMode: obj.joinMode,
      GroupMemberRepo.status : obj.status,
      GroupMemberRepo.updatedAt: obj.updatedAt,
      GroupMemberRepo.createdAt: obj.createdAt,
    };
    debugPrint("GroupMemberRepo/insert/1 $insert");
    await _db.insert(GroupMemberRepo.tableName, insert);
    return obj;
  }

  // 根据ID删除信息
  Future<int> delete(String gid, String userId) async {
    iPrint("group_member_repo/delete $gid, $userId");
    return await _db.delete(
      GroupMemberRepo.tableName,
      where: '${GroupMemberRepo.groupId} = ? and ${GroupMemberRepo.userId} = ?',
      whereArgs: [gid, userId],
    );
  }
  Future<int> deleteByGid(String gid) async {
    return await _db.delete(
      GroupMemberRepo.tableName,
      where: '${GroupMemberRepo.groupId} = ?',
      whereArgs: [gid],
    );
  }
  // 更新信息
  Future<int> update(String gid, String userId, Map<String, dynamic> json) async {
    Map<String, Object?> data = {};

    String? nickname = json[GroupMemberRepo.nickname];
    if (nickname != null) {
      data[GroupMemberRepo.nickname] = json[GroupMemberRepo.nickname];
    }
    String? avatar = json[GroupMemberRepo.avatar];
    if (avatar != null) {
      data[GroupMemberRepo.avatar] = json[GroupMemberRepo.avatar];
    }
    String? sign = json[GroupMemberRepo.sign];
    if (sign != null) {
      data[GroupMemberRepo.sign] = json[GroupMemberRepo.sign];
    }
    String? account = json.containsKey(GroupMemberRepo.account) ? json[GroupMemberRepo.account].toString() : null;
    if (account != null) {
      data[GroupMemberRepo.account] = account;
    }

    String? inviteCode = json[GroupMemberRepo.inviteCode];
    if (strNoEmpty(inviteCode)) {
      data[GroupMemberRepo.inviteCode] = json[GroupMemberRepo.inviteCode];
    }
    String? alias = json[GroupMemberRepo.alias];
    if (alias != null) {
      data[GroupMemberRepo.alias] = json[GroupMemberRepo.alias];
    }
    String? description = json[GroupMemberRepo.description];
    if (description != null) {
      data[GroupMemberRepo.description] = json[GroupMemberRepo.description];
    }
    int? isJoin = json[GroupMemberRepo.isJoin];
    if (isJoin != null) {
      data[GroupMemberRepo.isJoin] = json[GroupMemberRepo.isJoin];
    }
    int? status = json[GroupMemberRepo.status];
    if (status != null) {
      data[GroupMemberRepo.status] = json[GroupMemberRepo.status];
    }

    int role = json[GroupMemberRepo.role] ?? 0;
    if (role > 0) {
      data[GroupMemberRepo.role] = role;
    }

    int updatedAt = json[GroupMemberRepo.updatedAt] ?? 0;
    if (updatedAt > 0) {
      data[GroupMemberRepo.updatedAt] = updatedAt;
    }
    // String gid = json[GroupMemberRepo.groupId] ?? (json['group_id'] ?? (json['gid'] ?? ''));
    iPrint("GroupMemberRepo_update ${data.toString()};");
    if (gid.isNotEmpty && userId.isNotEmpty) {
      if (data.containsKey('id')) {
        data.remove('id');
      }
      return await _db.update(
        GroupMemberRepo.tableName,
        data,
        where: '${GroupMemberRepo.groupId} = ? and ${GroupMemberRepo.userId} = ?',
        whereArgs: [gid, userId],
      );
    } else {
      return 0;
    }
  }

  Future<GroupMemberModel> save(Map<String, dynamic> json) async {
    String gid = json[GroupMemberRepo.groupId] ?? '';
    String userId = json[GroupMemberRepo.userId] ?? '';
    // iPrint("GroupMemberRepo_save $tagId");
    GroupMemberModel? old = await findByUserId(gid, userId);
    iPrint("GroupMemberRepo_save $gid, ${old?.toJson().toString()};");
    if (old == null) {
      GroupMemberModel model = GroupMemberModel.fromJson(json);
      await insert(model);
      return model;
    } else {
      await update(gid, userId, json);
      return old;
    }
  }
  Future<GroupMemberModel?> findByUserId(String gid, String userId) async {
    List<Map<String, dynamic>> maps = await _db.query(
      GroupMemberRepo.tableName,
      columns: [],
      where: '${GroupMemberRepo.groupId} = ? AND ${GroupMemberRepo.userId} = ?',
      whereArgs: [gid, userId],
    );
    if (maps.isNotEmpty) {
      return GroupMemberModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<int?> countByGid(String gid) async {
    return await _db.pluck(
      "count(*) as count",
      GroupMemberRepo.tableName,
      where: '${GroupMemberRepo.groupId} = ?',
      whereArgs: [gid],
    );
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
