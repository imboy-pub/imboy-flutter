import 'package:flutter/cupertino.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/**
 * 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
 *
 * Sqlite 只负责维护表结构
 *
 */
class Sqlite {
  static final _dbName = "imboy.db";
  static final _dbVersion = 1;

  Sqlite._privateConstructor();

  static final Sqlite instance = Sqlite._privateConstructor();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    debugPrint(">>>>>>>>>>>>>>>>>>> on open db path {$path}");
    // Delete the database
    // await deleteDatabase(path);

    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    //注意： 创建多张表，需要执行多次 await db.execute 代码
    //      也就是一条SQL语句一个 db.execute

    // await db.execute("DROP TABLE IF EXISTS ${ContactRepo.tablename};");
    // await db.execute("DROP TABLE IF EXISTS ${MessageRepo.tablename};");
    // await db.execute("DROP TABLE IF EXISTS ${PersonRepo.tablename};");

    String contatsSql = '''
      CREATE TABLE IF NOT EXISTS ${ContactRepo.tablename} (
        ${ContactRepo.cuid} varchar(40) NOT NULL,
        ${ContactRepo.uid} varchar(40) NOT NULL,
        ${ContactRepo.nickname} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.avatar} varchar(255) NOT NULL DEFAULT '',
        ${ContactRepo.account} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.status} varchar(20) NOT NULL DEFAULT '',
        ${ContactRepo.remark} varchar(255) DEFAULT '',
        ${ContactRepo.area} varchar(80) DEFAULT '',
        ${ContactRepo.sign} varchar(255) NOT NULL DEFAULT '',
        ${ContactRepo.updateTime} int(16) NOT NULL DEFAULT 0,
        PRIMARY KEY("cuid","uid")
        );
      ''';
    debugPrint(">>>>>>>>>>>>>>>>>>> on _onCreate \n${contatsSql}\n");
    await db.execute(contatsSql);

    String conversationSql = '''
      CREATE TABLE IF NOT EXISTS ${ConversationRepo.tablename} (
        `${ConversationRepo.id}` INTERGER AUTO_INCREMENT,
        `${ConversationRepo.cuid}` varchar(40) NOT NULL,
        `${ConversationRepo.typeId}` varchar(40) NOT NULL,
        `${ConversationRepo.avatar}` varchar(255) NOT NULL DEFAULT '',
        `${ConversationRepo.title}` varchar(40) NOT NULL DEFAULT '',
        `${ConversationRepo.subtitle}` varchar(255) DEFAULT '',
        `${ConversationRepo.unreadNum}` int DEFAULT 0,
        `${ConversationRepo.type}` varchar(40) NOT NULL,
        `${ConversationRepo.msgtype}` varchar(40) NOT NULL,
        `${ConversationRepo.isShow}` bool NOT NULL,
        `${ConversationRepo.lasttime}` int DEFAULT 0,
        `${ConversationRepo.lastMsgStatus}` int DEFAULT 0,
        PRIMARY KEY(${ConversationRepo.id})
        );
      ''';
    debugPrint(">>>>>>>>>>>>>>>>>>> on _onCreate \n${conversationSql}\n");
    await db.execute(conversationSql);

    String messageSql = '''
      CREATE TABLE IF NOT EXISTS ${MessageRepo.tablename} (
        ${MessageRepo.id} varchar(40) NOT NULL,
        ${MessageRepo.type} VARCHAR (20),
        ${MessageRepo.from} VARCHAR (80),
        ${MessageRepo.to} VARCHAR (80),
        ${MessageRepo.payload} TEXT,
        ${MessageRepo.createdAt} INTERGER,
        ${MessageRepo.serverTs} INTERGER,
        ${MessageRepo.conversationId} int DEFAULT 0,
        ${MessageRepo.status} INTERGER,
        PRIMARY KEY(${MessageRepo.id})
        );
      ''';
    debugPrint(">>>>>>>>>>>>>>>>>>> on _onCreate messageSql \n${messageSql}\n");
    await db.execute(messageSql);
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

  Future<List<Map<String, dynamic>>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
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
    String sql = "SELECT COUNT(*) FROM " + table;
    if (strNoEmpty(where)) {
      sql += " WHERE " + where!;
    }
    Database db = await instance.database;
    int? res = await Sqflite.firstIntValue(await db.rawQuery(
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
    String sql = "SELECT " + column + " FROM " + table;
    if (strNoEmpty(where)) {
      sql += " WHERE " + where!;
    }
    Database db = await instance.database;
    int? res = await Sqflite.firstIntValue(await db.rawQuery(
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
