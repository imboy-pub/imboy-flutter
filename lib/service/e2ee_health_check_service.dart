import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// E2EE 健康检查结果
///
/// 包含密钥状态检查的详细结果
class E2EEHealthCheckResult {
  /// 是否需要更新密钥
  final bool needsUpdate;

  /// 当前密钥版本
  final String? currentVersion;

  /// 最新密钥版本
  final String? latestVersion;

  /// 原因代码
  final String reason;

  /// 附加信息
  final Map<String, dynamic>? details;

  const E2EEHealthCheckResult({
    required this.needsUpdate,
    this.currentVersion,
    this.latestVersion,
    required this.reason,
    this.details,
  });

  @override
  String toString() {
    return 'E2EEHealthCheckResult(needsUpdate: $needsUpdate, reason: $reason)';
  }
}

/// E2EE 健康检查服务
///
/// 负责：
/// - 检查密钥版本同步状态
/// - 同步好友的最新公钥
/// - 重试解密失败的消息
/// - 检查会话的解密失败率
///
/// @author Imboy Team
/// @since 2026-02-14
class E2EEHealthCheckService {
  // ================================================================
  // 单例模式
  // ================================================================

  E2EEHealthCheckService._internal();
  static final E2EEHealthCheckService _instance = E2EEHealthCheckService._internal();
  static E2EEHealthCheckService get to => _instance;

  // ================================================================
  // 密钥版本检查
  // ================================================================

  /// 检查指定用户的密钥版本
  ///
  /// [uid] 用户 ID（HashID 编码）
  /// [expectedKeyId] 期望的密钥 ID（可选）
  /// Returns: 健康检查结果
  ///
  /// @example
  /// ```dart
  /// final result = await E2EEHealthCheckService.to.checkUserKeyVersion(
  ///   uid: 'user123',
  ///   expectedKeyId: 'kid_abc123',
  /// );
  /// if (result.needsUpdate) {
  ///   print('需要更新密钥: ${result.reason}');
  /// }
  /// ```
  Future<E2EEHealthCheckResult> checkUserKeyVersion({
    required String uid,
    String? expectedKeyId,
  }) async {
    try {
      // 获取当前密钥 ID
      final currentKeyId = await StorageSecure().getKeyId();

      // 获取最新的设备密钥（强制刷新）
      final deviceKeys = await E2EEService.getUserDevicePublicKeys(
        uid,
        forceRefresh: true,
      );

      if (deviceKeys.isEmpty) {
        return E2EEHealthCheckResult(
          needsUpdate: true,
          currentVersion: currentKeyId,
          reason: 'no_keys',
          details: {'uid': uid},
        );
      }

      // 检查密钥版本是否匹配
      if (expectedKeyId != null && currentKeyId != expectedKeyId) {
        debugPrint('⚠️ [E2EE] 密钥版本不匹配: 期望=$expectedKeyId, 当前=$currentKeyId');
        return E2EEHealthCheckResult(
          needsUpdate: true,
          currentVersion: currentKeyId,
          latestVersion: expectedKeyId,
          reason: 'version_mismatch',
          details: {
            'uid': uid,
            'expected': expectedKeyId,
            'current': currentKeyId,
          },
        );
      }

      return E2EEHealthCheckResult(
        needsUpdate: false,
        currentVersion: currentKeyId,
        latestVersion: currentKeyId,
        reason: 'ok',
      );
    } catch (e) {
      debugPrint('❌ [E2EE] 检查密钥版本失败: $e');
      return E2EEHealthCheckResult(
        needsUpdate: true,
        reason: 'error',
        details: {'error': e.toString()},
      );
    }
  }

  /// 批量检查多个用户的密钥版本
  ///
  /// [uids] 用户 ID 列表
  /// Returns: Map`<uid, E2EEHealthCheckResult>`
  Future<Map<String, E2EEHealthCheckResult>> checkMultipleUserKeyVersions(
    List<String> uids,
  ) async {
    final results = <String, E2EEHealthCheckResult>{};

    for (final uid in uids) {
      results[uid] = await checkUserKeyVersion(uid: uid);
    }

    return results;
  }

  // ================================================================
  // 公钥同步
  // ================================================================

  /// 同步好友的最新公钥
  ///
  /// [uid] 好友用户 ID
  /// Returns: true 如果同步成功，否则 false
  ///
  /// @example
  /// ```dart
  /// final success = await E2EEHealthCheckService.to.syncFriendPublicKey('user123');
  /// if (success) {
  ///   print('公钥已同步');
  /// }
  /// ```
  Future<bool> syncFriendPublicKey(String uid) async {
    try {
      // 强制刷新缓存
      await E2EEService.getUserDevicePublicKeys(
        uid,
        forceRefresh: true,
      );

      debugPrint('✅ [E2EE] 已同步好友 $uid 的公钥');
      return true;
    } catch (e) {
      debugPrint('❌ [E2EE] 同步好友公钥失败: $e');
      return false;
    }
  }

  /// 批量同步多个好友的公钥
  ///
  /// [uids] 用户 ID 列表
  /// Returns: Map`<uid, success>`
  Future<Map<String, bool>> syncMultipleFriendPublicKeys(
    List<String> uids,
  ) async {
    final results = <String, bool>{};

    for (final uid in uids) {
      results[uid] = await syncFriendPublicKey(uid);
    }

    return results;
  }

  // ================================================================
  // 密钥存在性检查
  // ================================================================

  /// 检查当前设备是否有有效的 E2EE 密钥
  ///
  /// Returns: true 如果有有效密钥
  Future<bool> hasValidKey() async {
    try {
      return await E2EEKeyService.hasKey();
    } catch (e) {
      debugPrint('❌ [E2EE] 检查密钥存在性失败: $e');
      return false;
    }
  }

  /// 获取当前密钥信息
  ///
  /// Returns: 密钥信息 Map，如果密钥不存在则返回 null
  Future<Map<String, dynamic>?> getKeyInfo() async {
    try {
      return await E2EEKeyService.getKeyInfo();
    } catch (e) {
      debugPrint('❌ [E2EE] 获取密钥信息失败: $e');
      return null;
    }
  }

  // ================================================================
  // 密钥健康状态
  // ================================================================

  /// 获取 E2EE 系统的整体健康状态
  ///
  /// Returns: 健康状态 Map
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final hasKey = await hasValidKey();
      final keyInfo = await getKeyInfo();

      return {
        'has_key': hasKey,
        'key_info': keyInfo,
        'status': hasKey ? 'healthy' : 'no_key',
        'checked_at': DateTime.now().toUtc().toIso8601String(),
      };
    } catch (e) {
      return {
        'has_key': false,
        'status': 'error',
        'error': e.toString(),
        'checked_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  // ================================================================
  // 解密失败消息重试
  // ================================================================

  /// 重试解密失败的消息
  ///
  /// 扫描本地消息，找出解密失败的消息并重试
  ///
  /// [conversationUk3] 会话 UK3（可选，不指定则扫描所有会话）
  /// [onProgress] 进度回调
  /// Returns: 成功恢复的消息数量
  Future<int> retryFailedMessages({
    String? conversationUk3,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      // 1. 查询解密失败的消息
      final failedMessages = await _findFailedE2EEMessages(conversationUk3);

      if (failedMessages.isEmpty) {
        debugPrint('✅ [E2EE] 没有找到解密失败的消息');
        return 0;
      }

      debugPrint('📋 [E2EE] 找到 ${failedMessages.length} 条解密失败的消息，开始重试...');

      int recoveredCount = 0;
      int current = 0;
      final total = failedMessages.length;

      // 2. 逐条重试解密
      for (final msg in failedMessages) {
        current++;
        onProgress?.call(current, total);

        final result = await _retryDecryptMessage(msg);
        if (result) {
          recoveredCount++;
        }
      }

      debugPrint('✅ [E2EE] 重试完成: 成功恢复 $recoveredCount/$total 条消息');
      return recoveredCount;
    } catch (e) {
      debugPrint('❌ [E2EE] 重试解密失败消息异常: $e');
      return 0;
    }
  }

  /// 查找解密失败的 E2EE 消息
  ///
  /// [conversationUk3] 会话 UK3（可选）
  /// Returns: 失败消息列表
  Future<List<MessageModel>> _findFailedE2EEMessages(String? conversationUk3) async {
    try {
      final db = await SqliteService.to.db;
      if (db == null) {
        debugPrint('❌ [E2EE] 数据库未初始化');
        return [];
      }

      final List<MessageModel> failedMessages = [];

      // 查询所有消息表
      final tables = [
        MessageRepo.c2cTable,
        MessageRepo.c2gTable,
      ];

      for (final table in tables) {
        // 检查表是否存在
        final tableExists = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
            [table],
          ),
        );

        if (tableExists == null || tableExists == 0) {
          continue;
        }

        // 构建查询条件
        String whereClause;
        List<dynamic> whereArgs;

        if (conversationUk3 != null && conversationUk3.isNotEmpty) {
          whereClause = 'conversation_uk3 = ? AND payload LIKE ?';
          whereArgs = [conversationUk3, '%_e2ee_failed%'];
        } else {
          whereClause = 'payload LIKE ?';
          whereArgs = ['%_e2ee_failed%'];
        }

        final maps = await db.query(
          table,
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'created_at DESC',
          limit: 100, // 限制每次最多处理 100 条
        );

        for (final map in maps) {
          try {
            final msg = MessageModel.fromJson(map);
            // 验证是否真的是 E2EE 失败消息
            if (_isE2EEFailedMessage(msg)) {
              failedMessages.add(msg);
            }
          } catch (e) {
            debugPrint('⚠️ [E2EE] 解析消息失败: $e');
          }
        }
      }

      return failedMessages;
    } catch (e) {
      debugPrint('❌ [E2EE] 查询失败消息异常: $e');
      return [];
    }
  }

  /// 检查消息是否为 E2EE 解密失败消息
  bool _isE2EEFailedMessage(MessageModel msg) {
    final payload = msg.payload;
    if (payload == null) return false;

    Map<String, dynamic>? payloadMap;

    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          payloadMap = decoded;
        }
      } catch (_) {
        return false;
      }
    } else if (payload is Map<String, dynamic>) {
      payloadMap = payload;
    }

    if (payloadMap == null) return false;

    // 检查是否有 _e2ee_failed 标记
    return payloadMap['_e2ee_failed'] == true;
  }

  /// 重试解密单条消息
  ///
  /// [msg] 失败的消息
  /// Returns: true 如果解密成功并更新了消息
  Future<bool> _retryDecryptMessage(MessageModel msg) async {
    try {
      final payload = msg.payload;
      if (payload == null) return false;

      Map<String, dynamic>? payloadMap;

      if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          payloadMap = decoded;
        }
      } else if (payload is Map<String, dynamic>) {
        payloadMap = payload;
      }

      if (payloadMap == null) return false;

      // 检查是否有原始密文
      if (payloadMap['_e2ee_raw_ciphertext'] == null) {
        debugPrint('⚠️ [E2EE] 消息 ${msg.id} 没有原始密文，跳过');
        return false;
      }

      // 调用 E2EEService 重试解密
      final result = await E2EEService.retryDecryptFailedMessage(payloadMap);

      // 检查是否解密成功
      if (result.containsKey('_e2ee_failed') && result['_e2ee_failed'] == true) {
        debugPrint('⚠️ [E2EE] 消息 ${msg.id} 重试解密仍然失败');
        return false;
      }

      // 解密成功，更新数据库
      final table = msg.type == 'C2G' ? MessageRepo.c2gTable : MessageRepo.c2cTable;
      final repo = MessageRepo(tableName: table);

      await repo.update({
        'id': msg.id,
        'payload': result,
        'e2ee': null, // 清除失败标记
      });

      debugPrint('✅ [E2EE] 消息 ${msg.id} 解密成功并已更新');
      return true;
    } catch (e) {
      debugPrint('❌ [E2EE] 重试解密消息 ${msg.id} 异常: $e');
      return false;
    }
  }

  /// 检查会话的解密失败率
  ///
  /// [conversationUk3] 会话 UK3
  /// Returns: 解密失败率（0.0 - 1.0）
  Future<double> checkConversationFailureRate(String conversationUk3) async {
    try {
      final db = await SqliteService.to.db;
      if (db == null) {
        debugPrint('❌ [E2EE] 数据库未初始化');
        return 0.0;
      }

      // 查询所有消息表
      final tables = [
        MessageRepo.c2cTable,
        MessageRepo.c2gTable,
      ];

      int totalMessages = 0;
      int failedMessages = 0;

      for (final table in tables) {
        // 检查表是否存在
        final tableExists = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
            [table],
          ),
        );

        if (tableExists == null || tableExists == 0) {
          continue;
        }

        // 统计该会话的总消息数
        final countResult = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $table WHERE conversation_uk3 = ?',
            [conversationUk3],
          ),
        );
        totalMessages += (countResult ?? 0);

        // 统计解密失败的消息数（payload 中包含 _e2ee_failed）
        final failedResult = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $table WHERE conversation_uk3 = ? AND payload LIKE ?',
            [conversationUk3, '%_e2ee_failed%'],
          ),
        );
        failedMessages += (failedResult ?? 0);
      }

      if (totalMessages == 0) {
        return 0.0;
      }

      final rate = failedMessages / totalMessages;
      debugPrint('📊 [E2EE] 会话 $conversationUk3 解密失败率: ${(rate * 100).toStringAsFixed(2)}% ($failedMessages/$totalMessages)');

      return rate;
    } catch (e) {
      debugPrint('❌ [E2EE] 检查解密失败率异常: $e');
      return 0.0;
    }
  }
}
