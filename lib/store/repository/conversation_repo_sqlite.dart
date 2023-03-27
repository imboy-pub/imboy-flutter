import 'package:flutter/material.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/conversation_model.dart';

class ConversationRepo {
  static String tableName = 'conversation';

  static String id = 'id';
  static String peerId = 'peer_id';
  static String avatar = 'avatar';
  static String title = 'title';
  static String subtitle = 'subtitle';
  static String region = 'region';
  static String sign = 'sign';
  static String lastTime = 'lasttime';
  static String lastMsgId = 'last_msg_id';
  static String lastMsgStatus = 'last_msg_status';
  static String unreadNum = 'unread_num';

  // 等价与 msg type: C2C C2G 等等，根据type显示item
  static String type = 'type';

  // msgtype 定义见 ConversationModel/content 的定义
  static String msgtype = 'msgtype';
  static String isShow = "is_show";

  final Sqlite _db = Sqlite.instance;

  // 插入一条数据
  Future<int> insert(ConversationModel obj) async {
    Map<String, dynamic> insert = {
      ConversationRepo.peerId: obj.peerId,
      ConversationRepo.avatar: obj.avatar,
      ConversationRepo.title: obj.title,
      ConversationRepo.subtitle: obj.subtitle,
      // 单位毫秒，13位时间戳  1561021145560
      ConversationRepo.lastTime: obj.lastTime ?? DateTime.now().millisecond,
      ConversationRepo.lastMsgId: obj.lastMsgId,
      ConversationRepo.lastMsgStatus: obj.lastMsgStatus ?? 11,
      ConversationRepo.unreadNum: obj.unreadNum > 0 ? obj.unreadNum : 0,
      ConversationRepo.type: obj.type,
      ConversationRepo.msgtype: obj.msgtype,
      ConversationRepo.isShow: obj.isShow,
    };
    int lastInsertId = await _db.insert(ConversationRepo.tableName, insert);
    return lastInsertId;
  }

  Future<int> updateById(int id, Map<String, dynamic> data) async {
    return await _db.update(
      ConversationRepo.tableName,
      data,
      where: '${ConversationRepo.id} = ?',
      whereArgs: [id],
    );
  }

  // 更新信息
  Future<int> updateByPeerId(String peerId, Map<String, dynamic> data) async {
    data.remove(ConversationRepo.id);
    return await _db.update(
      ConversationRepo.tableName,
      data,
      where: '${ConversationRepo.peerId} = ?',
      whereArgs: [peerId],
    );
  }

  // 存在就更新，不存在就插入
  Future<ConversationModel> save(ConversationModel obj) async {
    String where = '${ConversationRepo.peerId} = ?';
    ConversationModel? oldObj = await findByPeerId(obj.peerId);
    int unreadNumOld = oldObj == null ? 0 : oldObj.unreadNum;
    obj.unreadNum = obj.unreadNum + unreadNumOld;
    if (oldObj == null) {
      obj.id = (await maxId()) + 1;
      await insert(obj);
    } else {
      await updateByPeerId(obj.peerId, obj.toJson());
    }
    if (obj.id == 0) {
      int? id = await _db.pluck(
        ConversationRepo.id,
        ConversationRepo.tableName,
        where: where,
        whereArgs: [obj.peerId],
      );
      if (id != null) {
        obj.id = id;
      }
    }
    return obj;
  }

  Future<int> maxId() async {
    int? id = await _db.pluck(
      "max(${ConversationRepo.id}) as maxId",
      ConversationRepo.tableName,
    );
    return id ?? 0;
  }

  //
  Future<List<ConversationModel>> search(
      String where, List<Object?>? whereArgs) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.peerId,
        ConversationRepo.avatar,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.lastTime,
        ConversationRepo.region,
        ConversationRepo.sign,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.unreadNum,
        ConversationRepo.type,
        ConversationRepo.msgtype,
      ],
      where: where,
      whereArgs: whereArgs,
      orderBy: "${ConversationRepo.lastTime} DESC",
    );

    if (maps.isEmpty) {
      return [];
    }

    List<ConversationModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(ConversationModel.fromJson(maps[i]));
    }
    return items;
  }

  //
  Future<List<ConversationModel>> list({limit = 2000}) async {
    List<Map<String, dynamic>> items = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
        ConversationRepo.peerId,
        ConversationRepo.avatar,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.region,
        ConversationRepo.sign,
        ConversationRepo.lastTime,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.unreadNum,
        ConversationRepo.type,
        ConversationRepo.msgtype,
      ],
      where: '${ConversationRepo.isShow} = ?',
      whereArgs: [1],
      orderBy: "${ConversationRepo.lastTime} DESC",
    );
    debugPrint(
        "> on ConversationRepo/all ${items.length} items ${items.toString()}");
    if (items.isEmpty) {
      return [];
    }
    List<ConversationModel> item2 = [];
    for (var element in items) {
      item2.add(ConversationModel.fromJson(element));
    }
    return item2;
  }

  Future<ConversationModel?> findById(int id) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
        ConversationRepo.peerId,
        ConversationRepo.avatar,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.region,
        ConversationRepo.sign,
        ConversationRepo.lastTime,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.unreadNum,
        ConversationRepo.type,
        ConversationRepo.msgtype,
      ],
      where: 'id=?',
      whereArgs: [id],
      orderBy: "${ConversationRepo.lastTime} DESC",
    );

    if (maps.isNotEmpty) {
      return ConversationModel.fromJson(maps.first);
    }
    return null;
  }

  //
  Future<ConversationModel?> findByPeerId(String peerId) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
        ConversationRepo.peerId,
        ConversationRepo.title,
        ConversationRepo.subtitle,
        ConversationRepo.region,
        ConversationRepo.sign,
        ConversationRepo.avatar,
        ConversationRepo.lastTime,
        ConversationRepo.lastMsgId,
        ConversationRepo.lastMsgStatus,
        ConversationRepo.msgtype,
        ConversationRepo.unreadNum,
      ],
      where: '${ConversationRepo.peerId} = ?',
      whereArgs: [peerId],
    );
    if (maps.isNotEmpty) {
      return ConversationModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String peerId) async {
    return await _db.delete(
      ConversationRepo.tableName,
      where: '${ConversationRepo.peerId} = ?',
      whereArgs: [peerId],
    );
  }

  // 记得及时关闭数据库，防止内存泄漏
  close() async {
    //await _db.close();
  }
}
