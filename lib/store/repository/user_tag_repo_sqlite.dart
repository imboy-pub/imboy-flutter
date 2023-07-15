import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserTagRepo {
  static String tableName = 'user_tag';

  static String userId = 'user_id'; // creator_user_id 创建人用户ID
  static String tagId = 'tag_id'; // 标签ID
  static String scene = 'scene'; // 标签应用场景 1  用户收藏记录标签  2 用户朋友标签
  static String name = 'name'; // 标签名称
  static String subtitle = 'subtitle'; //  例如 "leeyi108古古惑惑还, 15000049665"
  static String refererTime = 'referer_time'; // 被引用次数 关联object_id 数量
  static String updatedAt = 'updated_at';
  static String createdAt = 'created_at';

  final SqliteService _db = SqliteService.to;

  Future<List<UserTagModel>> page({
    int limit = 1000,
    int offset = 0,
    String where = "",
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserTagRepo.tableName,
      columns: [
        UserTagRepo.userId,
        UserTagRepo.tagId,
        UserTagRepo.scene,
        UserTagRepo.name,
        UserTagRepo.subtitle,
        UserTagRepo.refererTime,
        UserTagRepo.updatedAt,
        UserTagRepo.createdAt,
      ],
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    debugPrint(
        "UserTagRepo_page repo ${maps.length} $where, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<UserTagModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(UserTagModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<UserTagModel> insert(UserTagModel obj) async {
    Map<String, dynamic> insert = {
      UserTagRepo.userId: UserRepoLocal.to.currentUid,
      UserTagRepo.tagId: obj.tagId,
      UserTagRepo.scene: obj.scene,
      UserTagRepo.name: obj.name,
      UserTagRepo.subtitle: obj.subtitle,
      UserTagRepo.refererTime: obj.refererTime,
      UserTagRepo.updatedAt: obj.updatedAt,
      UserTagRepo.createdAt: obj.createdAt,
    };
    debugPrint("UserTagRepo/insert/1 $insert");
    await _db.insert(UserTagRepo.tableName, insert);
    return obj;
  }

  // 根据ID删除信息
  Future<int> delete(int tagId) async {
    return await _db.delete(
      UserTagRepo.tableName,
      where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, tagId],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    Map<String, Object?> data = {};
    if (strNoEmpty(json[UserTagRepo.name])) {
      data[UserTagRepo.name] = json[UserTagRepo.name];
    }
    String? subtitle = json[UserTagRepo.subtitle];
    if (subtitle != null) {
      data[UserTagRepo.subtitle] = json[UserTagRepo.subtitle];
    }

    int refererTime = json[UserTagRepo.refererTime] ?? 0;
    if (refererTime > 0) {
      data[UserTagRepo.refererTime] = refererTime;
    }

    int updatedAt = json[UserTagRepo.updatedAt] ?? 0;
    if (updatedAt > 0) {
      data[UserTagRepo.updatedAt] = updatedAt;
    }
    int tagId = json[UserTagRepo.tagId] ?? (json['id'] ?? 0);
    iPrint("UserTagRepo_update ${data.toString()};");
    if (tagId > 0) {
      return await _db.update(
        UserTagRepo.tableName,
        data,
        where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, tagId],
      );
    } else {
      return 0;
    }
  }

  Future<UserTagModel> save(Map<String, dynamic> json) async {
    int tagId = json[UserTagRepo.tagId] ?? (json['id'] ?? 0);
    // iPrint("UserTagRepo_save $tagId");
    UserTagModel? old = await findByTagId(tagId);
    iPrint("UserTagRepo_save $tagId, ${old?.toMap().toString()};");
    if (old == null) {
      UserTagModel model = UserTagModel.fromJson(json);
      await insert(model);
      return model;
    } else {
      await update(json);
      return old;
    }
  }

  Future<UserTagModel?> findByTagId(int tagId) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserTagRepo.tableName,
      columns: [],
      where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, tagId],
    );
    if (maps.isNotEmpty) {
      return UserTagModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
