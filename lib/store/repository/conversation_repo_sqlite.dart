import 'package:flutter/material.dart';
import 'package:imboy/helper/sqflite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class ConversationRepo {
  static String tablename = 'conversation';

  static String id = 'id';
  static String cuid = 'cuid';
  static String typeId = 'type_id';
  static String avatar = 'avatar';
  static String title = 'title';
  static String subtitle = 'subtitle';
  static String lasttime = 'lasttime';
  static String lastMsgId = 'last_msg_id';
  static String lastMsgStatus = 'last_msg_status';
  static String unreadNum = 'unread_num';
  // 等价与 msg type: C2C C2G 等等，根据type显示item
  static String type = 'type';
  // enum MessageType { custom, file, image, text, unsupported }
  static String msgtype = 'msgtype';
  static String isShow = "is_show";

  Sqlite _db = Sqlite.instance;

  // 插入一条数据
  Future<int> insert(ConversationModel obj) async {
    Map<String, dynamic> insert = {
      'id': obj.id,
      'cuid': UserRepoLocal.to.currentUid,
      'type_id': obj.typeId,
      'avatar': obj.avatar,
      'title': obj.title,
      'subtitle': obj.subtitle,
      // 单位毫秒，13位时间戳  1561021145560
      'lasttime': obj.lasttime ?? DateTime.now().millisecond,
      'last_msg_id': obj.lastMsgId,
      'last_msg_status': obj.lastMsgStatus ?? 11,
      'unread_num': obj.unreadNum > 0 ? obj.unreadNum : 0,
      'type': obj.type,
      'msgtype': obj.msgtype,
      'is_show': obj.isShow,
    };
    int lastInsertId = await _db.insert(ConversationRepo.tablename, insert);
    return lastInsertId;
  }

  Future<int> updateById(int id, Map<String, dynamic> data) async {
    return await _db.update(
      ConversationRepo.tablename,
      data,
      where: '${ConversationRepo.id} = ?',
      whereArgs: [id],
    );
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> data) async {
    data.remove(ConversationRepo.id);
    return await _db.update(
      ConversationRepo.tablename,
      data,
      where: '${ConversationRepo.cuid} = ? AND ${ConversationRepo.typeId} = ?',
      whereArgs: [data['cuid'], data['type_id']],
    );
  }

  // 存在就更新，不存在就插入
  Future<ConversationModel> save(String cuid, ConversationModel obj) async {
    String where =
        '${ConversationRepo.cuid} = ? AND ${ConversationRepo.typeId} = ?';
    ConversationModel? oldObj = await this.find(obj.typeId);
    int unreadNumOld = oldObj == null ? 0 : oldObj.unreadNum;
    obj.unreadNum = obj.unreadNum + unreadNumOld;
    if (oldObj == null) {
      obj.id = (await maxId()) + 1;
      insert(obj);
    } else {
      update(obj.toJson());
    }
    int? id = await _db.pluck(
      ConversationRepo.id,
      ConversationRepo.tablename,
      where: where,
      whereArgs: [cuid, obj.typeId],
    );
    obj.id = id!;
    return obj;
  }

  Future<int> maxId() async {
    int? id = await _db.pluck(
      "max(${ConversationRepo.id}) as maxId",
      ConversationRepo.tablename,
    );
    return id == null ? 0 : id;
  }

  //
  Future<List<ConversationModel>> search(
      String where, List<Object?>? whereArgs) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tablename,
      columns: [
        ConversationRepo.typeId,
        ConversationRepo.avatar,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.lasttime,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.unreadNum,
        ConversationRepo.type,
        ConversationRepo.msgtype,
      ],
      where: 'cuid=${UserRepoLocal.to.currentUid} AND ' + where,
      whereArgs: whereArgs,
      orderBy: "${ConversationRepo.lasttime} DESC",
    );

    if (maps.length == 0) {
      return [];
    }

    List<ConversationModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(ConversationModel.fromJson(maps[i]));
    }
    return items;
  }

  //
  Future<Map<String, ConversationModel>> findByCuid(String cuid) async {
    print(">>>>> on ConversationRepo/findByCuid cuid {$cuid}");
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tablename,
      columns: [
        ConversationRepo.id,
        ConversationRepo.cuid,
        ConversationRepo.typeId,
        ConversationRepo.avatar,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.lasttime,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.unreadNum,
        ConversationRepo.type,
        ConversationRepo.msgtype,
      ],
      where: 'cuid=? AND ${ConversationRepo.isShow} = ?',
      whereArgs: [cuid, 1],
      // where: 'cuid=?',
      // whereArgs: [cuid],
      orderBy: "${ConversationRepo.lasttime} DESC",
    );
    debugPrint(">>>>> on ConversationRepo/findByCuid maps " + maps.toString());
    if (maps.length == 0) {
      return {};
    }

    Map<String, ConversationModel> items = {};
    for (int i = 0; i < maps.length; i++) {
      ConversationModel item = ConversationModel.fromJson(maps[i]);
      items[item.typeId] = item;
    }
    return items;
  }

  Future<ConversationModel?> findById(int id) async {
    print(">>>>> on ConversationRepo/findById id {$id}");
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tablename,
      columns: [
        ConversationRepo.id,
        ConversationRepo.cuid,
        ConversationRepo.typeId,
        ConversationRepo.avatar,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.lasttime,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.unreadNum,
        ConversationRepo.type,
        ConversationRepo.msgtype,
      ],
      where: 'id=?',
      whereArgs: [id],
      // where: 'cuid=?',
      // whereArgs: [cuid],
      orderBy: "${ConversationRepo.lasttime} DESC",
    );
    debugPrint(">>>>> on ConversationRepo/findByCuid maps " + maps.toString());

    if (maps.length > 0) {
      return ConversationModel.fromJson(maps.first);
    }
    return null;
  }

  //
  Future<ConversationModel?> find(String typeId) async {
    List<Map<String, dynamic>> maps = await _db.query(
        ConversationRepo.tablename,
        columns: [
          ConversationRepo.id,
          ConversationRepo.typeId,
          ConversationRepo.title,
          ConversationRepo.subtitle,
          ConversationRepo.avatar,
          ConversationRepo.lasttime,
          ConversationRepo.lastMsgId,
          ConversationRepo.lastMsgStatus,
          ConversationRepo.msgtype,
          ConversationRepo.unreadNum,
        ],
        where:
            '${ConversationRepo.cuid} = ? AND ${ConversationRepo.typeId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, typeId]);
    if (maps.length > 0) {
      return ConversationModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String typeId) async {
    return await _db.delete(ConversationRepo.tablename,
        where:
            '${ConversationRepo.cuid} = ? AND ${ConversationRepo.typeId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, typeId]);
  }

  // 记得及时关闭数据库，防止内存泄漏
  close() async {
    //await _db.close();
  }
}
