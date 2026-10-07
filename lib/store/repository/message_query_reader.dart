import 'package:imboy/component/helper/func.dart' as func_helper;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 消息读取、历史分页及搜索；写入与离线事务由仓储入口负责。
class MessageQueryReader {
  final SqliteService db;
  final String tableName;
  final List<String> defaultColumns;
  final List<String> c2cColumns;
  static const c2cTable = 'msg_c2c';
  static const c2gTable = 'msg_c2g';
  List<String> get _readColumns =>
      tableName == c2cTable ? c2cColumns : defaultColumns;
  const MessageQueryReader({
    required this.db,
    required this.tableName,
    required this.defaultColumns,
    required this.c2cColumns,
  });

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
      final count = await db.count(
        tableName,
        where: "${MessageColumns.conversationUk3} = ?",
        whereArgs: [uk3],
      );
      offset = (count != null && count > size) ? (count - size) : 0;
      where = "${MessageColumns.conversationUk3} = ?";
      args = [uk3];
    } else {
      // 加载比nextAutoId更早的消息
      where =
          "${MessageColumns.conversationUk3} = ? AND ${MessageColumns.autoId} < ?";
      args = [uk3, nextAutoId];
      offset = 0;
    }

    try {
      List<Map<String, dynamic>> maps = await db.query(
        tableName,
        columns: _readColumns,
        where: where,
        whereArgs: args,
        orderBy: "${MessageColumns.autoId} ASC",
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
  Future<List<MessageModel>> pageNewerForConversation(
    String uk3,
    int prevAutoId,
    int size,
  ) async {
    String where;
    List<dynamic> args;

    if (prevAutoId <= 0) {
      where = "${MessageColumns.conversationUk3} = ?";
      args = [uk3];
    } else {
      where =
          "${MessageColumns.conversationUk3} = ? AND ${MessageColumns.autoId} > ?";
      args = [uk3, prevAutoId];
    }

    try {
      List<Map<String, dynamic>> maps = await db.query(
        tableName,
        columns: _readColumns,
        where: where,
        whereArgs: args,
        orderBy: "${MessageColumns.autoId} ASC",
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
      where = "$where AND ${MessageColumns.conversationUk3}=?";
      whereArgs.add(conversationUk3);
    }

    // 高级过滤：消息类型
    if (messageTypes != null && messageTypes.isNotEmpty) {
      final placeholders = messageTypes.map((_) => '?').join(',');
      where = "$where AND ${MessageColumns.type} IN ($placeholders)";
      whereArgs.addAll(messageTypes);
    }

    // 高级过滤：发送者
    if (func_helper.strNoEmpty(senderId)) {
      where = "$where AND ${MessageColumns.from}=?";
      whereArgs.add(senderId);
    }

    // 高级过滤：时间范围
    if (startDate != null) {
      where = "$where AND ${MessageColumns.createdAt} >= ?";
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      where = "$where AND ${MessageColumns.createdAt} <= ?";
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    // 使用优化的排序和索引
    String optimizedOrderBy =
        orderBy ??
        "${MessageColumns.createdAt} DESC, ${MessageColumns.autoId} DESC";

    func_helper.iPrint('searchLeading_tag query started');

    try {
      List<Map<String, dynamic>> maps = await db.query(
        tableName,
        columns: _readColumns,
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

  Future<List<MessageModel>> pageRetryCandidates({
    required List<int> statuses,
    required int limit,
    int? beforeCreatedAt,
    int? beforeAutoId,
  }) async {
    final placeholders = statuses.map((_) => '?').join(',');
    var where =
        '${MessageColumns.status} IN ($placeholders) '
        'AND ${MessageColumns.isAuthor}=?';
    final whereArgs = <Object?>[...statuses, 1];
    if (beforeCreatedAt != null && beforeAutoId != null) {
      where +=
          ' AND (${MessageColumns.createdAt} < ? OR '
          '(${MessageColumns.createdAt} = ? AND ${MessageColumns.autoId} < ?))';
      whereArgs.addAll([beforeCreatedAt, beforeCreatedAt, beforeAutoId]);
    }
    final rows = await db.query(
      tableName,
      columns: _readColumns,
      where: where,
      whereArgs: whereArgs,
      orderBy:
          '${MessageColumns.createdAt} DESC, ${MessageColumns.autoId} DESC',
      limit: limit,
    );
    return rows.map(MessageModel.fromJson).toList(growable: false);
  }

  Future<MessageModel?> find(String id, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        tableName,
        columns: _readColumns,
        where: '${MessageColumns.id} = ?',
        whereArgs: [id],
      );
    } else {
      maps = await db.query(
        tableName,
        columns: _readColumns,
        where: '${MessageColumns.id} = ?',
        whereArgs: [id],
      );
    }
    // func_helper.iPrint("> on MessageRepo/find tb $tableName, id $id, len ${maps.length}; ${maps.toList().toString()}");
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    }
    return null;
  }

  /// 根据状态查找消息
  /// Find messages by status.
  Future<List<MessageModel>> findByStatus(
    String conversationUk3,
    int status,
  ) async {
    List<Map<String, dynamic>> maps = await db.query(
      tableName,
      columns: _readColumns,
      where:
          '${MessageColumns.conversationUk3} = ? AND ${MessageColumns.status} = ?',
      whereArgs: [conversationUk3, status],
      orderBy: '${MessageColumns.createdAt} DESC',
    );

    List<MessageModel> messages = [];
    for (int i = 0; i < maps.length; i++) {
      messages.add(MessageModel.fromJson(maps[i]));
    }
    return messages;
  }

  Future<MessageModel?> lastMsg() async {
    List<Map<String, dynamic>> maps = await db.query(
      tableName,
      columns: _readColumns,
      where: '${MessageColumns.from} = ?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${MessageColumns.createdAt} desc",
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return MessageModel.fromJson(maps.first);
    }
    return null;
  }

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
  Future<List<MessageModel>> getMessages({
    String? conversationUk3,
    int limit = 20,
    int offset = 0,
    int? startTime,
    int? endTime,
  }) async {
    if (limit <= 0) return [];
    final predicates = <String>[];
    final arguments = <Object?>[];
    if (func_helper.strNoEmpty(conversationUk3)) {
      predicates.add('${MessageColumns.conversationUk3} = ?');
      arguments.add(conversationUk3);
    }
    if (startTime != null) {
      predicates.add('${MessageColumns.createdAt} >= ?');
      arguments.add(startTime);
    }
    if (endTime != null) {
      predicates.add('${MessageColumns.createdAt} <= ?');
      arguments.add(endTime);
    }
    final columns = defaultColumns.join(', ');
    final where = predicates.isEmpty ? '1=1' : predicates.join(' AND ');
    try {
      // 合并后只应用一次 OFFSET，避免每张表分别跳过导致全局历史漏项。
      final rows = await db.rawQuery(
        'SELECT * FROM ('
        'SELECT $columns, ${MessageColumns.senderDid} FROM $c2cTable '
        'UNION ALL '
        'SELECT $columns, NULL AS ${MessageColumns.senderDid} FROM $c2gTable'
        ') WHERE $where '
        'ORDER BY ${MessageColumns.createdAt} DESC, '
        '${MessageColumns.type} ASC, ${MessageColumns.autoId} DESC, ${MessageColumns.id} ASC '
        'LIMIT ? OFFSET ?',
        [...arguments, limit, offset < 0 ? 0 : offset],
      );
      return rows.map(MessageModel.fromJson).toList(growable: false);
    } on Object {
      return [];
    }
  }

  /// 计算与某个用户的消息数量
  ///
  /// [peerId] 对方用户 ID
  /// [since] 起始时间戳（毫秒），可选
  /// Returns: 消息数量
  Future<int> countMessagesWithUser(String peerId, {int? since}) async {
    try {
      int total = 0;

      // 遍历所有消息表
      for (final table in [c2cTable, c2gTable]) {
        String where =
            '(${MessageColumns.from} = ? OR ${MessageColumns.to} = ?)';
        List<Object?> whereArgs = [peerId, peerId];

        if (since != null) {
          where = '$where AND ${MessageColumns.createdAt} >= ?';
          whereArgs.add(since); // 消息 created_at 与调用契约均为毫秒
        }

        final count = await db.pluck<int>(
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
