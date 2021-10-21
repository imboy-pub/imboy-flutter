import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/helper/sqflite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';

class MessageRepo {
  static String tablename = 'message';

  static String id = 'id';
  static String type = 'type';
  static String from = 'from_id';
  static String to = 'to_id';
  static String payload = 'payload';
  static String createdAt = 'created_at';
  static String serverTs = 'server_ts';
  //
  static String conversationId = 'conversation_id';
  static String status = 'status';

  Sqlite _db = Sqlite.instance;

  final UserRepoSP current = Get.put(UserRepoSP.user);

  // 插入一条数据
  Future<MessageModel> insert(MessageModel msg) async {
    int? count = await _db.count(
      MessageRepo.tablename,
      where: "id=?",
      whereArgs: [MessageRepo.id],
    );
    if (count == 0) {
      Map<String, dynamic> insert = {
        '${MessageRepo.id}': msg.id,
        '${MessageRepo.type}': msg.type,
        '${MessageRepo.from}': msg.fromId,
        '${MessageRepo.to}': msg.toId,
        '${MessageRepo.payload}': json.encode(msg.payload),
        '${MessageRepo.createdAt}': msg.createdAt,
        '${MessageRepo.serverTs}': msg.serverTs ?? 0,
        '${MessageRepo.conversationId}': msg.conversationId,
        '${MessageRepo.status}': msg.status,
      };
      debugPrint(">>>>> on MessgeMode/insert " + insert.toString());
      await _db.insert(MessageRepo.tablename, insert);
    } else {
      debugPrint(
          ">>>>> on MessgeMode/insert count $count : " + insert.toString());
    }
    return msg;
  }

  Future<List<MessageModel>> findByConversation(int conversationId) async {
    String cuid = UserRepoSP.user.currentUid;
    List<Map<String, dynamic>> maps = await _db.query(MessageRepo.tablename,
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
        whereArgs: [conversationId]);

    if (maps == null || maps.length == 0) {
      return [];
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      messages.add(MessageModel.fromMap(maps[i]));
    }
    return messages;
  }

  // 查找所有信息
  Future<List<MessageModel>?> all() async {
    String cuid = UserRepoSP.user.currentUid;
    List<Map<String, dynamic>> maps =
        await _db.query(MessageRepo.tablename, columns: [
      MessageRepo.id,
      MessageRepo.type,
      MessageRepo.from,
      MessageRepo.to,
      MessageRepo.payload,
      MessageRepo.createdAt,
      MessageRepo.serverTs,
      MessageRepo.conversationId,
      MessageRepo.status,
    ]);

    if (maps == null || maps.length == 0) {
      return null;
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      messages.add(MessageModel.fromMap(maps[i]));
    }
    return messages;
  }

  //
  Future<MessageModel?> find(String id) async {
    List<Map<String, dynamic>> maps = await _db.query(MessageRepo.tablename,
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
        whereArgs: [id]);
    if (maps.length > 0) {
      return MessageModel.fromMap(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String id) async {
    return await _db.delete(MessageRepo.tablename,
        where: '${MessageRepo.id} = ?', whereArgs: [id]);
  }

  // 更新信息
  Future<int> update(MessageModel message) async {
    return await _db.update(MessageRepo.tablename, message.toMap(),
        where: '${MessageRepo.id} = ?', whereArgs: [message.id]);
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
