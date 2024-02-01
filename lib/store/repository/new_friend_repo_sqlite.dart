import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class NewFriendRepo {
  static String tableName = 'new_friend';

  static String uid = 'uid'; // 当前用户ID
  static String from = 'from_id'; // 发送中ID
  static String to = 'to_id'; // 接收者ID
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String msg = 'msg';

  // 0 待验证  1 已添加  2 已过期
  static String status = 'status';

  static String payload = 'payload';
  static String updateAt = "update_at";
  static String createAt = "create_at";
  static String source = "source";

  final SqliteService _db = SqliteService.to;

  // 插入一条数据
  Future<NewFriendModel> insert(NewFriendModel obj) async {
    Map<String, dynamic> insert = {
      NewFriendRepo.uid: UserRepoLocal.to.currentUid,
      NewFriendRepo.from: obj.from,
      NewFriendRepo.to: obj.to,
      NewFriendRepo.nickname: obj.nickname,
      NewFriendRepo.avatar: obj.avatar,
      NewFriendRepo.msg: obj.msg,
      NewFriendRepo.status: obj.status,
      NewFriendRepo.payload: obj.payload,
      // 单位毫秒，13位时间戳  1561021145560
      NewFriendRepo.updateAt:
          obj.updateAt ?? DateTimeHelper.utc(),
      NewFriendRepo.createAt: DateTimeHelper.utc(),
    };
    debugPrint("> on NewFriendRepo/insert/1 $insert");

    await _db.insert(NewFriendRepo.tableName, insert);
    return obj;
  }

  Future<List<NewFriendModel>> listNewFriend(String uid, int limit) async {
    List<Map<String, dynamic>> maps = await _db.query(
      NewFriendRepo.tableName,
      columns: [
        NewFriendRepo.uid,
        NewFriendRepo.from,
        NewFriendRepo.to,
        NewFriendRepo.nickname,
        NewFriendRepo.avatar,
        NewFriendRepo.status,
        NewFriendRepo.msg,
        NewFriendRepo.payload,
        NewFriendRepo.updateAt,
        NewFriendRepo.createAt,
      ],
      where: '${NewFriendRepo.uid}=?',
      whereArgs: [uid],
      orderBy: "${NewFriendRepo.createAt} desc",
      limit: limit,
    );
    // debugPrint("> on findFriend ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<NewFriendModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(NewFriendModel.fromJson(maps[i]));
    }
    return items;
  }

  //
  Future<NewFriendModel?> findByFromTo(String from, String to) async {
    List<Map<String, dynamic>> maps = await _db.query(
      NewFriendRepo.tableName,
      columns: [
        NewFriendRepo.uid,
        NewFriendRepo.from,
        NewFriendRepo.to,
        NewFriendRepo.nickname,
        NewFriendRepo.avatar,
        NewFriendRepo.status,
        NewFriendRepo.msg,
        NewFriendRepo.payload,
        NewFriendRepo.updateAt,
        NewFriendRepo.createAt,
      ],
      where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
      whereArgs: [from, to],
    );
    if (maps.isNotEmpty) {
      return NewFriendModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String from, String to) async {
    return await _db.delete(
      NewFriendRepo.tableName,
      where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
      whereArgs: [from, to],
    );
  }

  Future<int> deleteByUid(String uid) async {
    return await _db.delete(
      NewFriendRepo.tableName,
      where: '${NewFriendRepo.from} = ? or ${NewFriendRepo.to} = ?',
      whereArgs: [uid, uid],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String from = json[NewFriendRepo.from] ?? json['from'];
    String to = json[NewFriendRepo.to] ?? json['to'];
    Map<String, Object?> data = {};
    if (strNoEmpty(json[NewFriendRepo.msg])) {
      data[NewFriendRepo.msg] = json[NewFriendRepo.msg];
    }
    if (strNoEmpty(json[NewFriendRepo.nickname])) {
      data[NewFriendRepo.nickname] = json[NewFriendRepo.nickname];
    }
    if (strNoEmpty(json[NewFriendRepo.avatar])) {
      data[NewFriendRepo.avatar] = json[NewFriendRepo.avatar];
    }

    if (json[NewFriendRepo.status] >= 0) {
      data[NewFriendRepo.status] = json["status"];
    }
    if (strNoEmpty(json[NewFriendRepo.payload])) {
      data[NewFriendRepo.payload] = json[NewFriendRepo.payload];
    }

    if (json[NewFriendRepo.updateAt] != null &&
        json[NewFriendRepo.updateAt] >= 0) {
      data[NewFriendRepo.updateAt] = json[NewFriendRepo.updateAt];
    }
    if (json[NewFriendRepo.createAt] != null &&
        json[NewFriendRepo.createAt] >= 0) {
      data[NewFriendRepo.createAt] = json[NewFriendRepo.createAt];
    }

    if (strNoEmpty(from) && strNoEmpty(to)) {
      data[NewFriendRepo.updateAt] = DateTimeHelper.utc();
      return await _db.update(
        NewFriendRepo.tableName,
        data,
        where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
        whereArgs: [from, to],
      );
    } else {
      return 0;
    }
  }

  void save(Map<String, dynamic> json) async {
    String from = json[NewFriendRepo.from] ?? json['from'];
    String to = json[NewFriendRepo.to] ?? json['to'];
    NewFriendModel? old = await findByFromTo(from, to);
    // debugPrint("> on new_friend save: ${old.toString()}");
    if (old != null || old is NewFriendModel) {
      await update(json);
    } else {
      await insert(NewFriendModel.fromJson(json));
    }
  }

  Future<int?> countStatus(int status, String to) async {
    return await _db.count(
      NewFriendRepo.tableName,
      where: '${NewFriendRepo.status} = ? and ${NewFriendRepo.to} = ?',
      whereArgs: [status, to],
    );
  }
// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
