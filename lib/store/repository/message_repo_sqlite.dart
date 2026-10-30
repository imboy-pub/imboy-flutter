import 'package:imboy/store/repository/message_query_reader.dart';
import 'package:imboy/store/repository/message_repo_schema.dart';
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
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart'
    show ftsTextContentSql;
import 'package:synchronized/synchronized.dart';

class MessageRepo implements MessageRepository {
  static final _ftsReindexLock = Lock();
  final _ftsReindexTasks = <Future<void>>{};

  @visibleForTesting
  Future<void> waitForFtsReindexForTest() async {
    while (_ftsReindexTasks.isNotEmpty) {
      await Future.wait(_ftsReindexTasks.toList());
    }
  }

  // 表名/列名常量与 defaultColumns/c2cColumns 已拆至 message_repo_schema.dart；
  // 此处 static 转发（const 编译期内联，final 引用同一实例），保持既有
  // `MessageRepo.xxx` 调用面与导入兼容（W6 拆分，行为零变化）。
  static const String c2cTable = MessageRepoSchema.c2cTable;
  static const String c2gTable = MessageRepoSchema.c2gTable;
  static const String c2sTable = MessageRepoSchema.c2sTable;
  static const String s2cTable = MessageRepoSchema.s2cTable;

  static const String autoId = MessageRepoSchema.autoId;
  static const String id = MessageRepoSchema.id;
  static const String type = MessageRepoSchema.type;
  static const String from = MessageRepoSchema.from;
  static const String to = MessageRepoSchema.to;
  static const String payload = MessageRepoSchema.payload;
  static const String createdAt = MessageRepoSchema.createdAt;
  static const String conversationUk3 = MessageRepoSchema.conversationUk3;
  static const String status = MessageRepoSchema.status;
  static const String isAuthor = MessageRepoSchema.isAuthor;
  static const String topicId = MessageRepoSchema.topicId;
  static const String msgType = MessageRepoSchema.msgType;
  static const String action = MessageRepoSchema.action;
  static const String e2ee = MessageRepoSchema.e2ee;

  static final List<String> defaultColumns = MessageRepoSchema.defaultColumns;
  static final List<String> c2cColumns = MessageRepoSchema.c2cColumns;

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
    if (msg.fromId == '0') {
      return false;
    }

    if (msg.toId == '0') {
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

  // 验证表名是否在白名单中（白名单与映射逻辑在 MessageRepoSchema）
  static bool _isTableAllowed(String tableName) {
    return MessageRepoSchema.isTableAllowed(tableName);
  }

  static String getTableName(String type) =>
      MessageRepoSchema.getTableName(type);

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
    final session = UserRepoLocal.to;
    final ownerUid = session.currentUid;
    final generation = session.sessionGeneration;
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

      if (session.currentUid == ownerUid &&
          session.isCurrentSession(generation) &&
          !session.isClearingSession) {
        _scheduleFtsReindex(msg.id, targetTableName);
      }
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
    final bool ftsTracked =
        (tableName == MessageRepo.c2cTable ||
            tableName == MessageRepo.c2gTable) &&
        msgId.isNotEmpty &&
        (updateData.containsKey(MessageRepo.payload) ||
            updateData.containsKey(MessageRepo.status));
    // v37（<38）：FTS 索引全部经由会话守卫的延迟重索引任务维护，保证
    // 账号切换后零语句、事务内 FTS 可见性不变、回滚零残留。但 contentless
    // FTS 无法事后回查列值，清索引需要行更新**之前**的旧文本，因此这里
    // 仅预读旧值（best-effort，读不到时任务退化为按当前行值清理）。
    _FtsRowSnapshot? ftsOldRow;
    if (ftsTracked && txn == null) {
      ftsOldRow = await _ftsReadRowSnapshot(msgId);
    }
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
        ftsTracked &&
        session.currentUid == ownerUid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession) {
      _scheduleFtsReindex(
        msgId,
        tableName,
        oldText: ftsOldRow?.textContent,
        oldConversationUk3: ftsOldRow?.conversationUk3,
      );
    }
    return updatedRows;
  }

  /// 预读消息行旧值（清 contentless 索引行所需），失败返回 null。
  Future<_FtsRowSnapshot?> _ftsReadRowSnapshot(String msgId) async {
    try {
      final rows = await _db.rawQuery(
        'SELECT ${MessageRepo.autoId}, ${MessageRepo.payload}, '
        '${MessageRepo.msgType}, ${MessageRepo.conversationUk3} '
        'FROM $tableName WHERE ${MessageRepo.id} = ?',
        [msgId],
        false,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      Map<String, dynamic> payloadMap = {};
      final rawPayload = row[MessageRepo.payload];
      if (rawPayload is String && rawPayload.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawPayload);
          if (decoded is Map<String, dynamic>) payloadMap = decoded;
        } on Object {
          // 非法 JSON：按空 payload 处理
        }
      }
      return _FtsRowSnapshot(
        textContent: MessageFtsRepo.extractTextContent(
          row[MessageRepo.msgType]?.toString() ?? '',
          payloadMap,
        ),
        conversationUk3: row[MessageRepo.conversationUk3]?.toString() ?? '',
      );
    } on Object {
      // 预读失败不阻断更新；延迟任务退化为按更新后的行值清理。
      return null;
    }
  }

  /// 按消息行**旧值**清掉既有 FTS 索引行（必须在行删除之前调用）。
  ///
  /// v37 基线的 FTS5 表是 contentless：优先按 rowid 直接 DELETE（常规
  /// FTS5 表命中即删）；contentless 表 DELETE 命中行会抛错，此时回退为
  /// `'delete'` 命令并从消息行读取原 payload/msg_type/status（与 v38
  /// 触发器同源表达式，见 [ftsTextContentSql]）。全部为 best-effort：
  /// 失败仅记录，不阻断主写入。
  Future<void> _ftsRemoveStaleIndexEntry(String msgId) async {
    final ftsTable = '${tableName}_fts';
    final guard = '(SELECT user_version FROM pragma_user_version) < 38';
    try {
      final db = await _db.db;
      if (db == null) return;
      try {
        await db.rawUpdate(
          'DELETE FROM $ftsTable '
          'WHERE rowid = (SELECT ${MessageRepo.autoId} FROM $tableName '
          'WHERE ${MessageRepo.id} = ?) AND $guard',
          [msgId],
        );
        return;
      } on Object {
        // contentless 表命中已有行时 DELETE 会抛错 → 回退 'delete' 命令。
      }
      await db.rawUpdate(
        "INSERT INTO $ftsTable($ftsTable, rowid, id, conversation_uk3, text_content) "
        "SELECT 'delete', ${MessageRepo.autoId}, ${MessageRepo.id}, "
        '${MessageRepo.conversationUk3}, ${ftsTextContentSql('')} '
        'FROM $tableName WHERE ${MessageRepo.id} = ? AND $guard',
        [msgId],
      );
    } on Object catch (e) {
      AppLogger.error(
        '[message_repo_sqlite] FTS stale entry cleanup failed: '
        'errType=${e.runtimeType}',
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

  /// R07 phase1：按 msg_id 幂等补齐服务端权威排序事实（conv_seq /
  /// 首次 accepted_at）。
  ///
  /// 合同（R07-7 库层验证）：
  /// - 仅当对应列为 NULL 时写入传入值；已有值（含此前写入的可信接受值）
  ///   一律不覆盖；
  /// - 正文/密文（payload/e2ee）、附件引用、原始发送时间（created_at）、
  ///   status 等其余列**一律不动**；不触碰 conversation 表（**不重复增加
  ///   未读**）；行数不变（不插行不删行）；
  /// - 传入值必须来自可信 archive/offline/ACK 数据；本函数不校验来源，
  ///   也不回填 now（接线属 R07-wire）；
  /// - 幂等：重复调用结果一致（先读后判无可补字段即返回，不触碰库；
  ///   需要写入时用 COALESCE 仅补 NULL 列）。
  ///
  /// 返回 [ServerOrderBackfillResult]：rowExists=false 表示该 msg_id 在
  /// 本表无行（调用方应走正常落库路径而非补齐）。
  ///
  /// ## txn 语义（W8-B3，审查 P2 如实标注）
  ///
  /// - `txn != null`（**生产合同**）：读-判-写三步在调用方事务内原子完成。
  ///   生产唯一调用方 offline_message_writer 去重分支即此形态。
  /// - `txn == null`：**best-effort**——三步各自独立执行（读经 `_db`
  ///   禁缓存直查，写经 `_db.execute` 自动提交），跨连接并发下存在
  ///   "读到 NULL → 他人已补 → 再 COALESCE 写入"的交错窗口。因写入
  ///   本身是 COALESCE-only（仅补 NULL 列），并发交错最坏结果是重复
  ///   尝试同值写入，不会覆盖已有可信值；返回标志按本次读判+执行结果
  ///   给出，**不保证与并发写者的最终库状态一致**。该形态仅供测试/
  ///   诊断单点调用，不承担并发正确性。
  Future<ServerOrderBackfillResult> backfillServerOrderFacts({
    required String msgId,
    int? convSeq,
    int? acceptedAt,
    Transaction? txn,
  }) async {
    if (convSeq == null && acceptedAt == null) {
      throw ArgumentError(
        'backfillServerOrderFacts: convSeq/acceptedAt 至少提供一个，'
        '否则无补齐目标（拒绝空操作误用）',
      );
    }

    Future<List<Map<String, Object?>>> readRow() {
      final sel =
          'SELECT ${MessageColumns.convSeq} AS seq, '
          '${MessageColumns.acceptedAt} AS accepted '
          'FROM $tableName WHERE id = ? LIMIT 1';
      if (txn != null) return txn.rawQuery(sel, [msgId]);
      // 禁查询缓存：补齐判定必须读最新落库值
      return _db.rawQuery(sel, [msgId], false);
    }

    final rows = await readRow();
    if (rows.isEmpty) {
      return const ServerOrderBackfillResult(
        rowExists: false,
        convSeqApplied: false,
        acceptedAtApplied: false,
      );
    }
    final currentSeq = rows.first['seq'] as int?;
    final currentAccepted = rows.first['accepted'] as int?;
    final applySeq = convSeq != null && currentSeq == null;
    final applyAccepted = acceptedAt != null && currentAccepted == null;
    if (!applySeq && !applyAccepted) {
      // 幂等快速路径：无可补字段，不触碰库
      return ServerOrderBackfillResult(
        rowExists: true,
        convSeqApplied: false,
        acceptedAtApplied: false,
      );
    }

    // COALESCE 原子语义：仅 NULL 列接受新值；未传/已有值列保持不变
    final updateSql =
        'UPDATE $tableName SET '
        '${MessageColumns.convSeq} = COALESCE(${MessageColumns.convSeq}, ?), '
        '${MessageColumns.acceptedAt} = COALESCE(${MessageColumns.acceptedAt}, ?) '
        'WHERE id = ?';
    final updateArgs = [convSeq, acceptedAt, msgId];
    if (txn != null) {
      await txn.rawUpdate(updateSql, updateArgs);
    } else {
      await _db.execute(updateSql, updateArgs);
    }
    return ServerOrderBackfillResult(
      rowExists: true,
      convSeqApplied: applySeq,
      acceptedAtApplied: applyAccepted,
    );
  }

  @override
  Future<List<MessageModel>> pageForConversation(
    String uk3,
    int nextAutoId,
    int size,
  ) => _reader.pageForConversation(uk3, nextAutoId, size);

  Future<List<MessageModel>> pageContextForConversation(
    String uk3,
    int anchorAutoId,
    int size, {
    bool newer = false,
  }) =>
      _reader.pageContextForConversation(uk3, anchorAutoId, size, newer: newer);

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
    // 行删除**之前**清 FTS 索引：contentless 索引无法事后回查列值，
    // 'delete' 命令依赖行内旧 payload/msg_type/status 原值（见 v38 同源
    // 表达式）。best-effort，失败不阻断删除。
    if (tableName == MessageRepo.c2cTable ||
        tableName == MessageRepo.c2gTable) {
      await _ftsRemoveStaleIndexEntry(id);
    }
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
  }) {
    final session = UserRepoLocal.to;
    final ownerUid = session.currentUid;
    final generation = session.sessionGeneration;
    return OfflineMessageWriter(
      db: _db,
      getContainer: () => _container,
      activeConversation: () => _currentActiveConversationUk3,
      resolveTable: getTableName,
      indexMessage: (msg) async {
        if (session.currentUid != ownerUid ||
            !session.isCurrentSession(generation) ||
            session.isClearingSession) {
          return;
        }
        _scheduleFtsReindex(msg.id, getTableName(msg.type));
      },
      // W8-B4：注入本 repo 的权威顺序事实补齐实现，替代 writer 直接
      // import message_repo_sqlite（消除 repo 层循环依赖）。
      backfillServerOrderFacts: (msgId, {convSeq, acceptedAt, txn}) =>
          backfillServerOrderFacts(
            msgId: msgId,
            convSeq: convSeq,
            acceptedAt: acceptedAt,
            txn: txn,
          ),
    ).write(
      messages,
      onS2CMessage: onS2CMessage,
      trustedArchive: trustedArchive,
    );
  }

  void _scheduleFtsReindex(
    String id,
    String targetTable, {
    String? oldText,
    String? oldConversationUk3,
  }) {
    if (targetTable != c2cTable && targetTable != c2gTable) return;
    final task = _reindexFts(
      id,
      targetTable,
      oldText: oldText,
      oldConversationUk3: oldConversationUk3,
    );
    _ftsReindexTasks.add(task);
    unawaited(task.whenComplete(() => _ftsReindexTasks.remove(task)));
  }

  Future<void> _reindexFts(
    String id,
    String targetTable, {
    String? oldText,
    String? oldConversationUk3,
  }) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    bool isCurrent() =>
        session.currentUid == uid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    try {
      await _ftsReindexLock.synchronized(() async {
        if (!isCurrent()) return;
        final repo = targetTable == tableName
            ? this
            : MessageRepo(tableName: targetTable);
        final row = await repo.find(id);
        if (row == null || !isCurrent()) return;
        final ftsType = targetTable == MessageRepo.c2cTable ? 'C2C' : 'C2G';
        final textContent = MessageFtsRepo.extractTextContent(
          row.msgType ?? '',
          row.payloadMap,
        );
        // 撤回状态区间 (30..39)，与 v38 FTS 表达式保持一致
        final revoked =
            row.status != null && row.status! >= 30 && row.status! < 40;
        final fts = MessageFtsRepo();
        if (revoked || textContent.isEmpty) {
          // 撤回/无可索引文本：清掉既有索引行，而不是原样跳过
          // （否则撤回/清空后的消息仍然可被搜到）。contentless FTS 的
          // 'delete' 命令需要**建立索引时的原值**，因此优先使用行更新
          // 前预读的旧文本/旧会话键；预读缺失时退化为当前行值
          // （仅对"值未变"的撤回场景有效，旧文本已变的历史残留交由
          // v38 重建收敛）。
          await fts.removeFromIndex(
            type: ftsType,
            id: id,
            conversationUk3: oldConversationUk3 ?? row.conversationUk3,
            textContent: oldText ?? textContent,
            rowid: row.autoId,
          );
          return;
        }
        await fts.indexMessage(
          type: ftsType,
          id: id,
          conversationUk3: row.conversationUk3,
          textContent: textContent,
          rowid: row.autoId,
        );
      });
    } on Object catch (e) {
      AppLogger.error(
        '[message_repo_sqlite] FTS reindex after update failed: '
        'errType=${e.runtimeType}',
      );
    }
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

/// 行更新前预读的 FTS 相关旧值（contentless 索引清理依赖建索引时原值）。
class _FtsRowSnapshot {
  const _FtsRowSnapshot({
    required this.textContent,
    required this.conversationUk3,
  });

  /// 旧 payload/msg_type 抽取出的可索引文本。
  final String textContent;

  /// 旧会话键。
  final String conversationUk3;
}

/// [MessageRepo.backfillServerOrderFacts] 的结果（R07 phase1）。
class ServerOrderBackfillResult {
  const ServerOrderBackfillResult({
    required this.rowExists,
    required this.convSeqApplied,
    required this.acceptedAtApplied,
  });

  /// msg_id 在本表是否有行。
  final bool rowExists;

  /// 本次调用是否实际写入了 conv_seq（仅当列为 NULL 且传入了值）。
  final bool convSeqApplied;

  /// 本次调用是否实际写入了 accepted_at（仅当列为 NULL 且传入了值）。
  final bool acceptedAtApplied;

  @override
  String toString() =>
      'ServerOrderBackfillResult(rowExists: $rowExists, '
      'convSeqApplied: $convSeqApplied, acceptedAtApplied: $acceptedAtApplied)';
}
