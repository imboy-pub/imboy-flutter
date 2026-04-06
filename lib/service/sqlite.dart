import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/cached_sqlite_service.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
/// SQLite 本地数据库服务
/// SQLite local database service
///
/// 职责：
/// - 数据库连接管理（单例模式）
/// - CRUD 操作封装（增删改查）
/// - 事务操作支持
/// - 并发控制（使用 synchronized 锁）
/// - SQLite 标准回调（onCreate, onUpgrade, onDowngrade）
/// - 查询结果缓存（提升性能）
///
/// 注意：数据迁移、备份恢复功能由 MigrationService 提供
class SqliteService {
  static const _dbVersion = 13; // v13: Channel 频道功能 - 新增频道相关表

  // 单例构造
  SqliteService._privateConstructor();

  static final SqliteService to = SqliteService._privateConstructor();

  static Database? _db;

  // 全局数据库锁，确保所有写操作串行执行
  final Lock _dbLock = Lock();

  // 初始化锁，确保数据库只被初始化一次
  final Lock _initLock = Lock();

  // 查询缓存服务
  final CachedSqliteService _cacheService = CachedSqliteService();

  /// 获取数据库连接实例
  /// Get the database connection instance
  Future<Database?> get db async {
    if (_db != null) return _db;
    return await _initLock.synchronized(() async {
      _db = await _initDatabase();
      return _db;
    });
  }

  /// 关闭数据库连接
  /// Close the database connection
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// 构建数据库文件路径
  /// Build the database file path
  Future<String> dbPath() async {
    String name = "${currentEnv}_${UserRepoLocal.to.currentUid}.db";
    iPrint(
      "Database path: currentEnv=$currentEnv, uid=${UserRepoLocal.to.currentUid}, dbName=$name",
    );

    // Web 平台使用相对路径
    if (kIsWeb) {
      return name;
    }

    // 移动端/桌面端使用完整路径
    return join(await getDatabasesPath(), name);
  }

  /// 初始化数据库
  /// Initialize the database
  Future<Database?> _initDatabase() async {
    if (UserRepoLocal.to.currentUid.isEmpty) {
      return null;
    }

    // 👇 初始化 SQLite 数据库工厂（Web/桌面平台需要）
    // 条件导入会自动选择正确的实现
    initSqfliteFactory();

    String path = await dbPath();
    bool exists = await databaseExists(path);

    if (!exists) {
      iPrint("Creating new database");

      // Web 平台不需要文件系统操作
      if (!kIsWeb) {
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (e) {
          debugPrint('[SqliteService] directory creation failed: $e');
        }

        ByteData data = await rootBundle.load(
          url.join("assets", "example10.db"),
        );
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
      }
    } else {
      iPrint("Opening existing database");
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onOpen: _onOpen,
    );
  }

  /// 打开数据库时的配置回调
  /// Configure callback when database is opened
  FutureOr<void> _onConfigure(Database db) async {
    AppLogger.debug("SqliteService_onConfigure ${db.toString()}");

    ///  请记住，回调onCreate onUpgrade onDowngrade已经内部包装在事务中，
    ///  因此无需将语句包装在这些回调内的事务中。

    // 启用外键约束
    await db.execute('PRAGMA foreign_keys = ON');
    // 设置同步模式为NORMAL，平衡性能和数据安全
    await db.execute('PRAGMA synchronous = NORMAL');
    // 设置缓存大小为64MB，提升查询性能
    await db.execute('PRAGMA cache_size = -64000');
  }

  ///
  /// 因为是 Copy from asset，所以该方法一定不会执行
  /// 如果在调用之前数据库不存在，则调用[onCreate]
  /// 创建数据库回调
  /// Called when database is created
  Future<void> _onCreate(Database db, int version) async {
    iPrint("SqliteService_onCreate");
  }

  /// 数据库打开后的回调
  /// Called when database is opened (after onCreate/onUpgrade/onDowngrade)
  ///
  /// 在此回调中设置 WAL 模式，因为此时数据库文件已经完全初始化
  FutureOr<void> _onOpen(Database db) async {
    // 启用WAL模式，允许读写并发，提升性能
    // 注意：某些平台（如某些 Android 设备）可能不支持 WAL 或返回错误，需要捕获处理
    // 仅在非 Web 平台尝试设置 WAL 模式
    if (!kIsWeb) {
      try {
        await db.execute('PRAGMA journal_mode = WAL');
      } catch (e) {
        // WAL 失败不影响数据库使用，继续使用默认模式
        // 使用简洁的日志，避免显示完整错误堆栈
        iPrint('WAL mode not available, using default journal mode');
      }
    }
  }

  /// 数据库升级回调
  /// Called when upgrading database version
  ///
  /// 注意：实际的升级逻辑由 MigrationService 处理
  /// SqliteService 只负责调用 MigrationService
  ///
  /// 事务保证：onUpgrade 回调已经在 SQLite 的事务中执行（由 sqflite 自动处理）
  /// 如果迁移失败，SQLite 会自动回滚整个事务，确保数据库不会处于不一致状态
  Future<void> _onUpgrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onUpgrade oldVsn: $oldVsn, newVsn: $newVsn");

    // 检查当前数据库版本
    final currentVersion = await db.rawQuery('PRAGMA user_version');
    iPrint("📍 Current database version: $currentVersion");

    // 检查版本跳跃
    if (newVsn - oldVsn > 5) {
      iPrint("⚠️ Large version jump detected: v$oldVsn → v$newVsn");
    }

    // 调用 MigrationService 执行升级
    // MigrationService 会自动处理备份、恢复、数据完整性检查等逻辑
    // 注意：迁移操作在当前事务中执行，失败会自动回滚
    final result = await MigrationService.to.migrate(
      db: db,
      fromVersion: oldVsn,
      toVersion: newVsn,
      isUpgrade: true,
    );

    if (!result.success) {
      throw Exception('Migration failed: ${result.error}');
    }

    iPrint(
      "✅ Migration completed successfully: v${result.fromVersion} → v${result.toVersion}",
    );

    // 验证表结构是否正确
    await _verifyTableStructure(db);
  }

  /// 验证关键表的字段是否存在
  Future<void> _verifyTableStructure(Database db) async {
    try {
      final tables = ['msg_c2c', 'msg_c2g', 'msg_c2s', 'msg_s2c'];
      for (final table in tables) {
        final result = await db.rawQuery("PRAGMA table_info($table)");
        final columns = result.map((row) => row['name'] as String).toList();

        // 检查必需字段
        final requiredColumns = ['type', 'action', 'msg_type', 'e2ee'];
        for (final col in requiredColumns) {
          if (!columns.contains(col)) {
            throw Exception('Table $table missing required column: $col');
          }
        }
        iPrint("✅ Table $table structure verified: ${columns.length} columns");
      }
    } catch (e) {
      iPrint("⚠️ Table structure verification failed: $e");
      rethrow;
    }
  }

  /// 数据库降级回调
  /// Called when downgrading database version
  ///
  /// 注意：实际的降级逻辑由 MigrationService 处理
  /// SqliteService 只负责调用 MigrationService
  ///
  /// 事务保证：onDowngrade 回调已经在 SQLite 的事务中执行（由 sqflite 自动处理）
  /// 如果迁移失败，SQLite 会自动回滚整个事务，确保数据库不会处于不一致状态
  Future<void> _onDowngrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onDowngrade oldVsn: $oldVsn, newVsn: $newVsn");

    // 调用 MigrationService 执行降级
    // MigrationService 会自动处理备份、恢复、数据完整性检查等逻辑
    // 注意：迁移操作在当前事务中执行，失败会自动回滚
    final result = await MigrationService.to.migrate(
      db: db,
      fromVersion: oldVsn,
      toVersion: newVsn,
      isUpgrade: false,
    );

    if (!result.success) {
      throw Exception('Downgrade failed: ${result.error}');
    }

    iPrint(
      "✅ Downgrade completed successfully: v${result.fromVersion} → v${result.toVersion}",
    );
  }

  /// 插入数据（带重试机制和超时控制）
  /// Insert data (with retry logic and timeout control)
  ///
  /// 参数 (Parameters):
  /// - table: 表名
  /// - data: 要插入的数据
  /// - retries: 重试次数，默认 3
  /// - timeoutMs: 超时时间（毫秒），默认 5000ms (5秒)
  Future<int> insert(
    String table,
    Map<String, dynamic> data, {
    int retries = 3,
    int timeoutMs = 5000,
  }) async {
    final result = await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db
              .insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace)
              .timeout(
                Duration(milliseconds: timeoutMs),
                onTimeout: () {
                  AppLogger.warning('Insert timeout: table=$table');
                  return 0; // 超时返回 0
                },
              );
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          AppLogger.error('Insert error: table=$table, error=$e');
          rethrow;
        }
      }
      return 0;
    });

    // 清除相关缓存
    if (result > 0) {
      clearQueryCache(table);
    }

    return result;
  }

  /// 更新数据（带重试机制和超时控制）
  /// Update data (with retry logic and timeout control)
  ///
  /// 参数 (Parameters):
  /// - table: 表名
  /// - values: 要更新的值
  /// - where: WHERE 子句
  /// - whereArgs: WHERE 参数
  /// - conflictAlgorithm: 冲突算法
  /// - retries: 重试次数，默认 3
  /// - timeoutMs: 超时时间（毫秒），默认 5000ms (5秒)
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
    int retries = 3,
    int timeoutMs = 5000,
  }) async {
    final result = await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db
              .update(
                table,
                values,
                where: where,
                whereArgs: whereArgs,
                conflictAlgorithm: conflictAlgorithm,
              )
              .timeout(
                Duration(milliseconds: timeoutMs),
                onTimeout: () {
                  AppLogger.warning(
                    'Update timeout: table=$table, where=$where',
                  );
                  return 0; // 超时返回 0
                },
              );
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          AppLogger.error('Update error: table=$table, error=$e');
          rethrow;
        }
      }
      return 0;
    });

    // 清除相关缓存
    if (result > 0) {
      clearQueryCache(table);
    }

    return result;
  }

  /// 执行原始查询（带缓存和超时控制）
  /// Execute raw query (with cache and timeout control)
  ///
  /// 参数 (Parameters):
  /// - sql: SQL 查询语句
  /// - arguments: 查询参数
  /// - useCache: 是否使用缓存，默认 true
  /// - timeoutMs: 超时时间（毫秒），默认 5000ms (5秒)
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
    bool useCache = true,
    int timeoutMs = 5000,
  ]) async {
    final db = await this.db;
    if (db == null) return [];

    try {
      return await _cacheService
          .cachedQuery(db, sql, arguments: arguments, useCache: useCache)
          .timeout(
            Duration(milliseconds: timeoutMs),
            onTimeout: () {
              AppLogger.warning('SQL query timeout: $sql');
              return []; // 超时返回空结果
            },
          );
    } catch (e) {
      AppLogger.error('SQL query error: $sql, error: $e');
      rethrow;
    }
  }

  /// 执行原始 SQL 更新语句（带重试机制）
  /// Execute raw update SQL (with retry logic)
  Future<int> execute(
    String sql, [
    List<Object?>? arguments,
    int retries = 3,
  ]) async {
    return await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db.rawUpdate(sql, arguments);
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          AppLogger.error('Execute error: $e');
          rethrow;
        }
      }
      return 0;
    });
  }

  /// 执行查询操作（带超时控制）
  /// Perform a query (with timeout control)
  ///
  /// 参数 (Parameters):
  /// - table: 表名
  /// - distinct: 是否去重
  /// - columns: 查询的列
  /// - where: WHERE 子句
  /// - whereArgs: WHERE 参数
  /// - groupBy: GROUP BY 子句
  /// - having: HAVING 子句
  /// - orderBy: ORDER BY 子句
  /// - limit: 限制返回数量
  /// - offset: 偏移量
  /// - timeoutMs: 超时时间（毫秒），默认 10000ms (10秒)
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int timeoutMs = 10000,
  }) async {
    final db = await this.db;
    if (db == null) return [];

    try {
      return await db
          .query(
            table,
            distinct: distinct,
            columns: columns,
            where: where,
            whereArgs: whereArgs,
            groupBy: groupBy,
            having: having,
            orderBy: orderBy,
            limit: limit,
            offset: offset,
          )
          .timeout(
            Duration(milliseconds: timeoutMs),
            onTimeout: () {
              AppLogger.warning(
                'SQL query timeout: table=$table, where=$where',
              );
              return []; // 超时返回空结果
            },
          );
    } catch (e) {
      AppLogger.error('SQL query error: table=$table, error=$e');
      rethrow;
    }
  }

  /// 执行标量查询，返回首行首列值
  /// Execute scalar query, return first value of first row
  Future<T?> _scalarQuery<T>(String sql, [List<Object?>? whereArgs]) async {
    final db = await this.db;
    if (db == null) return null;
    final res = await db.rawQuery(sql, whereArgs);
    if (res.isEmpty || res.first.isEmpty) return null;
    return res.first.values.first as T?;
  }

  /// 查询某表记录总数
  /// Count number of rows in a table
  Future<int?> count(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    String sql = "SELECT COUNT(*) FROM $table";
    if (strNoEmpty(where)) {
      sql += " WHERE $where";
    }
    return await _scalarQuery<int>(sql, whereArgs);
  }

  /// 查询某一列的值（返回首行）
  /// Pluck a single column value from the first matched row
  Future<T?> pluck<T>(
    String column,
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    String sql = "SELECT $column FROM $table";
    if (strNoEmpty(where)) {
      sql += " WHERE $where";
    }
    final result = await _scalarQuery(sql, whereArgs);
    if (result == null) return null;

    // 类型转换（适配 SQLite 类型系统）
    try {
      if (result is T) return result;
      if (T == int) return int.tryParse(result.toString()) as T?;
      if (T == double) return double.tryParse(result.toString()) as T?;
      if (T == String) return result.toString() as T;
      if (T == Uint8List && result is List<int>) {
        return Uint8List.fromList(result) as T;
      }
    } catch (_) {
      AppLogger.debug('pluck<$T> 类型转换失败: $result');
    }

    return null;
  }

  /// 删除记录（带重试机制）
  /// Delete records (with retry logic)
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    int retries = 3,
  }) async {
    final result = await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db.delete(table, where: where, whereArgs: whereArgs);
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          AppLogger.error('Delete error: $e');
          rethrow;
        }
      }
      return 0;
    });

    // 清除相关缓存
    if (result > 0) {
      clearQueryCache(table);
    }

    return result;
  }

  /// 使用事务进行批处理操作
  /// Execute batch operations within a transaction
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool exclusive = false,
  }) async {
    if (exclusive) {
      // 排他事务需要全局锁
      return await _dbLock.synchronized(() async {
        final db = await this.db;
        if (db == null) throw Exception('Database is null');
        return await db.transaction(action);
      });
    } else {
      // 普通事务，依赖WAL模式的并发支持
      final db = await this.db;
      if (db == null) throw Exception('Database is null');
      return await db.transaction(action);
    }
  }

  /// 批量插入（带全局锁）
  /// Insert multiple records in batch (with global lock)
  Future<void> batchInsert(
    String table,
    List<Map<String, dynamic>> dataList, {
    int batchSize = 500,
  }) async {
    if (dataList.isEmpty) return;
    await _dbLock.synchronized(() async {
      final db = await this.db;
      if (db == null) return;
      // 分批处理，避免单次事务过大
      for (int i = 0; i < dataList.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize) < dataList.length
            ? (i + batchSize)
            : dataList.length;
        for (int j = i; j < end; j++) {
          batch.insert(
            table,
            dataList[j],
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  /// 判断数据库被锁定错误
  /// Check if error is 'database is locked'
  bool _isDatabaseLockedError(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('database is locked') ||
        errorStr.contains('database is closed') ||
        errorStr.contains('sqlite_locked') ||
        errorStr.contains('database is busy');
  }

  /// 清除查询缓存
  /// 当数据变更时调用，确保缓存一致性
  void clearQueryCache([String? pattern]) {
    if (pattern == null) {
      _cacheService.clearAllCache();
    } else {
      _cacheService.invalidateCache(pattern);
    }
  }

  /// 获取查询缓存统计信息
  Map<String, dynamic> getCacheStats() => _cacheService.getCacheStats();

  /// 清理过期缓存
  void cleanupExpiredCache() => _cacheService.cleanupExpiredCaches();
}
