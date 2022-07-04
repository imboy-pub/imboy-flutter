import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class NewFriendRepo {
  static String tablename = 'new_friend';

  static String uid = 'uid'; // 当前用户ID
  static String from = 'fromid'; // 发送中ID
  static String to = 'toid'; // 接收者ID
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String msg = 'msg';
  // 已添加 已过期 待验证 接受
  static String status = 'status';

  static String payload = 'payload';
  static String updateTime = "update_time";
  static String createTime = "create_time";

  final Sqlite _db = Sqlite.instance;

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
      NewFriendRepo.updateTime:
          obj.updateTime ?? DateTime.now().millisecondsSinceEpoch,
      NewFriendRepo.createTime: DateTime.now().millisecondsSinceEpoch,
    };
    debugPrint(">>> on NewFriendRepo/insert/1 " + insert.toString());

    await _db.insert(NewFriendRepo.tablename, insert);
    return obj;
  }

  Future<List<NewFriendModel>> listNewFriend(String uid, int limit) async {
    List<Map<String, dynamic>> maps = await _db.query(
      NewFriendRepo.tablename,
      columns: [
        NewFriendRepo.uid,
        NewFriendRepo.from,
        NewFriendRepo.to,
        NewFriendRepo.nickname,
        NewFriendRepo.avatar,
        NewFriendRepo.status,
        NewFriendRepo.msg,
        NewFriendRepo.payload,
        NewFriendRepo.updateTime,
        NewFriendRepo.createTime,
      ],
      where: '${NewFriendRepo.uid}=?',
      whereArgs: [uid],
      orderBy: "create_time desc",
      limit: limit,
    );
    // debugPrint(">>> on findFriend ${maps.length}, ${maps.toList().toString()}");
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
      NewFriendRepo.tablename,
      columns: [
        NewFriendRepo.uid,
        NewFriendRepo.from,
        NewFriendRepo.to,
        NewFriendRepo.nickname,
        NewFriendRepo.avatar,
        NewFriendRepo.status,
        NewFriendRepo.msg,
        NewFriendRepo.payload,
        NewFriendRepo.updateTime,
        NewFriendRepo.createTime,
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
      NewFriendRepo.tablename,
      where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
      whereArgs: [from, to],
    );
  }

  Future<int> deleteForUid(String uid) async {
    return await _db.delete(
      NewFriendRepo.tablename,
      where: '${NewFriendRepo.from} = ? or ${NewFriendRepo.to} = ?',
      whereArgs: [uid, uid],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String from = json["from"];
    String to = json["to"];
    Map<String, Object?> data = {};
    if (strNoEmpty(json["msg"])) {
      data["msg"] = json["msg"];
    }
    if (strNoEmpty(json["remark"])) {
      data["remark"] = json["remark"];
    }
    if (strNoEmpty(json["nickname"])) {
      data["nickname"] = json["nickname"];
    }
    if (strNoEmpty(json["avatar"] ?? "")) {
      data["avatar"] = json["avatar"];
    }

    if (json["status"] >= 0) {
      data["status"] = json["status"];
    }
    if (strNoEmpty(json["payload"])) {
      data["payload"] = json["payload"];
    }

    if (json["update_time"] != null && json["update_time"] >= 0) {
      data["update_time"] = json["update_time"];
    }
    if (json["create_time"] != null && json["create_time"] >= 0) {
      data["create_time"] = json["create_time"];
    }

    if (strNoEmpty(from) && strNoEmpty(to)) {
      data["update_time"] = DateTimeHelper.currentTimeMillis();
      return await _db.update(
        NewFriendRepo.tablename,
        data,
        where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
        whereArgs: [from, to],
      );
    } else {
      return 0;
    }
  }

  void save(Map<String, dynamic> json) async {
    String from = json["from"] ?? "";
    String to = json["to"] ?? "";
    NewFriendModel? old = await findByFromTo(from, to);
    // debugPrint(">>> on new_friend save: ${old.toString()}");
    if (old != null || old is NewFriendModel) {
      update(json);
    } else {
      insert(NewFriendModel.fromJson(json));
    }
  }

  Future<int?> countStatus(int status, String to) async {
    return await _db.count(
      NewFriendRepo.tablename,
      where: '${NewFriendRepo.status} = ? and ${NewFriendRepo.to} = ?',
      whereArgs: [status, to],
    );
  }
  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
