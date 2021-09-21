import 'package:flutter/cupertino.dart';
import 'package:imboy/store/repository/message_repo.dart';
import 'package:imboy/store/repository/person_repo.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/**
 * 参考 https://www.javacodegeeks.com/2020/06/using-sqlite-in-flutter-tutorial.html
 *
 * DatabaseHelper 只负责维护表结构
 *
 */
class DatabaseHelper {
  static final _databaseName = "imboy.db";
  static final _databaseVersion = 1;

  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    debugPrint(">>>>>>>>>>>>>>>>>>> on open db path {path}");
    // Delete the database
    await deleteDatabase(path);

    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    //注意： 创建多张表，需要执行多次 await db.execute 代码
    //      也就是一条SQL语句一个 db.execute

    await db.execute("DROP TABLE IF EXISTS ${MessageRepo.tablename}");
    await db.execute("DROP TABLE IF EXISTS ${PersonRepo.tablename}");

    String persionSql = '''
      CREATE TABLE IF NOT EXISTS ${PersonRepo.tablename} (
        ${PersonRepo.uid} VARCHAR (80) PRIMARY KEY,
        ${PersonRepo.account} VARCHAR (160) UNIQUE,
        ${PersonRepo.nickname} VARCHAR (160),
        ${PersonRepo.avatar} VARCHAR (400),
        ${PersonRepo.birthday} VARCHAR (80),
        ${PersonRepo.role} VARCHAR (20),
        ${PersonRepo.gender} VARCHAR (20),
        ${PersonRepo.levelId} INTERGER,
        ${PersonRepo.language} VARCHAR (20),
        ${PersonRepo.sign} VARCHAR (160),
        ${PersonRepo.allowType} VARCHAR (20),
        ${PersonRepo.location} VARCHAR (80)
        );
      ''';
    debugPrint(">>>>>>>>>>>>>>>>>>> on _onCreate \n{persionSql}\n");
    await db.execute(persionSql);

    String messageSql = '''
      CREATE TABLE IF NOT EXISTS ${MessageRepo.tablename} (
        ${MessageRepo.id} INTERGER AUTO_INCREMENT PRIMARY KEY,
        ${MessageRepo.type} VARCHAR (20),
        ${MessageRepo.from} VARCHAR (80),
        ${MessageRepo.to} VARCHAR (80),
        ${MessageRepo.payload} TEXT,
        ${MessageRepo.serverTs} INTERGER
        );
      ''';
    debugPrint(">>>>>>>>>>>>>>>>>>> on _onCreate \n{messageSql}\n");
    await db.execute(messageSql);
  }
}
