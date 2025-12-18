import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
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
      whereArgs: [msg.id],
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
      debugPrint("> on MessageModel/insert tb $tableName : $insert");
      await _db.insert(tableName, insert);
    } else {
      debugPrint("> on MessageModel/insert count $count : $insert");
    }
    return msg;
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> data) async {
    if (data.containsKey(MessageRepo.payload) &&
        data[MessageRepo.payload] is Map<String, dynamic>) {
      data[MessageRepo.payload] = jsonEncode(data[MessageRepo.payload]);
    }
    iPrint("message_repo/update $tableName ;");
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
    String uk3,
    int nextAutoId,
    int size,
  ) async {
    String where =
        "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} < ?";
    List args = [uk3, nextAutoId];
    if (nextAutoId <= 0) {
      where = "${MessageRepo.conversationUk3} = ?";
      args = [uk3];
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

  /// 加载较新的消息（用于双向分页）
  Future<List<MessageModel>> pageNewerForConversation(
    String uk3,
    int prevAutoId,
    int size,
  ) async {
    String where =
        "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} > ?";
    List args = [uk3, prevAutoId];
    if (prevAutoId <= 0) {
      where = "${MessageRepo.conversationUk3} = ?";
      args = [uk3];
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
      orderBy: "${MessageRepo.autoId} ASC",
      offset: 0,
      limit: size,
    );
    if (maps.isEmpty) {
      return [];
    }

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      messages.add(MessageModel.fromJson(maps[i]));
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
      // 优化搜索：使用更精确的JSON提取和索引
      where =
          "$where AND (json_extract(payload, '\$.text') LIKE ? OR json_extract(payload, '\$.quote_text') LIKE ? OR json_extract(payload, '\$.title') LIKE ? OR json_extract(payload, '\$.filename') LIKE ?)";
      whereArgs.addAll([
        "%$kwd%", "%$kwd%", "%$kwd%", "%$kwd%"
      ]);
    }

    if (strNoEmpty(conversationUk3)) {
      where = "$where AND ${MessageRepo.conversationUk3}=?";
      whereArgs.add(conversationUk3);
    }

    // 使用优化的排序和索引
    String optimizedOrderBy = orderBy ?? "${MessageRepo.createdAt} DESC, ${MessageRepo.autoId} DESC";

    iPrint("searchLeading_tag where $where");

    try {
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
        orderBy: optimizedOrderBy,
        limit: size,
        offset: offset,
      );

      debugPrint(
          "> on MessageRepo_page tb $tableName, $conversationUk3, kwd $kwd, page $page, len ${maps.length}");

      if (maps.isEmpty) {
        return [];
      }

      List<MessageModel> messages = [];
      for (int i = 0; i < maps.length; i++) {
        messages.add(MessageModel.fromJson(maps[i]));
      }
      return messages;
    } catch (e) {
      debugPrint("MessageRepo page error: $e");
      return [];
    }
  }

  /// 优化的全文搜索
  Future<List<MessageModel>> fullTextSearch({
    required String query,
    String? conversationUk3,
    int page = 1,
    int size = 20,
    List<String>? messageTypes,
    String? senderId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      page = page > 1 ? page : 1;
      int offset = (page - 1) * size;

      // 构建查询条件
      String where = "1=1";
      List<Object?> whereArgs = [];

      // 基础文本搜索
      if (query.trim().isNotEmpty) {
        where = "$where AND (json_extract(payload, '\$.text') LIKE ? OR json_extract(payload, '\$.quote_text') LIKE ? OR json_extract(payload, '\$.title') LIKE ? OR json_extract(payload, '\$.filename') LIKE ? OR json_extract(payload, '\$.description') LIKE ?)";
        String pattern = "%${query.trim()}%";
        whereArgs.addAll([pattern, pattern, pattern, pattern, pattern]);
      }

      // 会话过滤
      if (strNoEmpty(conversationUk3)) {
        where = "$where AND ${MessageRepo.conversationUk3}=?";
        whereArgs.add(conversationUk3);
      }

      // 消息类型过滤
      if (messageTypes != null && messageTypes.isNotEmpty) {
        String placeholders = messageTypes.map((_) => '?').join(',');
        where = "$where AND ${MessageRepo.type} IN ($placeholders)";
        whereArgs.addAll(messageTypes);
      }

      // 发送者过滤
      if (strNoEmpty(senderId)) {
        where = "$where AND ${MessageRepo.from}=?";
        whereArgs.add(senderId);
      }

      // 时间范围过滤
      if (startDate != null) {
        where = "$where AND ${MessageRepo.createdAt} >= ?";
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        where = "$where AND ${MessageRepo.createdAt} <= ?";
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      // 执行查询
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
        orderBy: "${MessageRepo.createdAt} DESC, ${MessageRepo.autoId} DESC",
        limit: size,
        offset: offset,
      );

      debugPrint("fullTextSearch: ${maps.length} results for query: $query");

      if (maps.isEmpty) {
        return [];
      }

      List<MessageModel> messages = [];
      for (final map in maps) {
        messages.add(MessageModel.fromJson(map));
      }
      return messages;
    } catch (e) {
      debugPrint("fullTextSearch error: $e");
      return [];
    }
  }

  /// 搜索建议生成（简化版本）
  Future<List<String>> generateSearchSuggestions(String prefix, {int maxSuggestions = 5}) async {
    if (prefix.trim().length < 2) return [];

    try {
      // 使用现有搜索方法获取包含前缀的消息
      List<MessageModel> results = await page(
        page: 1,
        size: maxSuggestions * 3,
        kwd: prefix.trim(),
      );

      Set<String> suggestions = {};
      for (final msg in results) {
        String? text = msg.payload['text'] as String?;
        String? title = msg.payload['title'] as String?;

        // 检查文本内容
        if (text != null && text.toLowerCase().contains(prefix.toLowerCase())) {
          List<String> words = text.trim().split(RegExp(r'\s+'));
          for (final word in words) {
            if (word.toLowerCase().startsWith(prefix.toLowerCase()) && word.length > 2) {
              suggestions.add(word);
              if (suggestions.length >= maxSuggestions) break;
            }
          }
        }

        // 检查标题
        if (title != null && title.toLowerCase().contains(prefix.toLowerCase())) {
          List<String> words = title.trim().split(RegExp(r'\s+'));
          for (final word in words) {
            if (word.toLowerCase().startsWith(prefix.toLowerCase()) && word.length > 2) {
              suggestions.add(word);
              if (suggestions.length >= maxSuggestions) break;
            }
          }
        }

        if (suggestions.length >= maxSuggestions) break;
      }

      return suggestions.toList();
    } catch (e) {
      debugPrint("generateSearchSuggestions error: $e");
      return [];
    }
  }

  /// 创建搜索索引
  Future<void> createSearchIndexes() async {
    try {
      // 为搜索相关的字段创建索引
      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_created_at
        ON $tableName (${MessageRepo.createdAt} DESC)
      ''');

      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_conversation_uk3
        ON $tableName (${MessageRepo.conversationUk3})
      ''');

      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_from_id
        ON $tableName (${MessageRepo.from})
      ''');

      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_type
        ON $tableName (${MessageRepo.type})
      ''');

      // 复合索引用于常见搜索组合
      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_conversation_created
        ON $tableName (${MessageRepo.conversationUk3}, ${MessageRepo.createdAt} DESC)
      ''');

      debugPrint("Search indexes created for $tableName");
    } catch (e) {
      debugPrint("Error creating search indexes: $e");
    }
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
    // iPrint("> on MessageRepo/find tb $tableName, id $id, len ${maps.length}; ${maps.toList().toString()}");
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

  /// 根据状态查找消息
  /// Find messages by status.
  Future<List<MessageModel>> findByStatus(
    String conversationUk3,
    int status,
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
        MessageRepo.topicId,
        MessageRepo.conversationUk3,
        MessageRepo.status,
      ],
      where: '${MessageRepo.conversationUk3} = ? AND ${MessageRepo.status} = ?',
      whereArgs: [conversationUk3, status],
      orderBy: '${MessageRepo.createdAt} DESC',
    );
    
    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      messages.add(MessageModel.fromJson(maps[i]));
    }
    return messages;
  }

  /// 批量更新消息状态
  /// Batch update message status.
  Future<int> batchUpdateStatus(List<String> messageIds, int status) async {
    if (messageIds.isEmpty) return 0;
    
    final placeholders = messageIds.map((_) => '?').join(',');
    final whereClause = '${MessageRepo.id} IN ($placeholders)';
    
    return await _db.update(
      tableName,
      {MessageRepo.status: status},
      where: whereClause,
      whereArgs: messageIds,
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

  /// 批量插入离线消息
  Future<List<String>?> batchInsertOfflineMessages(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return null;

    List<String> msgIds = [];
    try {
      await _db.transaction((txn) async {
        for (final msgData in messages) {
          String msgId = msgData['msg_id'] ?? '';
          String type = msgData['type'] ?? 'C2C';

          msgIds.add(msgId);
          // 检查消息是否已存在
          List<Map> existing = await txn.rawQuery(
            'SELECT COUNT(*) as count FROM ${MessageRepo.getTableName(type)} WHERE id = ?',
            [msgId],
          );

          if (existing.first['count'] == 0) {
            // 解析消息负载
            Map<String, dynamic> payload = msgData['payload'] ?? {};
            String fromId = msgData['from'] ?? '';
            String toId = msgData['to'] ?? '';
            int createdAt = msgData['created_at'] ?? 0;

            // 确定消息方向（是否为作者）
            String currentUid = UserRepoLocal.to.currentUid;
            bool isAuthor = fromId == currentUid;

            // 构建会话UK3
            String peerId = isAuthor ? toId : fromId;
            String conversationUk3 = "${type}_${currentUid}_$peerId";

            Map<String, dynamic> insertData = {
              MessageRepo.id: msgId,
              MessageRepo.type: type,
              MessageRepo.from: fromId,
              MessageRepo.to: toId,
              MessageRepo.payload: json.encode(payload),
              MessageRepo.createdAt: createdAt,
              MessageRepo.isAuthor: isAuthor ? 1 : 0,
              MessageRepo.topicId: '',
              MessageRepo.conversationUk3: conversationUk3,
              MessageRepo.status: 20, // 已读状态
            };

            await txn.insert(
              MessageRepo.getTableName(type),
              insertData,
            );

            iPrint("离线消息插入成功: $msgId, type: $type, conversation: $conversationUk3");
          } else {
            iPrint("离线消息已存在，跳过: $msgId");
          }
        }
      });

      iPrint("批量插入离线消息完成，共 ${messages.length} 条消息");
      return msgIds;
    } catch (e) {
      iPrint("批量插入离线消息失败: $e");
      rethrow;
    }
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
