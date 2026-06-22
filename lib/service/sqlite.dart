import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/cached_sqlite_service.dart';
import 'package:imboy/service/db_encryption_key_service.dart';
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
  // v21: 修复 moment_notify 唯一索引 NULL 语义（COALESCE(comment_id, '')）
  // v20: Slice A-1 新增 moment_notify 表（朋友圈通知中心）
  // v19: 群成员禁言 group_member.mute_until
  // v18: C7-α-1 本地 DND 免打扰 conversation.is_muted
  static const _dbVersion = 21;

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
    // 仅当缓存句柄仍处于打开状态才复用。迁移回滚等路径可能在 SqliteService
    // 之外关闭底层 Database（见 migration_service._restoreFromSnapshot）却未重置
    // _db，旧逻辑会派发已关闭句柄导致 database_closed 刷屏。此处改为按 isOpen
    // 判断并自动重开。
    final cached = _db;
    if (cached != null && cached.isOpen) return cached;
    return await _initLock.synchronized(() async {
      // 双重检查：可能已被其它等待者重开
      final c = _db;
      if (c != null && c.isOpen) return c;
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
        } catch (e, s) {
          AppLogger.error('[sqlite] Directory creation error', e, s);
          rethrow;
        }

        // 加密平台不复制明文模板：
        // SQLCipher 创建数据库时会自动加密，onCreate 回调负责建表。
        // 明文模板无法被 SQLCipher 打开（报 "out of memory" = 密钥不匹配）。
        // 非加密平台仍复制明文模板（模板含初始 schema，避免 onCreate 为空）。
        if (!isEncryptionSupported) {
          ByteData data = await rootBundle.load(
            url.join("assets", "example10.db"),
          );
          List<int> bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          await File(path).writeAsBytes(bytes, flush: true);
        }
      }
    } else {
      iPrint("Opening existing database");
    }

    // 获取加密密钥（支持加密的平台才启用）
    String? password;
    bool encrypted = false;
    final uid = UserRepoLocal.to.currentUid;
    if (isEncryptionSupported) {
      password = await DbEncryptionKeyService.getOrCreateKey(uid);

      if (exists) {
        // 已有数据库：检测是否已加密，未加密则尝试迁移
        encrypted = await _migrateToEncryptedIfNeeded(path, password);
      } else {
        // 新建数据库：SQLCipher 直接创建加密数据库
        encrypted = true;
      }

      // 清理过期的加密迁移备份文件（7 天后自动删除）
      unawaited(_cleanupEncryptionBackups(path));
    }

    try {
      return await openEncryptedDatabase(
        path,
        // 迁移失败时回退到无密码打开（明文模式）
        password: encrypted ? password : null,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      AppLogger.error('Failed to open database: $e');
      // 二次兜底：用密码打开失败，尝试无密码打开
      if (encrypted && password != null) {
        try {
          AppLogger.warning('Retrying database open without encryption...');
          return await openEncryptedDatabase(
            path,
            password: null,
            version: _dbVersion,
            onConfigure: _onConfigure,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
            onDowngrade: _onDowngrade,
            onOpen: _onOpen,
          );
        } catch (fallbackError) {
          AppLogger.error('Fallback open also failed: $fallbackError');
        }
      }
      // 返回 null 触发降级处理，避免应用崩溃
      return null;
    }
  }

  /// 检测并迁移未加密数据库到加密数据库
  ///
  /// 迁移策略：
  /// 1. 尝试用密码打开数据库（检测是否已加密）
  /// 2. 如果成功 → 已加密，返回 true
  /// 3. 如果失败 → 文件是明文的，SQLCipher 无法打开明文文件
  ///    → 备份原文件 → 删除 → 返回 true（让调用方创建新的加密数据库）
  ///    → 数据从服务器重新同步
  ///
  /// 返回 true 表示数据库已加密或已删除可重建
  /// 返回 false 表示迁移失败且无法恢复
  Future<bool> _migrateToEncryptedIfNeeded(String path, String password) async {
    // 先尝试用密码打开，如果成功说明已经加密
    try {
      final testDb = await openEncryptedDatabase(path, password: password);
      await testDb.rawQuery('SELECT count(*) FROM sqlite_master');
      await testDb.close();
      iPrint('✅ Database already encrypted');
      return true;
    } catch (_) {
      // 用密码打开失败，说明未加密
      iPrint('🔄 Database not yet encrypted');
    }

    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      // 空文件或不存在 → 直接创建加密数据库
      return true;
    }

    // 文件是明文的，SQLCipher 无法打开
    // 策略：备份 → 删除 → 让调用方创建新的加密库
    final backupPath = '$path.plain.bak';
    try {
      await file.copy(backupPath);
      iPrint('📦 Backed up plaintext database to $backupPath');
    } catch (e) {
      AppLogger.error('Failed to backup plaintext database: $e');
    }

    try {
      await file.delete();
      iPrint('🗑️ Deleted plaintext database (backup preserved)');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete plaintext database: $e');
      return false;
    }
  }

  /// 清理过期的加密迁移备份文件
  ///
  /// 在加密迁移成功后，备份文件保留 7 天。
  /// 超过 7 天的备份自动删除，避免占用存储空间。
  static Future<void> _cleanupEncryptionBackups(
    String dbPath, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    // 清理两种命名模式的备份文件
    final backupPaths = ['$dbPath.plain.bak', '$dbPath.pre_encrypt.bak'];
    try {
      for (final backupPath in backupPaths) {
        final backupFile = File(backupPath);
        if (!await backupFile.exists()) continue;

        final stat = await backupFile.stat();
        if (DateTime.now().difference(stat.modified) > maxAge) {
          await backupFile.delete();
          iPrint('🗑️ Deleted expired encryption backup: $backupPath');
        }
      }
    } catch (e) {
      // 清理失败不影响正常功能，仅记录日志
      AppLogger.debug('Encryption backup cleanup failed: $e');
    }
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
  /// 如果在调用之前数据库不存在，则调用[onCreate]
  /// 创建数据库回调
  /// Called when database is created
  Future<void> _onCreate(Database db, int version) async {
    iPrint("SqliteService_onCreate version=$version");

    // 加密平台不复制明文模板，直接创建空加密数据库。
    // 需要从 example10.db 资源中读取基线 schema 并执行建表，
    // 然后执行 v10+ 的增量迁移脚本（ALTER TABLE 等）。
    // 非加密平台从 example10.db 模板复制（含初始 schema），此处无需额外操作。
    if (isEncryptionSupported) {
      // 1. 从 assets/example10.db 读取 schema
      final schemaSql = await rootBundle.loadString(
        'assets/migrations/baseline_schema.sql',
      );

      // 按分号分割并逐条执行（过滤空行和注释）
      final statements = schemaSql
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.startsWith('--'))
          .toList();

      for (final sql in statements) {
        // 跳过 SQLite 内部表的创建语句（sqlite_sequence 等）
        if (sql.toLowerCase().contains('sqlite_')) continue;
        try {
          await db.execute(sql);
        } catch (e) {
          // 忽略 "already exists" 错误
          final errorStr = e.toString().toLowerCase();
          if (!errorStr.contains('already exists')) {
            rethrow;
          }
        }
      }

      // 2. 设置基线版本号（example10.db 的 user_version = 16）
      await db.execute('PRAGMA user_version = 16');

      // 3. 执行 v16 → version 的增量迁移
      if (version > 16) {
        final result = await MigrationService.to.migrate(
          db: db,
          fromVersion: 16,
          toVersion: version,
          isUpgrade: true,
        );

        if (!result.success) {
          throw Exception('Migration failed: ${result.error}');
        }
      }

      iPrint("✅ Schema initialized: baseline(16) → v$version");
    }
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
            await Future<dynamic>.delayed(
              Duration(milliseconds: 100 * (attempt + 1)),
            );
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
            await Future<dynamic>.delayed(
              Duration(milliseconds: 100 * (attempt + 1)),
            );
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
            await Future<dynamic>.delayed(
              Duration(milliseconds: 100 * (attempt + 1)),
            );
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
    final result = await _scalarQuery<T>(sql, whereArgs);
    if (result == null) return null;

    // 类型转换（适配 SQLite 类型系统）
    try {
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
            await Future<dynamic>.delayed(
              Duration(milliseconds: 100 * (attempt + 1)),
            );
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
