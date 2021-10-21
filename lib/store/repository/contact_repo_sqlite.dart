import 'package:flutter/material.dart';
import 'package:imboy/helper/sqflite.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';

class ContactRepo {
  static String tablename = 'contact';

  static String cuid = 'cuid';
  static String uid = 'uid';
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String account = 'account';
  static String status = 'status';
  static String remark = 'remark';
  static String area = 'area';
  static String sign = 'sign';
  static String updateTime = "update_time";

  Sqlite _db = Sqlite.instance;

  // 插入一条数据
  Future<ContactModel> insert(ContactModel obj) async {
    String cuid = UserRepoSP.user.currentUid;
    Map<String, dynamic> insert = {
      'cuid': cuid,
      'uid': obj.uid,
      'nickname': obj.nickname,
      'avatar': obj.avatar,
      'account': obj.account,
      'status': obj.status,
      'remark': obj.remark ?? '',
      'area': obj.area ?? '',
      'sign': obj.sign ?? '',
      // 单位毫秒，13位时间戳  1561021145560
      'update_time': obj.updateTime ?? DateTime.now().millisecondsSinceEpoch,
    };
    await _db.insert(ContactRepo.tablename, insert);
    return obj;
  }

  Future<List<ContactModel>> findByCuid(String cuid) async {
    print(">>>>> on findByCuid {$cuid}");
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tablename,
      columns: [
        ContactRepo.uid,
        ContactRepo.nickname,
        ContactRepo.avatar,
        ContactRepo.account,
        ContactRepo.status,
        ContactRepo.remark,
        ContactRepo.area,
        ContactRepo.sign,
        ContactRepo.updateTime,
      ],
      where: 'cuid=?',
      whereArgs: <String>[cuid],
      orderBy: "update_time desc",
    );
    debugPrint(">>>>> on ContactRepo/findByCuid maps: " + maps.toString());
    if (maps.length == 0) {
      return [];
    }

    List<ContactModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(ContactModel.fromMap(maps[i]));
    }
    return items;
  }

  //
  Future<ContactModel?> find(String uid) async {
    String cuid = UserRepoSP.user.currentUid;
    List<Map<String, dynamic>> maps = await _db.query(
      ContactRepo.tablename,
      columns: [
        ContactRepo.uid,
        ContactRepo.nickname,
        ContactRepo.avatar,
        ContactRepo.account,
        ContactRepo.status,
        ContactRepo.remark,
        ContactRepo.area,
        ContactRepo.sign,
      ],
      where: '${ContactRepo.cuid} = ? and ${ContactRepo.uid} = ?',
      whereArgs: [cuid, uid],
    );
    if (maps.length > 0) {
      return ContactModel.fromMap(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    String cuid = UserRepoSP.user.currentUid;
    return await _db.delete(
      ContactRepo.tablename,
      where: '${ContactRepo.cuid} = ? and ${ContactRepo.uid} = ?',
      whereArgs: [cuid, id],
    );
  }

  // 更新信息
  Future<int> update(ContactModel obj) async {
    String cuid = UserRepoSP.user.currentUid;
    return await _db.update(
      ContactRepo.tablename,
      obj.toMap(),
      where: '${ContactRepo.cuid} = ? and ${ContactRepo.uid} = ?',
      whereArgs: [cuid, obj.uid],
    );
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
