/// SQLite 数据库工厂初始化 - Web 平台实现
///
/// 仅在 Web 平台编译和使用
/// Web 平台不支持 SQLCipher 加密
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common/sqflite.dart';

import 'browser_sqlite_storage_bridge_web.dart';

/// 初始化 SQLite 数据库工厂
/// Web 平台使用 sqflite_common_ffi_web
/// 唯一桥在首次数据库操作前取得整个物理 namespace 的写租约
void initSqfliteFactory() {
  if (!kIsWeb) {
    throw UnsupportedError('initSqfliteFactory_web 只能在 Web 平台使用');
  }
  databaseFactory = browserSqliteStorageBridge.factory;
}

/// Web 平台不支持数据库加密
bool get isEncryptionSupported => false;

/// Web 平台打开数据库（忽略 password 参数）
///
/// Web 平台不支持 SQLCipher，password 参数被忽略。
Future<Database> openEncryptedDatabase(
  String path, {
  String? password,
  int? version,
  OnDatabaseConfigureFn? onConfigure,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
  OnDatabaseVersionChangeFn? onDowngrade,
  OnDatabaseOpenFn? onOpen,
  bool readOnly = false,
}) async {
  // Web 平台忽略 password，使用明文数据库
  return await openDatabase(
    path,
    version: version,
    onConfigure: onConfigure,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
    onDowngrade: onDowngrade,
    onOpen: onOpen,
    readOnly: readOnly,
  );
}
