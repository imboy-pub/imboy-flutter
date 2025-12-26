import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/sqlite_ddl.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
/// SQLite 本地数据库服务
/// SQLite local database service
///
/// 仅负责表结构和数据的读写，数据初始化等逻辑由其他模块负责。
class SqliteService {
  static const _dbVersion = 9;

  // 单例构造
  SqliteService._privateConstructor();

  static final SqliteService to = SqliteService._privateConstructor();

  static Database? _db;

  // 全局数据库锁，确保所有写操作串行执行
  final Lock _dbLock = Lock();

  // 初始化锁，确保数据库只被初始化一次
  final Lock _initLock = Lock();

  /// 获取数据库连接实例
  /// Get the database connection instance
  Future<Database?> get db async {

    if (_db != null) return _db;
    // https://developer.android.com/reference/android/database/sqlite/package-summary
    /*
    // 查询 SQLite 版本
    final versionResult =
        await _db?.database.rawQuery('select sqlite_version();');
    if (versionResult!.isNotEmpty) {
      iPrint('SQLite version: $versionResult');
      // ios [  +55 ms] flutter: iPrint SQLite version: [{sqlite_version(): 3.46.1}]
      // andriod [ +225 ms] I/flutter (19060): iPrint SQLite version: [{sqlite_version(): 3.46.0}]
    }
    */
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
    return join(await getDatabasesPath(), name);
  }

  /// 初始化数据库
  /// Initialize the database
  Future<Database?> _initDatabase() async {
    if (UserRepoLocal.to.currentUid.isEmpty) {
      return null;
    }

    String path = await dbPath();
    bool exists = await databaseExists(path);

    if (!exists) {
      iPrint("Creating new database");

      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      ByteData data = await rootBundle.load(url.join("assets", "example.db"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
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
    );
  }

  /// 打开数据库时的配置回调
  /// Configure callback when database is opened
  FutureOr<void> _onConfigure(Database db) async {
    debugPrint("SqliteService_onConfigure ${db.toString()}");
    // 外键、加密设置等可放在此处

    // https://github.com/davidmartos96/sqflite_sqlcipher/blob/master/sqflite/README.md
    // https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/encryption_support.md
    // This is the part where we pass the "password"
    // await db.rawQuery("PRAGMA KEY='$SOLIDIFIED_KEY}'");
    //注意： 创建多张表，需要执行多次 await db.execute 代码
    //      也就是一条SQL语句一个 db.execute

    ///  请记住，回调onCreate onUpgrade onDowngrade已经内部包装在事务中，
    ///  因此无需将语句包装在这些回调内的事务中。
  }

  ///
  /// 因为是 Copy from asset，所以该方法一定不会执行
  /// 如果在调用之前数据库不存在，则调用[onCreate]
  /// 创建数据库回调
  /// Called when database is created
  Future<void> _onCreate(Database db, int version) async {
    iPrint("SqliteService_onCreate");
  }

  /// 数据库升级回调
  /// Called when upgrading database version
  Future<void> _onUpgrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onUpgrade oldVsn: $oldVsn, newVsn: $newVsn");
    await SqliteDdl.onUpgrade(db, oldVsn, newVsn);
  }

  /// 数据库降级回调
  /// Called when downgrading database version
  Future<void> _onDowngrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onDowngrade oldVsn: $oldVsn, newVsn: $newVsn");
    await SqliteDdl.onDowngrade(db, oldVsn, newVsn);
  }

  /// 插入数据（带重试机制）
  /// Insert data (with retry logic)
  Future<int> insert(String table, Map<String, dynamic> data, {int retries = 3}) async {
    return await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          debugPrint('Insert error: $e');
          rethrow;
        }
      }
      return 0;
    });
  }

  /// 更新数据（带重试机制）
  /// Update data (with retry logic)
  Future<int> update(
      String table,
      Map<String, Object?> values, {
        String? where,
        List<Object?>? whereArgs,
        ConflictAlgorithm? conflictAlgorithm,
        int retries = 3,
      }) async {
    return await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db.update(
            table,
            values,
            where: where,
            whereArgs: whereArgs,
            conflictAlgorithm: conflictAlgorithm,
          );
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          debugPrint('Update error: $e');
          rethrow;
        }
      }
      return 0;
    });
  }

  /// 执行原始查询
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await this.db;
    if (db == null) return [];
    return await db.rawQuery(sql, arguments);
  }

  /// 执行原始 SQL 更新语句（带重试机制）
  /// Execute raw update SQL (with retry logic)
  Future<int> execute(String sql, [List<Object?>? arguments, int retries = 3]) async {
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
          debugPrint('Execute error: $e');
          rethrow;
        }
      }
      return 0;
    });
  }

  /// 执行查询操作
  /// Perform a query
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
      }) async {
    final db = await this.db;
    if (db == null) return [];
    return await db.query(
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
    );
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
  Future<int?> count(String table, {String? where, List<Object?>? whereArgs}) async {
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
      debugPrint('pluck<$T> 类型转换失败: $result');
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
    return await _dbLock.synchronized(() async {
      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final db = await this.db;
          if (db == null) return 0;
          return await db.delete(
            table,
            where: where,
            whereArgs: whereArgs,
          );
        } catch (e) {
          if (_isDatabaseLockedError(e) && attempt < retries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            continue;
          }
          debugPrint('Delete error: $e');
          rethrow;
        }
      }
      return 0;
    });
  }

  /// 使用事务进行批处理操作（带全局锁）
  /// Execute batch operations within a transaction (with global lock)
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    return await _dbLock.synchronized(() async {
      final db = await this.db;
      if (db == null) throw Exception('Database is null');
      return await db.transaction(action);
    });
  }

  /// 批量插入（带全局锁）
  /// Insert multiple records in batch (with global lock)
  Future<void> batchInsert(String table, List<Map<String, dynamic>> dataList) async {
    await _dbLock.synchronized(() async {
      final db = await this.db;
      if (db == null) return;
      final batch = db.batch();
      for (var data in dataList) {
        batch.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// 判断数据库被锁定错误
  /// Check if error is 'database is locked'
  bool _isDatabaseLockedError(dynamic e) {
    return e.toString().contains('database is locked');
  }
}