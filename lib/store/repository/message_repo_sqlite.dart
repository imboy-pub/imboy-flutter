import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:sqflite/sqflite.dart';

class MessageRepo {
  // v2.0 表名常量（与服务端保持一致）
  static String c2cTable = 'msg_c2c';
  static String c2gTable = 'msg_c2g';
  static String c2sTable = 'msg_c2s';
  static String s2cTable = 'msg_s2c';

  // 旧表名常量（用于迁移期兼容）
  static const String _legacyC2cTable = 'message';
  static const String _legacyC2gTable = 'group_message';
  static const String _legacyC2sTable = 'c2s_message';
  static const String _legacyS2cTable = 's2c_message';

  // 表名映射：新表名 -> 旧表名（用于向后兼容）
  static final Map<String, String> _legacyTableMapping = {
    c2cTable: _legacyC2cTable,
    c2gTable: _legacyC2gTable,
    c2sTable: _legacyC2sTable,
    s2cTable: _legacyS2cTable,
  };

  // 数据库版本标记（用于判断是否已完成迁移）
  static int _dbVersion = 9;
  static bool _hasCheckedMigration = false;

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

  // v2.0 新增字段（从 payload 中提取到顶层）
  static String msgType = 'msg_type';  // 消息类型：text, image, audio, video, file 等
  static String action = 'action';      // S2C 消息指令
  static String e2ee = 'e2ee';          // 端到端加密信息（JSON 字符串）

  static final List<String> defaultColumns = [
    autoId,
    id,
    type,
    from,
    to,
    payload,
    createdAt,
    isAuthor,
    status,
    conversationUk3,
    topicId,
    msgType,  // v2.0 新增
    action,   // v2.0 新增
    e2ee,     // v2.0 新增
  ];

  // 当前活动的会话 UK3（用于离线消息同步时判断是否需要触发消息事件）
  static String? _currentActiveConversationUk3;

  /// 设置当前活动的会话 UK3
  /// 由聊天页面在打开/关闭时调用
  static void setCurrentActiveConversationUk3(String? uk3) {
    _currentActiveConversationUk3 = uk3;
  }

  /// 获取当前活动的会话 UK3
  static String? get currentActiveConversationUk3 => _currentActiveConversationUk3;

  final SqliteService _db = SqliteService.to;

  final String tableName;

  MessageRepo({required this.tableName}) {
    // 验证表名是否合法
    if (!_isTableAllowed(tableName)) {
      throw ArgumentError('Invalid table name: $tableName');
    }
  }

  /// 获取实际使用的表名（处理迁移期兼容性）
  /// 如果新表存在则使用新表名，否则尝试使用旧表名
  Future<String> getActualTableName() async {
    if (!_hasCheckedMigration) {
      await _checkDatabaseVersion();
    }

    // 如果数据库版本 >= 10，使用新表名
    if (_dbVersion >= 10) {
      return tableName;
    }

    // 否则检查新表是否存在
    final db = await _db.db;
    final count = Sqflite.firstIntValue(
      await db!.rawQuery(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      ),
    );

    if (count != null && count > 0) {
      // 新表存在，使用新表名
      return tableName;
    }

    // 新表不存在，尝试使用旧表名
    final legacyTableName = _legacyTableMapping[tableName];
    if (legacyTableName != null) {
      final legacyCount = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
          [legacyTableName],
        ),
      );

      if (legacyCount != null && legacyCount > 0) {
        debugPrint('MessageRepo: 使用旧表名 $legacyTableName 替代 $tableName');
        return legacyTableName;
      }
    }

    // 都不存在，返回新表名（会报错，但这是预期的）
    return tableName;
  }

  /// 检查数据库版本
  Future<void> _checkDatabaseVersion() async {
    try {
      final db = await _db.db;
      final version = Sqflite.firstIntValue(
        await db!.rawQuery('PRAGMA user_version'),
      );
      _dbVersion = version ?? 9;
      _hasCheckedMigration = true;
      debugPrint('MessageRepo: 数据库版本 v$_dbVersion');
    } catch (e) {
      debugPrint('MessageRepo: 检查数据库版本失败: $e');
      _dbVersion = 9;
      _hasCheckedMigration = true;
    }
  }

  // 数据验证：验证必填字段
  bool _validateMessageData(MessageModel msg) {
    // 验证 ID 不为空
    if (msg.id == null || msg.id!.isEmpty) {
      debugPrint('MessageRepo: 消息 ID 不能为空');
      return false;
    }

    // 验证 ID 长度不超过数据库限制 (假设 varchar(255))
    if (msg.id!.length > 255) {
      debugPrint('MessageRepo: 消息 ID 长度超过限制');
      return false;
    }

    // 验证 fromId 和 toId
    if (msg.fromId == null || msg.fromId!.isEmpty) {
      debugPrint('MessageRepo: 发送者 ID 不能为空');
      return false;
    }

    if (msg.toId == null || msg.toId!.isEmpty) {
      debugPrint('MessageRepo: 接收者 ID 不能为空');
      return false;
    }

    // 验证 conversationUk3
    if (msg.conversationUk3.isEmpty) {
      debugPrint('MessageRepo: 会话 UK3 不能为空');
      return false;
    }

    // 验证时间戳在合理范围内 (2000-01-01 到 2100-01-01)
    if (msg.createdAt < 946684800000 || msg.createdAt > 4102444800000) {
      debugPrint('MessageRepo: 消息时间戳不在合理范围内');
      return false;
    }

    // 验证状态值
    if (msg.status != null && (msg.status! < 0 || msg.status! > 100)) {
      debugPrint('MessageRepo: 消息状态值不在有效范围内');
      return false;
    }

    return true;
  }

  // 允许的表名白名单
  static final Set<String> _allowedTables = {
    MessageRepo.c2cTable,
    MessageRepo.c2gTable,
    MessageRepo.c2sTable,
    MessageRepo.s2cTable,
  };

  // 验证表名是否在白名单中
  static bool _isTableAllowed(String tableName) {
    return _allowedTables.contains(tableName);
  }

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

    // 验证返回的表名是否在白名单中
    if (!_isTableAllowed(tb)) {
      throw ArgumentError('Invalid table name: $tb');
    }

    return tb;
  }

  // 插入一条数据
  Future<MessageModel> insert(MessageModel msg, {Transaction? txn}) async {
    // 数据验证
    if (!_validateMessageData(msg)) {
      throw ArgumentError('Invalid message data');
    }

    // 使用 getTableName 获取表名（支持 v2.0 新表名）
    final msgType = (msg.type?.isNotEmpty == true) ? msg.type! : 'C2C'; // 默认为 C2C
    final targetTableName = MessageRepo.getTableName(msgType);

    int? count;
    if (txn != null) {
      count = await txn
          .rawQuery('SELECT COUNT(*) as count FROM $targetTableName WHERE id = ?', [
            msg.id,
          ])
          .then((result) => result.first['count'] as int?);
    } else {
      count = await _db.count(targetTableName, where: "id=?", whereArgs: [msg.id]);
    }
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
        // v2.0 新增字段
        MessageRepo.msgType: msg.msgType ?? '',
        MessageRepo.action: msg.action,
        MessageRepo.e2ee: msg.e2ee != null ? json.encode(msg.e2ee) : '',
      };
      debugPrint("> on MessageModel/insert tb $targetTableName : $insert");
      if (txn != null) {
        await txn.insert(
          targetTableName,
          insert,
        );
      } else {
        await _db.insert(
          targetTableName,
          insert,
        );
      }
    } else {
      debugPrint("> on MessageModel/insert count $count : $insert");
    }
    return msg;
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> data, {Transaction? txn}) async {
    if (data.containsKey(MessageRepo.payload) &&
        data[MessageRepo.payload] is Map<String, dynamic>) {
      data[MessageRepo.payload] = jsonEncode(data[MessageRepo.payload]);
    }
    // 移除主键 id，因为 SQLite 不允许更新主键
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove(MessageRepo.id);
    updateData.remove(MessageRepo.autoId);

    iPrint("message_repo/update $tableName ;");
    if (txn != null) {
      return await txn.update(
        tableName,
        updateData,
        where: '${MessageRepo.id} = ?',
        whereArgs: [data[MessageRepo.id]],
      );
    } else {
      return await _db.update(
        tableName,
        updateData,
        where: '${MessageRepo.id} = ?',
        whereArgs: [data[MessageRepo.id]],
      );
    }
  }

  // 存在就更新，不存在就插入
  Future<int?> save(MessageModel obj, {Transaction? txn}) async {
    int? count;
    if (txn != null) {
      final result = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE id = ?',
        [obj.id],
      );
      count = (result.first['count'] as int?);
    } else {
      count = await _db.count(
        tableName,
        where: '${MessageRepo.id} = ?',
        whereArgs: [obj.id],
      );
    }
    if (count == null || count == 0) {
      await insert(obj, txn: txn);
    } else {
      Map<String, dynamic> data = obj.toJson();
      data.remove(MessageRepo.autoId);
      await update(data, txn: txn);
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
    int offset;

    if (nextAutoId <= 0) {
      // 加载最新的消息，需要计算offset
      final count = await _db.count(
        tableName,
        where: "${MessageRepo.conversationUk3} = ?",
        whereArgs: [uk3],
      );
      offset = (count != null && count > size) ? (count - size) : 0;
      where = "${MessageRepo.conversationUk3} = ?";
      args = [uk3];
    } else {
      // 加载比nextAutoId更早的消息
      where =
          "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} < ?";
      args = [uk3, nextAutoId];
      offset = 0;
    }

    try {
      List<Map<String, dynamic>> maps = await _db.query(
        tableName,
        columns: defaultColumns,
        where: where,
        whereArgs: args,
        orderBy: "${MessageRepo.autoId} ASC",
        limit: size,
        offset: offset,
      );

      if (maps.isEmpty) {
        return [];
      }

      List<MessageModel> messages = [];
      for (var map in maps) {
        messages.add(MessageModel.fromJson(map));
      }
      return messages;
    } catch (e) {
      debugPrint(
        "MessageRepo pageForConversation error: $e, where: $where, args: $args",
      );
      return [];
    }
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
      where =
          "${MessageRepo.conversationUk3} = ? AND ${MessageRepo.autoId} > ?";
      args = [uk3, prevAutoId];
    }

    try {
      List<Map<String, dynamic>> maps = await _db.query(
        tableName,
        columns: defaultColumns,
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
    } catch (e) {
      debugPrint(
        "MessageRepo pageNewerForConversation error: $e, where: $where, args: $args",
      );
      return [];
    }
  }

  Future<List<MessageModel>> page({
    required int page,
    required int size,
    String? kwd,
    String? conversationUk3,
    String? orderBy,
    // 高级过滤参数
    List<String>? messageTypes,
    String? senderId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    String where = "1=1";
    List<Object?> whereArgs = [];

    if (strNoEmpty(kwd)) {
      kwd = kwd!.trim();
      String pattern = "%$kwd%";
      // 搜索 payload 中的 text 字段，使用参数化查询防止 SQL 注入
      where = "$where AND json_extract(payload, '\$.text') LIKE ?";
      whereArgs.add(pattern);
    }

    if (strNoEmpty(conversationUk3)) {
      where = "$where AND ${MessageRepo.conversationUk3}=?";
      whereArgs.add(conversationUk3);
    }

    // 高级过滤：消息类型
    if (messageTypes != null && messageTypes.isNotEmpty) {
      final placeholders = messageTypes.map((_) => '?').join(',');
      where = "$where AND ${MessageRepo.type} IN ($placeholders)";
      whereArgs.addAll(messageTypes);
    }

    // 高级过滤：发送者
    if (strNoEmpty(senderId)) {
      where = "$where AND ${MessageRepo.from}=?";
      whereArgs.add(senderId);
    }

    // 高级过滤：时间范围
    if (startDate != null) {
      where = "$where AND ${MessageRepo.createdAt} >= ?";
      whereArgs.add(startDate.millisecondsSinceEpoch ~/ 1000);
    }
    if (endDate != null) {
      where = "$where AND ${MessageRepo.createdAt} <= ?";
      whereArgs.add(endDate.millisecondsSinceEpoch ~/ 1000);
    }

    // 使用优化的排序和索引
    String optimizedOrderBy =
        orderBy ?? "${MessageRepo.createdAt} DESC, ${MessageRepo.autoId} DESC";

    iPrint("searchLeading_tag kwd $kwd, where $where");

    try {
      List<Map<String, dynamic>> maps = await _db.query(
        tableName,
        columns: defaultColumns,
        where: where,
        whereArgs: whereArgs,
        orderBy: optimizedOrderBy,
        limit: size,
        offset: offset,
      );

      debugPrint(
        "> on MessageRepo_page tb $tableName, $conversationUk3, kwd $kwd, page $page, len ${maps.length}",
      );

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
  Future<MessageModel?> find(String id, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        tableName,
        columns: defaultColumns,
        where: '${MessageRepo.id} = ?',
        whereArgs: [id],
      );
    } else {
      maps = await _db.query(
        tableName,
        columns: defaultColumns,
        where: '${MessageRepo.id} = ?',
        whereArgs: [id],
      );
    }
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
      columns: defaultColumns,
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
      columns: defaultColumns,
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
  Future<List<String>?> batchInsertOfflineMessages(
    List<Map<String, dynamic>> messages, {
    Future<void> Function(Map<String, dynamic>)? onS2CMessage,
  }) async {
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
      // 先收集 S2C 消息，在事务外处理
      final List<Map<String, dynamic>> s2cMessages = [];
      final List<Map<String, dynamic>> normalMessages = [];

      for (final msgData in messages) {
        final rawMsgId = msgData['msg_id'] ?? msgData['id'];
        final msgId = rawMsgId?.toString() ?? '';
        // 优化类型处理，确保类型标准化
        String type = (msgData['type'] ?? 'C2C').toString().toUpperCase();
        // 处理可能的类型别名
        switch (type) {
          case 'C2C_SERVER_ACK':
            type = 'C2C';
            break;
          case 'C2G_SERVER_ACK':
            type = 'C2G';
            break;
          case 'S2C_SERVER_ACK':
            type = 'S2C';
            break;
        }

        if (msgId.isEmpty) {
          iPrint("离线消息缺少id，跳过: ${msgData.toString()}");
          continue;
        }

        // S2C 消息是系统消息，不应该插入数据库
        if (type == 'S2C') {
          s2cMessages.add(msgData);
          addAckId(msgId);
          continue;
        }

        normalMessages.add(msgData);
      }

      // 处理普通消息（插入数据库）
      await _db.transaction((txn) async {
        for (final msgData in normalMessages) {
          final rawMsgId = msgData['msg_id'] ?? msgData['id'];
          final msgId = rawMsgId?.toString() ?? '';
          String type = (msgData['type'] ?? 'C2C').toString().toUpperCase();

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

          // 验证 payload 有效性：必须包含 msg_type 字段
          if (!payload.containsKey('msg_type') || payload.isEmpty) {
            iPrint("离线消息 payload 无效或为空，跳过: $msgId, payload: $payload");
            addAckId(msgId); // 仍然需要 ACK，避免服务端重复推送
            continue;
          }

          final fromId = (msgData['from'] ?? '').toString();
          final toId = (msgData['to'] ?? '').toString();
          final createdAt = _parseCreatedAt(msgData['created_at']);
          final topicId =
              int.tryParse((msgData['topic_id'] ?? 0).toString()) ?? 0;

          // 确定消息方向（是否为作者）
          String currentUid = UserRepoLocal.to.currentUid;
          bool isAuthor = fromId == currentUid;

          // 构建会话UK3
          String peerId = '';
          if (type == 'C2G') {
            peerId = toId;
            if (peerId.isEmpty) {
              peerId = (payload['group_id'] ?? payload['groupId'] ?? '')
                  .toString();
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
            // v2.0 新增字段
            MessageRepo.msgType: payload['msg_type'] ?? '',
            MessageRepo.action: type == 'S2C' ? (payload['action'] ?? '') : '',
            MessageRepo.e2ee: payload['e2ee'] != null ? json.encode(payload['e2ee']) : '',
          };

          await txn.insert(tableName, insertData);

          inserted.add(
            _InsertedOfflineMessage(
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
            ),
          );

          addAckId(msgId);

          iPrint(
            "离线消息插入成功: $msgId, type: $type, conversation: $conversationUk3",
          );
        }
      });

      if (inserted.isNotEmpty) {
        await _syncOfflineConversationsAndNotify(inserted);
      }
      // 处理 S2C 消息（在事务外）
      // 处理 S2C 消息（在事务外）
      if (s2cMessages.isNotEmpty && onS2CMessage != null) {
        iPrint("开始处理 ${s2cMessages.length} 条 S2C 消息");
        for (final msgData in s2cMessages) {
          try {
            // 调用回调函数处理 S2C 消息
            await onS2CMessage(msgData);
          } catch (e) {
            iPrint("处理 S2C 消息失败: ${msgData['id']}, 错误: $e");
          }
        }
      }
    } catch (e) {
      iPrint("批量插入离线消息失败: $e");
      return ackMsgIds;
    }
    return null;
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

  Future<void> _syncOfflineConversationsAndNotify(
    List<_InsertedOfflineMessage> inserted,
  ) async {
    final conversationRepo = ConversationRepo();
    final contactRepo = ContactRepo();
    final groupRepo = GroupRepo();

    // 使用 ProviderContainer 访问 Riverpod Provider
    final container = ProviderContainer();
    final conversationNotifier = container.read(conversationProvider.notifier);

    // 获取当前会话 ID - 使用静态字段跟踪当前活动会话
    // 注意：如果没有打开的聊天页面，currentConversationUk3 将为空
    final String currentConversationUk3 = _currentActiveConversationUk3 ?? '';

    final Map<String, _OfflineConversationAgg> convAgg = {};
    for (final msg in inserted) {
      final key = '${msg.type}::${msg.peerId}';
      final agg = convAgg.putIfAbsent(
        key,
        () => _OfflineConversationAgg(type: msg.type, peerId: msg.peerId),
      );
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
      final existing = await conversationRepo.findByPeerId(
        agg.type,
        agg.peerId,
      );

      ConversationModel conv;
      if (existing == null) {
        // 创建新会话时确保设置所有必要字段
        conv = ConversationModel(
          id: 0,
          peerId: agg.peerId,
          avatar: avatar,
          title: title,
          subtitle: preview.subtitle,
          type: agg.type,
          msgType: preview.msgType,
          lastMsgId: latest.id,
          lastTime: latest.createdAt,
          unreadNum: agg.unreadDelta, // 使用计算出的未读数
          payload: {},
          isShow: 1,
        );
        conv.id = await conversationRepo.insert(conv);
        iPrint("创建新会话: ${conv.toJson()}, 未读数: ${agg.unreadDelta}");
      } else {
        // 更新现有会话，总是更新最后消息信息
        int newUnreadNum = existing.unreadNum + agg.unreadDelta;
        await conversationRepo.updateById(existing.id, {
          ConversationRepo.avatar: avatar.isNotEmpty ? avatar : existing.avatar,
          ConversationRepo.title: title.isNotEmpty ? title : existing.title,
          ConversationRepo.subtitle: preview.subtitle,
          ConversationRepo.msgType: preview.msgType,
          ConversationRepo.lastMsgId: latest.id,
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.unreadNum: newUnreadNum,
          ConversationRepo.isShow: 1,
        });

        // 重新获取更新后的会话
        conv = (await conversationRepo.findById(existing.id)) ?? existing;
        iPrint(
          "更新会话: ${conv.toJson()}, 新增未读数: ${agg.unreadDelta}, 总未读数: $newUnreadNum",
        );
      }

      // 触发会话列表刷新 - 多重保障
      AppEventBus.fireData(conv); // 全局事件

      // 更新会话逻辑中的内存映射
      // 使用 Riverpod Provider
      await conversationNotifier.replace(conv);

      // 更新未读数
      if (agg.unreadDelta > 0) {
        await conversationNotifier.increaseConversationRemind(
          conv,
          agg.unreadDelta,
        );
      }

      iPrint("已更新会话列表: ${conv.uk3}, 未读数增加: ${agg.unreadDelta}");
    }

    if (currentConversationUk3.isNotEmpty) {
      for (final msg in inserted) {
        if (msg.conversationUk3 != currentConversationUk3) continue;
        try {
          AppEventBus.fireData(
            await msg.toMessageModel().toTypeMessage(),
            'Message',
          );
        } catch (_) {}
      }
    }
  }

  static ({String msgType, String subtitle}) _derivePreview(
    Map<String, dynamic> payload,
  ) {
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

        if (oldUk3 == null ||
            oldUk3.isEmpty ||
            fromId == null ||
            toId == null) {
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

  /// 从多个表（msg_c2c、msg_c2g）查询消息
  /// 按创建时间排序返回
  ///
  /// 参数:
  /// - [conversationUk3]: 会话 UK3（可选）
  /// - [limit]: 返回的最大消息数量（默认 20）
  /// - [offset]: 偏移量（默认 0）
  /// - [startTime]: 开始时间戳（可选）
  /// - [endTime]: 结束时间戳（可选）
  ///
  /// 返回: 消息列表，按创建时间降序排列
  static Future<List<MessageModel>> getMessages({
    String? conversationUk3,
    int limit = 20,
    int offset = 0,
    int? startTime,
    int? endTime,
  }) async {
    try {
      final db = SqliteService.to;
      final List<MessageModel> allMessages = [];

      // 从 msg_c2c 表查询
      final c2cMessages = await _getMessagesFromTable(
        db,
        c2cTable,
        conversationUk3: conversationUk3,
        limit: limit,
        offset: offset,
        startTime: startTime,
        endTime: endTime,
      );
      allMessages.addAll(c2cMessages);

      // 从 msg_c2g 表查询
      final c2gMessages = await _getMessagesFromTable(
        db,
        c2gTable,
        conversationUk3: conversationUk3,
        limit: limit,
        offset: offset,
        startTime: startTime,
        endTime: endTime,
      );
      allMessages.addAll(c2gMessages);

      // 按创建时间降序排序
      allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 应用 limit
      if (allMessages.length > limit) {
        return allMessages.sublist(0, limit);
      }

      return allMessages;
    } catch (e) {
      debugPrint("MessageRepo getMessages error: $e");
      return [];
    }
  }

  /// 从单个表查询消息
  static Future<List<MessageModel>> _getMessagesFromTable(
    SqliteService db,
    String table, {
    String? conversationUk3,
    int limit = 20,
    int offset = 0,
    int? startTime,
    int? endTime,
  }) async {
    try {
      String where = "1=1";
      List<Object?> whereArgs = [];

      if (strNoEmpty(conversationUk3)) {
        where = "$where AND ${MessageRepo.conversationUk3}=?";
        whereArgs.add(conversationUk3);
      }

      if (startTime != null) {
        where = "$where AND ${MessageRepo.createdAt} >= ?";
        whereArgs.add(startTime);
      }

      if (endTime != null) {
        where = "$where AND ${MessageRepo.createdAt} <= ?";
        whereArgs.add(endTime);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        table,
        columns: defaultColumns,
        where: where,
        whereArgs: whereArgs,
        orderBy: "${MessageRepo.createdAt} DESC",
        limit: limit,
        offset: offset,
      );

      final List<MessageModel> messages = [];
      for (final map in maps) {
        messages.add(MessageModel.fromJson(map));
      }

      return messages;
    } catch (e) {
      debugPrint("_getMessagesFromTable error: $e, table: $table");
      return [];
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
