import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
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
  static String updatedAt = "updated_at";
  static String createdAt = "created_at";
  static String source = 'source';

  // 公共列名列表
  static final List<String> defaultColumns = [
    NewFriendRepo.uid,
    NewFriendRepo.from,
    NewFriendRepo.to,
    NewFriendRepo.nickname,
    NewFriendRepo.avatar,
    NewFriendRepo.status,
    NewFriendRepo.msg,
    NewFriendRepo.payload,
    NewFriendRepo.updatedAt,
    NewFriendRepo.createdAt,
  ];

  final SqliteService _db = SqliteService.to;

  // 插入一条数据
  Future<NewFriendModel> insert(NewFriendModel obj, {Transaction? txn}) async {
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
      NewFriendRepo.updatedAt: obj.updatedAt,
      NewFriendRepo.createdAt: DateTimeHelper.millisecond(),
    };
    debugPrint("> on NewFriendRepo/insert/1 $insert");

    if (txn != null) {
      await txn.insert(NewFriendRepo.tableName, insert);
    } else {
      await _db.insert(NewFriendRepo.tableName, insert);
    }
    return obj;
  }

  Future<List<NewFriendModel>> listNewFriend(String uid, int limit) async {
    List<Map<String, dynamic>> maps = await _db.query(
      NewFriendRepo.tableName,
      columns: defaultColumns,
      where: '${NewFriendRepo.uid}=?',
      whereArgs: [uid],
      orderBy: "${NewFriendRepo.createdAt} desc",
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
  Future<NewFriendModel?> findByFromTo(
    String from,
    String to, {
    Transaction? txn,
  }) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        NewFriendRepo.tableName,
        columns: defaultColumns,
        where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
        whereArgs: [from, to],
      );
    } else {
      maps = await _db.query(
        NewFriendRepo.tableName,
        columns: defaultColumns,
        where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
        whereArgs: [from, to],
      );
    }
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
  Future<int> update(Map<String, dynamic> json, {Transaction? txn}) async {
    String from = (json[NewFriendRepo.from] ?? json['from'] ?? '').toString();
    String to = (json[NewFriendRepo.to] ?? json['to'] ?? '').toString();
    Map<String, Object?> data = {};
    if (strNoEmpty(json[NewFriendRepo.msg] as String?)) {
      data[NewFriendRepo.msg] = json[NewFriendRepo.msg];
    }
    if (strNoEmpty(json[NewFriendRepo.nickname] as String?)) {
      data[NewFriendRepo.nickname] = json[NewFriendRepo.nickname];
    }
    if (strNoEmpty(json[NewFriendRepo.avatar] as String?)) {
      data[NewFriendRepo.avatar] = json[NewFriendRepo.avatar];
    }

    if ((json[NewFriendRepo.status] as num) >= 0) {
      data[NewFriendRepo.status] = json["status"];
    }
    if (strNoEmpty(json[NewFriendRepo.payload] as String?)) {
      data[NewFriendRepo.payload] = json[NewFriendRepo.payload];
    }

    if (json[NewFriendRepo.updatedAt] != null &&
        (json[NewFriendRepo.updatedAt] as num) >= 0) {
      data[NewFriendRepo.updatedAt] = json[NewFriendRepo.updatedAt];
    }
    if (json[NewFriendRepo.createdAt] != null &&
        (json[NewFriendRepo.createdAt] as num) >= 0) {
      data[NewFriendRepo.createdAt] = json[NewFriendRepo.createdAt];
    }

    if (strNoEmpty(from) && strNoEmpty(to)) {
      data[NewFriendRepo.updatedAt] = DateTimeHelper.millisecond();
      if (txn != null) {
        return await txn.update(
          NewFriendRepo.tableName,
          data,
          where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
          whereArgs: [from, to],
        );
      } else {
        return await _db.update(
          NewFriendRepo.tableName,
          data,
          where: '${NewFriendRepo.from} = ? and ${NewFriendRepo.to} = ?',
          whereArgs: [from, to],
        );
      }
    } else {
      return 0;
    }
  }

  Future<void> save(Map<String, dynamic> json) async {
    String from = (json[NewFriendRepo.from] ?? json['from'] ?? '').toString();
    String to = (json[NewFriendRepo.to] ?? json['to'] ?? '').toString();
    await _db.transaction<void>((txn) async {
      NewFriendModel? old = await findByFromTo(from, to, txn: txn);
      if (old != null) {
        await update(json, txn: txn);
      } else {
        await insert(NewFriendModel.fromJson(json), txn: txn);
      }
    });
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
