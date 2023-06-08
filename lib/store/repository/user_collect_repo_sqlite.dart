import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserCollectRepo {
  static String tableName = 'user_collect';

  static String userId = 'user_id'; //
  static String kind = 'kind'; //
  static String kindId = 'kind_id'; //
  static String source = 'source'; //
  static String remark = 'remark';

  static String updatedAt = 'updated_at';
  static String createdAt = 'created_at';
  static String info = 'info';

  final Sqlite _db = Sqlite.instance;

  Future<List<UserCollectModel>> page({
    int limit = 1000,
    int offset = 0,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserCollectRepo.tableName,
      columns: [
        // UserCollectRepo.userId,
        UserCollectRepo.kind,
        UserCollectRepo.kindId,
        UserCollectRepo.source,
        UserCollectRepo.remark,
        UserCollectRepo.updatedAt,
        UserCollectRepo.createdAt,
        UserCollectRepo.info,
      ],
      where: '${UserCollectRepo.userId}=?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${UserCollectRepo.createdAt} desc",
      limit: limit,
      offset: offset,
    );
    debugPrint("> on page ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<UserCollectModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(UserCollectModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<UserCollectModel> insert(UserCollectModel obj) async {
    Map<String, dynamic> insert = {
      UserCollectRepo.userId: UserRepoLocal.to.currentUid,
      UserCollectRepo.kind: obj.kind,
      UserCollectRepo.kindId: obj.kindId,
      UserCollectRepo.source: obj.source,
      UserCollectRepo.remark: obj.remark,
      UserCollectRepo.updatedAt: obj.updatedAt,
      UserCollectRepo.createdAt: obj.createdAt,
      UserCollectRepo.info: obj.info,
    };
    debugPrint("> on UserCollectRepo/insert/1 $insert");

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
    Map<String, Object?> data = {};
    if (strNoEmpty(json[UserCollectRepo.remark])) {
      data[UserCollectRepo.remark] = json[UserCollectRepo.remark];
    }

    int createdAt = json[UserCollectRepo.createdAt] ?? 0;
    if (createdAt > 0) {
      data[UserCollectRepo.createdAt] = createdAt;
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

  Future<List<UserCollectModel>> search({
    required String kwd,
    int limit = 1000,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserCollectRepo.tableName,
      columns: [
        // UserCollectRepo.userId,
        UserCollectRepo.kind,
        UserCollectRepo.kindId,
        UserCollectRepo.source,
        UserCollectRepo.remark,
        UserCollectRepo.updatedAt,
        UserCollectRepo.createdAt,
        UserCollectRepo.info,
      ],
      where: '${UserCollectRepo.userId}=? and ('
          '${UserCollectRepo.source} like "%$kwd%" or ${UserCollectRepo.remark} like "%$kwd%"'
          ')',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${UserCollectRepo.createdAt} desc",
      limit: limit,
    );
    debugPrint("> on search ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<UserCollectModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(UserCollectModel.fromJson(maps[i]));
    }
    return items;
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
