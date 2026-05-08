/// 朋友圈通知仓库（Slice A-1）。
///
/// 对应 `moment_notify` 表（迁移 v20）。职责：
///   - insert：S2C 收到 `moment_like` / `moment_comment` 时落库
///   - page：通知中心列表页分页加载
///   - markRead / markAllRead：单条 / 全部已读
///   - unreadCount：顶部红点数
///   - delete / clear：用户手动删除
///
/// 去重语义：依赖 v21 迁移重建的 `uq_moment_notify_dedup` 唯一索引
///（user_id + action + moment_id + from_uid + COALESCE(comment_id, '')），
/// 重复 S2C 推送自动被 SQLite 吞掉，客户端无需上层去重逻辑。
///
/// 注：v20 原索引直接使用 `comment_id`，但 SQLite "NULL != NULL" 语义
/// 使 `comment_id IS NULL` 的 moment_like 行无法被唯一索引拦截；
/// v21 用 `COALESCE(comment_id, '')` 将 NULL 折叠为空串参与唯一约束修复。
library;

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/moment_notify_columns.dart';
import 'package:imboy/store/model/moment_notify_model.dart';

class MomentNotifyRepo {
  final SqliteService _db = SqliteService.to;

  /// 插入一条通知。重复（被唯一索引拦截）返回 0。
  Future<int> insert(MomentNotifyModel model) async {
    final db = await _db.db;
    if (db == null) return 0;
    return db.insert(
      MomentNotifyColumns.table,
      model.toInsertMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 分页查询当前用户的通知（新到旧）。
  Future<List<MomentNotifyModel>> page({
    required String userId,
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db.db;
    if (db == null) return const [];
    final rows = await db.query(
      MomentNotifyColumns.table,
      where: '${MomentNotifyColumns.userId} = ?',
      whereArgs: [userId],
      orderBy:
          '${MomentNotifyColumns.createdAt} DESC, '
          '${MomentNotifyColumns.id} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(MomentNotifyModel.fromRow).toList(growable: false);
  }

  /// 未读数。
  Future<int> unreadCount(String userId) async {
    final db = await _db.db;
    if (db == null) return 0;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${MomentNotifyColumns.table} '
      'WHERE ${MomentNotifyColumns.userId} = ? '
      'AND ${MomentNotifyColumns.isRead} = 0',
      [userId],
    );
    if (rows.isEmpty) return 0;
    final v = rows.first['c'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// 标记单条已读。返回受影响行数。
  Future<int> markRead(int id) async {
    final db = await _db.db;
    if (db == null) return 0;
    return db.update(
      MomentNotifyColumns.table,
      {MomentNotifyColumns.isRead: 1},
      where: '${MomentNotifyColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// 标记当前用户全部已读。返回受影响行数。
  Future<int> markAllRead(String userId) async {
    final db = await _db.db;
    if (db == null) return 0;
    return db.update(
      MomentNotifyColumns.table,
      {MomentNotifyColumns.isRead: 1},
      where:
          '${MomentNotifyColumns.userId} = ? AND ${MomentNotifyColumns.isRead} = 0',
      whereArgs: [userId],
    );
  }

  /// 删除单条通知。
  Future<int> delete(int id) async {
    final db = await _db.db;
    if (db == null) return 0;
    return db.delete(
      MomentNotifyColumns.table,
      where: '${MomentNotifyColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// 清空当前用户的所有通知。
  Future<int> clearAll(String userId) async {
    final db = await _db.db;
    if (db == null) return 0;
    return db.delete(
      MomentNotifyColumns.table,
      where: '${MomentNotifyColumns.userId} = ?',
      whereArgs: [userId],
    );
  }
}
