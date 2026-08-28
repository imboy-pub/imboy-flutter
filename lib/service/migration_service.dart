import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:imboy/service/migrations/manifest_all.dart';
import 'package:imboy/service/migration_script.dart';
import 'package:imboy/service/migration_script_planner.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

export 'package:imboy/service/migration_script.dart';

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

  /// 已加载的降级脚本（测试用：A-21 回归守护 v19~v25 块存在性）
  @visibleForTesting
  Map<int, MigrationScript> get debugDowngradeScripts =>
      _downgradeScripts ?? const {};

  /// 已加载的升级脚本（测试用）
  @visibleForTesting
  Map<int, MigrationScript> get debugUpgradeScripts =>
      _upgradeScripts ?? const {};

  /// 初始化（加载迁移脚本）
  ///
  /// 【WP3】脚本块不再从 SQL 字符串解析，而是直接从类型化清单
  /// kMigrationManifest 构造——单一真源（边数据、方向、描述全部来自
  /// manifest；assets/migrations/*.sql 与 kUpgradeScriptSql/kDowngradeScriptSql
  /// 均为生成物，由生成器 --check 守护一致）。
  Future<void> init() async {
    if (_upgradeScripts != null) {
      _logger.d('MigrationService already initialized');
      return;
    }

    _logger.i('Initializing MigrationService...');

    try {
      _upgradeScripts = {
        for (final e in kMigrationManifest.upgradesByTo.values)
          e.blockLabel: MigrationScript(
            version: e.blockLabel,
            targetVersion: e.toVersion,
            description: e.description,
            sqlStatements: e.sqlStatements,
          ),
      };
      _downgradeScripts = {
        for (final e in kMigrationManifest.downgradesByFrom.values)
          e.blockLabel: MigrationScript(
            version: e.blockLabel,
            targetVersion: e.toVersion,
            description: e.description,
            sqlStatements: e.sqlStatements,
          ),
      };

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
  /// 这些回调已经在 sqflite 的事务中执行（回调实际收到的是事务句柄，
  /// 故参数类型为 [DatabaseExecutor]），因此不需要、也不允许额外创建事务。
  /// 迁移失败时由调用方 rethrow，sqflite 自动回滚整个事务。
  ///
  /// 【WP2 原子性契约】本方法在事务内执行，因此：
  /// - 禁止文件级快照/恢复：事务内复制主 db 文件不是一致性快照（WAL/
  ///   混合页），失败路径恢复会关闭活动连接并覆盖主库，与 sqflite 事务
  ///   回滚职责冲突（研究文档 §2.3 P0）。一致性快照由协调器在事务外
  ///   提供（后续 WP），本方法只依赖外层事务回滚。
  /// - 禁止字符串吞错：唯一允许的幂等兼容是显式的 ADD COLUMN
  ///   precondition（目标列已存在 → 跳过该条语句并留痕），其他任何 SQL
  ///   错误如实抛出交由事务回滚。
  Future<MigrationResult> migrate({
    required DatabaseExecutor db,
    required int fromVersion,
    required int toVersion,
    bool isUpgrade = true,
  }) async {
    try {
      // 确保迁移脚本已加载
      await init();

      // 数据完整性检查：迁移前验证数据库状态
      if (!await _verifyDatabaseIntegrity(db)) {
        throw Exception('Database integrity check failed before migration');
      }

      // 获取并执行 SQL（按正确顺序：升级升序、降级降序）。
      // 路径上任何所需块缺失都会抛 MissingMigrationPathException /
      // MissingMigrationScriptException（WP1），由下方 catch 转为 failure，
      // 绝不静默返回空计划成功。
      final scripts = MigrationScriptPlanner.plan(
        scripts: isUpgrade ? _upgradeScripts! : _downgradeScripts!,
        fromVersion: fromVersion,
        toVersion: toVersion,
      );

      if (scripts.isEmpty) {
        // from == to 的 no-op（planner 唯一返回空计划的合法情形）。
        // from != to 时 planner 已保证要么非空要么抛错；此处防御性
        // fail-closed：万一出现空计划，绝不报告成功。
        if (fromVersion != toVersion) {
          return MigrationResult.failure(
            error:
                'Empty migration plan for v$fromVersion → v$toVersion '
                '(fail-closed; planner should have thrown)',
            fromVersion: fromVersion,
            toVersion: toVersion,
          );
        }
        _logger.i('No-op migration: v$fromVersion → v$toVersion');
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
          // 显式幂等 precondition：脚本对已存在列重复 ADD COLUMN
          // （v11/v12 块对 v10 已加列的历史重复）时跳过并留痕；
          // 其余语句照常执行，错误如实抛出（WP2：不再吞 duplicate column）。
          if (await _addColumnAlreadySatisfied(db, sql)) {
            _logger.i(
              'Precondition satisfied, skip: ADD COLUMN already exists '
              '(${_preview(sql)})',
            );
            continue;
          }
          await db.execute(sql);
          _logger.d('Executed: ${_preview(sql)}');
        }

        // 每个脚本执行后进行完整性检查
        if (!await _verifyDatabaseIntegrity(db)) {
          throw Exception(
            'Database integrity check failed after v${script.targetVersion}',
          );
        }
      }

      _logger.i('Migration completed: v$fromVersion → v$toVersion');

      return MigrationResult.success(
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    } catch (e, stackTrace) {
      _logger.e('Migration failed', error: e, stackTrace: stackTrace);

      // 【WP2】失败路径只依赖外层 sqflite 事务回滚（调用方 rethrow 本
      // failure 后 sqflite 回滚且不推进版本号）。这里绝不：
      //   - close 数据库连接（句柄归 sqflite 管理）；
      //   - 复制/覆盖任何数据库文件（见方法注释的原子性契约）。
      return MigrationResult.failure(
        error: e.toString(),
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    }
  }

  /// 安全截取 SQL 预览（避免超长语句刷屏，也避免 SQL 短于 3 时 RangeError）
  static String _preview(String sql) =>
      sql.length > 50 ? '${sql.substring(0, 50)}...' : sql;

  /// ADD COLUMN 语句的静态识别与目标列已存在的显式 precondition。
  static final RegExp _addColumnPattern = RegExp(
    r'''ALTER\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["'`]?(\w+)["'`]?\s+ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?["'`]?(\w+)''',
    caseSensitive: false,
  );

  /// 若 [sql] 是 `ALTER TABLE t ADD COLUMN c` 且列 c 已存在，返回 true
  /// （调用方跳过该语句）；其余情况一律返回 false（照常执行）。
  ///
  /// 这是 WP2 对旧"吞 duplicate column 错误"的显式替代：幂等意图在
  /// 执行前声明，而不是执行后按错误字符串猜。
  Future<bool> _addColumnAlreadySatisfied(
    DatabaseExecutor db,
    String sql,
  ) async {
    final match = _addColumnPattern.firstMatch(sql);
    if (match == null) return false;
    final table = match.group(1)!;
    final column = match.group(2)!;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  /// 数据完整性检查
  Future<bool> _verifyDatabaseIntegrity(DatabaseExecutor db) async {
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

  /// 【WP3】历史 _parseMigrationScripts 已删除：脚本块直接从类型化清单
  /// kMigrationManifest 构造（见 init），不再从 SQL 字符串解析方向/目标。

  /// 清理旧快照
  ///
  /// 【WP2】事务内的 _createSnapshot / _restoreFromSnapshot / _cleanupSnapshot
  /// 已删除（在 sqflite 版本迁移事务回调内复制/覆盖主库文件不是一致性
  /// 操作，且与外层事务回滚冲突——研究文档 §2.3 P0）。历史遗留的
  /// db_snapshots 临时目录仍由本方法按期限清理；新的一致性快照能力由
  /// 迁移协调器（后续 WP）在事务外提供。
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
