import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/contact_model.dart';

class ContactRepo {
  static String tableName = 'contact';

  static String uid = 'uid';
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String gender = 'gender';
  static String account = 'account';
  static String status = 'status';
  static String remark = 'remark';
  static String region = 'region';
  static String sign = 'sign';
  static String source = 'source';
  static String updateTime = "update_time";
  static String isFriend = 'is_friend';

  //isFrom 好友关系发起人
  static String isFrom = 'is_from';

  final Sqlite _db = Sqlite.instance;

  Future<List<ContactModel>> search({
    required String kwd,
    int limit = 1000,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: [
        ContactRepo.uid,
        ContactRepo.nickname,
        ContactRepo.avatar,
        ContactRepo.account,
        ContactRepo.status,
        ContactRepo.remark,
        ContactRepo.region,
        ContactRepo.sign,
        ContactRepo.source,
        ContactRepo.gender,
        ContactRepo.isFriend,
        ContactRepo.isFrom,
      ],
      where: '${ContactRepo.isFriend}=? and ('
          '${ContactRepo.nickname} like "%$kwd%" or ${ContactRepo.remark} like "%$kwd%"'
          ')',
      whereArgs: [1],
      orderBy: "update_time desc",
      limit: limit,
    );
    debugPrint("> on search ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<ContactModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(ContactModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<ContactModel> insert(ContactModel obj) async {
    Map<String, dynamic> insert = {
      ContactRepo.uid: obj.uid,
      ContactRepo.nickname: obj.nickname,
      ContactRepo.avatar: obj.avatar,
      ContactRepo.account: obj.account,
      ContactRepo.status: obj.status,
      ContactRepo.remark: obj.remark,
      ContactRepo.gender: obj.gender,
      ContactRepo.region: obj.region,
      ContactRepo.sign: obj.sign,
      ContactRepo.source: obj.source,
      // 单位毫秒，13位时间戳  1561021145560
      ContactRepo.updateTime:
          obj.updateTime ?? DateTime.now().millisecondsSinceEpoch,
      ContactRepo.isFriend: obj.isFriend,
      ContactRepo.isFrom: obj.isFrom,
    };
    debugPrint(">>> on ContactRepo/insert/1 $insert");

    await _db.insert(ContactRepo.tableName, insert);
    return obj;
  }

  Future<List<Map<String, dynamic>>> selectFriend(
      {List<String>? columns}) async {
    columns ??= [
      ContactRepo.uid,
      ContactRepo.nickname,
      ContactRepo.avatar,
      ContactRepo.account,
      ContactRepo.status,
      ContactRepo.remark,
      ContactRepo.region,
      ContactRepo.sign,
      ContactRepo.source,
      ContactRepo.gender,
      ContactRepo.isFriend,
      ContactRepo.isFrom,
    ];
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: columns,
      where: '${ContactRepo.isFriend}=?',
      whereArgs: [1],
      orderBy: "update_time desc",
      limit: 10000,
    );
    debugPrint("> on selectFriend ${maps.length}, ${maps.toList().toString()}");
    return maps;
  }

  Future<List<ContactModel>> findFriend({List<String>? columns}) async {
    columns ??= [
      ContactRepo.uid,
      ContactRepo.nickname,
      ContactRepo.avatar,
      ContactRepo.account,
      ContactRepo.status,
      ContactRepo.remark,
      ContactRepo.region,
      ContactRepo.sign,
      ContactRepo.source,
      ContactRepo.gender,
      ContactRepo.isFriend,
      ContactRepo.isFrom,
    ];
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: columns,
      where: '${ContactRepo.isFriend}=?',
      whereArgs: [1],
      orderBy: "update_time desc",
      limit: 10000,
    );
    // debugPrint("> on findFriend ${maps.length}, ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<ContactModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(ContactModel.fromJson(maps[i]));
    }
    return items;
  }

  //
  Future<ContactModel?> findByUid(String uid) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: [
        ContactRepo.uid,
        ContactRepo.nickname,
        ContactRepo.avatar,
        ContactRepo.account,
        ContactRepo.status,
        ContactRepo.remark,
        ContactRepo.region,
        ContactRepo.sign,
        ContactRepo.source,
        ContactRepo.gender,
        ContactRepo.updateTime,
        ContactRepo.isFriend,
        ContactRepo.isFrom,
      ],
      where: '${ContactRepo.uid} = ?',
      whereArgs: [uid],
    );
    if (maps.isNotEmpty) {
      return ContactModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    return await _db.delete(
      ContactRepo.tableName,
      where: '${ContactRepo.uid} = ?',
      whereArgs: [id],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json["uid"] ?? "");
    Map<String, Object?> data = {};
    if (strNoEmpty(json["account"])) {
      data[ContactRepo.account] = json["account"];
    }
    if (strNoEmpty(json["nickname"])) {
      data[ContactRepo.nickname] = json["nickname"];
    }
    if (strNoEmpty(json["avatar"] ?? "")) {
      data[ContactRepo.avatar] = json["avatar"];
    }

    if (strNoEmpty(json["status"].toString())) {
      data[ContactRepo.status] = json["status"].toString();
    }
    if (strNoEmpty(json["remark"])) {
      data[ContactRepo.remark] = json["remark"];
    }
    if (strNoEmpty(json["region"])) {
      data[ContactRepo.region] = json["region"];
    }
    if (strNoEmpty(json["sign"])) {
      data[ContactRepo.sign] = json["sign"];
    }
    if (strNoEmpty(json["source"])) {
      data[ContactRepo.source] = json["source"];
    }
    if (json["gender"] > 0) {
      data[ContactRepo.gender] = json["gender"];
    }

    debugPrint(">>> on ContactRepo/update/1 data: ${data.toString()}");
    if (strNoEmpty(uid)) {
      data[ContactRepo.isFrom] = json[ContactRepo.isFrom] ?? 0;
      data[ContactRepo.isFriend] = json[ContactRepo.isFriend] ?? 0;
      data[ContactRepo.updateTime] = DateTimeHelper.currentTimeMillis();
      return await _db.update(
        ContactRepo.tableName,
        data,
        where: '${ContactRepo.uid} = ?',
        whereArgs: [uid],
      );
    } else {
      return 0;
    }
  }

  void save(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json["uid"] ?? "");
    ContactModel? old = await findByUid(uid);
    if (old != null || old is ContactModel) {
      await update(json);
    } else {
      await insert(ContactModel.fromJson(json));
    }
  }

  Future<int> deleteForUid(String uid) async {
    return await _db.delete(
      ContactRepo.tableName,
      where: '${ContactRepo.uid} = ?',
      whereArgs: [uid],
    );
  }
// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
