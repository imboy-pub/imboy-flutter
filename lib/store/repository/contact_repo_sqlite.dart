import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class ContactRepo {
  static String tableName = 'contact';

  static String userId = 'user_id'; // 联系人所属用户ID
  static String peerId = 'peer_id'; // 联系人用户ID
  static String nickname = 'nickname'; // 联系人昵称
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
  static String categoryId = 'category_id';

  //isFrom 好友关系发起人 1 是  0 否
  static String isFrom = 'is_from';

  final Sqlite _db = Sqlite.instance;

  Future<List<ContactModel>> search({
    required String kwd,
    int limit = 1000,
    int offset = 0,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: [
        ContactRepo.peerId,
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
        ContactRepo.categoryId,
      ],
      where: '${ContactRepo.userId} = ? and ${ContactRepo.isFriend} = ? and ('
          '${ContactRepo.nickname} like "%$kwd%" or ${ContactRepo.remark} like "%$kwd%"'
          ')',
      whereArgs: [UserRepoLocal.to.currentUid, 1],
      orderBy: "update_time desc",
      limit: limit,
      offset: offset,
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
      ContactRepo.userId: UserRepoLocal.to.currentUid,
      ContactRepo.peerId: obj.peerId,
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
          obj.updateTime ?? DateTimeHelper.currentTimeMillis(),
      ContactRepo.isFriend: obj.isFriend,
      ContactRepo.isFrom: obj.isFrom,
      ContactRepo.categoryId: obj.categoryId,
    };
    // debugPrint("> on ContactRepo/insert/1 $insert");

    await _db.insert(ContactRepo.tableName, insert);
    return obj;
  }

  Future<List<Map<String, dynamic>>> selectFriend({
    List<String>? columns,
    int limit = 10000,
    int offset = 0,
  }) async {
    columns ??= [
      ContactRepo.peerId,
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
      ContactRepo.categoryId,
    ];
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: columns,
      where: '${ContactRepo.userId} = ? and ${ContactRepo.isFriend} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, 1],
      orderBy: "${ContactRepo.updateTime} desc",
      limit: limit,
      offset: offset,
    );
    // debugPrint("> on selectFriend ${maps.length}, ${maps.toList().toString()}");
    return maps;
  }

  Future<List<ContactModel>> findFriend({
    List<String>? columns,
    int limit = 10000,
    int offset = 0,
  }) async {
    columns ??= [
      ContactRepo.peerId,
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
      ContactRepo.categoryId,
    ];
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: columns,
      where: '${ContactRepo.userId} = ? and ${ContactRepo.isFriend} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, 1],
      orderBy: "${ContactRepo.nickname} asc",
      limit: limit,
      offset: offset,
    );
    debugPrint("> on findFriend ${maps.length}, ${maps.toList().toString()}");
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
  Future<ContactModel?> findByUid(String uid, {bool autoFetch = true}) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tableName,
      columns: [
        ContactRepo.peerId,
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
        ContactRepo.categoryId,
      ],
      where: '${ContactRepo.userId} = ? and ${ContactRepo.peerId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
    if (maps.isNotEmpty) {
      return ContactModel.fromJson(maps.first);
    }
    if (autoFetch) {
      // 如果没有联系人，同步去取
      return await (ContactProvider()).syncByUid(uid);
    } else {
      return null;
    }
  }

  // 根据ID删除信息
  Future<int> delete(String uid) async {
    return await _db.delete(
      ContactRepo.tableName,
      where: '${ContactRepo.userId} = ? and ${ContactRepo.peerId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json) async {
    String uid = json["id"] ?? (json[ContactRepo.peerId] ?? "");
    Map<String, Object?> data = {};
    if (strNoEmpty(json[ContactRepo.account])) {
      data[ContactRepo.account] = json[ContactRepo.account];
    }
    if (strNoEmpty(json["nickname"])) {
      data[ContactRepo.nickname] = json["nickname"];
    }
    if (strNoEmpty(json["avatar"])) {
      data[ContactRepo.avatar] = json["avatar"];
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

    if (json.containsKey(ContactRepo.status)) {
      data[ContactRepo.status] = json[ContactRepo.status];
    }
    if (json.containsKey(ContactRepo.gender)) {
      data[ContactRepo.gender] = json[ContactRepo.gender];
    }
    if (json.containsKey(ContactRepo.isFrom)) {
      data[ContactRepo.isFrom] = json[ContactRepo.isFrom];
    }
    if (json.containsKey(ContactRepo.isFriend)) {
      data[ContactRepo.isFriend] = json[ContactRepo.isFriend];
    }
    if (json.containsKey(ContactRepo.categoryId)) {
      data[ContactRepo.categoryId] = json[ContactRepo.categoryId];
    }
    // debugPrint("> on ContactRepo/update/1 data: ${data.toString()}");
    if (strNoEmpty(uid)) {
      data[ContactRepo.updateTime] = DateTimeHelper.currentTimeMillis();
      return await _db.update(
        ContactRepo.tableName,
        data,
        where: '${ContactRepo.userId} = ? and ${ContactRepo.peerId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, uid],
      );
    } else {
      return 0;
    }
  }

  /// checkIsFriend = true 的时候，保留旧的 isFriend 值
  Future<ContactModel> save(Map<String, dynamic> json) async {
    // debugPrint("contact_repo_save $checkIsFriend, ${json.toString()}");
    // json['id'] 兼容 api响应的数据
    String uid = json['id'] ?? (json[ContactRepo.peerId] ?? "");
    ContactModel? old = await findByUid(uid, autoFetch: false);
    if (old is ContactModel) {
      await update(json);
      return old;
    } else {
      ContactModel model = ContactModel.fromJson(json);
      await insert(model);
      return model;
    }
  }

  Future<int> deleteByUid(String uid) async {
    return await _db.delete(
      ContactRepo.tableName,
      where: '${ContactRepo.userId} = ? and ${ContactRepo.peerId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, uid],
    );
  }
// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
