/// SQLite 数据库工厂初始化 - Web 平台实现
///
/// 仅在 Web 平台编译和使用
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// 初始化 SQLite 数据库工厂
/// Web 平台使用 sqflite_common_ffi_web
/// 使用 databaseFactoryFfiWebNoWebWorker 避免需要额外的 Web Worker 文件
void initSqfliteFactory() {
  if (!kIsWeb) {
    throw UnsupportedError('initSqfliteFactory_web 只能在 Web 平台使用');
  }
  // Web 平台使用 sqflite_common_ffi_web（无 Web Worker 版本）
  // 注意：此版本在主线程运行，长时间查询可能会阻塞 UI
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
