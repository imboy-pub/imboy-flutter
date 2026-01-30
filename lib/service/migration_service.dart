import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 迁移脚本模型
class MigrationScript {
  final int version; // 起始版本
  final int targetVersion; // 目标版本
  final String description;
  final List<String> sqlStatements;

  MigrationScript({
    required this.version,
    required this.targetVersion,
    required this.description,
    required this.sqlStatements,
  });

  String get fullSql => sqlStatements.join('\n');
}

/// 迁移结果
class MigrationResult {
  final bool success;
  final int? fromVersion;
  final int? toVersion;
  final String? error;
  final String? snapshotPath;

  MigrationResult({
    required this.success,
    this.fromVersion,
    this.toVersion,
    this.error,
    this.snapshotPath,
  });

  factory MigrationResult.success({int? fromVersion, int? toVersion}) {
    return MigrationResult(
      success: true,
      fromVersion: fromVersion,
      toVersion: toVersion,
    );
  }

  factory MigrationResult.failure({
    required String error,
    int? fromVersion,
    int? toVersion,
    String? snapshotPath,
  }) {
    return MigrationResult(
      success: false,
      error: error,
      fromVersion: fromVersion,
      toVersion: toVersion,
      snapshotPath: snapshotPath,
    );
  }
}

/// 数据库迁移服务
///
/// 职责：
/// 1. 从资源文件加载迁移脚本
/// 2. 解析版本化迁移脚本
/// 3. 执行增量迁移
/// 4. 提供备份和恢复机制
class MigrationService {
  static final Logger _logger = Logger();

  /// 升级脚本路径
  static const String _upgradeScriptPath = 'assets/migrations/upgrade.sql';

  /// 降级脚本路径
  static const String _downgradeScriptPath = 'assets/migrations/downgrade.sql';

  // 单例
  static final MigrationService to = MigrationService._privateConstructor();

  MigrationService._privateConstructor();

  /// 升级脚本缓存
  Map<int, MigrationScript>? _upgradeScripts;

  /// 降级脚本缓存
  Map<int, MigrationScript>? _downgradeScripts;

  /// 当前目标版本（从升级脚本中获取）
  int get targetVersion {
    if (_upgradeScripts == null || _upgradeScripts!.isEmpty) {
      return 9; // 默认版本
    }
    // 返回最高目标版本
    return _upgradeScripts!.values
        .map((s) => s.targetVersion)
        .reduce((a, b) => a > b ? a : b);
  }

  /// 初始化（加载迁移脚本）
  Future<void> init() async {
    if (_upgradeScripts != null) {
      _logger.d('MigrationService already initialized');
      return;
    }

    _logger.i('Initializing MigrationService...');

    try {
      _upgradeScripts = await _loadMigrationScripts(_upgradeScriptPath);
      _downgradeScripts = await _loadMigrationScripts(_downgradeScriptPath);

      _logger.i('MigrationService initialized');
      _logger.i('Loaded ${_upgradeScripts!.length} upgrade scripts');
      _logger.i('Loaded ${_downgradeScripts!.length} downgrade scripts');
      _logger.i('Target version: $targetVersion');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to initialize MigrationService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 自动迁移（App 启动时调用）
  Future<MigrationResult> autoMigrate() async {
    await init();

    // 注意：这里不直接获取 db，而是由 SqliteService 调用
    // 这个方法主要用于检查是否有待执行的迁移
    final currentVersion = await _getCurrentVersion();
    final target = targetVersion;

    _logger.i('Auto migration check: v$currentVersion → v$target');

    if (currentVersion >= target) {
      _logger.i('Database is up to date (v$currentVersion)');
      return MigrationResult.success(
        fromVersion: currentVersion,
        toVersion: currentVersion,
      );
    }

    // 返回需要迁移的信息，由 SqliteService 执行实际迁移
    return MigrationResult.success(
      fromVersion: currentVersion,
      toVersion: target,
    );
  }

  /// 获取当前数据库版本
  Future<int> _getCurrentVersion() async {
    // 注意：这个方法需要由 SqliteService 提供数据库实例
    // 这里只是一个占位，实际实现需要与 SqliteService 集成
    return 9; // 默认版本
  }

  /// 执行迁移（由 SqliteService 调用）
  ///
  /// 注意：此方法在 SqliteService 的 onUpgrade/onDowngrade 回调中被调用，
  /// 这些回调已经在事务中执行，因此不需要额外创建事务。
  /// 如果迁移失败，SQLite 会自动回滚整个事务。
  Future<MigrationResult> migrate({
    required Database db,
    required int fromVersion,
    required int toVersion,
    bool isUpgrade = true,
  }) async {
    String? snapshotPath;

    try {
      // 确保迁移脚本已加载
      await init();

      // 创建快照（在事务外执行）
      snapshotPath = await _createSnapshot(db);

      // 数据完整性检查：迁移前验证数据库状态
      if (!await _verifyDatabaseIntegrity(db)) {
        throw Exception('Database integrity check failed before migration');
      }

      // 获取并执行 SQL
      final scripts = isUpgrade
          ? _getMigrationScripts(_upgradeScripts!, fromVersion, toVersion)
          : _getMigrationScripts(_downgradeScripts!, toVersion, fromVersion);

      if (scripts.isEmpty) {
        _logger.w('No migration scripts found for v$fromVersion → v$toVersion');
        return MigrationResult.success(
          fromVersion: fromVersion,
          toVersion: toVersion,
        );
      }

      _logger.i('Executing ${scripts.length} migration scripts...');

      // 执行迁移（已在事务中，由 SqliteService 的 onUpgrade/onDowngrade 回调保证）
      for (int i = 0; i < scripts.length; i++) {
        final script = scripts[i];
        _logger.i(
          'Progress: ${i + 1}/${scripts.length} - v${script.version} → v${script.targetVersion}',
        );

        for (final sql in script.sqlStatements) {
          try {
            await db.execute(sql);
            // 安全截取：避免 SQL 语句长度小于 50 时抛出 RangeError
            final preview = sql.length > 50 ? '${sql.substring(0, 50)}...' : sql;
            _logger.d('Executed: $preview');
          } catch (e) {
            // 忽略 "duplicate column" 错误（字段已存在）
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('duplicate column')) {
              _logger.w('Column already exists (ignoring): $e');
            } else {
              // 其他错误重新抛出
              rethrow;
            }
          }
        }

        // 每个脚本执行后进行完整性检查
        if (!await _verifyDatabaseIntegrity(db)) {
          throw Exception(
            'Database integrity check failed after v${script.targetVersion}',
          );
        }
      }

      // 清理快照
      await _cleanupSnapshot(snapshotPath);

      _logger.i('Migration completed: v$fromVersion → v$toVersion');

      return MigrationResult.success(
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    } catch (e, stackTrace) {
      _logger.e('Migration failed', error: e, stackTrace: stackTrace);

      // 注意：由于此方法在 SQLite 事务中执行，失败会自动回滚
      // 快照恢复只在事务回滚失败时作为备用方案
      if (snapshotPath != null) {
        try {
          await _restoreFromSnapshot(db, snapshotPath);
          _logger.i('Restored from snapshot');
        } catch (restoreError) {
          _logger.e('Failed to restore from snapshot', error: restoreError);
        }
      }

      return MigrationResult.failure(
        error: e.toString(),
        fromVersion: fromVersion,
        toVersion: toVersion,
        snapshotPath: snapshotPath,
      );
    }
  }

  /// 数据完整性检查
  Future<bool> _verifyDatabaseIntegrity(Database db) async {
    try {
      // 执行 SQLite 完整性检查
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isNotEmpty && result.first.values.first != 'ok') {
        _logger.e(
          'Database integrity check failed: ${result.first.values.first}',
        );
        return false;
      }

      // 检查外键约束
      final foreignKeyCheck = await db.rawQuery('PRAGMA foreign_key_check');
      if (foreignKeyCheck.isNotEmpty) {
        _logger.e('Foreign key check failed: $foreignKeyCheck');
        return false;
      }

      return true;
    } catch (e) {
      _logger.e('Error during integrity check: $e');
      return false;
    }
  }

  /// 加载迁移脚本文件
  Future<Map<int, MigrationScript>> _loadMigrationScripts(
    String scriptPath,
  ) async {
    try {
      final content = await rootBundle.loadString(scriptPath);
      return _parseMigrationScripts(content);
    } catch (e) {
      _logger.w('Failed to load migration scripts from $scriptPath: $e');
      return {}; // 返回空映射，允许没有迁移脚本的情况
    }
  }

  /// 解析迁移脚本文件
  Map<int, MigrationScript> _parseMigrationScripts(String content) {
    final scripts = <int, MigrationScript>{};

    // 按版本标记分割
    final blocks = content.split('-- VERSION:');

    for (final block in blocks.skip(1)) {
      final lines = block.split('\n');
      if (lines.isEmpty) continue;

      // 解析版本号（起始版本）
      final startVersion = int.tryParse(lines[0].trim());
      if (startVersion == null) continue;

      // 解析元数据
      String description = '';

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('-- DESC:')) {
          description = trimmed.substring('-- DESC:'.length).trim();
        }
      }

      // 提取 SQL 语句
      final sqlStatements = <String>[];
      final currentStatement = StringBuffer();

      // 目标版本（从 PRAGMA user_version 中提取）
      int targetVersion = startVersion;

      // 跳过第一行（版本号），从第二行开始处理 SQL 语句
      for (final line in lines.skip(1)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('--')) continue;

        currentStatement.write(line);
        currentStatement.write('\n');

        // 提取 PRAGMA user_version 作为目标版本
        if (trimmed.startsWith('PRAGMA user_version')) {
          final match = RegExp(
            r'PRAGMA user_version\s*=\s*(\d+)',
          ).firstMatch(trimmed);
          if (match != null) {
            targetVersion = int.parse(match.group(1)!);
          }
        }

        if (trimmed.endsWith(';')) {
          sqlStatements.add(currentStatement.toString().trim());
          currentStatement.clear();
        }
      }

      if (currentStatement.isNotEmpty) {
        sqlStatements.add(currentStatement.toString().trim());
      }

      // 使用起始版本作为 key
      scripts[startVersion] = MigrationScript(
        version: startVersion,
        targetVersion: targetVersion,
        description: description,
        sqlStatements: sqlStatements,
      );
    }

    return scripts;
  }

  /// 获取需要执行的迁移脚本
  List<MigrationScript> _getMigrationScripts(
    Map<int, MigrationScript> scripts,
    int fromVersion,
    int toVersion,
  ) {
    final result = <MigrationScript>[];

    // 获取所有需要执行的脚本（按起始版本排序）
    final sortedKeys = scripts.keys.toList()..sort();

    for (final startVersion in sortedKeys) {
      final script = scripts[startVersion];
      if (script == null) continue;

      // 只执行起始版本 > fromVersion 且目标版本 <= toVersion 的脚本
      // 注意：起始版本等于 fromVersion 的脚本是当前版本，不需要执行
      if (script.version > fromVersion && script.targetVersion <= toVersion) {
        result.add(script);
      }
    }

    return result;
  }

  /// 创建快照
  Future<String> _createSnapshot(Database db) async {
    final dbPath = db.path;
    final tempDir = await getTemporaryDirectory();
    final snapshotDir = Directory(path.join(tempDir.path, 'db_snapshots'));
    await snapshotDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final snapshotPath = path.join(snapshotDir.path, 'snapshot_$timestamp.db');

    await File(dbPath).copy(snapshotPath);
    _logger.d('Snapshot created: $snapshotPath');

    return snapshotPath;
  }

  /// 从快照恢复
  Future<void> _restoreFromSnapshot(Database db, String snapshotPath) async {
    final dbPath = db.path;

    await db.close();

    await File(snapshotPath).copy(dbPath);

    // 重新打开数据库
    // 注意：这里需要由 SqliteService 重新打开
  }

  /// 清理快照
  Future<void> _cleanupSnapshot(String snapshotPath) async {
    try {
      await File(snapshotPath).delete();
    } catch (e) {
      _logger.w('Failed to cleanup snapshot: $e');
    }
  }

  /// 清理旧快照
  Future<int> cleanupOldSnapshots({
    Duration maxAge = const Duration(days: 1),
  }) async {
    final tempDir = await getTemporaryDirectory();
    final snapshotDir = Directory(path.join(tempDir.path, 'db_snapshots'));

    if (!await snapshotDir.exists()) return 0;

    int cleaned = 0;
    final now = DateTime.now();

    await for (final entity in snapshotDir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        if (now.difference(stat.modified) > maxAge) {
          await entity.delete();
          cleaned++;
        }
      }
    }

    return cleaned;
  }
}
