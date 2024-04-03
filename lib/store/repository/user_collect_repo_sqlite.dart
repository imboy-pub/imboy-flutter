import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserCollectRepo {
  static String tableName = 'user_collect';

  static String userId = 'user_id'; //
  // Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  static String kind = 'kind'; //
  static String kindId = 'kind_id'; //
  static String source = 'source'; //
  static String remark = 'remark';

  // 多个tag 用半角逗号分隔，单个tag不超过14字符
  static String tag = 'tag';

  static String updatedAt = 'updated_at';
  static String createdAt = 'created_at';
  static String info = 'info';

  final SqliteService _db = SqliteService.to;

  Future<List<UserCollectModel>> page({
    int limit = 1000,
    int offset = 0,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserCollectRepo.tableName,
      columns: [
        UserCollectRepo.userId,
        UserCollectRepo.kind,
        UserCollectRepo.kindId,
        UserCollectRepo.source,
        UserCollectRepo.remark,
        UserCollectRepo.updatedAt,
        UserCollectRepo.createdAt,
        UserCollectRepo.tag,
        UserCollectRepo.info,
      ],
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? "${UserCollectRepo.createdAt} desc",
      limit: limit,
      offset: offset,
    );
    // debugPrint("user_collect_repo_page ${maps.length}");
    // debugPrint("user_collect_repo_page ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<UserCollectModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(UserCollectModel.fromJson(maps[i]));
    }
    return items;
  }

  Future<UserCollectModel> save(Map<String, dynamic> json) async {
    String kid = json[UserCollectRepo.kindId];
    UserCollectModel? old = await findByKindId(kid);
    if (old is UserCollectModel) {
      await update(kid, json);
      return old;
    } else {
      UserCollectModel model = UserCollectModel.fromJson(json);
      await insert(model);
      return model;
    }
  }

  // 插入一条数据
  Future<UserCollectModel> insert(UserCollectModel obj) async {
    String tag = obj.tag;
    if (tag.isNotEmpty && !tag.endsWith(',')) {
      tag = "$tag,";
    }
    tag = tag.replaceAll(',,', ',');

    Map<String, dynamic> insert = {
      UserCollectRepo.userId: UserRepoLocal.to.currentUid,
      UserCollectRepo.kind: obj.kind,
      UserCollectRepo.kindId: obj.kindId,
      UserCollectRepo.source: obj.source,
      UserCollectRepo.remark: obj.remark,
      UserCollectRepo.tag: tag,
      UserCollectRepo.updatedAt: obj.updatedAt,
      UserCollectRepo.createdAt: obj.createdAt,
      UserCollectRepo.info: jsonEncode(obj.info),
    };
    debugPrint("UserCollectRepo_insert/1 $insert");

    await _db.insert(UserCollectRepo.tableName, insert);
    return obj;
  }

  // 根据ID删除信息
  Future<int> delete(String kid) async {
    return await _db.delete(
      UserCollectRepo.tableName,
      where: '${UserCollectRepo.userId} = ? and ${UserCollectRepo.kindId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, kid],
    );
  }

  // 更新信息
  Future<int> update(String kid, Map<String, dynamic> json) async {
    // iPrint("user_collect_repo_sqlite/update $kid, ${json.toString()}");
    Map<String, Object?> data = {};
    if (strNoEmpty(json[UserCollectRepo.remark])) {
      data[UserCollectRepo.remark] = json[UserCollectRepo.remark];
    }
    String? tag = json[UserCollectRepo.tag];
    if (tag != null) {
      if (tag.isNotEmpty && !tag.endsWith(',')) {
        tag = "$tag,";
      }
      tag = tag.replaceAll(',,', ',');
      data[UserCollectRepo.tag] = tag;
    }
    // if (json.containsKey(UserCollectRepo.source)){
    //   iPrint("user_collect_repo_sqlite/update 2 ${json[UserCollectRepo.source]}");
    // }
    if (json.containsKey(UserCollectRepo.source) &&
        strNoEmpty(json[UserCollectRepo.source].toString())) {
      data[UserCollectRepo.source] = json[UserCollectRepo.source];
    }
    var info = json[UserCollectRepo.info] ?? {};
    if (info is String && strNoEmpty(info)) {
      data[UserCollectRepo.info] = info;
    } else if (mapNoEmpty(info)) {
      data[UserCollectRepo.info] = jsonEncode(info);
    }

    int updatedAt = json[UserCollectRepo.updatedAt] ?? 0;
    if (updatedAt > 0) {
      data[UserCollectRepo.updatedAt] = updatedAt;
    }

    if (strNoEmpty(kid)) {
      return await _db.update(
        UserCollectRepo.tableName,
        data,
        where:
            '${UserCollectRepo.userId} = ? and ${UserCollectRepo.kindId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, kid],
      );
    } else {
      return 0;
    }
  }

  Future<UserCollectModel?> findByKindId(String kindId) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserCollectRepo.tableName,
      columns: [],
      where: '${UserCollectRepo.userId} = ? and ${UserCollectRepo.kindId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, kindId],
    );
    if (maps.isNotEmpty) {
      return UserCollectModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
