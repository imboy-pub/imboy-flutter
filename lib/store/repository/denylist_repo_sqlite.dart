import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class DenylistRepo {
  static String tableName = 'user_denylist';

  static String uid = 'user_id'; // 记录所属用户D I
  static String deniedUid = 'denied_user_id'; // 被列入名单的用户ID
  static String nickname = 'nickname'; // 被列入名单的用户昵称
  static String avatar = 'avatar';
  static String gender = 'gender';
  static String account = 'account';
  static String region = 'region';
  static String sign = 'sign';
  static String source = 'source';
  static String remark = 'remark';
  static String createdAt = "created_at";

  final Sqlite _db = Sqlite.instance;

  Future<List<DenylistModel>> page({
    int limit = 1000,
    int offset = 0,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      DenylistRepo.tableName,
      columns: [
        DenylistRepo.deniedUid,
        DenylistRepo.nickname,
        DenylistRepo.avatar,
        DenylistRepo.account,
        DenylistRepo.remark,
        DenylistRepo.region,
        DenylistRepo.sign,
        DenylistRepo.source,
        DenylistRepo.gender,
        DenylistRepo.createdAt,
      ],
      where: '${DenylistRepo.uid}=?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${DenylistRepo.createdAt} desc",
      limit: limit,
      offset: offset,
    );
    debugPrint("> on page ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<DenylistModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(DenylistModel.fromJson(maps[i]));
    }
    return items;
  }

  Future<List<DenylistModel>> search({
    required String kwd,
    int limit = 1000,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      DenylistRepo.tableName,
      columns: [
        DenylistRepo.deniedUid,
        DenylistRepo.nickname,
        DenylistRepo.avatar,
        DenylistRepo.account,
        DenylistRepo.remark,
        DenylistRepo.region,
        DenylistRepo.sign,
        DenylistRepo.source,
        DenylistRepo.gender,
        DenylistRepo.createdAt,
      ],
      where: '${DenylistRepo.uid}=? and ('
          '${DenylistRepo.nickname} like "%$kwd%" or ${DenylistRepo.remark} like "%$kwd%"'
          ')',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${DenylistRepo.createdAt} desc",
      limit: limit,
    );
    debugPrint("> on search ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<DenylistModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(DenylistModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<DenylistModel> insert(DenylistModel obj) async {
    Map<String, dynamic> insert = {
      DenylistRepo.uid: UserRepoLocal.to.currentUid,
      DenylistRepo.deniedUid: obj.deniedUid,
      DenylistRepo.nickname: obj.nickname,
      DenylistRepo.avatar: obj.avatar,
      DenylistRepo.account: obj.account,
      DenylistRepo.remark: obj.remark,
      DenylistRepo.gender: obj.gender,
      DenylistRepo.region: obj.region,
      DenylistRepo.sign: obj.sign,
      DenylistRepo.source: obj.source,
      // 单位毫秒，13位时间戳  1561021145560
      DenylistRepo.createdAt:
          obj.createdAt ?? DateTimeHelper.currentTimeMillis(),
    };
    debugPrint("> on DenylistRepo/insert/1 $insert");

    await _db.insert(DenylistRepo.tableName, insert);
    return obj;
  }

  Future<int> count() async {
    int? count = await _db.count(
      DenylistRepo.tableName,
      where: '${DenylistRepo.uid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid],
    );
    return count ?? 0;
  }

  Future<int> inDenylist(String uid) async {
    int? count = await _db.count(
      DenylistRepo.tableName,
      where: '${DenylistRepo.uid} = ? and ${DenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
    return count ?? 0;
  }

  //
  Future<DenylistModel?> findByDeniedUid(String uid) async {
    List<Map<String, dynamic>> maps = await _db.query(
      DenylistRepo.tableName,
      columns: [
        DenylistRepo.deniedUid,
        DenylistRepo.nickname,
        DenylistRepo.avatar,
        DenylistRepo.account,
        DenylistRepo.remark,
        DenylistRepo.region,
        DenylistRepo.sign,
        DenylistRepo.source,
        DenylistRepo.gender,
        DenylistRepo.createdAt,
      ],
      where: '${DenylistRepo.uid} = ? and ${DenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
    if (maps.isNotEmpty) {
      return DenylistModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    return await _db.delete(
      DenylistRepo.tableName,
      where: '${DenylistRepo.uid} = ? and ${DenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, id],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json[DenylistRepo.deniedUid] ?? "");
    Map<String, Object?> data = {};
    if (strNoEmpty(json["account"])) {
      data[DenylistRepo.account] = json["account"];
    }
    if (strNoEmpty(json["nickname"])) {
      data[DenylistRepo.nickname] = json["nickname"];
    }
    if (strNoEmpty(json["avatar"] ?? "")) {
      data[DenylistRepo.avatar] = json["avatar"];
    }

    if (strNoEmpty(json["remark"])) {
      data[DenylistRepo.remark] = json["remark"];
    }
    if (strNoEmpty(json["region"])) {
      data[DenylistRepo.region] = json["region"];
    }
    if (strNoEmpty(json["sign"])) {
      data[DenylistRepo.sign] = json["sign"];
    }
    if (strNoEmpty(json["source"])) {
      data[DenylistRepo.source] = json["source"];
    }
    if (json["gender"] > 0) {
      data[DenylistRepo.gender] = json["gender"];
    }

    debugPrint("> on DenylistRepo/update/1 data: ${data.toString()}");
    if (strNoEmpty(uid)) {
      data[DenylistRepo.createdAt] = DateTimeHelper.currentTimeMillis();
      return await _db.update(
        DenylistRepo.tableName,
        data,
        where: '${DenylistRepo.uid} = ? and ${DenylistRepo.deniedUid} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, uid],
      );
    } else {
      return 0;
    }
  }

  void save(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json[DenylistRepo.deniedUid] ?? "");
    DenylistModel? old = await findByDeniedUid(uid);
    if (old is DenylistModel) {
      await update(json);
    } else {
      await insert(DenylistModel.fromJson(json));
    }
  }

  Future<int> deleteForUid(String uid) async {
    return await _db.delete(
      DenylistRepo.tableName,
      where: '${DenylistRepo.uid} = ? and ${DenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
  }
// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
