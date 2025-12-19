import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

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
    String where;
    List args;

    if (nextAutoId <= 0) {
      where = "${MessageRepo.conversationUk3} = ?";
      args = [uk3];
    } else {
      where = "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} < ?";
      args = [uk3, nextAutoId];
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
    String where;
    List args;

    if (prevAutoId <= 0) {
      where = "${MessageRepo.conversationUk3} = ?";
      args = [uk3];
    } else {
      where = "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} > ?";
      args = [uk3, prevAutoId];
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

    final List<String> ackMsgIds = [];
    final Set<String> ackIdSet = <String>{};
    void addAckId(String id) {
      if (id.isEmpty) return;
      if (ackIdSet.add(id)) {
        ackMsgIds.add(id);
      }
    }

    final List<_InsertedOfflineMessage> inserted = [];
    try {
      await _db.transaction((txn) async {
        for (final msgData in messages) {
          final rawMsgId = msgData['msg_id'] ?? msgData['id'];
          final msgId = rawMsgId?.toString() ?? '';
          final type = (msgData['type'] ?? 'C2C').toString().toUpperCase();

          if (msgId.isEmpty) {
            iPrint("离线消息缺少id，跳过: ${msgData.toString()}");
            continue;
          }

          final tableName = MessageRepo.getTableName(type);
          if (tableName.isEmpty) {
            iPrint("离线消息type不支持，跳过: $type");
            continue;
          }

          // 检查消息是否已存在
          final List<Map<String, Object?>> existing = await txn.rawQuery(
            'SELECT COUNT(*) as count FROM $tableName WHERE id = ?',
            [msgId],
          );
          final int existingCount = (existing.first['count'] as int?) ?? 0;

          if (existingCount > 0) {
            addAckId(msgId);
            iPrint("离线消息已存在，跳过: $msgId");
            continue;
          }

          // 解析消息负载
          Map<String, dynamic> payload = {};
          final payloadRaw = msgData['payload'];
          if (payloadRaw is Map) {
            payload = payloadRaw.cast<String, dynamic>();
          } else if (payloadRaw is String && payloadRaw.isNotEmpty) {
            try {
              final decoded = json.decode(payloadRaw);
              if (decoded is Map) {
                payload = decoded.cast<String, dynamic>();
              }
            } catch (_) {}
          }

          final fromId = (msgData['from'] ?? '').toString();
          final toId = (msgData['to'] ?? '').toString();
          final createdAt = _parseCreatedAt(msgData['created_at']);
          final topicId = int.tryParse((msgData['topic_id'] ?? 0).toString()) ?? 0;

          // 确定消息方向（是否为作者）
          String currentUid = UserRepoLocal.to.currentUid;
          bool isAuthor = fromId == currentUid;

          // 构建会话UK3
          String peerId = '';
          if (type == 'C2G') {
            peerId = toId;
            if (peerId.isEmpty) {
              peerId = (payload['group_id'] ?? payload['groupId'] ?? '').toString();
            }
          } else if (type == 'S2C') {
            peerId = fromId;
          } else {
            peerId = isAuthor ? toId : fromId;
          }

          if (peerId.isEmpty) {
            iPrint("离线消息缺少peerId，跳过: $msgId, type: $type");
            continue;
          }

          String conversationUk3 = ConversationUk3Generator.generateSmart(
            type: type,
            currentUserId: currentUid,
            peerId: peerId,
          );

          Map<String, dynamic> insertData = {
            MessageRepo.id: msgId,
            MessageRepo.type: type,
            MessageRepo.from: fromId,
            MessageRepo.to: toId,
            MessageRepo.payload: json.encode(payload),
            MessageRepo.createdAt: createdAt,
            MessageRepo.isAuthor: isAuthor ? 1 : 0,
            MessageRepo.topicId: topicId,
            MessageRepo.conversationUk3: conversationUk3,
            MessageRepo.status: IMBoyMessageStatus.delivered,
          };

          await txn.insert(
            tableName,
            insertData,
          );

          inserted.add(_InsertedOfflineMessage(
            id: msgId,
            type: type,
            fromId: fromId,
            toId: toId,
            payload: payload,
            createdAt: createdAt,
            isAuthor: isAuthor ? 1 : 0,
            topicId: topicId,
            conversationUk3: conversationUk3,
            status: IMBoyMessageStatus.delivered,
            peerId: peerId,
          ));

          addAckId(msgId);

          iPrint("离线消息插入成功: $msgId, type: $type, conversation: $conversationUk3");
        }
      });

      if (inserted.isNotEmpty) {
        await _syncOfflineConversationsAndNotify(inserted);
      }
      iPrint("批量插入离线消息完成，共 ${messages.length} 条消息");
      return ackMsgIds;
    } catch (e) {
      iPrint("批量插入离线消息失败: $e");
      rethrow;
    }
  }

  static int _parseCreatedAt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    final s = raw.toString();
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    try {
      return DateTimeHelper.rfc3339ToMillisecond(s);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _syncOfflineConversationsAndNotify(List<_InsertedOfflineMessage> inserted) async {
    final conversationRepo = ConversationRepo();
    final contactRepo = ContactRepo();
    final groupRepo = GroupRepo();

    final ConversationLogic? conversationLogic =
        Get.isRegistered<ConversationLogic>() ? Get.find<ConversationLogic>() : null;
    final ChatLogic? chatLogic = Get.isRegistered<ChatLogic>() ? Get.find<ChatLogic>() : null;
    final currentConversationUk3 = chatLogic?.state.currentConversationId.value ?? '';

    final Map<String, _OfflineConversationAgg> convAgg = {};
    for (final msg in inserted) {
      final key = '${msg.type}::${msg.peerId}';
      final agg = convAgg.putIfAbsent(key, () => _OfflineConversationAgg(type: msg.type, peerId: msg.peerId));
      agg.observe(msg, currentConversationUk3);
    }

    for (final agg in convAgg.values) {
      final latest = agg.latest;
      if (latest == null) continue;

      String avatar = '';
      String title = '';
      try {
        if (agg.type == 'C2G') {
          final g = await groupRepo.findById(agg.peerId);
          avatar = g?.avatar ?? '';
          title = g?.title ?? '';
        } else {
          final ct = await contactRepo.findByUid(agg.peerId, autoFetch: false);
          avatar = ct?.avatar ?? '';
          title = ct?.title ?? '';
        }
      } catch (_) {}

      final preview = _derivePreview(latest.payload);
      final existing = await conversationRepo.findByPeerId(agg.type, agg.peerId);

      ConversationModel conv;
      if (existing == null) {
        conv = await conversationRepo.save(ConversationModel(
          peerId: agg.peerId,
          avatar: avatar,
          title: title,
          subtitle: preview.subtitle,
          type: agg.type,
          msgType: preview.msgType,
          lastMsgId: latest.id,
          lastTime: latest.createdAt,
          unreadNum: 0,
          id: 0,
          isShow: 1,
        ));
      } else {
        if (latest.createdAt > existing.lastTime) {
          await conversationRepo.updateById(existing.id, {
            ConversationRepo.avatar: avatar,
            ConversationRepo.title: title,
            ConversationRepo.subtitle: preview.subtitle,
            ConversationRepo.msgType: preview.msgType,
            ConversationRepo.lastMsgId: latest.id,
            ConversationRepo.lastTime: latest.createdAt,
            ConversationRepo.isShow: 1,
          });
          conv = (await conversationRepo.findById(existing.id)) ?? existing;
        } else {
          conv = existing;
        }
      }

      eventBus.fire(conv);
      if (conversationLogic != null && agg.unreadDelta > 0) {
        await conversationLogic.increaseConversationRemind(conv, agg.unreadDelta);
      }
    }

    if (currentConversationUk3.isNotEmpty) {
      for (final msg in inserted) {
        if (msg.conversationUk3 != currentConversationUk3) continue;
        try {
          eventBus.fire(await msg.toMessageModel().toTypeMessage());
        } catch (_) {}
      }
    }
  }

  static ({String msgType, String subtitle}) _derivePreview(Map<String, dynamic> payload) {
    String msgType = (payload['msg_type'] ?? '').toString();
    String subtitle = (payload['text'] ?? '').toString();
    if (msgType == 'custom') {
      msgType = (payload['custom_type'] ?? '').toString();
      subtitle = '';
    } else if (msgType == 'quote') {
      subtitle = (payload['quote_text'] ?? '').toString();
    } else if (msgType == 'location') {
      subtitle = (payload['title'] ?? '').toString();
    }
    return (msgType: msgType, subtitle: subtitle);
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }

  /// 数据迁移工具：将旧格式UK3转换为新格式
  /// 这个方法可以在应用启动时调用，一次性迁移所有历史数据
  static Future<void> migrateLegacyUk3Data() async {
    try {
      iPrint("开始迁移历史UK3数据...");

      final db = SqliteService.to;
      final tables = [c2cTable, c2gTable, c2sTable, s2cTable];

      for (final table in tables) {
        await _migrateTableUk3(db, table);
      }

      iPrint("历史UK3数据迁移完成");
    } catch (e) {
      iPrint("历史UK3数据迁移失败: $e");
    }
  }

  /// 迁移单个表的UK3数据
  static Future<void> _migrateTableUk3(SqliteService db, String table) async {
    try {
      // 查询所有需要迁移的消息
      final maps = await db.query(
        table,
        columns: ['auto_id', 'conversation_uk3', 'from_id', 'to_id'],
        where: "conversation_uk3 IS NOT NULL AND conversation_uk3 != ''",
      );

      if (maps.isEmpty) {
        iPrint("表 $table 无需迁移的UK3数据");
        return;
      }

      iPrint("开始迁移表 $table 的 ${maps.length} 条UK3数据");

      int migratedCount = 0;

      for (final map in maps) {
        final autoId = map['auto_id'];
        final oldUk3 = map['conversation_uk3'] as String?;
        final fromId = map['from_id'] as String?;
        final toId = map['to_id'] as String?;

        if (oldUk3 == null || oldUk3.isEmpty || fromId == null || toId == null) {
          continue;
        }

        // 检查是否需要迁移（新旧格式是否不同）
        final newUk3 = _generateNewUk3(oldUk3, fromId, toId);
        if (newUk3 == oldUk3) {
          continue; // 格式相同，无需迁移
        }

        // 执行迁移
        final result = await db.update(
          table,
          {'conversation_uk3': newUk3},
          where: 'auto_id = ?',
          whereArgs: [autoId],
        );

        if (result > 0) {
          migratedCount++;
        }
      }

      iPrint("表 $table 迁移完成，成功迁移 $migratedCount 条记录");
    } catch (e) {
      iPrint("迁移表 $table 失败: $e");
    }
  }

  /// 根据旧格式UK3和用户信息生成新格式UK3
  static String _generateNewUk3(String oldUk3, String fromId, String toId) {
    try {
      final parts = oldUk3.split('_');
      if (parts.length < 3) return oldUk3;

      final type = parts[0].toUpperCase();

      // 如果已经是新格式，直接返回
      if (type == oldUk3.split('_')[0]) {
        // 检查是否已经是标准化格式（用户ID已排序）
        if (type == 'C2C') {
          final normalizedIds = _normalizeUserIds(fromId, toId);
          final expectedNewUk3 = 'C2C_$normalizedIds';
          if (oldUk3.toUpperCase() == expectedNewUk3) {
            return oldUk3; // 已经是新格式
          }
        }
      }

      // 生成新格式
      switch (type) {
        case 'C2C':
          final normalizedIds = _normalizeUserIds(fromId, toId);
          return 'C2C_$normalizedIds';
        case 'C2G':
          return 'C2G_${fromId}_$toId'; // 群组消息保持原始格式
        default:
          return oldUk3;
      }
    } catch (e) {
      return oldUk3;
    }
  }

  /// 标准化用户ID顺序（按字母排序）
  static String _normalizeUserIds(String id1, String id2) {
    final sortedIds = [id1, id2]..sort();
    return '${sortedIds.first}_${sortedIds.last}';
  }

  /// 检查数据库中是否存在旧格式数据
  static Future<bool> hasLegacyUk3Data() async {
    try {
      final db = SqliteService.to;
      final tables = [c2cTable, c2gTable, c2sTable, s2cTable];

      for (final table in tables) {
        final result = await db.query(
          table,
          columns: ['COUNT(*) as count'],
          where: "conversation_uk3 LIKE ? OR conversation_uk3 LIKE ?",
          whereArgs: ['c2c_%', 'c2g_%'],
          limit: 1,
        );

        final count = result.first['count'] as int;
        if (count > 0) {
          return true;
        }
      }

      return false;
    } catch (e) {
      iPrint("检查旧格式数据失败: $e");
      return false;
    }
  }
}

class _InsertedOfflineMessage {
  final String id;
  final String type;
  final String fromId;
  final String toId;
  final Map<String, dynamic> payload;
  final int createdAt;
  final int isAuthor;
  final int topicId;
  final String conversationUk3;
  final int status;
  final String peerId;

  const _InsertedOfflineMessage({
    required this.id,
    required this.type,
    required this.fromId,
    required this.toId,
    required this.payload,
    required this.createdAt,
    required this.isAuthor,
    required this.topicId,
    required this.conversationUk3,
    required this.status,
    required this.peerId,
  });

  MessageModel toMessageModel() {
    return MessageModel(
      id,
      autoId: 0,
      type: type,
      fromId: fromId,
      toId: toId,
      payload: payload,
      createdAt: createdAt,
      isAuthor: isAuthor,
      topicId: topicId,
      conversationUk3: conversationUk3,
      status: status,
    );
  }
}

class _OfflineConversationAgg {
  final String type;
  final String peerId;
  _InsertedOfflineMessage? latest;
  int unreadDelta = 0;

  _OfflineConversationAgg({required this.type, required this.peerId});

  void observe(_InsertedOfflineMessage msg, String currentConversationUk3) {
    if (latest == null || msg.createdAt >= (latest?.createdAt ?? 0)) {
      latest = msg;
    }
    if (msg.isAuthor == 0 && msg.conversationUk3 != currentConversationUk3) {
      unreadDelta += 1;
    }
  }
}
