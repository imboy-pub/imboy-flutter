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
  final SqliteService _db = SqliteService.to;

  /// 向 FTS 索引中插入 C2C 消息
  Future<void> indexC2cMessage({
    required String id,
    required String conversationUk3,
    required String textContent,
  }) async {
    if (textContent.trim().isEmpty) return;
    try {
      await _db.execute(
        'INSERT INTO msg_c2c_fts(id, conversation_uk3, text_content) VALUES(?, ?, ?)',
        [id, conversationUk3, textContent],
      );
    } catch (e) {
      iPrint('[FTS] C2C 索引写入失败: $e');
    }
  }

  /// 向 FTS 索引中插入 C2G 消息
  Future<void> indexC2gMessage({
    required String id,
    required String conversationUk3,
    required String textContent,
  }) async {
    if (textContent.trim().isEmpty) return;
    try {
      await _db.execute(
        'INSERT INTO msg_c2g_fts(id, conversation_uk3, text_content) VALUES(?, ?, ?)',
        [id, conversationUk3, textContent],
      );
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
  }) async {
    if (type == 'C2C') {
      await indexC2cMessage(
        id: id,
        conversationUk3: conversationUk3,
        textContent: textContent,
      );
    } else if (type == 'C2G') {
      await indexC2gMessage(
        id: id,
        conversationUk3: conversationUk3,
        textContent: textContent,
      );
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
    int limit = 50,
  }) async {
    return _search(
      table: 'msg_c2c_fts',
      query: query,
      conversationUk3: conversationUk3,
      limit: limit,
    );
  }

  /// 搜索 C2G 消息
  Future<List<FtsSearchResult>> searchC2g({
    required String query,
    String? conversationUk3,
    int limit = 50,
  }) async {
    return _search(
      table: 'msg_c2g_fts',
      query: query,
      conversationUk3: conversationUk3,
      limit: limit,
    );
  }

  /// 全局搜索（C2C + C2G）
  ///
  /// 合并两个表的搜索结果，按 rank 排序
  Future<List<FtsSearchResult>> searchAll({
    required String query,
    String? conversationUk3,
    int limit = 50,
  }) async {
    final c2cResults = await searchC2c(
      query: query,
      conversationUk3: conversationUk3,
      limit: limit,
    );
    final c2gResults = await searchC2g(
      query: query,
      conversationUk3: conversationUk3,
      limit: limit,
    );

    final merged = [...c2cResults, ...c2gResults];
    merged.sort((a, b) => a.rank.compareTo(b.rank)); // rank 越小越相关
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
        "VALUES('delete', ?, ?, ?)",
        [id, conversationUk3, textContent],
      );
    } catch (e) {
      iPrint('[FTS] 索引删除失败: $e');
    }
  }

  /// 内部搜索方法
  Future<List<FtsSearchResult>> _search({
    required String table,
    required String query,
    String? conversationUk3,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // 转义 FTS5 特殊字符
      final safeQuery = _escapeFts5Query(query);

      String sql;
      List<dynamic> params;

      if (conversationUk3 != null && conversationUk3.isNotEmpty) {
        sql = 'SELECT id, conversation_uk3, '
            'snippet($table, 2, \'<b>\', \'</b>\', \'...\', 32) as snippet, '
            'rank '
            'FROM $table '
            'WHERE $table MATCH ? AND conversation_uk3 = ? '
            'ORDER BY rank LIMIT ?';
        params = [safeQuery, conversationUk3, limit];
      } else {
        sql = 'SELECT id, conversation_uk3, '
            'snippet($table, 2, \'<b>\', \'</b>\', \'...\', 32) as snippet, '
            'rank '
            'FROM $table '
            'WHERE $table MATCH ? '
            'ORDER BY rank LIMIT ?';
        params = [safeQuery, limit];
      }

      final rows = await _db.rawQuery(sql, params);
      return rows.map((row) {
        return FtsSearchResult(
          id: row['id'] as String? ?? '',
          conversationUk3: row['conversation_uk3'] as String? ?? '',
          snippet: row['snippet'] as String? ?? '',
          rank: (row['rank'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (e) {
      iPrint('[FTS] 搜索失败: $e');
      return [];
    }
  }

  /// 从消息 payload 和 msgType 提取可索引的文本内容
  ///
  /// 仅索引有文本意义的消息类型，图片/视频/文件等返回空字符串
  static String extractTextContent(
    String? msgType,
    Map<String, dynamic> payload,
  ) {
    switch (msgType) {
      case 'text':
        return (payload['text'] ?? '').toString().trim();
      case 'quote':
        return (payload['quote_text'] ?? '').toString().trim();
      case 'location':
        final title = (payload['title'] ?? '').toString().trim();
        final address = (payload['address'] ?? '').toString().trim();
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
