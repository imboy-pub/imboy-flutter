/// @提及频率聚合查询（C2 Layer B）
///
/// 独立文件、零 imboy 传递依赖，便于 sqflite_ffi in-memory 纯测试。
///
/// 表字段约定（见 assets/migrations/upgrade.sql:911 `msg_c2g`）：
///   - `from_id`     INTEGER  发送者 uid
///   - `conversation_uk3` TEXT  会话唯一键
///   - `created_at`  INTEGER  毫秒时间戳
///
/// D11：不做 status 过滤，撤回/删除消息仍视为一次发言行为。
/// D10：WHERE 采用 `conversation_uk3 + created_at`，命中
///      `idx_msg_c2g_conversation_created_at` 组合索引。
library;

import 'package:sqflite_common/sqlite_api.dart';

class MentionFrequencyRepo {
  MentionFrequencyRepo._();

  /// 核心 SQL — 暴露为公开常量便于日志排查 / 索引审查。
  static const String querySql =
      'SELECT from_id AS sender, COUNT(*) AS cnt FROM msg_c2g '
      'WHERE conversation_uk3 = ? AND created_at >= ? '
      'GROUP BY from_id';

  /// 执行聚合查询，返回 `{senderUid: count}` map。
  ///
  /// 接受任意实现 [DatabaseExecutor] 的对象：生产走 sqflite_sqlcipher，
  /// 测试走 sqflite_common_ffi 内存数据库。
  ///
  /// 边界语义：`created_at >= sinceMs`（包含等于 sinceMs 的消息）。
  static Future<Map<String, int>> queryWith(
    DatabaseExecutor db, {
    required String conversationUk3,
    required int sinceMs,
  }) async {
    final rows = await db.rawQuery(querySql, [conversationUk3, sinceMs]);
    return _parseRows(rows);
  }

  static Map<String, int> _parseRows(List<Map<String, Object?>> rows) {
    final out = <String, int>{};
    for (final r in rows) {
      final sender = r['sender'];
      final cnt = r['cnt'];
      if (sender != null && cnt is int) {
        out[sender.toString()] = cnt;
      }
    }
    return out;
  }
}
