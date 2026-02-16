/// E2EE 社交恢复仓库
///
/// 管理社交恢复的代理信息和分片记录
///
/// @author ImBoy Team
/// @since 2026-02-14
library;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite/sqflite.dart';

/// 代理信息模型
class E2EESocialTrusteeModel {
  /// 自增 ID
  final int? id;

  /// 代理用户 ID
  final String trusteeUid;

  /// 代理设备 ID
  final String? trusteeDeviceId;

  /// 分片索引
  final int shareIndex;

  /// 状态 (pending, accepted, rejected, expired)
  final String status;

  /// 邀请时间
  final String invitedAt;

  /// 接受时间
  final String? acceptedAt;

  /// 加密的分片数据（Base64）
  final String? encryptedShare;

  /// 分片有效期（ISO8601）
  final String? expiresAt;

  const E2EESocialTrusteeModel({
    this.id,
    required this.trusteeUid,
    this.trusteeDeviceId,
    required this.shareIndex,
    required this.status,
    required this.invitedAt,
    this.acceptedAt,
    this.encryptedShare,
    this.expiresAt,
  });

  factory E2EESocialTrusteeModel.fromMap(Map<String, dynamic> map) {
    return E2EESocialTrusteeModel(
      id: map['id'] as int?,
      trusteeUid: map['trustee_uid'] as String,
      trusteeDeviceId: map['trustee_device_id']?.toString(),
      shareIndex: map['share_index'] as int,
      status: map['status'] as String,
      invitedAt: map['invited_at'] as String,
      acceptedAt: map['accepted_at']?.toString(),
      encryptedShare: map['encrypted_share']?.toString(),
      expiresAt: map['expires_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'trustee_uid': trusteeUid,
      'trustee_device_id': trusteeDeviceId,
      'share_index': shareIndex,
      'status': status,
      'invited_at': invitedAt,
      'accepted_at': acceptedAt,
      'encrypted_share': encryptedShare,
      'expires_at': expiresAt,
    };
  }

  /// 转换为 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'uid': trusteeUid,
      'device_id': trusteeDeviceId,
      'share_index': shareIndex,
      'status': status,
      'invited_at': invitedAt,
      'accepted_at': acceptedAt,
    };
  }
}

/// 社交恢复配置模型
class E2EESocialConfigModel {
  /// 自增 ID
  final int? id;

  /// 用户 ID
  final String uid;

  /// 代理总数
  final int trusteeCount;

  /// 恢复阈值
  final int threshold;

  /// 配置创建时间
  final String createdAt;

  /// 最后更新时间
  final String? updatedAt;

  /// 是否激活
  final bool isActive;

  const E2EESocialConfigModel({
    this.id,
    required this.uid,
    required this.trusteeCount,
    required this.threshold,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory E2EESocialConfigModel.fromMap(Map<String, dynamic> map) {
    return E2EESocialConfigModel(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      trusteeCount: map['trustee_count'] as int,
      threshold: map['threshold'] as int,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at']?.toString(),
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'trustee_count': trusteeCount,
      'threshold': threshold,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_active': isActive ? 1 : 0,
    };
  }
}

/// E2EE 社交恢复仓库
///
/// 单例模式，提供代理和配置的 CRUD 操作
class E2EESocialRepo {
  /// 单例实例
  static final E2EESocialRepo _instance = E2EESocialRepo._internal();

  factory E2EESocialRepo() => _instance;

  E2EESocialRepo._internal();

  /// 数据库服务
  final SqliteService _db = SqliteService.to;

  /// 代理表名
  static const String trusteeTableName = 'e2ee_social_trustee';

  /// 配置表名
  static const String configTableName = 'e2ee_social_config';

  // ================================================================
  // 表结构定义
  // ================================================================

  /// 代理表建表 SQL
  static const String createTrusteeTableSql = '''
    CREATE TABLE IF NOT EXISTS $trusteeTableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trustee_uid TEXT NOT NULL,
      trustee_device_id TEXT,
      share_index INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      invited_at TEXT NOT NULL,
      accepted_at TEXT,
      encrypted_share TEXT,
      expires_at TEXT,
      UNIQUE(trustee_uid, share_index)
    );
  ''';

  /// 配置表建表 SQL
  static const String createConfigTableSql = '''
    CREATE TABLE IF NOT EXISTS $configTableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uid TEXT NOT NULL UNIQUE,
      trustee_count INTEGER NOT NULL DEFAULT 5,
      threshold INTEGER NOT NULL DEFAULT 3,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      is_active INTEGER NOT NULL DEFAULT 1
    );
  ''';

  /// 创建索引 SQL
  static const List<String> createIndexSql = [
    'CREATE INDEX IF NOT EXISTS idx_${trusteeTableName}_uid ON $trusteeTableName (trustee_uid);',
    'CREATE INDEX IF NOT EXISTS idx_${trusteeTableName}_status ON $trusteeTableName (status);',
    'CREATE INDEX IF NOT EXISTS idx_${configTableName}_uid ON $configTableName (uid);',
  ];

  // ================================================================
  // 代理操作
  // ================================================================

  /// 添加代理
  Future<int> addTrustee(E2EESocialTrusteeModel trustee, {Transaction? txn}) async {
    iPrint("📝 [E2EESocialRepo] addTrustee: ${trustee.trusteeUid}");

    final map = trustee.toMap();
    map.remove('id');

    if (txn != null) {
      return await txn.insert(trusteeTableName, map);
    } else {
      return await _db.insert(trusteeTableName, map);
    }
  }

  /// 批量添加代理
  Future<void> addTrustees(List<E2EESocialTrusteeModel> trustees) async {
    await _db.transaction((txn) async {
      for (final trustee in trustees) {
        await addTrustee(trustee, txn: txn);
      }
    });
  }

  /// 更新代理状态
  Future<int> updateTrusteeStatus(
    String trusteeUid,
    String status, {
    Transaction? txn,
  }) async {
    iPrint("📝 [E2EESocialRepo] updateTrusteeStatus: $trusteeUid -> $status");

    final data = {
      'status': status,
      if (status == 'accepted')
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (txn != null) {
      return await txn.update(
        trusteeTableName,
        data,
        where: 'trustee_uid = ?',
        whereArgs: [trusteeUid],
      );
    } else {
      return await _db.update(
        trusteeTableName,
        data,
        where: 'trustee_uid = ?',
        whereArgs: [trusteeUid],
      );
    }
  }

  /// 保存加密的分片
  Future<int> saveEncryptedShare(
    String trusteeUid,
    int shareIndex,
    String encryptedShare, {
    Transaction? txn,
  }) async {
    iPrint("🔐 [E2EESocialRepo] saveEncryptedShare for: $trusteeUid");

    final data = {
      'encrypted_share': encryptedShare,
      'status': 'pending',
    };

    if (txn != null) {
      return await txn.update(
        trusteeTableName,
        data,
        where: 'trustee_uid = ? AND share_index = ?',
        whereArgs: [trusteeUid, shareIndex],
      );
    } else {
      return await _db.update(
        trusteeTableName,
        data,
        where: 'trustee_uid = ? AND share_index = ?',
        whereArgs: [trusteeUid, shareIndex],
      );
    }
  }

  /// 获取所有代理
  Future<List<E2EESocialTrusteeModel>> getAllTrustees() async {
    final maps = await _db.query(
      trusteeTableName,
      orderBy: 'share_index ASC',
    );

    return maps.map((map) => E2EESocialTrusteeModel.fromMap(map)).toList();
  }

  /// 获取已接受代理（用于恢复）
  Future<List<E2EESocialTrusteeModel>> getAcceptedTrustees() async {
    final maps = await _db.query(
      trusteeTableName,
      where: 'status = ?',
      whereArgs: ['accepted'],
      orderBy: 'share_index ASC',
    );

    return maps.map((map) => E2EESocialTrusteeModel.fromMap(map)).toList();
  }

  /// 获取待处理代理
  Future<List<E2EESocialTrusteeModel>> getPendingTrustees() async {
    final maps = await _db.query(
      trusteeTableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'share_index ASC',
    );

    return maps.map((map) => E2EESocialTrusteeModel.fromMap(map)).toList();
  }

  /// 根据用户 ID 查找代理
  Future<E2EESocialTrusteeModel?> findTrusteeByUid(String trusteeUid) async {
    final maps = await _db.query(
      trusteeTableName,
      where: 'trustee_uid = ?',
      whereArgs: [trusteeUid],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return E2EESocialTrusteeModel.fromMap(maps.first);
  }

  /// 删除代理
  Future<int> deleteTrustee(String trusteeUid, {Transaction? txn}) async {
    iPrint("🗑️ [E2EESocialRepo] deleteTrustee: $trusteeUid");

    if (txn != null) {
      return await txn.delete(
        trusteeTableName,
        where: 'trustee_uid = ?',
        whereArgs: [trusteeUid],
      );
    } else {
      return await _db.delete(
        trusteeTableName,
        where: 'trustee_uid = ?',
        whereArgs: [trusteeUid],
      );
    }
  }

  /// 清空所有代理
  Future<int> deleteAllTrustees({Transaction? txn}) async {
    iPrint("🧹 [E2EESocialRepo] deleteAllTrustees");

    if (txn != null) {
      return await txn.delete(trusteeTableName);
    } else {
      return await _db.delete(trusteeTableName);
    }
  }

  /// 统计各状态的代理数量
  Future<Map<String, int>> countTrusteesByStatus() async {
    final result = <String, int>{};

    try {
      final maps = await _db.rawQuery(
        'SELECT status, COUNT(*) as count FROM $trusteeTableName GROUP BY status',
      );

      for (final map in maps) {
        final status = map['status'] as String?;
        final count = map['count'] as int?;
        if (status != null && count != null) {
          result[status] = count;
        }
      }
    } catch (e) {
      iPrint("⚠️ [E2EESocialRepo] countTrusteesByStatus error: $e");
    }

    return result;
  }

  // ================================================================
  // 配置操作
  // ================================================================

  /// 保存配置
  Future<int> saveConfig(E2EESocialConfigModel config, {Transaction? txn}) async {
    iPrint("📝 [E2EESocialRepo] saveConfig for: ${config.uid}");

    // 先尝试更新
    final existing = await getConfig(config.uid);
    if (existing != null) {
      final data = {
        'trustee_count': config.trusteeCount,
        'threshold': config.threshold,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_active': config.isActive ? 1 : 0,
      };

      if (txn != null) {
        return await txn.update(
          configTableName,
          data,
          where: 'uid = ?',
          whereArgs: [config.uid],
        );
      } else {
        return await _db.update(
          configTableName,
          data,
          where: 'uid = ?',
          whereArgs: [config.uid],
        );
      }
    }

    // 不存在则插入
    final map = config.toMap();
    map.remove('id');

    if (txn != null) {
      return await txn.insert(configTableName, map);
    } else {
      return await _db.insert(configTableName, map);
    }
  }

  /// 获取配置
  Future<E2EESocialConfigModel?> getConfig(String uid) async {
    final maps = await _db.query(
      configTableName,
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return E2EESocialConfigModel.fromMap(maps.first);
  }

  /// 停用配置
  Future<int> deactivateConfig(String uid, {Transaction? txn}) async {
    iPrint("🔴 [E2EESocialRepo] deactivateConfig for: $uid");

    final data = {
      'is_active': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (txn != null) {
      return await txn.update(
        configTableName,
        data,
        where: 'uid = ?',
        whereArgs: [uid],
      );
    } else {
      return await _db.update(
        configTableName,
        data,
        where: 'uid = ?',
        whereArgs: [uid],
      );
    }
  }

  // ================================================================
  // 表管理
  // ================================================================

  /// 检查表是否存在
  Future<bool> _tableExists(String tableName) async {
    try {
      await _db.query(tableName, limit: 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 初始化表（如果不存在）
  Future<void> initTables() async {
    if (!await _tableExists(trusteeTableName)) {
      await _db.execute(createTrusteeTableSql);
      iPrint("✅ [E2EESocialRepo] table created: $trusteeTableName");
    }

    if (!await _tableExists(configTableName)) {
      await _db.execute(createConfigTableSql);
      iPrint("✅ [E2EESocialRepo] table created: $configTableName");
    }

    // 创建索引
    for (final sql in createIndexSql) {
      try {
        await _db.execute(sql);
      } catch (e) {
        // 索引可能已存在，忽略错误
      }
    }
  }
}
