/// E2EE 传输会话仓库
///
/// 管理设备间传输会话的本地持久化
///
/// @author ImBoy Team
/// @since 2026-02-14
library;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite/sqflite.dart';

/// E2EE 传输会话模型
class E2EETransferSessionModel {
  /// 会话 ID
  final String sessionId;

  /// 发送方 UID
  final String? fromUid;

  /// 发送方设备 ID
  final String? fromDeviceId;

  /// 接收方 UID
  final String toUid;

  /// 状态 (pending, accepted, completed, expired, cancelled, failed)
  final String status;

  /// 过期时间（ISO8601）
  final String? expiresAt;

  /// 创建时间（ISO8601）
  final String createdAt;

  /// 更新时间（ISO8601）
  final String? updatedAt;

  /// 额外元数据（JSON）
  final String? metadata;

  const E2EETransferSessionModel({
    required this.sessionId,
    this.fromUid,
    this.fromDeviceId,
    required this.toUid,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory E2EETransferSessionModel.fromMap(Map<String, dynamic> map) {
    return E2EETransferSessionModel(
      sessionId: map['session_id'] as String,
      fromUid: map['from_uid']?.toString(),
      fromDeviceId: map['from_device_id']?.toString(),
      toUid: map['to_uid'] as String,
      status: map['status'] as String,
      expiresAt: map['expires_at']?.toString(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at']?.toString(),
      metadata: map['metadata']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'from_uid': fromUid,
      'from_device_id': fromDeviceId,
      'to_uid': toUid,
      'status': status,
      'expires_at': expiresAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'metadata': metadata,
    };
  }

  /// 转换为 JSON 格式（用于 API 响应）
  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'from_uid': fromUid,
      'from_device_id': fromDeviceId,
      'to_uid': toUid,
      'status': status,
      'expires_at': expiresAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (metadata != null) 'metadata': _parseMetadata(metadata),
    };
  }

  Map<String, dynamic>? _parseMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(
        (metadata.startsWith('{')
            ? metadata
            : '{}') as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }
}

/// E2EE 传输会话仓库
///
/// 单例模式，提供传输会话的 CRUD 操作
class E2EETransferRepo {
  /// 单例实例
  static final E2EETransferRepo _instance = E2EETransferRepo._internal();

  factory E2EETransferRepo() => _instance;

  E2EETransferRepo._internal();

  /// 数据库服务
  final SqliteService _db = SqliteService.to;

  /// 表名
  static const String tableName = 'e2ee_transfer_session';

  // ================================================================
  // 表结构定义
  // ================================================================

  /// 建表 SQL
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL UNIQUE,
      from_uid TEXT,
      from_device_id TEXT,
      to_uid TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      expires_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      metadata TEXT
    );
  ''';

  /// 创建索引 SQL
  static const List<String> createIndexSql = [
    'CREATE INDEX IF NOT EXISTS idx_${tableName}_to_uid ON $tableName (to_uid);',
    'CREATE INDEX IF NOT EXISTS idx_${tableName}_status ON $tableName (status);',
    'CREATE INDEX IF NOT EXISTS idx_${tableName}_created_at ON $tableName (created_at);',
  ];

  // ================================================================
  // CRUD 操作
  // ================================================================

  /// 插入传输会话
  Future<int> insert(E2EETransferSessionModel session, {Transaction? txn}) async {
    iPrint("📝 [E2EETransferRepo] insert session: ${session.sessionId}");

    final map = session.toMap();
    map.remove('id'); // 移除 id，让数据库自增

    if (txn != null) {
      return await txn.insert(tableName, map);
    } else {
      return await _db.insert(tableName, map);
    }
  }

  /// 更新传输会话状态
  Future<int> updateStatus(
    String sessionId,
    String status, {
    Transaction? txn,
  }) async {
    iPrint("📝 [E2EETransferRepo] updateStatus: $sessionId -> $status");

    final data = {
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (txn != null) {
      return await txn.update(
        tableName,
        data,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } else {
      return await _db.update(
        tableName,
        data,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    }
  }

  /// 根据 session_id 查找
  Future<E2EETransferSessionModel?> findBySessionId(
    String sessionId, {
    Transaction? txn,
  }) async {
    List<Map<String, dynamic>> maps;

    if (txn != null) {
      maps = await txn.query(
        tableName,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } else {
      maps = await _db.query(
        tableName,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    }

    if (maps.isEmpty) {
      return null;
    }

    return E2EETransferSessionModel.fromMap(maps.first);
  }

  /// 获取用户的待处理传输列表
  Future<List<E2EETransferSessionModel>> getPendingByToUid(
    String toUid, {
    int limit = 50,
  }) async {
    final maps = await _db.query(
      tableName,
      where: 'to_uid = ? AND status = ?',
      whereArgs: [toUid, 'pending'],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => E2EETransferSessionModel.fromMap(map)).toList();
  }

  /// 获取所有待处理的传输
  Future<List<E2EETransferSessionModel>> getAllPending({int limit = 100}) async {
    final maps = await _db.query(
      tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => E2EETransferSessionModel.fromMap(map)).toList();
  }

  /// 获取用户的传输历史
  Future<List<E2EETransferSessionModel>> getHistoryByToUid(
    String toUid, {
    int page = 1,
    int size = 20,
  }) async {
    final offset = (page - 1) * size;

    final maps = await _db.query(
      tableName,
      where: 'to_uid = ?',
      whereArgs: [toUid],
      orderBy: 'created_at DESC',
      limit: size,
      offset: offset,
    );

    return maps.map((map) => E2EETransferSessionModel.fromMap(map)).toList();
  }

  /// 删除传输会话
  Future<int> delete(String sessionId, {Transaction? txn}) async {
    iPrint("🗑️ [E2EETransferRepo] delete session: $sessionId");

    if (txn != null) {
      return await txn.delete(
        tableName,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } else {
      return await _db.delete(
        tableName,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    }
  }

  /// 清理过期的传输会话
  Future<int> cleanupExpired({Transaction? txn}) async {
    final now = DateTime.now().toUtc().toIso8601String();

    iPrint("🧹 [E2EETransferRepo] cleanupExpired sessions before $now");

    if (txn != null) {
      return await txn.delete(
        tableName,
        where: 'expires_at IS NOT NULL AND expires_at < ?',
        whereArgs: [now],
      );
    } else {
      return await _db.delete(
        tableName,
        where: 'expires_at IS NOT NULL AND expires_at < ?',
        whereArgs: [now],
      );
    }
  }

  /// 统计各状态的传输数量
  Future<Map<String, int>> countByStatus() async {
    final result = <String, int>{};

    try {
      final maps = await _db.rawQuery(
        'SELECT status, COUNT(*) as count FROM $tableName GROUP BY status',
      );

      for (final map in maps) {
        final status = map['status'] as String?;
        final count = map['count'] as int?;
        if (status != null && count != null) {
          result[status] = count;
        }
      }
    } catch (e) {
      iPrint("⚠️ [E2EETransferRepo] countByStatus error: $e");
    }

    return result;
  }

  /// 检查表是否存在
  Future<bool> tableExists() async {
    try {
      await _db.query(tableName, limit: 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 初始化表（如果不存在）
  Future<void> initTable() async {
    if (!await tableExists()) {
      await _db.execute(createTableSql);
      for (final sql in createIndexSql) {
        await _db.execute(sql);
      }
      iPrint("✅ [E2EETransferRepo] table created: $tableName");
    }
  }
}
