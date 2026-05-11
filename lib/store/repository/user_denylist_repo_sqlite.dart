import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserDenylistRepo {
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

  // 公共列名列表
  static final List<String> defaultColumns = [
    UserDenylistRepo.deniedUid,
    UserDenylistRepo.nickname,
    UserDenylistRepo.avatar,
    UserDenylistRepo.account,
    UserDenylistRepo.remark,
    UserDenylistRepo.region,
    UserDenylistRepo.sign,
    UserDenylistRepo.source,
    UserDenylistRepo.gender,
    UserDenylistRepo.createdAt,
  ];

  final SqliteService _db = SqliteService.to;

  Future<List<DenylistModel>> page({int limit = 1000, int offset = 0}) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserDenylistRepo.tableName,
      columns: defaultColumns,
      where: '${UserDenylistRepo.uid}=?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${UserDenylistRepo.createdAt} desc",
      limit: limit,
      offset: offset,
    );
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
    String pattern = "%$kwd%";
    List<Map<String, dynamic>> maps = await _db.query(
      UserDenylistRepo.tableName,
      columns: defaultColumns,
      where:
          '${UserDenylistRepo.uid}=? and ('
          '${UserDenylistRepo.nickname} like ? or ${UserDenylistRepo.remark} like ?'
          ')',
      whereArgs: [UserRepoLocal.to.currentUid, pattern, pattern],
      orderBy: "${UserDenylistRepo.createdAt} desc",
      limit: limit,
    );
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
  Future<DenylistModel> insert(DenylistModel obj, {Transaction? txn}) async {
    Map<String, dynamic> insert = {
      UserDenylistRepo.uid: UserRepoLocal.to.currentUid,
      UserDenylistRepo.deniedUid: obj.deniedUid,
      UserDenylistRepo.nickname: obj.nickname,
      UserDenylistRepo.avatar: obj.avatar,
      UserDenylistRepo.account: obj.account,
      UserDenylistRepo.remark: obj.remark,
      UserDenylistRepo.gender: obj.gender,
      UserDenylistRepo.region: obj.region,
      UserDenylistRepo.sign: obj.sign,
      UserDenylistRepo.source: obj.source,
      // 单位毫秒，13位时间戳  1561021145560
      UserDenylistRepo.createdAt: obj.createdAt,
    };
    if (txn != null) {
      await txn.insert(UserDenylistRepo.tableName, insert);
    } else {
      await _db.insert(UserDenylistRepo.tableName, insert);
    }
    return obj;
  }

  Future<int> count() async {
    int? count = await _db.count(
      UserDenylistRepo.tableName,
      where: '${UserDenylistRepo.uid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid],
    );
    return count ?? 0;
  }

  Future<int> inDenylist(String uid) async {
    int? count = await _db.count(
      UserDenylistRepo.tableName,
      where:
          '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
    return count ?? 0;
  }

  //
  Future<DenylistModel?> findByDeniedUid(String uid, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        UserDenylistRepo.tableName,
        columns: defaultColumns,
        where:
            '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, uid],
      );
    } else {
      maps = await _db.query(
        UserDenylistRepo.tableName,
        columns: defaultColumns,
        where:
            '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, uid],
      );
    }
    if (maps.isNotEmpty) {
      return DenylistModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    return await _db.delete(
      UserDenylistRepo.tableName,
      where:
          '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, id],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json, {Transaction? txn}) async {
    String uid = (json["id"] ?? (json[UserDenylistRepo.deniedUid] ?? ""))
        .toString();
    Map<String, Object?> data = {};
    if (strNoEmpty(json["account"])) {
      data[UserDenylistRepo.account] = json["account"];
    }
    if (strNoEmpty(json["nickname"])) {
      data[UserDenylistRepo.nickname] = json["nickname"];
    }
    if (strNoEmpty(json["avatar"] ?? "")) {
      data[UserDenylistRepo.avatar] = json["avatar"];
    }

    if (strNoEmpty(json["remark"])) {
      data[UserDenylistRepo.remark] = json["remark"];
    }
    if (strNoEmpty(json["region"])) {
      data[UserDenylistRepo.region] = json["region"];
    }
    if (strNoEmpty(json["sign"])) {
      data[UserDenylistRepo.sign] = json["sign"];
    }
    if (strNoEmpty(json["source"])) {
      data[UserDenylistRepo.source] = json["source"];
    }
    if ((json["gender"] as num) > 0) {
      data[UserDenylistRepo.gender] = json["gender"];
    }

    if (strNoEmpty(uid)) {
      data[UserDenylistRepo.createdAt] = DateTimeHelper.millisecond();
      if (txn != null) {
        return await txn.update(
          UserDenylistRepo.tableName,
          data,
          where:
              '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
          whereArgs: [UserRepoLocal.to.currentUid, uid],
        );
      } else {
        return await _db.update(
          UserDenylistRepo.tableName,
          data,
          where:
              '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
          whereArgs: [UserRepoLocal.to.currentUid, uid],
        );
      }
    } else {
      return 0;
    }
  }

  Future<void> save(Map<String, dynamic> json) async {
    String uid = (json["id"] ?? (json[UserDenylistRepo.deniedUid] ?? ""))
        .toString();
    await _db.transaction<void>((txn) async {
      DenylistModel? old = await findByDeniedUid(uid, txn: txn);
      if (old is DenylistModel) {
        await update(json, txn: txn);
      } else {
        await insert(DenylistModel.fromJson(json), txn: txn);
      }
    });
  }

  Future<int> deleteForUid(String uid) async {
    return await _db.delete(
      UserDenylistRepo.tableName,
      where:
          '${UserDenylistRepo.uid} = ? and ${UserDenylistRepo.deniedUid} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
