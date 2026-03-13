import 'dart:convert';

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:sqflite/sqflite.dart';

/// 频道消息 Repository
///
/// 负责频道消息的本地数据库操作：
/// - 消息的 CRUD
/// - 分页查询
/// - 置顶消息管理
class ChannelMessageRepo {
  static const String tableName = 'channel_message';

  // 消息表字段
  static const String id = 'id';
  static const String channelId = 'channel_id';
  static const String authorId = 'author_id';
  static const String authorName = 'author_name';
  static const String authorAvatar = 'author_avatar';
  static const String content = 'content';
  static const String msgType = 'msg_type';
  static const String payload = 'payload';
  static const String createdAt = 'created_at';
  static const String isPinned = 'is_pinned';
  static const String viewCount = 'view_count';
  static const String reactionSummary = 'reaction_summary';

  final SqliteService _db = SqliteService.to;

  // ==================== 消息 CRUD ====================

  /// 保存消息
  Future<void> saveMessage(
    ChannelMessageModel message, {
    Transaction? txn,
  }) async {
    final map = message.toMap();
    if (txn != null) {
      await txn.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // SqliteService.insert 内部已使用 ConflictAlgorithm.replace
      await _db.insert(tableName, map);
    }
    iPrint('ChannelMessageRepo: 保存消息 ${message.id}');
  }

  /// 批量保存消息
  Future<void> saveMessages(
    List<ChannelMessageModel> messages, {
    Transaction? txn,
  }) async {
    for (final message in messages) {
      await saveMessage(message, txn: txn);
    }
    iPrint('ChannelMessageRepo: 批量保存 ${messages.length} 条消息');
  }

  /// 获取单条消息
  Future<ChannelMessageModel?> getMessage(String messageId) async {
    final maps = await _db.query(
      tableName,
      where: '$id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ChannelMessageModel.fromMap(maps.first);
    }
    return null;
  }

  /// 更新消息
  Future<int> updateMessage(String messageId, Map<String, dynamic> data) async {
    data.remove(id); // 移除主键
    return await _db.update(
      tableName,
      data,
      where: '$id = ?',
      whereArgs: [messageId],
    );
  }

  /// 删除消息
  Future<int> deleteMessage(String messageId) async {
    return await _db.delete(
      tableName,
      where: '$id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== 分页查询 ====================

  /// 分页获取频道消息
  ///
  /// [channelId] 频道 ID
  /// [cursor] 游标（上一页最后一条消息的创建时间），null 表示获取最新消息
  /// [limit] 每页数量
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    String where = '$ChannelMessageRepo.channelId = ?';
    List<dynamic> whereArgs = [channelId];

    if (cursor != null) {
      where += ' AND $createdAt < ?';
      whereArgs.add(cursor);
    }

    final maps = await _db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: '$createdAt DESC',
      limit: limit,
    );

    return maps.map((map) => ChannelMessageModel.fromMap(map)).toList();
  }

  /// 获取最新的 N 条消息
  Future<List<ChannelMessageModel>> getLatestMessages({
    required String channelId,
    int limit = 20,
  }) async {
    return await getMessages(channelId: channelId, limit: limit);
  }

  /// 获取更早的消息（上拉加载）
  ///
  /// [beforeTime] 获取此时间之前的消息
  Future<List<ChannelMessageModel>> getMessagesBefore({
    required String channelId,
    required int beforeTime,
    int limit = 20,
  }) async {
    final maps = await _db.query(
      tableName,
      where: '$ChannelMessageRepo.channelId = ? AND $createdAt < ?',
      whereArgs: [channelId, beforeTime],
      orderBy: '$createdAt DESC',
      limit: limit,
    );

    return maps.map((map) => ChannelMessageModel.fromMap(map)).toList();
  }

  /// 获取指定消息之后的消息（下拉加载新消息）
  ///
  /// [afterTime] 获取此时间之后的消息
  Future<List<ChannelMessageModel>> getMessagesAfter({
    required String channelId,
    required int afterTime,
    int limit = 100,
  }) async {
    final maps = await _db.query(
      tableName,
      where: '$ChannelMessageRepo.channelId = ? AND $createdAt > ?',
      whereArgs: [channelId, afterTime],
      orderBy: '$createdAt ASC',
      limit: limit,
    );

    return maps.map((map) => ChannelMessageModel.fromMap(map)).toList();
  }

  // ==================== 置顶消息 ====================

  /// 获取置顶消息
  Future<List<ChannelMessageModel>> getPinnedMessages(String channelId) async {
    final maps = await _db.query(
      tableName,
      where: '$ChannelMessageRepo.channelId = ? AND $isPinned = ?',
      whereArgs: [channelId, 1],
      orderBy: '$createdAt DESC',
    );

    return maps.map((map) => ChannelMessageModel.fromMap(map)).toList();
  }

  /// 设置消息置顶状态
  Future<int> setMessagePinned(String messageId, bool pinned) async {
    return await _db.update(
      tableName,
      {isPinned: pinned ? 1 : 0},
      where: '$id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== 辅助查询 ====================

  /// 获取频道最后一条消息
  Future<ChannelMessageModel?> getLastMessage(String channelId) async {
    final maps = await _db.query(
      tableName,
      where: '$ChannelMessageRepo.channelId = ?',
      whereArgs: [channelId],
      orderBy: '$createdAt DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ChannelMessageModel.fromMap(maps.first);
    }
    return null;
  }

  /// 获取频道消息总数
  Future<int> getMessageCount(String channelId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName '
      'WHERE ${ChannelMessageRepo.channelId} = ?',
      [channelId],
    );

    return result.isNotEmpty ? parseModelInt(result.first['count']) : 0;
  }

  /// 检查消息是否存在
  Future<bool> messageExists(String messageId) async {
    final maps = await _db.query(
      tableName,
      columns: [id],
      where: '$id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ==================== 统计更新 ====================

  /// 增加阅读量
  Future<int> incrementViewCount(String messageId) async {
    final message = await getMessage(messageId);
    if (message == null) return 0;

    return await _db.update(
      tableName,
      {viewCount: message.viewCount + 1},
      where: '$id = ?',
      whereArgs: [messageId],
    );
  }

  /// 更新反应统计
  Future<int> updateReactionSummary(
    String messageId,
    Map<String, int> summary,
  ) async {
    return await _db.update(
      tableName,
      {reactionSummary: jsonEncode(summary)},
      where: '$id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== 批量操作 ====================

  /// 删除频道的所有消息
  Future<int> deleteMessagesByChannel(String channelId) async {
    final count = await _db.delete(
      tableName,
      where: '$ChannelMessageRepo.channelId = ?',
      whereArgs: [channelId],
    );
    iPrint('ChannelMessageRepo: 删除频道 $channelId 的 $count 条消息');
    return count;
  }

  /// 删除旧消息（保留最近 N 条）
  ///
  /// 用于清理存储空间
  Future<int> deleteOldMessages(String channelId, int keepCount) async {
    // 先获取要保留的消息 ID
    final keepIds = await _db.rawQuery(
      'SELECT $id FROM $tableName WHERE $ChannelMessageRepo.channelId = ? ORDER BY $createdAt DESC LIMIT ?',
      [channelId, keepCount],
    );

    if (keepIds.isEmpty || keepIds.length < keepCount) {
      // 消息数量不足，不需要删除
      return 0;
    }

    // 构建排除列表
    final excludeIds = keepIds.map((row) => row[id] as String).toList();
    final placeholders = List.filled(excludeIds.length, '?').join(',');

    // 删除不在保留列表中的消息
    final count = await _db.delete(
      tableName,
      where: '$ChannelMessageRepo.channelId = ? AND $id NOT IN ($placeholders)',
      whereArgs: [channelId, ...excludeIds],
    );

    iPrint(
      'ChannelMessageRepo: 清理频道 $channelId 的旧消息，保留 $keepCount 条，删除 $count 条',
    );
    return count;
  }

  /// 批量删除消息
  Future<int> deleteMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return 0;

    final placeholders = List.filled(messageIds.length, '?').join(',');
    return await _db.delete(
      tableName,
      where: '$id IN ($placeholders)',
      whereArgs: messageIds,
    );
  }

  // ==================== 搜索 ====================

  /// 搜索频道消息（仅搜索文本消息）
  Future<List<ChannelMessageModel>> searchMessages(
    String channelId,
    String keyword, {
    int limit = 50,
  }) async {
    final maps = await _db.query(
      tableName,
      where: '$ChannelMessageRepo.channelId = ? AND $content LIKE ?',
      whereArgs: [channelId, '%$keyword%'],
      orderBy: '$createdAt DESC',
      limit: limit,
    );

    return maps.map((map) => ChannelMessageModel.fromMap(map)).toList();
  }

  // ==================== 清理操作 ====================

  /// 清理所有频道消息（慎用！）
  Future<void> clearAll() async {
    await _db.delete(tableName);
    iPrint('ChannelMessageRepo: 清理所有频道消息');
  }

  /// 关闭数据库连接（空实现，由 SqliteService 统一管理）
  Future<void> close() async {
    // 由 SqliteService 统一管理
  }
}
