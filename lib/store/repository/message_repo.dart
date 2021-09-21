import 'dart:convert';

import 'package:imboy/helper/database.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:sqflite/sqflite.dart';

class MessageRepo {
  static String tablename = 'im_message';

  static String id = 'id';
  static String type = 'type';
  static String from = 'from_id';
  static String to = 'to_id';
  static String payload = 'payload';
  static String serverTs = 'server_ts';

  Database? _db;

  MessageRepo() {
    _database();
  }

  _database() async {
    this._db = await DatabaseHelper.instance.database;
    // debugPrint(">>>>>>>>>>>>>>>>>>> on MessageRepo _database ${this._db}");
  }

  // 插入一条数据
  Future<MessageModel> insert(Map<String, dynamic> data) async {
    if (this._db == null) {
      await this._database();
    }
    MessageModel msg = new MessageModel.fromMap(data);
    Map<String, dynamic> insert = {
      'type': msg.type,
      'from_id': msg.fromId,
      'to_id': msg.toId,
      'payload': json.encode(msg.payload!.toMap()),
      'server_ts': msg.serverTs ?? 0,
    };
    msg.id = await this._db!.insert(MessageRepo.tablename, insert);
    return msg;
  }

  // 查找所有信息
  Future<List<MessageModel>?> all() async {
    if (this._db == null) {
      await this._database();
    }
    List<Map<String, dynamic>> maps =
        await _db!.query(MessageRepo.tablename, columns: [
      MessageRepo.id,
      MessageRepo.type,
      MessageRepo.from,
      MessageRepo.to,
      MessageRepo.payload,
      MessageRepo.serverTs
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
  Future<MessageModel?> find(int id) async {
    if (this._db == null) {
      await this._database();
    }
    List<Map<String, dynamic>> maps = await _db!.query(MessageRepo.tablename,
        columns: [
          MessageRepo.id,
          MessageRepo.type,
          MessageRepo.from,
          MessageRepo.to,
          MessageRepo.payload,
          MessageRepo.serverTs
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
    if (this._db == null) {
      await this._database();
    }
    return await _db!.delete(MessageRepo.tablename,
        where: '${MessageRepo.id} = ?', whereArgs: [id]);
  }

  // 更新信息
  Future<int> update(MessageModel message) async {
    if (this._db == null) {
      await this._database();
    }
    return await _db!.update(MessageRepo.tablename, message.toMap(),
        where: '${MessageRepo.id} = ?', whereArgs: [message.id]);
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db!.close();
// }
}
