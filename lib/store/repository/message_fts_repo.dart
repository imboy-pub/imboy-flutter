/// 消息全文搜索仓库
///
/// 基于 SQLite FTS5 的本地消息全文搜索。
/// 不依赖后端，支持离线搜索。
///
/// FTS5 表结构:
/// - msg_c2c_fts: C2C 消息搜索索引
/// - msg_c2g_fts: C2G 消息搜索索引
///
/// 索引策略:
/// - 新消息插入时同步写入 FTS 索引
/// - 仅索引文本内容 (text_content)，不索引密文
library;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:synchronized/synchronized.dart';

/// FTS 搜索结果
class FtsSearchResult {
  final String id;
  final String conversationUk3;
  final String snippet;
  final double rank;

  FtsSearchResult({
    required this.id,
    required this.conversationUk3,
    required this.snippet,
    required this.rank,
  });
}

/// 消息 FTS 仓库
class MessageFtsRepo {
  // FTS5 has no unique constraint. All repo instances must serialize each
  // delete/insert pair so concurrent background reindex tasks cannot duplicate.
  static final _indexLock = Lock();
  final SqliteService _db = SqliteService.to;

  /// 向 FTS 索引中插入 C2C 消息
  ///
  /// [rowid] 传入消息表 auto_id 时按显式 rowid 写入，保证
  /// "索引 rowid == 消息 auto_id" 的对齐关系（v37 contentless FTS
  /// 无法按列值回查/删除，搜索与清理都依赖该对齐）；缺省时保持
  /// 旧行为（隐式 rowid，仅适用于独立合成的常规 FTS5 表）。
  Future<void> indexC2cMessage({
    required String id,
    required String conversationUk3,
    required String textContent,
    int? rowid,
  }) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    bool isCurrent() =>
        session.currentUid == uid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    if (textContent.trim().isEmpty || !isCurrent()) return;
    try {
      await _indexLock.synchronized(() async {
        // 先删后插保证幂等：FTS5 无唯一约束，裸 INSERT 重复索引会产生
        // 双行（搜索同 id 命中两条）；update 后重索引路径必然重复。
        await _db.execute(
          'DELETE FROM msg_c2c_fts WHERE id = ? '
          'AND (SELECT user_version FROM pragma_user_version) < 38',
          [id],
          3,
          isCurrent,
        );
        if (!isCurrent()) return;
        await _db.execute(
          rowid == null
              ? 'INSERT INTO msg_c2c_fts(id, conversation_uk3, text_content) '
                    'SELECT ?, ?, ? WHERE (SELECT user_version FROM pragma_user_version) < 38'
              : 'INSERT INTO msg_c2c_fts(rowid, id, conversation_uk3, text_content) '
                    'SELECT ?, ?, ?, ? WHERE (SELECT user_version FROM pragma_user_version) < 38',
          rowid == null
              ? [id, conversationUk3, textContent]
              : [rowid, id, conversationUk3, textContent],
          3,
          isCurrent,
        );
      });
    } catch (e) {
      iPrint('[FTS] C2C 索引写入失败: $e');
    }
  }

  /// 向 FTS 索引中插入 C2G 消息
  ///
  /// [rowid] 语义同 [indexC2cMessage]。
  Future<void> indexC2gMessage({
    required String id,
    required String conversationUk3,
    required String textContent,
    int? rowid,
  }) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    bool isCurrent() =>
        session.currentUid == uid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    if (textContent.trim().isEmpty || !isCurrent()) return;
    try {
      await _indexLock.synchronized(() async {
        // 幂等化，同 indexC2cMessage
        await _db.execute(
          'DELETE FROM msg_c2g_fts WHERE id = ? '
          'AND (SELECT user_version FROM pragma_user_version) < 38',
          [id],
          3,
          isCurrent,
        );
        if (!isCurrent()) return;
        await _db.execute(
          rowid == null
              ? 'INSERT INTO msg_c2g_fts(id, conversation_uk3, text_content) '
                    'SELECT ?, ?, ? WHERE (SELECT user_version FROM pragma_user_version) < 38'
              : 'INSERT INTO msg_c2g_fts(rowid, id, conversation_uk3, text_content) '
                    'SELECT ?, ?, ?, ? WHERE (SELECT user_version FROM pragma_user_version) < 38',
          rowid == null
              ? [id, conversationUk3, textContent]
              : [rowid, id, conversationUk3, textContent],
          3,
          isCurrent,
        );
      });
    } catch (e) {
      iPrint('[FTS] C2G 索引写入失败: $e');
    }
  }

  /// 索引消息（根据类型自动选择表）
  Future<void> indexMessage({
    required String type,
    required String id,
    required String conversationUk3,
    required String textContent,
    int? rowid,
  }) async {
    if (type == 'C2C') {
      await indexC2cMessage(
        id: id,
        conversationUk3: conversationUk3,
        textContent: textContent,
        rowid: rowid,
      );
    } else if (type == 'C2G') {
      await indexC2gMessage(
        id: id,
        conversationUk3: conversationUk3,
        textContent: textContent,
        rowid: rowid,
      );
    }
  }

  /// 从 FTS 索引中移除一条消息的索引行（v37 repo 路径，v38 后为 no-op）。
  ///
  /// v37 基线的 FTS5 表是 contentless（content=''）：
  /// - 常规 FTS5 表：plain `DELETE ... WHERE rowid = ?` 直接生效；
  /// - contentless 表：SQLite 禁止 DELETE 命中行（抛错），必须回退为
  ///   `'delete'` 命令，且需提供 rowid 与**当初写入的原值**（列值不
  ///   匹配时 FTS5 静默忽略，值已被删过时会报 index 损坏错误）。
  /// 因此 [textContent] 必须是建立索引时的文本。
  Future<void> removeFromIndex({
    required String type,
    required String id,
    required String conversationUk3,
    required String textContent,
    int? rowid,
  }) async {
    final table = type == 'C2C' ? 'msg_c2c_fts' : 'msg_c2g_fts';
    final guard = '(SELECT user_version FROM pragma_user_version) < 38';
    try {
      if (rowid != null) {
        try {
          await _db.execute('DELETE FROM $table WHERE rowid = ? AND $guard', [
            rowid,
          ], 3);
          return;
        } on Object {
          // contentless 表命中已有行时 DELETE 会抛错 → 回退 'delete' 命令。
        }
        await _db.execute(
          "INSERT INTO $table($table, rowid, id, conversation_uk3, text_content) "
          "SELECT 'delete', ?, ?, ?, ? WHERE $guard",
          [rowid, id, conversationUk3, textContent],
          3,
        );
      } else {
        // 无 rowid 时只能按列值删（仅常规 FTS5 表有效；contentless 为静默 no-op）。
        await _db.execute('DELETE FROM $table WHERE id = ? AND $guard', [
          id,
        ], 3);
      }
    } catch (e) {
      iPrint('[FTS] 索引删除失败: $e');
    }
  }

  /// 搜索 C2C 消息
  ///
  /// [query] 搜索关键词
  /// [conversationUk3] 可选，限定在某个会话中搜索
  /// [limit] 返回结果数上限
  Future<List<FtsSearchResult>> searchC2c({
    required String query,
    String? conversationUk3,
    int? startTime,
    int? endTime,
    bool throwOnError = false,
    int limit = 50,
  }) async {
    return _search(
      table: 'msg_c2c_fts',
      query: query,
      conversationUk3: conversationUk3,
      startTime: startTime,
      endTime: endTime,
      throwOnError: throwOnError,
      limit: limit,
    );
  }

  /// 搜索 C2G 消息
  Future<List<FtsSearchResult>> searchC2g({
    required String query,
    String? conversationUk3,
    int? startTime,
    int? endTime,
    bool throwOnError = false,
    int limit = 50,
  }) async {
    return _search(
      table: 'msg_c2g_fts',
      query: query,
      conversationUk3: conversationUk3,
      startTime: startTime,
      endTime: endTime,
      throwOnError: throwOnError,
      limit: limit,
    );
  }

  /// 全局搜索（C2C + C2G）
  ///
  /// 合并两个表的搜索结果，按 rank 排序
  Future<List<FtsSearchResult>> searchAll({
    required String query,
    String? conversationUk3,
    String type = 'all',
    int? startTime,
    int? endTime,
    bool throwOnError = false,
    bool Function()? isCurrent,
    int limit = 50,
  }) async {
    if (isCurrent != null && !isCurrent()) return [];
    final c2cResults = type == 'C2G'
        ? <FtsSearchResult>[]
        : await searchC2c(
            query: query,
            conversationUk3: conversationUk3,
            startTime: startTime,
            endTime: endTime,
            throwOnError: throwOnError,
            limit: limit,
          );
    if (isCurrent != null && !isCurrent()) return [];
    final c2gResults = type == 'C2C'
        ? <FtsSearchResult>[]
        : await searchC2g(
            query: query,
            conversationUk3: conversationUk3,
            startTime: startTime,
            endTime: endTime,
            throwOnError: throwOnError,
            limit: limit,
          );
    if (isCurrent != null && !isCurrent()) return [];

    final merged = [...c2cResults, ...c2gResults];
    // FTS5 rank 为负数，越负越相关；升序排列使最相关结果在前。
    // NaN 守卫：将 NaN 推到末尾。
    merged.sort((a, b) {
      final ra = a.rank.isNaN ? double.infinity : a.rank;
      final rb = b.rank.isNaN ? double.infinity : b.rank;
      final rankOrder = ra.compareTo(rb);
      if (rankOrder != 0) return rankOrder;
      final conversationOrder = a.conversationUk3.compareTo(b.conversationUk3);
      if (conversationOrder != 0) return conversationOrder;
      return a.id.compareTo(b.id);
    });
    if (merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  /// 从 FTS 索引中删除消息
  Future<void> deleteFromIndex({
    required String type,
    required String id,
    required String conversationUk3,
    required String textContent,
  }) async {
    final table = type == 'C2C' ? 'msg_c2c_fts' : 'msg_c2g_fts';
    try {
      // FTS5 外部内容表删除需要 INSERT INTO ... VALUES('delete', ...)
      await _db.execute(
        "INSERT INTO $table($table, id, conversation_uk3, text_content) "
        "SELECT 'delete', ?, ?, ? "
        'WHERE (SELECT user_version FROM pragma_user_version) < 38',
        [id, conversationUk3, textContent],
      );
    } catch (e) {
      iPrint('[FTS] 索引删除失败: $e');
    }
  }

  /// 内部搜索方法
  ///
  /// v37 基线的 FTS5 表是 contentless（content=''）：索引行取不回
  /// id/conversation_uk3 列值（查询结果恒为 NULL），因此生产 schema 下
  /// JOIN 消息表回填消息身份（rowid == auto_id 对齐由索引写入保证），
  /// 会话/时间过滤也走消息表列；v38（content 视图）下 rowid 仍等于
  /// auto_id，同一 SQL 两种版本通用。仅当消息表不存在（独立合成的
  /// 常规 FTS5 mini schema）时才回退到直接查 FTS 表的旧路径。
  Future<List<FtsSearchResult>> _search({
    required String table,
    required String query,
    String? conversationUk3,
    int? startTime,
    int? endTime,
    bool throwOnError = false,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      return await _searchJoined(
        table: table,
        query: query,
        conversationUk3: conversationUk3,
        startTime: startTime,
        endTime: endTime,
        limit: limit,
      );
    } on Object catch (e) {
      iPrint('[FTS] JOIN 搜索失败: $e');
      if (throwOnError) rethrow;
    }
    try {
      return await _searchFtsOnly(
        table: table,
        query: query,
        conversationUk3: conversationUk3,
        startTime: startTime,
        endTime: endTime,
        limit: limit,
      );
    } catch (e) {
      iPrint('[FTS] 搜索失败: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// 生产路径：JOIN 消息表回填 id/会话键并下推过滤条件。
  Future<List<FtsSearchResult>> _searchJoined({
    required String table,
    required String query,
    String? conversationUk3,
    int? startTime,
    int? endTime,
    required int limit,
  }) async {
    // 转义 FTS5 特殊字符
    final safeQuery = _escapeFts5Query(query);
    final messageTable = table == 'msg_c2c_fts' ? 'msg_c2c' : 'msg_c2g';

    final conditions = <String>[];
    final params = <dynamic>[safeQuery];
    if (conversationUk3 != null && conversationUk3.isNotEmpty) {
      conditions.add('message.conversation_uk3 = ?');
      params.add(conversationUk3);
    }
    if (startTime != null) {
      conditions.add('message.created_at >= ?');
      params.add(startTime);
    }
    if (endTime != null) {
      conditions.add('message.created_at <= ?');
      params.add(endTime);
    }
    params.add(limit);
    // 注意：snippet() 的首参必须是 FTS5 表名本身（别名会被当作普通
    // 列引用解析而报 no such column），因此 fts 表不使用别名。
    final sql =
        'SELECT message.id AS id, message.conversation_uk3 AS conversation_uk3, '
        "snippet($table, 2, '<b>', '</b>', '...', 32) as snippet, $table.rank AS rank "
        'FROM $table '
        'JOIN $messageTable AS message ON message.auto_id = $table.rowid '
        'WHERE $table MATCH ?${conditions.isEmpty ? '' : ' AND ${conditions.join(' AND ')}'} '
        'ORDER BY $table.rank, message.conversation_uk3, message.id LIMIT ?';

    final rows = await _db.rawQuery(sql, params, false, 5000);
    return _rowsToResults(rows);
  }

  /// 回退路径：直接查 FTS 表（无消息表的合成 mini schema）。
  Future<List<FtsSearchResult>> _searchFtsOnly({
    required String table,
    required String query,
    String? conversationUk3,
    int? startTime,
    int? endTime,
    required int limit,
  }) async {
    final safeQuery = _escapeFts5Query(query);
    final conditions = <String>['$table MATCH ?'];
    final params = <dynamic>[safeQuery];
    if (conversationUk3 != null && conversationUk3.isNotEmpty) {
      conditions.add('$table.conversation_uk3 = ?');
      params.add(conversationUk3);
    }
    if (startTime != null || endTime != null) {
      final messageTable = table == 'msg_c2c_fts' ? 'msg_c2c' : 'msg_c2g';
      final timeConditions = <String>['message.id = $table.id'];
      if (startTime != null) {
        timeConditions.add('message.created_at >= ?');
        params.add(startTime);
      }
      if (endTime != null) {
        timeConditions.add('message.created_at <= ?');
        params.add(endTime);
      }
      conditions.add(
        'EXISTS (SELECT 1 FROM $messageTable AS message '
        'WHERE ${timeConditions.join(' AND ')})',
      );
    }
    params.add(limit);
    final sql =
        'SELECT id, conversation_uk3, '
        'snippet($table, 2, \'<b>\', \'</b>\', \'...\', 32) as snippet, '
        'rank FROM $table WHERE ${conditions.join(' AND ')} '
        'ORDER BY rank, conversation_uk3, id LIMIT ?';

    final rows = await _db.rawQuery(sql, params, false, 5000);
    return _rowsToResults(rows);
  }

  List<FtsSearchResult> _rowsToResults(List<Map<String, Object?>> rows) {
    return rows.map((row) {
      return FtsSearchResult(
        id: row['id'] as String? ?? '',
        conversationUk3: row['conversation_uk3'] as String? ?? '',
        snippet: row['snippet'] as String? ?? '',
        rank: (row['rank'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  /// 从消息 payload 和 msgType 提取可索引的文本内容
  ///
  /// 仅索引有文本意义的消息类型，图片/视频/文件等返回空字符串
  static String extractTextContent(
    String? msgType,
    Map<String, dynamic> payload,
  ) {
    if (payload['_e2ee_failed'] == true) return '';
    String text(String key) {
      final value = payload[key];
      return value is String ? value.trim() : '';
    }

    switch (msgType) {
      case 'text':
        return text('text');
      case 'quote':
        return text('quote_text');
      case 'location':
        final title = text('title');
        final address = text('address');
        return '$title $address'.trim();
      default:
        return '';
    }
  }

  /// 转义 FTS5 查询中的特殊字符
  String _escapeFts5Query(String query) {
    // FTS5 特殊字符: AND OR NOT NEAR " * ^
    // 对用户输入加双引号包裹，实现精确短语搜索
    final trimmed = query.trim();
    if (trimmed.contains('"')) {
      // 如果用户已经使用了引号，原样传递
      return trimmed;
    }
    // 默认使用前缀搜索
    return '"$trimmed"*';
  }
}
