import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' as func_helper;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message_conversation_utils.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageRepo implements MessageRepository {
  // v2.0 表名常量（与服务端保持一致）
  static const String c2cTable = 'msg_c2c';
  static const String c2gTable = 'msg_c2g';
  static const String c2sTable = 'msg_c2s';
  static const String s2cTable = 'msg_s2c';

  static const String autoId = 'auto_id';
  static const String id = 'id'; // message_id

  // C2C C2G C2C_REVOKE_ACK C2G_REVOKE_ACK
  static const String type = 'type';
  static const String from = 'from_id';
  static const String to = 'to_id';
  static const String payload = 'payload';
  static const String createdAt = 'created_at';

  // varchar(80)
  static const String conversationUk3 = 'conversation_uk3';
  static const String status = 'status';

  // from id is author bool true | false
  static const String isAuthor = 'is_author';
  static const String topicId = 'topic_id';

  // v2.0 新增字段（从 payload 中提取到顶层）
  static const String msgType =
      'msg_type'; // 消息类型：text, image, voice, video, file 等
  static const String action = 'action'; // S2C 消息指令
  static const String e2ee = 'e2ee'; // 端到端加密信息（JSON 字符串）

  static final List<String> defaultColumns = List.unmodifiable([
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
    msgType, // v2.0 新增
    action, // v2.0 新增
    e2ee, // v2.0 新增
  ]);

  // 共享 ProviderContainer — 必须通过 setProviderContainer 注入，否则 UI 状态不同步
  // 初始值为 null，防止创建与根容器状态不同步的孤立容器
  static ProviderContainer? _providerContainer;

  /// 注入应用级 ProviderContainer（由 MessageService.setProviderContainer 级联调用）
  static void setProviderContainer(ProviderContainer container) {
    _providerContainer = container;
  }

  /// 获取已注入的容器，未注入时抛出断言错误
  static ProviderContainer get _container {
    assert(
      _providerContainer != null,
      'MessageRepo: ProviderContainer 未注入，请先调用 setProviderContainer',
    );
    return _providerContainer!;
  }

  // 当前活动的会话 UK3（用于离线消息同步时判断是否需要触发消息事件）
  static String? _currentActiveConversationUk3;

  /// 设置当前活动的会话 UK3
  /// 由聊天页面在打开/关闭时调用
  static void setCurrentActiveConversationUk3(String? uk3) {
    _currentActiveConversationUk3 = uk3;
  }

  /// 获取当前活动的会话 UK3
  static String? get currentActiveConversationUk3 =>
      _currentActiveConversationUk3;

  final SqliteService _db = SqliteService.to;

  @override
  final String tableName;

  MessageRepo({required this.tableName}) {
    // 验证表名是否合法
    if (!_isTableAllowed(tableName)) {
      throw ArgumentError('Invalid table name: $tableName');
    }
  }

  /// 获取实际使用的表名。
  /// 项目未发布，统一使用当前版本标准表名。
  @override
  Future<String> getActualTableName() async {
    return tableName;
  }

  // 数据验证：验证必填字段
  bool _validateMessageData(MessageModel msg) {
    // 验证 ID 不为空
    if (msg.id.isEmpty) {
      return false;
    }

    // 验证 fromId 和 toId
    if (msg.fromId == 0) {
      return false;
    }

    if (msg.toId == 0) {
      return false;
    }

    // 验证 conversationUk3
    if (msg.conversationUk3.isEmpty) {
      return false;
    }

    // 验证时间戳在合理范围内 (2000-01-01 到 2100-01-01)
    if (msg.createdAt < 946684800000 || msg.createdAt > 4102444800000) {
      return false;
    }

    // 验证状态值
    if (msg.status != null && (msg.status! < 0 || msg.status! > 100)) {
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
    // func_helper.iPrint("> rtc msg S_RECEIVED:$res");
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

  /// 跨表更新消息状态（遍历 C2C/C2G/C2S 查找消息并更新）
  ///
  /// 返回 true 表示找到并更新成功，false 表示未找到
  static Future<bool> updateStatusInAnyTable(
    String messageId,
    int status,
  ) async {
    for (final tableType in ['C2C', 'C2G', 'C2S']) {
      final tb = getTableName(tableType);
      final repo = MessageRepo(tableName: tb);
      final msg = await repo.find(messageId);
      if (msg != null) {
        await repo.update({'id': messageId, MessageRepo.status: status});
        msg.status = status;
        return true;
      }
    }
    return false;
  }

  // 插入一条数据
  @override
  Future<MessageModel> insert(MessageModel msg, {Transaction? txn}) async {
    // 数据验证
    if (!_validateMessageData(msg)) {
      throw ArgumentError('Invalid message data');
    }

    // 使用 getTableName 获取表名（支持 v2.0 新表名）
    final msgType = (msg.type?.isNotEmpty == true)
        ? msg.type!
        : 'C2C'; // 默认为 C2C
    final targetTableName = MessageRepo.getTableName(msgType);

    int? count;
    if (txn != null) {
      count = await txn
          .rawQuery(
            'SELECT COUNT(*) as count FROM $targetTableName WHERE id = ?',
            [msg.id],
          )
          .then((result) => result.first['count'] as int?);
    } else {
      count = await _db.count(
        targetTableName,
        where: "id=?",
        whereArgs: [msg.id],
      );
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
      if (kDebugMode) {}
      if (txn != null) {
        await txn.insert(targetTableName, insert);
      } else {
        await _db.insert(targetTableName, insert);
      }

      // 同步写入 FTS 索引（异步，不阻塞消息插入）
      unawaited(
        _indexMessageToFts(
          type: msgType,
          id: msg.id,
          conversationUk3: msg.conversationUk3,
          msgTypeField: msg.msgType ?? '',
          payload: msg.payload as Map<String, dynamic>,
        ),
      );
    } else {
      if (kDebugMode) {}
    }
    return msg;
  }

  // 更新信息
  @override
  Future<int> update(Map<String, dynamic> data, {Transaction? txn}) async {
    // payload: Map -> JSON 字符串
    if (data.containsKey(MessageRepo.payload) &&
        data[MessageRepo.payload] is Map<String, dynamic>) {
      data[MessageRepo.payload] = jsonEncode(data[MessageRepo.payload]);
    }
    // e2ee: Map -> JSON 字符串（数据库存储需要字符串格式）
    if (data.containsKey(MessageRepo.e2ee) &&
        data[MessageRepo.e2ee] is Map<String, dynamic>) {
      data[MessageRepo.e2ee] = jsonEncode(data[MessageRepo.e2ee]);
    }
    // 移除主键 id，因为 SQLite 不允许更新主键
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove(MessageRepo.id);
    updateData.remove(MessageRepo.autoId);

    func_helper.iPrint("message_repo/update $tableName ;");
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

  /// 【新增 H3】带条件的更新操作（CAS - Compare-And-Set）
  ///
  /// 用于防止竞态条件，只更新符合特定条件的记录
  ///
  /// [data] 要更新的数据
  /// [where] WHERE 子句
  /// [whereArgs] WHERE 参数
  /// [txn] 可选的事务对象
  ///
  /// 返回更新的行数（如果为 0，说明没有符合条件的记录）
  @override
  Future<int> updateWithConditions(
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
    Transaction? txn,
  }) async {
    // payload: Map -> JSON 字符串
    if (data.containsKey(MessageRepo.payload) &&
        data[MessageRepo.payload] is Map<String, dynamic>) {
      data[MessageRepo.payload] = jsonEncode(data[MessageRepo.payload]);
    }
    // e2ee: Map -> JSON 字符串
    if (data.containsKey(MessageRepo.e2ee) &&
        data[MessageRepo.e2ee] is Map<String, dynamic>) {
      data[MessageRepo.e2ee] = jsonEncode(data[MessageRepo.e2ee]);
    }
    // 移除主键 id
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove(MessageRepo.id);
    updateData.remove(MessageRepo.autoId);

    func_helper.iPrint(
      "message_repo/updateWithConditions $tableName ; where: $where",
    );
    if (txn != null) {
      return await txn.update(
        tableName,
        updateData,
        where: where,
        whereArgs: whereArgs,
      );
    } else {
      return await _db.update(
        tableName,
        updateData,
        where: where,
        whereArgs: whereArgs,
      );
    }
  }

  // 存在就更新，不存在就插入
  @override
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

  @override
  Future<List<MessageModel>> pageForConversation(
    String uk3,
    int nextAutoId,
    int size,
  ) async {
    String where;
    List<dynamic> args;
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
    } on Object {
      return [];
    }
  }

  /// 加载较新的消息（用于双向分页）
  @override
  Future<List<MessageModel>> pageNewerForConversation(
    String uk3,
    int prevAutoId,
    int size,
  ) async {
    String where;
    List<dynamic> args;

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
    } on Object {
      return [];
    }
  }

  @override
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

    if (func_helper.strNoEmpty(kwd)) {
      kwd = kwd!.trim();
      String pattern = "%$kwd%";
      // 搜索 payload 中的 text 字段，使用参数化查询防止 SQL 注入
      where = "$where AND json_extract(payload, '\$.text') LIKE ?";
      whereArgs.add(pattern);
    }

    if (func_helper.strNoEmpty(conversationUk3)) {
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
    if (func_helper.strNoEmpty(senderId)) {
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

    func_helper.iPrint("searchLeading_tag kwd $kwd, where $where");

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

      if (maps.isEmpty) {
        return [];
      }

      List<MessageModel> messages = [];
      for (int i = 0; i < maps.length; i++) {
        messages.add(MessageModel.fromJson(maps[i]));
      }
      return messages;
    } on Object {
      return [];
    }
  }

  /// 创建搜索索引
  @override
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
    } on Object catch (e) {
      func_helper.iPrint('[message_repo_sqlite] execute error: $e');
      // TODO(error-handling): 高危路径，评估是否应 rethrow/上报
    }
  }

  //
  @override
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
    // func_helper.iPrint("> on MessageRepo/find tb $tableName, id $id, len ${maps.length}; ${maps.toList().toString()}");
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  @override
  Future<int> delete(String id) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.id} = ?',
      whereArgs: [id],
    );
  }

  // 根据UID删除信息
  @override
  Future<int> deleteByUid(String uid) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.from} = ? or ${MessageRepo.to} = ?',
      whereArgs: [uid, uid],
    );
  }

  /// 根据状态查找消息
  /// Find messages by status.
  @override
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
  @override
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

  @override
  Future<int> deleteByConversationId(String uk3) async {
    return await _db.delete(
      tableName,
      where: '${MessageRepo.conversationUk3} = ?',
      whereArgs: [uk3],
    );
  }

  @override
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
  @override
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
          func_helper.iPrint("离线消息缺少id，跳过: ${msgData.toString()}");
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
            func_helper.iPrint("离线消息type不支持，跳过: $type");
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
            func_helper.iPrint("离线消息已存在，跳过: $msgId");
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
            } on Object catch (e) {
              func_helper.iPrint('[message_repo_sqlite] decode error: $e');
              // TODO(error-handling): 高危路径，评估是否应 rethrow/上报
            }
          }

          // WebSocket API v2.0: msg_type/action/e2ee 在顶层，不在 payload 内
          // 获取顶层字段
          var msgType = (msgData['msg_type'] ?? '').toString();

          if (kDebugMode) {
            func_helper.iPrint(
              '🔍 [DEBUG 离线消息] 原始数据: msgId=$msgId, msgData[\'msg_type\']="${msgData['msg_type']}", payload keys=${payload.keys.toList()}',
            );
          }

          // 【重构】使用 MessageTypeNormalizer 做类型合法性校验
          msgType = MessageTypeNormalizer.normalize(
            msgType: msgType,
            payload: payload,
          );

          if (kDebugMode) {
            func_helper.iPrint('🔍 [DEBUG 离线消息] 归一化后: msgType="$msgType"');
          }
          final action = (msgData['action'] ?? '').toString();
          final e2ee = msgData['e2ee'];

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
            func_helper.iPrint("离线消息缺少peerId，跳过: $msgId, type: $type");
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
            // v2.0 新增字段 - 从消息顶层获取（不在 payload 内）
            // 所有消息类型都应包含这三个字段
            MessageRepo.msgType: msgType,
            MessageRepo.action: action, // ✅ 修复：所有类型都写入 action
            MessageRepo.e2ee: e2ee != null ? json.encode(e2ee) : '',
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
              msgType: msgType, // WebSocket API v2.0: 从顶层字段读取
            ),
          );

          addAckId(msgId);

          func_helper.iPrint(
            "离线消息插入成功: $msgId, type: $type, conversation: $conversationUk3",
          );
        }
      });

      if (inserted.isNotEmpty) {
        // 批量写入 FTS 索引（异步，不阻塞离线消息处理）
        for (final msg in inserted) {
          unawaited(
            _indexMessageToFts(
              type: msg.type,
              id: msg.id,
              conversationUk3: msg.conversationUk3,
              msgTypeField: msg.msgType,
              payload: msg.payload,
            ),
          );
        }

        await _syncOfflineConversationsAndNotify(inserted);
      }
      // 处理 S2C 消息（在事务外）
      // 处理 S2C 消息（在事务外）
      if (s2cMessages.isNotEmpty && onS2CMessage != null) {
        func_helper.iPrint("开始处理 ${s2cMessages.length} 条 S2C 消息");
        for (final msgData in s2cMessages) {
          try {
            // 调用回调函数处理 S2C 消息
            await onS2CMessage(msgData);
          } on Object catch (e) {
            func_helper.iPrint("处理 S2C 消息失败: ${msgData['id']}, 错误: $e");
          }
        }
      }
    } on Object catch (e) {
      func_helper.iPrint("批量插入离线消息失败: $e");
      return null;
    }
    return ackMsgIds;
  }

  static int _parseCreatedAt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    final s = raw.toString();
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    try {
      return DateTimeHelper.rfc3339ToMillisecond(s);
    } on Object {
      return 0;
    }
  }

  Future<void> _syncOfflineConversationsAndNotify(
    List<_InsertedOfflineMessage> inserted,
  ) async {
    final conversationRepo = ConversationRepo();
    final contactRepo = ContactRepo();
    final groupRepo = GroupRepo();

    final conversationNotifier = _container.read(conversationProvider.notifier);

    // 获取当前会话 ID - 使用静态字段跟踪当前活动会话
    // 注意：如果没有打开的聊天页面，currentConversationUk3 将为空
    final String currentConversationUk3 = _currentActiveConversationUk3 ?? '';

    final Map<String, _OfflineConversationAgg> convAgg = {};
    final currentUid = UserRepoLocal.to.currentUid; // C7-β
    for (final msg in inserted) {
      final key = '${msg.type}::${msg.peerId}';
      final agg = convAgg.putIfAbsent(
        key,
        () => _OfflineConversationAgg(
          type: msg.type,
          peerId: msg.peerId,
          currentUid: currentUid,
        ),
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
      } on Object catch (e) {
        func_helper.iPrint('[message_repo_sqlite] findByUid error: $e');
        // TODO(error-handling): 高危路径，评估是否应 rethrow/上报
      }

      // WebSocket API v2.0: 从顶层字段读取 msg_type 和 status
      if (kDebugMode) {
        func_helper.iPrint(
          '🔍 [DEBUG 会话同步] latest.msgType="${latest.msgType}", latest.status=${latest.status}, payload keys=${latest.payload.keys.toList()}',
        );
      }
      final preview = _derivePreview(
        latest.msgType,
        latest.status,
        latest.payload,
      );
      final existing = await conversationRepo.findByPeerId(
        agg.type,
        agg.peerId,
      );

      ConversationModel conv;
      if (existing == null) {
        // 创建新会话时确保设置所有必要字段
        conv = ConversationModel(
          id: 0,
          peerId: parseModelInt(agg.peerId),
          avatar: avatar,
          title: title,
          subtitle: preview.subtitle,
          type: agg.type,
          msgType: preview.msgType,
          lastMsgId: parseModelInt(latest.id),
          lastTime: latest.createdAt,
          lastMsgStatus: latest.status, // 传递消息状态
          unreadNum: agg.unreadDelta, // 使用计算出的未读数
          mentionUnread: agg.mentionDelta, // C7-β
          payload: {},
          isShow: 1,
        );
        conv.id = await conversationRepo.insert(conv);
        func_helper.iPrint("创建新会话: ${conv.toJson()}, 未读数: ${agg.unreadDelta}");
      } else {
        // 更新现有会话，总是更新最后消息信息
        int newUnreadNum = existing.unreadNum + agg.unreadDelta;
        int newMentionUnread =
            existing.mentionUnread + agg.mentionDelta; // C7-β
        await conversationRepo.updateById(existing.id, {
          ConversationRepo.avatar: avatar.isNotEmpty ? avatar : existing.avatar,
          ConversationRepo.title: title.isNotEmpty ? title : existing.title,
          ConversationRepo.subtitle: preview.subtitle,
          ConversationRepo.msgType: preview.msgType,
          ConversationRepo.lastMsgId: parseModelInt(latest.id),
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.lastMsgStatus: latest.status, // 传递消息状态
          ConversationRepo.unreadNum: newUnreadNum,
          ConversationRepo.mentionUnread: newMentionUnread, // C7-β
          ConversationRepo.isShow: 1,
        });

        // 重新获取更新后的会话
        conv = (await conversationRepo.findById(existing.id)) ?? existing;
        func_helper.iPrint(
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

      func_helper.iPrint("已更新会话列表: ${conv.uk3}, 未读数增加: ${agg.unreadDelta}");
    }

    if (currentConversationUk3.isNotEmpty) {
      for (final msg in inserted) {
        if (msg.conversationUk3 != currentConversationUk3) continue;
        try {
          AppEventBus.fireData(
            await msg.toMessageModel().toTypeMessage(),
            'Message',
          );
        } on Object catch (e) {
          func_helper.iPrint('[message_repo_sqlite] toMessageModel error: $e');
          // TODO(error-handling): 高危路径，评估是否应 rethrow/上报
        }
      }
    }
  }

  /// WebSocket API v2.0: 根据消息 status 和 payload 生成会话预览
  ///
  /// 方案 D: 检查 status 字段（30=peer_revoked, 31=my_revoked）
  static ({String msgType, String subtitle}) _derivePreview(
    String msgType,
    int? status,
    Map<String, dynamic> payload,
  ) {
    // 【重构】使用 MessageTypeNormalizer 做类型合法性校验
    final effectiveMsgType = MessageTypeNormalizer.normalize(
      msgType: msgType,
      payload: payload,
    );

    if (kDebugMode) {
      func_helper.iPrint(
        '🔍 [DEBUG _derivePreview] 输入: msgType="$msgType", effective=$effectiveMsgType',
      );
    }

    // 方案 D: 检查 status 字段（撤回状态 30-39）
    if (IMBoyMessageStatus.isRevokedStatus(status)) {
      // status = 30 (peer_revoked) 或 31 (my_revoked)
      // 保留原始 msg_type，让会话列表知道原始内容类型
      if (status == IMBoyMessageStatus.peerRevoked) {
        return (
          msgType: msgType,
          subtitle: '[${t.common.otherRevokedMessage}]',
        );
      } else {
        return (msgType: msgType, subtitle: '[${t.common.youRevokedMessage}]');
      }
    }

    // 【简化】使用 effectiveMsgType 判断内容类型
    String subtitle;
    switch (effectiveMsgType) {
      case 'text':
        subtitle = (payload['text'] ?? '').toString();
        break;
      case 'quote':
        subtitle = (payload['quote_text'] ?? '').toString();
        break;
      case 'location':
        subtitle = (payload['title'] ?? '[位置]').toString();
        break;
      case 'image':
        subtitle = '[图片]';
        break;
      case 'imageMulti':
        subtitle = '[多图]';
        break;
      case 'voice':
        subtitle = '[语音]';
        break;
      case 'video':
        subtitle = '[视频]';
        break;
      case 'file':
        final filename = payload['filename']?.toString() ?? '';
        final name = payload['name']?.toString() ?? '';
        subtitle = filename.isNotEmpty
            ? filename
            : (name.isNotEmpty ? name : '[文件]');
        break;
      case 'webrtcAudio':
      case 'webrtcVideo':
        subtitle = '[通话]';
        break;
      case 'visitCard':
        subtitle = '[名片]';
        break;
      case 'system':
        subtitle = '[系统消息]';
        break;
      default:
        // 未知类型，尝试从 text 字段获取
        subtitle = (payload['text'] ?? '[消息]').toString();
        break;
    }

    if (kDebugMode) {
      func_helper.iPrint(
        '🔍 [DEBUG _derivePreview] 返回: msgType=$effectiveMsgType, subtitle=$subtitle',
      );
    }
    return (msgType: effectiveMsgType, subtitle: subtitle);
  }

  /// 将消息写入 FTS 索引（fire-and-forget，不阻塞主流程）
  static Future<void> _indexMessageToFts({
    required String type,
    required String id,
    required String conversationUk3,
    required String msgTypeField,
    required Map<String, dynamic> payload,
  }) async {
    final textContent = MessageFtsRepo.extractTextContent(
      msgTypeField,
      payload,
    );
    if (textContent.isEmpty) return;

    // 确定 FTS 表类型
    final ftsType = type.toUpperCase();
    if (ftsType != 'C2C' && ftsType != 'C2G') return;

    await MessageFtsRepo().indexMessage(
      type: ftsType,
      id: id,
      conversationUk3: conversationUk3,
      textContent: textContent,
    );
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }

  /// ============================================
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
    } on Object {
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

      if (func_helper.strNoEmpty(conversationUk3)) {
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
    } on Object {
      return [];
    }
  }

  /// 计算与某个用户的消息数量
  ///
  /// [peerId] 对方用户 ID
  /// [since] 起始时间戳（毫秒），可选
  /// Returns: 消息数量
  @override
  Future<int> countMessagesWithUser(String peerId, {int? since}) async {
    try {
      int total = 0;

      // 遍历所有消息表
      for (final table in [c2cTable, c2gTable]) {
        String where = '(${MessageRepo.from} = ? OR ${MessageRepo.to} = ?)';
        List<Object?> whereArgs = [peerId, peerId];

        if (since != null) {
          where = '$where AND ${MessageRepo.createdAt} >= ?';
          whereArgs.add(since ~/ 1000); // 转换为秒
        }

        final count = await _db.pluck<int>(
          "COUNT(*) as count",
          table,
          where: where,
          whereArgs: whereArgs,
        );

        total += count ?? 0;
      }

      return total;
    } on Object {
      return 0;
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
  final String msgType; // WebSocket API v2.0: 顶层 msg_type 字段

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
    required this.msgType, // WebSocket API v2.0
  });

  MessageModel toMessageModel() {
    return MessageModel(
      id,
      autoId: 0,
      type: type,
      fromId: parseModelInt(fromId),
      toId: parseModelInt(toId),
      payload: payload,
      createdAt: createdAt,
      isAuthor: isAuthor,
      topicId: topicId,
      conversationUk3: conversationUk3,
      status: status,
      msgType: msgType, // WebSocket API v2.0
    );
  }
}

class _OfflineConversationAgg {
  final String type;
  final String peerId;
  final String currentUid; // C7-β: 判定消息是否 @ 当前用户
  _InsertedOfflineMessage? latest;
  int unreadDelta = 0;
  int mentionDelta = 0; // C7-β

  _OfflineConversationAgg({
    required this.type,
    required this.peerId,
    this.currentUid = '',
  });

  void observe(_InsertedOfflineMessage msg, String currentConversationUk3) {
    if (latest == null || msg.createdAt >= (latest?.createdAt ?? 0)) {
      latest = msg;
    }
    if (msg.isAuthor == 0 && msg.conversationUk3 != currentConversationUk3) {
      unreadDelta += 1;
      // C7-β：离线批量路径对称累加 mention_unread
      final mentionIds = extractMentionIdsFromPayload(msg.payload);
      mentionDelta += computeMentionUnreadIncrement(
        isFromCurrentUser: false, // isAuthor == 0 保证非自己
        isUserInChat: false, // 路径前提保证不在当前会话
        mentionIds: mentionIds,
        currentUid: currentUid,
      );
    }
  }
}
