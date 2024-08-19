import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MessageRepo {
  static String c2cTable = 'message';
  static String c2gTable = 'group_message';
  static String c2sTable = 'c2s_message';
  static String s2cTable = 's2c_message';

  static String autoId = 'auto_id';
  static String id = 'id'; // message_id

  // C2C C2G C2C_REVOKE_ACK C2G_REVOKE_ACK
  static String type = 'type';
  static String from = 'from_id';
  static String to = 'to_id';
  static String payload = 'payload';
  static String createdAt = 'created_at';

  // varchar(80)
  static String conversationUk3 = 'conversation_uk3';
  static String status = 'status';

  // from id is author bool true | false
  static String isAuthor = 'is_author';
  static String topicId = 'topic_id';

  final SqliteService _db = SqliteService.to;

  final String tableName;

  MessageRepo({required this.tableName});

  static String getTableName(String type) {
    String tb = '';
    // iPrint("> rtc msg S_RECEIVED:$res");
    switch (type.toUpperCase()) {
      case 'C2C':
        tb = MessageRepo.c2cTable;
        break;
      case 'C2G':
        tb = MessageRepo.c2gTable;
        break;
      case 'C2S':
        tb = MessageRepo.c2sTable;
        break;
      case 'S2C':
        tb = MessageRepo.s2cTable;
        break;

      //
      case 'C2C_SERVER_ACK':
        tb = MessageRepo.c2cTable;
        break;
      case 'C2G_SERVER_ACK':
        tb = MessageRepo.c2gTable;
        break;
      case 'C2S_SERVER_ACK':
        tb = MessageRepo.c2sTable;
        break;
      case 'S2C_SERVER_ACK':
        tb = MessageRepo.s2cTable;
        break;

      //
      case 'C2C_REVOKE':
        tb = MessageRepo.c2cTable;
        break;
      case 'C2G_REVOKE':
        tb = MessageRepo.c2gTable;
        break;

      case 'C2C_REVOKE_ACK':
        tb = MessageRepo.c2cTable;
        break;
      case 'C2G_REVOKE_ACK':
        tb = MessageRepo.c2gTable;
        break;
    }
    return tb;
  }

  // 插入一条数据
  Future<MessageModel> insert(MessageModel msg) async {
    int? count = await _db.count(
      tableName,
      where: "id=?",
      whereArgs: [MessageRepo.id],
    );
    if (count == 0) {
      Map<String, dynamic> insert = {
        'auto_id': null,
        MessageRepo.id: msg.id,
        MessageRepo.type: msg.type,
        MessageRepo.from: msg.fromId,
        MessageRepo.to: msg.toId,
        MessageRepo.payload: json.encode(msg.payload),
        MessageRepo.createdAt: msg.createdAt,
        MessageRepo.isAuthor: msg.isAuthor,
        MessageRepo.topicId: msg.topicId,
        MessageRepo.conversationUk3: msg.conversationUk3,
        MessageRepo.status: msg.status,
      };
      debugPrint("> on MessgeMode/insert tb $tableName : $insert");
      await _db.insert(tableName, insert);
    } else {
      debugPrint("> on MessgeMode/insert count $count : $insert");
    }
    return msg;
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> data) async {
    if (data.containsKey(MessageRepo.payload) &&
        data[MessageRepo.payload] is Map<String, dynamic>) {
      data[MessageRepo.payload] = jsonEncode(data[MessageRepo.payload]);
    }
    return await _db.update(
      tableName,
      data,
      where: '${MessageRepo.id} = ?',
      whereArgs: [data[MessageRepo.id]],
    );
  }

  // 存在就更新，不存在就插入
  Future<int?> save(MessageModel obj) async {
    int? count = await _db.count(
      tableName,
      where: '${MessageRepo.id} = ?',
      whereArgs: [obj.id],
    );
    if (count == null || count == 0) {
      await insert(obj);
    } else {
      Map<String, dynamic> data = obj.toJson();
      data.remove(MessageRepo.autoId);
      await update(data);
    }
    // debugPrint("> on MessageRepo/save count:$count; id: $obj.id");
    return count;
  }

  Future<List<MessageModel>> pageForConversation(
    ConversationModel obj,
    int nextAutoId,
    int size,
  ) async {
    String where =
        "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} < ?";
    List args = [obj.uk3, nextAutoId];
    if (nextAutoId <= 0) {
      where = "${MessageRepo.conversationUk3} = ?";
      args = [obj.uk3];
    }
    List<Map<String, dynamic>> maps = await _db.query(
      tableName,
      columns: [
        MessageRepo.autoId,
        MessageRepo.id,
        MessageRepo.type,
        MessageRepo.from,
        MessageRepo.to,
        MessageRepo.payload,
        MessageRepo.createdAt,
        MessageRepo.isAuthor,
        MessageRepo.topicId,
        MessageRepo.topicId,
        MessageRepo.status,
        MessageRepo.conversationUk3,
      ],
      where: where,
      whereArgs: args,
      orderBy: "${MessageRepo.autoId} DESC",
      offset: 0,
      limit: size,
    );
    if (maps.isEmpty) {
      return [];
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      // 使得 msg asc 排序
      int j = maps.length - i - 1;
      messages.add(MessageModel.fromJson(maps[j]));
    }
    return messages;
  }

  Future<List<MessageModel>> page({
    required int page,
    required int size,
    String? kwd,
    String? conversationUk3,
    String? orderBy,
  }) async {
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    String where = "1=1";
    List<Object?> whereArgs = [];
    if (strNoEmpty(kwd)) {
      kwd = kwd!.trim();
      // where = "$where and (${MessageRepo.payload} like '%$kwd%')";
      where =
          "$where AND (json_extract(payload, '\$.text') LIKE '%$kwd%' or json_extract(payload, '\$.quote_text') LIKE '%$kwd%' or json_extract(payload, '\$.title') LIKE '%$kwd%')";
    }
    if (strNoEmpty(conversationUk3)) {
      where = "$where and ${MessageRepo.conversationUk3}=?";
      whereArgs.add(conversationUk3);
    }
    iPrint("searchLeading_tag where $where");
    List<Map<String, dynamic>> maps = await _db.query(
      tableName,
      columns: [
        MessageRepo.autoId,
        MessageRepo.id,
        MessageRepo.type,
        MessageRepo.from,
        MessageRepo.to,
        MessageRepo.payload,
        MessageRepo.createdAt,
        MessageRepo.isAuthor,
        MessageRepo.topicId,
        MessageRepo.status,
        MessageRepo.conversationUk3,
      ],
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? "${MessageRepo.createdAt} desc",
      limit: size,
      offset: offset,
    );
    debugPrint(
        "> on MessageRepo_page tb $tableName, $conversationUk3, kwd $kwd, page $page, len ${maps.length}; ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      messages.add(MessageModel.fromJson(maps[i]));
    }
    return messages;
  }

  //
  Future<MessageModel?> find(String id) async {
    List<Map<String, dynamic>> maps = await _db.query(
      tableName,
      columns: [
        MessageRepo.autoId,
        MessageRepo.id,
        MessageRepo.type,
        MessageRepo.from,
        MessageRepo.to,
        MessageRepo.payload,
        MessageRepo.createdAt,
        MessageRepo.isAuthor,
        MessageRepo.topicId,
        MessageRepo.conversationUk3,
        MessageRepo.status,
      ],
      where: '${MessageRepo.id} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.id} = ?',
      whereArgs: [id],
    );
  }

  // 根据UID删除信息
  Future<int> deleteByUid(String uid) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.from} = ? or ${MessageRepo.to} = ?',
      whereArgs: [uid, uid],
    );
  }

  Future<int> deleteByConversationId(String uk3) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.conversationUk3} = ?',
      whereArgs: [uk3],
    );
  }

  Future<MessageModel?> lastMsg() async {
    List<Map<String, dynamic>> maps = await _db.query(
      tableName,
      columns: [
        MessageRepo.autoId,
        MessageRepo.id,
        MessageRepo.type,
        MessageRepo.from,
        MessageRepo.to,
        MessageRepo.payload,
        MessageRepo.createdAt,
        MessageRepo.isAuthor,
        MessageRepo.topicId,
        MessageRepo.conversationUk3,
        MessageRepo.status,
      ],
      where: '${MessageRepo.from} = ?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${MessageRepo.createdAt} desc",
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    }
    return null;
  }
// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
