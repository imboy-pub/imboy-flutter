import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/sqlite_ddl.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
/// Sqlite 只负责维护表结构
class SqliteService {
  static const _dbVersion = 2;

  SqliteService._privateConstructor();

  static final SqliteService to = SqliteService._privateConstructor();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }
    String dbName = "imboy_${UserRepoLocal.to.currentUid}.db";
    debugPrint("> on Sqlite.database $dbName");
    _db = await initDatabase(dbName);
    return _db!;
  }

  Future<void> close() async {
    if (_db != null) {
      _db = null;
    }
  }

  Future<Database> initDatabase(String dbName) async {
    String path = join(await getDatabasesPath(), dbName);
    debugPrint("> on open db path {$path}");
    // // 当[readOnly](默认为false)为true时，其他参数均为忽略，数据库按原样打开
    // bool isexits = await databaseExists(path);
    // debugPrint("> on open db readOnly: ${isexits}, path {$path}");
    // Delete the database
    // await deleteDatabase(path);
    // if
    return await openDatabase(
      path,
      version: _dbVersion,
      readOnly: false,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  Future _onUpgrade(Database db, int oldVsn, int newVsn) async {
    debugPrint("SqliteService_onUpgrade oldVsn: $oldVsn, newVsn: $newVsn");
    if (oldVsn == 1 && newVsn == 2) {
      await SqliteDdl.userCollect(db);
    } else if (newVsn == 3) {}
  }

  Future _onDowngrade(Database db, int oldVsn, int newVsn) async {
    debugPrint("SqliteService_onDowngrade oldVsn: $oldVsn, newVsn: $newVsn");
    // from 2 to 1
    // [  +22 ms] flutter: SqliteService_onDowngrade oldVsn: 2, newVsn: 1
    if (oldVsn == 2 && newVsn == 1) {
      await db.execute("DROP TABLE IF EXISTS ${UserCollectRepo.tableName};");
    } else if (oldVsn == 2) {}
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    debugPrint("SqliteService_onDowngrade version: $version");
    //注意： 创建多张表，需要执行多次 await db.execute 代码
    //      也就是一条SQL语句一个 db.execute

    // await db.execute("DROP TABLE IF EXISTS ${ContactRepo.tableName};");
    // await db.execute("DROP TABLE IF EXISTS ${ConversationRepo.tableName};");
    // await db.execute("DROP TABLE IF EXISTS ${MessageRepo.tableName};");
    // await db.execute("DROP TABLE IF EXISTS ${NewFriendRepo.tableName};");
    // TODO leeyi 2023-04-19
    // https://www.wangfenjin.com/posts/simple-tokenizer/
    // await db.execute('''
    //       CREATE VIRTUAL TABLE t1 USING fts5(x, tokenize = "simple");
    //     ''');
    await SqliteDdl.contact(db);
    await SqliteDdl.conversation(db);
    await SqliteDdl.message(db);
    await SqliteDdl.newFriend(db);
    await SqliteDdl.userDenylist(db);
    await SqliteDdl.userDevice(db);
    await SqliteDdl.userCollect(db);
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    Database db = await to.db;
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
    Database db = await to.db;
    var res = await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
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
    Database db = await to.db;
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
    Database db = await to.db;
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
    Database db = await to.db;
    int? res = Sqflite.firstIntValue(await db.rawQuery(
      sql,
      whereArgs,
    ));
    return res;
  }

  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    Database db = await to.db;
    var res = await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    return res;
  }
}
