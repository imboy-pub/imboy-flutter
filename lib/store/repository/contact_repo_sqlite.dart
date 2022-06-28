import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/contact_model.dart';

class ContactRepo {
  static String tablename = 'contact';

  static String uid = 'uid';
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String gender = 'gender';
  static String account = 'account';
  static String status = 'status';
  static String remark = 'remark';
  static String region = 'region';
  static String sign = 'sign';
  static String updateTime = "update_time";
  static String isFriend = 'is_friend';

  final Sqlite _db = Sqlite.instance;

  // 插入一条数据
  Future<ContactModel> insert(ContactModel obj) async {
    Map<String, dynamic> insert = {
      'uid': obj.uid,
      'nickname': obj.nickname,
      'avatar': obj.avatar,
      'account': obj.account,
      'status': obj.status,
      'remark': obj.remark,
      'gender': obj.gender,
      'region': obj.region,
      'sign': obj.sign,
      // 单位毫秒，13位时间戳  1561021145560
      'update_time': obj.updateTime ?? DateTime.now().millisecondsSinceEpoch,
      'is_friend': obj.isFriend,
    };
    debugPrint(">>> on ContactRepo/insert/1 " + insert.toString());

    await _db.insert(ContactRepo.tablename, insert);
    return obj;
  }

  Future<List<ContactModel>> findFriend() async {
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tablename,
      columns: [
        ContactRepo.uid,
        ContactRepo.nickname,
        ContactRepo.avatar,
        ContactRepo.account,
        ContactRepo.status,
        ContactRepo.remark,
        ContactRepo.region,
        ContactRepo.sign,
        ContactRepo.gender,
        ContactRepo.isFriend,
      ],
      where: '${ContactRepo.isFriend}=?',
      whereArgs: [1],
      orderBy: "update_time desc",
      limit: 10000,
    );
    // debugPrint(">>> on findFriend ${maps.length}, ${maps.toList().toString()}");
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
      ContactRepo.tablename,
      columns: [
        ContactRepo.uid,
        ContactRepo.nickname,
        ContactRepo.avatar,
        ContactRepo.account,
        ContactRepo.status,
        ContactRepo.remark,
        ContactRepo.region,
        ContactRepo.sign,
        ContactRepo.gender,
        ContactRepo.updateTime,
        ContactRepo.isFriend,
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
      ContactRepo.tablename,
      where: '${ContactRepo.uid} = ?',
      whereArgs: [id],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json["uid"] ?? "");
    Map<String, Object?> data = {};
    if (strNoEmpty(json["account"])) {
      data["account"] = json["account"];
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
    if (strNoEmpty(json["remark"])) {
      data["remark"] = json["remark"];
    }
    if (strNoEmpty(json["region"])) {
      data["region"] = json["region"];
    }
    if (strNoEmpty(json["sign"])) {
      data["sign"] = json["sign"];
    }
    if (json["gender"] > 0) {
      data["gender"] = json["gender"];
    }

    debugPrint(">>> on ContactRepo/update/1 data: ${data.toString()}");
    if (strNoEmpty(uid)) {
      data["is_friend"] = json["is_friend"] ?? 0;
      data["update_time"] = DateTimeHelper.currentTimeMillis();
      return await _db.update(
        ContactRepo.tablename,
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
      update(json);
    } else {
      insert(ContactModel.fromJson(json));
    }
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
