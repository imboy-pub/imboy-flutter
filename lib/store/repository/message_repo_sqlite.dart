import 'package:imboy/store/repository/message_query_reader.dart';
import 'package:imboy/store/repository/offline_message_writer.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' as func_helper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/service/app_logger.dart';

class MessageRepo implements MessageRepository {
  final _ftsReindexTasks = <Future<void>>{};

  @visibleForTesting
  Future<void> waitForFtsReindexForTest() async {
    while (_ftsReindexTasks.isNotEmpty) {
      await Future.wait(_ftsReindexTasks.toList());
    }
  }

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

  /// C2C 专用读取列。sender_did 只存在于 msg_c2c，不能放进所有表的
  /// defaultColumns，否则 C2G/C2S 查询会因列不存在而失败。
  static final List<String> c2cColumns = List.unmodifiable([
    ...defaultColumns,
    MessageColumns.senderDid,
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
  MessageQueryReader get _reader => MessageQueryReader(
    db: _db,
    tableName: tableName,
    defaultColumns: defaultColumns,
    c2cColumns: c2cColumns,
  );

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
  /// 返回 true 表示当前会话找到并更新成功；未找到或会话失效返回 false。
  /// 会话失效时停止后续表更新，不回滚已开始的写入。
  static Future<bool> updateStatusInAnyTable(
    String messageId,
    int status,
  ) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    bool isCurrent() =>
        uid.isNotEmpty &&
        session.currentUid == uid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    if (!isCurrent()) return false;
    try {
      final db = SqliteService.to;
      for (final tableType in ['C2C', 'C2G', 'C2S']) {
        if (!isCurrent()) return false;
        final tb = getTableName(tableType);
        final updated = await db.update(
          tb,
          {MessageRepo.status: status},
          where: '${MessageRepo.id} = ?',
          whereArgs: [messageId],
        );
        if (!isCurrent()) return false;
        if (updated > 0) return true;
      }
      return false;
    } on Exception catch (e) {
      func_helper.iPrint(
        '[MessageRepo] updateStatusInAnyTable failed id=$messageId '
        'status=$status error=${e.runtimeType}',
      );
      return false;
    }
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
      if (targetTableName == MessageRepo.c2gTable &&
          msg.e2ee != null &&
          msg.senderDid != null &&
          msg.senderDid!.isNotEmpty) {
        insert[MessageRepo.e2ee] = jsonEncode({
          ...msg.e2ee!,
          MessageModel.localSenderDidKey: msg.senderDid,
        });
      }
      if (targetTableName == MessageRepo.c2cTable &&
          msg.senderDid != null &&
          msg.senderDid!.isNotEmpty) {
        insert[MessageColumns.senderDid] = msg.senderDid;
      }
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
          payload: msg.payloadMap,
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
    final session = UserRepoLocal.to;
    final ownerUid = session.currentUid;
    final generation = session.sessionGeneration;
    final updateData = Map<String, dynamic>.from(data);
    final targetId = updateData[MessageRepo.id];
    final msgId = targetId?.toString() ?? '';
    // payload: Map -> JSON 字符串
    if (updateData.containsKey(MessageRepo.payload) &&
        updateData[MessageRepo.payload] is Map<String, dynamic>) {
      updateData[MessageRepo.payload] = jsonEncode(
        updateData[MessageRepo.payload],
      );
    }
    // e2ee: Map -> JSON 字符串（数据库存储需要字符串格式）
    if (updateData.containsKey(MessageRepo.e2ee) &&
        updateData[MessageRepo.e2ee] is Map<String, dynamic>) {
      updateData[MessageRepo.e2ee] = jsonEncode(updateData[MessageRepo.e2ee]);
    }
    // 移除主键 id，因为 SQLite 不允许更新主键
    updateData.remove(MessageRepo.id);
    updateData.remove(MessageRepo.autoId);

    func_helper.iPrint("message_repo/update $tableName ;");
    final int updatedRows;
    if (txn != null) {
      updatedRows = await txn.update(
        tableName,
        updateData,
        where: '${MessageRepo.id} = ?',
        whereArgs: [targetId],
      );
    } else {
      updatedRows = await _db.update(
        tableName,
        updateData,
        where: '${MessageRepo.id} = ?',
        whereArgs: [targetId],
      );
    }
    // Re-read only after a successful write, retaining the original session.
    if (updatedRows > 0 &&
        updateData.containsKey(MessageRepo.payload) &&
        msgId.isNotEmpty &&
        session.currentUid == ownerUid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession) {
      final task = _reindexFtsAfterPayloadUpdate(msgId);
      _ftsReindexTasks.add(task);
      unawaited(task.whenComplete(() => _ftsReindexTasks.remove(task)));
    }
    return updatedRows;
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
  ) => _reader.pageForConversation(uk3, nextAutoId, size);
  @override
  Future<List<MessageModel>> pageNewerForConversation(
    String uk3,
    int prevAutoId,
    int size,
  ) => _reader.pageNewerForConversation(uk3, prevAutoId, size);
  @override
  Future<List<MessageModel>> page({
    required int page,
    required int size,
    String? kwd,
    String? conversationUk3,
    String? orderBy,
    List<String>? messageTypes,
    String? senderId,
    DateTime? startDate,
    DateTime? endDate,
  }) => _reader.page(
    page: page,
    size: size,
    kwd: kwd,
    conversationUk3: conversationUk3,
    orderBy: orderBy,
    messageTypes: messageTypes,
    senderId: senderId,
    startDate: startDate,
    endDate: endDate,
  );
  Future<List<MessageModel>> pageRetryCandidates({
    required List<int> statuses,
    required int limit,
    int? beforeCreatedAt,
    int? beforeAutoId,
  }) => _reader.pageRetryCandidates(
    statuses: statuses,
    limit: limit,
    beforeCreatedAt: beforeCreatedAt,
    beforeAutoId: beforeAutoId,
  );

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
    } on Object catch (e, s) {
      AppLogger.error('[message_repo_sqlite] execute error', e, s);
      rethrow;
    }
  }

  //
  @override
  Future<MessageModel?> find(String id, {Transaction? txn}) =>
      _reader.find(id, txn: txn);

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

  @override
  Future<List<MessageModel>> findByStatus(String conversationUk3, int status) =>
      _reader.findByStatus(conversationUk3, status);

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
  Future<MessageModel?> lastMsg() => _reader.lastMsg();

  @override
  Future<List<String>?> batchInsertOfflineMessages(
    List<Map<String, dynamic>> messages, {
    Future<void> Function(Map<String, dynamic>)? onS2CMessage,
    bool trustedArchive = false,
  }) => OfflineMessageWriter(
    db: _db,
    getContainer: () => _container,
    activeConversation: () => _currentActiveConversationUk3,
    resolveTable: getTableName,
    indexMessage: (msg) => _indexMessageToFts(
      type: msg.type,
      id: msg.id,
      conversationUk3: msg.conversationUk3,
      msgTypeField: msg.msgType,
      payload: msg.payload is Map<String, dynamic>
          ? msg.payload as Map<String, dynamic>
          : <String, dynamic>{},
    ),
  ).write(messages, onS2CMessage: onS2CMessage, trustedArchive: trustedArchive);

  /// 将消息写入 FTS 索引（fire-and-forget，不阻塞主流程）
  /// payload 更新后重索引 FTS（update 内异步触发，不阻塞主更新）。
  /// update 只有 id+payload，回读一行补齐 conversation_uk3/msg_type
  /// 后复用 [_indexMessageToFts]；索引函数自身幂等（先删后插）。
  Future<void> _reindexFtsAfterPayloadUpdate(String id) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    bool isCurrent() =>
        session.currentUid == uid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    try {
      if (!isCurrent()) return;
      final row = await find(id);
      if (row == null || !isCurrent()) return;
      final ftsType = tableName == MessageRepo.c2cTable
          ? 'C2C'
          : tableName == MessageRepo.c2gTable
          ? 'C2G'
          : '';
      if (ftsType.isEmpty) return;
      await _indexMessageToFts(
        type: ftsType,
        id: id,
        conversationUk3: row.conversationUk3,
        msgTypeField: row.msgType ?? '',
        payload: row.payloadMap,
      );
    } on Object catch (e) {
      AppLogger.error(
        '[message_repo_sqlite] FTS reindex after update failed: '
        'errType=${e.runtimeType}',
      );
    }
  }

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

  static Future<List<MessageModel>> getMessages({
    String? conversationUk3,
    int limit = 20,
    int offset = 0,
    int? startTime,
    int? endTime,
  }) =>
      MessageQueryReader(
        db: SqliteService.to,
        tableName: c2cTable,
        defaultColumns: defaultColumns,
        c2cColumns: c2cColumns,
      ).getMessages(
        conversationUk3: conversationUk3,
        limit: limit,
        offset: offset,
        startTime: startTime,
        endTime: endTime,
      );

  @override
  Future<int> countMessagesWithUser(String peerId, {int? since}) =>
      _reader.countMessagesWithUser(peerId, since: since);
}
