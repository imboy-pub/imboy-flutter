import 'dart:convert';

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../component/helper/func.dart';

class ConversationRepo {
  static String tableName = 'conversation';

  static String id = 'id';
  static String userId = 'user_id';
  static String peerId = 'peer_id';
  static String avatar = 'avatar';
  static String title = 'title';
  static String subtitle = 'subtitle';
  static String region = 'region';
  static String sign = 'sign';
  static String lastTime = 'last_time';
  static String lastMsgId = 'last_msg_id';
  static String lastMsgStatus = 'last_msg_status';
  static String unreadNum = 'unread_num';
  static String payload = 'payload';

  // 等价与 msg type: C2C C2G 等等，根据type显示item
  static String type = 'type';

  // msgType 定义见 ConversationModel/content 的定义
  static String msgType = 'msg_type';
  static String isShow = "is_show";

  final SqliteService _db = SqliteService.to;

  // 插入一条数据
  Future<int> insert(ConversationModel obj) async {
    Map<String, dynamic> insert = {
      ConversationRepo.userId: UserRepoLocal.to.currentUid,
      ConversationRepo.peerId: obj.peerId,
      ConversationRepo.avatar: obj.avatar,
      ConversationRepo.title: obj.title,
      ConversationRepo.subtitle: obj.subtitle,
      // 单位毫秒，13位时间戳  1561021145560
      ConversationRepo.lastTime: obj.lastTime,
      ConversationRepo.lastMsgId: obj.lastMsgId,
      ConversationRepo.lastMsgStatus: obj.lastMsgStatus ?? 11,
      ConversationRepo.unreadNum: obj.unreadNum > 0 ? obj.unreadNum : 0,
      ConversationRepo.type: obj.type,
      ConversationRepo.msgType: obj.msgType,
      ConversationRepo.isShow: obj.isShow,
      ConversationRepo.payload: jsonEncode(obj.payload)
    };
    // return lastInsertId;
    return await _db.insert(ConversationRepo.tableName, insert);
  }

  Future<int> updateById(int id, Map<String, dynamic> data) async {
    iPrint(
        "ConversationRepo_updateById $id, ${data.toString()} ${DateTime.now()}");
    if (data.containsKey(ConversationRepo.payload) &&
        data[ConversationRepo.payload] is Map<String, dynamic>) {
      data[ConversationRepo.payload] =
          jsonEncode(data[ConversationRepo.payload]);
    }
    data.remove(ConversationRepo.id);
    return await _db.update(
      ConversationRepo.tableName,
      data,
      where: '${ConversationRepo.id} = ?',
      whereArgs: [id],
    );
  }

  // 更新信息
  Future<int> updateByPeerId(
    String type,
    String peerId,
    Map<String, dynamic> data,
  ) async {
    iPrint("ConversationRepo_updateByPeerId $id, ${data.toString()}");
    data.remove(ConversationRepo.id);
    if (data.containsKey(ConversationRepo.payload) &&
        data[ConversationRepo.payload] is Map<String, dynamic>) {
      data[ConversationRepo.payload] =
          jsonEncode(data[ConversationRepo.payload]);
    }
    return await _db.update(
      ConversationRepo.tableName,
      data,
      where:
          '${ConversationRepo.type} = ? and ${ConversationRepo.userId} = ? and ${ConversationRepo.peerId} = ?',
      whereArgs: [type, UserRepoLocal.to.currentUid, peerId],
    );
  }

  // 存在就更新，不存在就插入
  Future<ConversationModel> save(ConversationModel obj) async {
    iPrint("ConversationRepo_save ${obj.toJson().toString()}");
    ConversationModel? oldObj = await findByPeerId(obj.type, obj.peerId);
    int unreadNumOld = oldObj == null ? 0 : oldObj.unreadNum;
    // obj.isShow = oldObj?.isShow ?? 1;
    obj.unreadNum = obj.unreadNum + unreadNumOld;
    if (oldObj == null) {
      obj.id = await insert(obj);
    } else {
      Map<String, dynamic> data = obj.toJson();
      data.remove(ConversationRepo.id);
      await updateById(oldObj.id, data);
      obj.id = oldObj.id;
    }
    return obj;
  }

  //
  Future<List<ConversationModel>> search(
    String where,
    List<Object?>? whereArgs,
  ) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
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
        ConversationRepo.msgType,
        ConversationRepo.payload,
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
  Future<List<ConversationModel>> list({
    int limit = 2000,
    int offset = 0,
    String type = '',
  }) async {
    String where =
        '${ConversationRepo.userId} = ? and ${ConversationRepo.isShow} = ? and ${ConversationRepo.lastTime} > 0';
    List whereArgs = [UserRepoLocal.to.currentUid, 1];
    if (type.isNotEmpty) {
      where += " and ${ConversationRepo.type} = ?";
      whereArgs.add(type);
    }
    List<Map<String, dynamic>> items = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
        ConversationRepo.userId,
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
        ConversationRepo.payload,
        ConversationRepo.type,
        ConversationRepo.msgType,
        // ConversationRepo.isShow,
      ],
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: "${ConversationRepo.lastTime} DESC",
    );
    iPrint(
        "> on ConversationRepo/all ${items.length} items ${items.toString()}");
    if (items.isEmpty) {
      return [];
    }
    List<ConversationModel> item2 = [];
    for (var e in items) {
      // if(e['t'])
      item2.add(ConversationModel.fromJson(e));
    }
    return item2;
  }

  Future<ConversationModel?> findById(int id) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
        ConversationRepo.userId,
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
        ConversationRepo.payload,
        ConversationRepo.type,
        ConversationRepo.msgType,
        // ConversationRepo.isShow,
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
  Future<ConversationModel?> findByPeerId(String type, String peerId) async {
    List<Map<String, dynamic>> maps = await _db.query(
      ConversationRepo.tableName,
      columns: [
        ConversationRepo.id,
        ConversationRepo.userId,
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
        ConversationRepo.payload,
        ConversationRepo.type,
        ConversationRepo.msgType,
        // ConversationRepo.isShow,
      ],
      where:
          '${ConversationRepo.type} = ? and ${ConversationRepo.userId} = ? and ${ConversationRepo.peerId} = ?',
      whereArgs: [type, UserRepoLocal.to.currentUid, peerId],
    );
    iPrint(
        "> on pageMessages findByPeerId $type, ${UserRepoLocal.to.currentUid}, pid $peerId, ${maps.toString()}");
    if (maps.isNotEmpty) {
      return ConversationModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String type, String peerId) async {
    return await _db.delete(
      ConversationRepo.tableName,
      where:
          '${ConversationRepo.type} = ? and ${ConversationRepo.userId} = ? and ${ConversationRepo.peerId} = ?',
      whereArgs: [type, UserRepoLocal.to.currentUid, peerId],
    );
  }

  // 记得及时关闭数据库，防止内存泄漏
  close() async {
    //await _db.close();
  }
}
