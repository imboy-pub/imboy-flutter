import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class NewFriendRepo {
  static String tablename = 'new_friend';

  static String from = 'from';
  static String to = 'to';
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String msg = 'msg';
  // 已添加 已过期 待验证 接受
  static String status = 'status';

  static String payload = 'payload';
  static String updateTime = "update_time";
  static String createTime = "create_time";

  Sqlite _db = Sqlite.instance;

  // 插入一条数据
  Future<NewFriendModel> insert(NewFriendModel obj) async {
    Map<String, dynamic> insert = {
      'from': obj.from,
      'to': obj.to,
      'nickname': obj.nickname,
      'avatar': obj.avatar,
      'msg': obj.msg,
      'status': obj.status,
      'payload': obj.payload,
      // 单位毫秒，13位时间戳  1561021145560
      'update_time': obj.updateTime ?? DateTime.now().millisecondsSinceEpoch,
      'create_time': DateTime.now().millisecondsSinceEpoch,
    };
    debugPrint(">>> on NewFriendRepo/insert/1 " + insert.toString());

    await _db.insert(NewFriendRepo.tablename, insert);
    return obj;
  }

  Future<List<NewFriendModel>> findFriend() async {
    List<Map<String, dynamic>> maps = await _db.query(
      NewFriendRepo.tablename,
      columns: [
        NewFriendRepo.from,
        NewFriendRepo.to,
        NewFriendRepo.nickname,
        NewFriendRepo.avatar,
        NewFriendRepo.status,
        NewFriendRepo.msg,
        NewFriendRepo.payload,
      ],
      where: '${NewFriendRepo.from}=?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "update_time desc",
      limit: 10000,
    );
    // debugPrint(">>> on findFriend ${maps.length}, ${maps.toList().toString()}");
    if (maps.length == 0) {
      return [];
    }

    List<NewFriendModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(NewFriendModel.fromJson(maps[i]));
    }
    return items;
  }

  //
  Future<NewFriendModel?> findByUid(String uid) async {
    List<Map<String, dynamic>> maps = await _db.query(
      NewFriendRepo.tablename,
      columns: [
        NewFriendRepo.from,
        NewFriendRepo.to,
        NewFriendRepo.nickname,
        NewFriendRepo.avatar,
        NewFriendRepo.status,
        NewFriendRepo.msg,
        NewFriendRepo.payload,
      ],
      where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
    if (maps.length > 0) {
      return NewFriendModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    return await _db.delete(
      NewFriendRepo.tablename,
      where: '${NewFriendRepo.to} = ?',
      whereArgs: [id],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json["uid"] ?? "");
    Map<String, Object?> data = {};
    if (strNoEmpty(json["msg"])) {
      data["msg"] = json["msg"];
    }
    if (strNoEmpty(json["nickname"])) {
      data["nickname"] = json["nickname"];
    }
    if (strNoEmpty(json["avatar"] ?? "")) {
      data["avatar"] = json["avatar"];
    }

    if (strNoEmpty(json["status"])) {
      data["status"] = json["status"];
    }
    if (strNoEmpty(json["payload"])) {
      data["payload"] = json["payload"];
    }

    if (strNoEmpty(uid)) {
      data["update_time"] = DateTimeHelper.currentTimeMillis();
      return await _db.update(
        NewFriendRepo.tablename,
        data,
        where: '${NewFriendRepo.from} = ?',
        whereArgs: [uid],
      );
    } else {
      return 0;
    }
  }

  void save(Map<String, dynamic> json) async {
    NewFriendModel? old = await this.findByUid(json["to"]);
    if (old != null || old is NewFriendModel) {
      this.update(json);
    } else {
      this.insert(NewFriendModel.fromJson(json));
    }
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
