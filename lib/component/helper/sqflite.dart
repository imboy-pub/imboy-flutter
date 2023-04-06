import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
/// Sqlite 只负责维护表结构
class Sqlite {
  static const _dbVersion = 1;

  Sqlite._privateConstructor();

  static final Sqlite instance = Sqlite._privateConstructor();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    String dbName = "${UserRepoLocal.to.currentUid}imboy.db";
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
    );
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    //注意： 创建多张表，需要执行多次 await db.execute 代码
    //      也就是一条SQL语句一个 db.execute

    // await db.execute("DROP TABLE IF EXISTS ${ContactRepo.tableName};");
    // await db.execute("DROP TABLE IF EXISTS ${ConversationRepo.tableName};");
    // await db.execute("DROP TABLE IF EXISTS ${MessageRepo.tableName};");
    // await db.execute("DROP TABLE IF EXISTS ${NewFriendRepo.tableName};");

    String contactSql = '''
      CREATE TABLE IF NOT EXISTS ${ContactRepo.tableName} (
        ${ContactRepo.uid} varchar(40) NOT NULL,
        ${ContactRepo.nickname} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.avatar} varchar(255) NOT NULL DEFAULT '',
        ${ContactRepo.gender} int(4) NOT NULL DEFAULT 0,
        ${ContactRepo.account} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.status} varchar(20) NOT NULL DEFAULT '',
        ${ContactRepo.remark} varchar(255) DEFAULT '',
        ${ContactRepo.region} varchar(80) DEFAULT '',
        ${ContactRepo.sign} varchar(255) NOT NULL DEFAULT '',
        ${ContactRepo.source} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.updateTime} int(16) NOT NULL DEFAULT 0,
        ${ContactRepo.isFriend} int(4) NOT NULL DEFAULT 0,
        ${ContactRepo.isFrom} int(4) NOT NULL DEFAULT 0,
        PRIMARY KEY("uid")
        );
      ''';
    debugPrint("> on _onCreate \n$contactSql\n");
    await db.execute(contactSql);

    String conversationSql = '''
      CREATE TABLE IF NOT EXISTS ${ConversationRepo.tableName} (
        `${ConversationRepo.id}` INTEGER,
        `${ConversationRepo.peerId}` varchar(40) NOT NULL,
        `${ConversationRepo.avatar}` varchar(255) NOT NULL DEFAULT '',
        `${ConversationRepo.title}` varchar(40) NOT NULL DEFAULT '',
        `${ConversationRepo.subtitle}` varchar(255) DEFAULT '',
        `${ConversationRepo.region}` varchar(255) DEFAULT '',
        `${ConversationRepo.sign}` varchar(255) DEFAULT '',
        `${ConversationRepo.unreadNum}` int NOT NULL DEFAULT 0,
        `${ConversationRepo.type}` varchar(40) NOT NULL,
        `${ConversationRepo.msgType}` varchar(40) NOT NULL,
        `${ConversationRepo.isShow}` int NOT NULL DEFAULT 0,
        `${ConversationRepo.lastTime}` int DEFAULT 0,
        `${ConversationRepo.lastMsgId}` varchar(40) NOT NULL,
        `${ConversationRepo.lastMsgStatus}` int DEFAULT 0,
        PRIMARY KEY(${ConversationRepo.id})
        );
      ''';
    debugPrint("> on _onCreate \n$conversationSql\n");
    await db.execute(conversationSql);

    String messageSql = '''
      CREATE TABLE IF NOT EXISTS ${MessageRepo.tableName} (
        auto_id INTEGER,
        ${MessageRepo.id} varchar(40) NOT NULL,
        ${MessageRepo.type} VARCHAR (20),
        ${MessageRepo.from} VARCHAR (80),
        ${MessageRepo.to} VARCHAR (80),
        ${MessageRepo.payload} TEXT,
        ${MessageRepo.createdAt} INTERGER,
        ${MessageRepo.serverTs} INTERGER,
        ${MessageRepo.conversationId} int DEFAULT 0,
        ${MessageRepo.status} INTERGER,
        PRIMARY KEY(auto_id)
        );
      ''';
    debugPrint("> on _onCreate messageSql \n$messageSql\n");
    await db.execute(messageSql);
    await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS uk_Msgid ON ${MessageRepo.tableName} (${MessageRepo.id});");

    String newFriendSql = '''
      CREATE TABLE IF NOT EXISTS ${NewFriendRepo.tableName} (
        auto_id INTEGER,
        ${NewFriendRepo.uid} varchar(40) NOT NULL,
        ${NewFriendRepo.from} varchar(40) NOT NULL,
        ${NewFriendRepo.to} varchar(40) NOT NULL,
        ${NewFriendRepo.nickname} varchar(40) NOT NULL DEFAULT '',
        ${NewFriendRepo.avatar} varchar(255) NOT NULL DEFAULT '',
        ${NewFriendRepo.msg} varchar(255) NOT NULL DEFAULT '',
        ${NewFriendRepo.status} varchar(20) NOT NULL DEFAULT '',
        ${NewFriendRepo.payload} text DEFAULT '',
        ${NewFriendRepo.updateTime} int(16) NOT NULL DEFAULT 0,
        ${NewFriendRepo.createTime} int(16) NOT NULL DEFAULT 0,
        PRIMARY KEY("auto_id"),
        CONSTRAINT uk_FromTo UNIQUE (
            ${NewFriendRepo.from},
            ${NewFriendRepo.to}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$newFriendSql\n");
    await db.execute(newFriendSql);
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    Database db = await instance.database;
    int lastInsertId = await db.insert(table, data);
    return lastInsertId;
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    Database db = await instance.database;
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
    Database db = await instance.database;
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
    Database db = await instance.database;
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
    Database db = await instance.database;
    int? res = Sqflite.firstIntValue(await db.rawQuery(
      sql,
      whereArgs,
    ));
    return res;
  }

  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    Database db = await instance.database;
    var res = await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    return res;
  }
}
