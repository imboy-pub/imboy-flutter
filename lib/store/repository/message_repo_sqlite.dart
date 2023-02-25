import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/message_model.dart';

class MessageRepo {
  static String tablename = 'message';

  static String id = 'id';
  // C2C GROUP
  static String type = 'type';
  static String from = 'from_id';
  static String to = 'to_id';
  static String payload = 'payload';
  static String createdAt = 'created_at';
  static String serverTs = 'server_ts';
  //
  static String conversationId = 'conversation_id';
  static String status = 'status';

  final Sqlite _db = Sqlite.instance;

  // 插入一条数据
  Future<MessageModel> insert(MessageModel msg) async {
    int? count = await _db.count(
      MessageRepo.tablename,
      where: "id=?",
      whereArgs: [MessageRepo.id],
    );
    if (count == 0) {
      Map<String, dynamic> insert = {
        'autoid': null,
        MessageRepo.id: msg.id,
        MessageRepo.type: msg.type,
        MessageRepo.from: msg.fromId,
        MessageRepo.to: msg.toId,
        MessageRepo.payload: json.encode(msg.payload),
        MessageRepo.createdAt: msg.createdAt,
        MessageRepo.serverTs: msg.serverTs ?? 0,
        MessageRepo.conversationId: msg.conversationId,
        MessageRepo.status: msg.status,
      };
      debugPrint(">>> on MessgeMode/insert $insert");
      await _db.insert(MessageRepo.tablename, insert);
    } else {
      debugPrint(">>> on MessgeMode/insert count $count : $insert");
    }
    return msg;
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> data) async {
    return await _db.update(
      MessageRepo.tablename,
      data,
      where: '${MessageRepo.id} = ?',
      whereArgs: [data['id']],
    );
  }

  // 存在就更新，不存在就插入
  Future<int?> save(MessageModel obj) async {
    String where = '${MessageRepo.id} = ?';
    int? count = await _db.count(
      MessageRepo.tablename,
      where: where,
      whereArgs: [obj.id],
    );
    if (count == null || count == 0) {
      await insert(obj);
    } else {
      await update(obj.toJson());
    }
    debugPrint(">>>>> on MessageRepo/save count:$count; id: $obj.id");
    return count;
  }

  Future<List<MessageModel>> findByConversation(
    int conversationId,
    int page,
    int size,
  ) async {
    List<Map<String, dynamic>> maps = await _db.query(
      MessageRepo.tablename,
      columns: [
        MessageRepo.id,
        MessageRepo.type,
        MessageRepo.from,
        MessageRepo.to,
        MessageRepo.payload,
        MessageRepo.createdAt,
        MessageRepo.serverTs,
        MessageRepo.status,
        MessageRepo.conversationId,
      ],
      where: "${MessageRepo.conversationId} = ?",
      whereArgs: [conversationId],
      orderBy: "${MessageRepo.createdAt} DESC",
      offset: ((page - 1) > 0 ? (page - 1) : 0) * size,
      limit: size,
    );
    debugPrint(
        "> on findByConversation : $conversationId, $page, ${maps.length}; ${maps.toString()}");
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
      MessageRepo.tablename,
      columns: [
        MessageRepo.id,
        MessageRepo.type,
        MessageRepo.from,
        MessageRepo.to,
        MessageRepo.payload,
        MessageRepo.createdAt,
        MessageRepo.serverTs,
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
      MessageRepo.tablename,
      where: '${MessageRepo.id} = ?',
      whereArgs: [id],
    );
  }

  // 根据UID删除信息
  Future<int> deleteForUid(String uid) async {
    return await _db.delete(
      MessageRepo.tablename,
      where: '${MessageRepo.from} = ? or ${MessageRepo.to} = ?',
      whereArgs: [uid, uid],
    );
  }
// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
