import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/sqlite_ddl.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
/// Sqlite 只负责维护表结构
class SqliteService {
  static const _dbVersion = 9;

  SqliteService._privateConstructor();

  static final SqliteService to = SqliteService._privateConstructor();

  static Database? _db;

  Future<Database?> get db async {
    _db ??= await _initDatabase();

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
    return _db;
  }

  Future<void> close() async {
    if (_db != null) {
      _db = null;
    }
  }

  Future<String> dbPath() async {
    String name = "${currentEnv}_${UserRepoLocal.to.currentUid}.db";
    return join(await getDatabasesPath(), name);
  }

  Future<Database?> _initDatabase() async {
    // Init ffi loader if needed.
    sqfliteFfiInit();
    // Use the database
    // db.dispose();
    debugPrint(
        " UserRepoLocal.to.currentUid isEmpty ${UserRepoLocal.to.currentUid.isEmpty};");
    if (UserRepoLocal.to.currentUid.isEmpty) {
      // Get.offAll(() => PassportPage());
      return null;
    }
    String path = await dbPath();

    // Check if the database exists
    var exists = await databaseExists(path);
    if (!exists) {
      // Should happen only the first time you launch your application
      iPrint("Creating new copy from asset");
      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load(url.join("assets", "example.db"));
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      iPrint("Opening existing database");
    }

    // debugPrint("> on open db path {$path}");
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
        readOnly: false,
        singleInstance: true,
      ), // 重新打开相同的文件是安全的，它会给你相同的数据库。
    );
  }

  /// 打开数据库时调用的第一个回调函数。
  /// 它允许您执行数据库初始化，例如启用外键或预写日志
  Future<FutureOr<void>> _onConfigure(Database db) async {
    debugPrint("SqliteService_onConfigure ${db.toString()}");
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
  Future _onCreate(Database db, int version) async {
    iPrint("SqliteService_onCreate");
  }

  /// 数据库已经存在，且[version]高于上一个数据库
  ///数据库版本
  Future _onUpgrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onUpgrade oldVsn: $oldVsn, newVsn: $newVsn");
    await SqliteDdl.onUpgrade(db, oldVsn, newVsn);
  }

  Future _onDowngrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onDowngrade oldVsn: $oldVsn, newVsn: $newVsn");
    await SqliteDdl.onDowngrade(db, oldVsn, newVsn);
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    Database? db = await to.db;
    if (db == null) {
      return 0;
    }
    int lastInsertId = await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return lastInsertId;
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    Database? db = await to.db;
    if (db == null) {
      return 0;
    }
    var res = await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    return res;
  }

  /// See [Database.rawUpdate]
  Future<int> execute(String sql, [List<Object?>? arguments]) async {
    Database? db = await to.db;
    if (db == null) {
      return 0;
    }
    var res = await db.rawUpdate(
      sql,
      arguments,
    );
    return res;
  }

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
    Database? db = await to.db;
    if (db == null) {
      return [];
    }
    var res = await db.query(
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
    return res;
  }

  Future<int?> count(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    String sql = "SELECT COUNT(*) FROM $table";
    if (strNoEmpty(where)) {
      sql += " WHERE $where";
    }
    // debugPrint('sqlite count $sql');
    Database? db = await to.db;
    if (db == null) {
      return null;
    }
    int? res = Sqflite.firstIntValue(await db.rawQuery(
      sql,
      whereArgs,
    ));
    return res;
  }

  Future<int?> pluck(
    String column,
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    String sql = "SELECT $column FROM $table";
    if (strNoEmpty(where)) {
      sql += " WHERE $where";
    }
    Database? db = await to.db;
    if (db == null) {
      return null;
    }
    int? res = Sqflite.firstIntValue(await db.rawQuery(
      sql,
      whereArgs,
    ));
    return res;
  }

  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    Database? db = await to.db;
    if (db == null) {
      return 0;
    }
    var res = await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    return res;
  }
}
