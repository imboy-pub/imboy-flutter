import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/component/helper/func.dart';

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
  // C7-β: 独立 @ 未读计数（db v17 新增列）
  static String mentionUnread = 'mention_unread';
  // C7-α-1: 本地群免打扰 DND（db v18 新增列；1=静音通知，0=默认）
  // 注：与 chat_input.isMuted（admin 群禁言）语义不同，此处是用户个人静音通知。
  static String isMuted = 'is_muted';
  static String payload = 'payload';

  // 等价与 msg type: C2C C2G 等等，根据type显示item
  static String type = 'type';

  // msgType 定义见 ConversationModel/content 的定义
  static String msgType = 'msg_type';
  static String isShow = "is_show";

  final SqliteService _db = SqliteService.to;

  // 插入一条数据
  Future<int> insert(ConversationModel obj, {Transaction? txn}) async {
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
      ConversationRepo.payload: jsonEncode(obj.payload),
    };
    // return lastInsertId;
    if (txn != null) {
      return await txn.insert(ConversationRepo.tableName, insert);
    } else {
      return await _db.insert(ConversationRepo.tableName, insert);
    }
  }

  Future<int> updateById(
    int id,
    Map<String, dynamic> data, {
    Transaction? txn,
  }) async {
    // iPrint(
    //     "ConversationRepo_updateById $id, ${data.toString()} ${DateTime.now()}");
    if (data.containsKey(ConversationRepo.payload) &&
        data[ConversationRepo.payload] is Map<String, dynamic>) {
      data[ConversationRepo.payload] = jsonEncode(
        data[ConversationRepo.payload],
      );
    }
    data.remove(ConversationRepo.id);
    if (txn != null) {
      return await txn.update(
        ConversationRepo.tableName,
        data,
        where: '${ConversationRepo.id} = ?',
        whereArgs: [id],
      );
    } else {
      return await _db.update(
        ConversationRepo.tableName,
        data,
        where: '${ConversationRepo.id} = ?',
        whereArgs: [id],
      );
    }
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
      data[ConversationRepo.payload] = jsonEncode(
        data[ConversationRepo.payload],
      );
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
    ConversationModel? oldObj = await findByPeerId(obj.type, obj.peerId.toString());
    int unreadNumOld = oldObj == null ? 0 : oldObj.unreadNum;
    int mentionUnreadOld = oldObj == null ? 0 : oldObj.mentionUnread; // C7-β
    // obj.isShow = oldObj?.isShow ?? 1;
    obj.unreadNum = obj.unreadNum + unreadNumOld;
    obj.mentionUnread = obj.mentionUnread + mentionUnreadOld; // C7-β 对称累加
    if (oldObj == null) {
      obj.id = await insert(obj);
    } else {
      Map<String, dynamic> data = obj.toJson();
      data.remove(ConversationRepo.id);
      await updateById(oldObj.id, data);
      obj = (await findByPeerId(obj.type, obj.peerId.toString()))!;
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
        ConversationRepo.isShow,
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
  // limit 默认 200：会话列表 SQLCipher 解密 2000 行 × payload blob 易触发 SQLITE_NOMEM
  // Limit 200: loading 2000 rows with payload blobs causes SQLITE_NOMEM under SQLCipher
  Future<List<ConversationModel>> list({
    int limit = 200,
    int offset = 0,
    String type = '',
  }) async {
    // 使用 >= 0 而不是 > 0，以便显示已清空聊天记录的会话（lastTime = 0）
    // 这些会话会按 lastTime DESC 排在列表底部
    String where =
        '${ConversationRepo.userId} = ? and ${ConversationRepo.isShow} = ? and ${ConversationRepo.lastTime} >= 0';
    List<Object?> whereArgs = [UserRepoLocal.to.currentUid, 1];
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
        ConversationRepo.isShow,
      ],
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: "${ConversationRepo.lastTime} DESC",
    );
    iPrint("> on ConversationRepo/all ${items.length} items");
    if (items.isEmpty) {
      return [];
    }
    List<ConversationModel> item2 = [];
    for (var e in items) {
      // if(e['t'])
      try {
        item2.add(ConversationModel.fromJson(e));
      } catch (e, s) {
        iPrint("ConversationRepo/list err $e; $s");
      }
    }
    return item2;
  }

  Future<ConversationModel?> findById(int id, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
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
          ConversationRepo.isShow,
        ],
        where: 'id=?',
        whereArgs: [id],
        orderBy: "${ConversationRepo.lastTime} DESC",
      );
    } else {
      maps = await _db.query(
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
          ConversationRepo.isShow,
        ],
        where: 'id=?',
        whereArgs: [id],
        orderBy: "${ConversationRepo.lastTime} DESC",
      );
    }

    if (maps.isNotEmpty) {
      return ConversationModel.fromJson(maps.first);
    }
    return null;
  }

  //
  Future<ConversationModel?> findByPeerId(
    String type,
    String peerId, {
    Transaction? txn,
  }) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
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
          ConversationRepo.isShow,
        ],
        where:
            '${ConversationRepo.type} = ? and ${ConversationRepo.userId} = ? and ${ConversationRepo.peerId} = ?',
        whereArgs: [type, UserRepoLocal.to.currentUid, peerId],
      );
    } else {
      maps = await _db.query(
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
          ConversationRepo.isShow,
        ],
        where:
            '${ConversationRepo.type} = ? and ${ConversationRepo.userId} = ? and ${ConversationRepo.peerId} = ?',
        whereArgs: [type, UserRepoLocal.to.currentUid, peerId],
      );
    }
    // iPrint(
    // "> on pageMessages findByPeerId $type, ${UserRepoLocal.to.currentUid}, pid $peerId, ${maps.toString()}");
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

  /// 清空会话的所有消息并更新会话状态（事务保证原子性）
  ///
  /// [model] 要清空消息的会话模型
  ///
  /// 返回更新后的会话模型
  ///
  /// 该方法在一个事务中完成以下操作：
  /// 1. 删除该会话的所有消息
  /// 2. 更新会话表的 last_msg_id、last_time 等字段
  /// 3. 重新加载并返回更新后的会话模型
  ///
  /// 使用事务确保原子性：要么全部成功，要么全部回滚
  Future<ConversationModel?> clearMessages(ConversationModel model) async {
    return await _db.transaction((txn) async {
      final tableName = MessageRepo.getTableName(model.type);

      // 1. 先统计要删除的消息数量（用于清理重试队列）
      final result = await txn.rawQuery(
        'SELECT id FROM $tableName WHERE ${MessageRepo.conversationUk3} = ?',
        [model.uk3],
      );

      // v16: id 列从 TEXT 迁移到 INTEGER，此处用 toString() 兼容 int/String 两种返回
      final msgIds = result.map((row) => row['id'].toString()).toList();

      // 2. 清理重试队列中的消息
      if (msgIds.isNotEmpty) {
        for (final msgId in msgIds) {
          try {
            MessageRetry.instance.removeFromRetryQueue(msgId);
          } catch (e) {
            debugPrint('清理重试队列失败: $msgId, error: $e');
          }
        }
        iPrint('已从重试队列清理 ${msgIds.length} 条消息: conversationUk3=${model.uk3}');
      }

      // 3. 删除消息
      final deletedCount = await txn.delete(
        tableName,
        where: '${MessageRepo.conversationUk3} = ?',
        whereArgs: [model.uk3],
      );

      // 4. 更新会话表（清空所有 last msg 相关信息）
      await txn.update(
        ConversationRepo.tableName,
        {
          ConversationRepo.lastTime: 0, // 清空最后消息时间（避免会话飘到顶部）
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.subtitle: '', // 清空副标题（最后消息预览）
          ConversationRepo.msgType: '', // 清空消息类型
        },
        where: '${ConversationRepo.id} = ?',
        whereArgs: [model.id],
      );

      iPrint(
        '清空聊天记录: 已更新会话 last_msg, conversationUk3=${model.uk3}, 删除消息数=$deletedCount',
      );

      // 5. 在同一事务中重新查询更新后的会话数据
      final maps = await txn.query(
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
          ConversationRepo.isShow,
        ],
        where: '${ConversationRepo.id} = ?',
        whereArgs: [model.id],
      );

      if (maps.isNotEmpty) {
        return ConversationModel.fromJson(maps.first);
      }
      return null;
    });
  }

  /// 删除会话及其所有消息（事务保证原子性）
  ///
  /// [model] 要删除的会话模型
  ///
  /// 返回删除的消息数量
  ///
  /// 该方法在一个事务中完成以下操作：
  /// 1. 查询并清理该会话所有消息的重试队列
  /// 2. 删除该会话的所有消息
  /// 3. 删除会话记录本身
  ///
  /// 使用事务确保原子性：要么全部成功，要么全部回滚
  Future<int> deleteConversation(ConversationModel model) async {
    return await _db.transaction((txn) async {
      final tableName = MessageRepo.getTableName(model.type);

      // 1. 查询该会话的所有消息ID（用于清理重试队列）
      final result = await txn.rawQuery(
        'SELECT id FROM $tableName WHERE ${MessageRepo.conversationUk3} = ?',
        [model.uk3],
      );

      // v16: id 列从 TEXT 迁移到 INTEGER，此处用 toString() 兼容 int/String 两种返回
      final msgIds = result.map((row) => row['id'].toString()).toList();

      // 2. 清理重试队列中的消息
      if (msgIds.isNotEmpty) {
        for (final msgId in msgIds) {
          try {
            MessageRetry.instance.removeFromRetryQueue(msgId);
          } catch (e) {
            debugPrint('清理重试队列失败: $msgId, error: $e');
          }
        }
        iPrint('已从重试队列清理 ${msgIds.length} 条消息: conversationUk3=${model.uk3}');
      }

      // 3. 删除消息
      final deletedCount = await txn.delete(
        tableName,
        where: '${MessageRepo.conversationUk3} = ?',
        whereArgs: [model.uk3],
      );

      // 4. 删除会话记录
      await txn.delete(
        ConversationRepo.tableName,
        where: '${ConversationRepo.id} = ?',
        whereArgs: [model.id],
      );

      iPrint(
        '删除会话: 已删除会话及其消息, conversationUk3=${model.uk3}, 删除消息数=$deletedCount',
      );

      return deletedCount;
    });
  }

  // 记得及时关闭数据库，防止内存泄漏
  Future<void> close() async {
    //await _db.close();
  }

  Future<void> update(String value, Map<String, int> map) async {}
}
