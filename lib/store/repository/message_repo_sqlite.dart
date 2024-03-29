import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MessageRepo {
  static String c2cTable = 'message';
  static String c2gTable = 'group_message';

  static String autoId = 'auto_id';
  static String id = 'id'; // message_id

  // C2C C2G C2C_REVOKE_ACK C2G_REVOKE_ACK
  static String type = 'type';
  static String from = 'from_id';
  static String to = 'to_id';
  static String payload = 'payload';
  static String createdAt = 'created_at';
  //
  static String conversationId = 'conversation_id';
  static String status = 'status';
  // from id is author bool true | false
  static String isAuthor = 'is_author';

  final SqliteService _db = SqliteService.to;

  final String tableName;

  MessageRepo({required this.tableName});

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
        MessageRepo.conversationId: msg.conversationId,
        MessageRepo.status: msg.status,
      };
      debugPrint("> on MessgeMode/insert $insert");
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
    int conversationId,
    int nextAutoId,
    int size,
  ) async {
    String where =
        "${MessageRepo.conversationId} = ? AND ${MessageRepo.autoId} < ?";
    List<int> args = [conversationId, nextAutoId];
    if (nextAutoId <= 0) {
      where = "${MessageRepo.conversationId} = ?";
      args = [conversationId];
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
        MessageRepo.status,
        MessageRepo.conversationId,
      ],
      where: where,
      whereArgs: args,
      orderBy: "${MessageRepo.autoId} DESC",
      offset: 0,
      limit: size,
    );
    debugPrint(
        "findByConversation $conversationId, where $where, ${maps.length}; ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      int j = maps.length - i - 1;
      messages.add(MessageModel.fromJson(maps[j]));
    }
    return messages;
  }

  Future<List<MessageModel>> findByConversation(
    int conversationId,
    int page,
    int size,
  ) async {
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
        MessageRepo.status,
        MessageRepo.conversationId,
      ],
      where: "${MessageRepo.conversationId} = ?",
      whereArgs: [conversationId],
      orderBy: "${MessageRepo.createdAt} DESC",
      offset: ((page - 1) > 0 ? (page - 1) : 0) * size,
      limit: size,
    );
    // debugPrint(
    //     "> on findByConversation  $conversationId, $page, ${maps.length}; ${maps.toList().toString()}");
    if (maps.isEmpty) {
      return [];
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      int j = maps.length - i - 1;
      messages.add(MessageModel.fromJson(maps[j]));
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
        MessageRepo.conversationId,
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

  Future<int> deleteByConversationId(int id) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.conversationId} = ?',
      whereArgs: [id],
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
        MessageRepo.conversationId,
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
