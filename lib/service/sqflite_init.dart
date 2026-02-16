/// SQLite 数据库工厂初始化 - 条件导入
///
/// 根据平台自动选择正确的实现：
/// - Web 平台：使用 sqflite_init_web.dart（sqflite_common_ffi_web）
/// - 非 Web 平台：使用 sqflite_init_stub.dart
library;

// 条件导入：Web 平台使用 FFI Web 实现，其他平台使用存根
export 'sqflite_init_stub.dart' if (dart.library.js) 'sqflite_init_web.dart';
