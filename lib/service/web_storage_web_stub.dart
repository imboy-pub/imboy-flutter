/// Web 平台存储工具 - IndexedDB 存根实现
///
/// 非 Web 平台使用，提供空实现
library;

/// 初始化数据库（存根）
Future<dynamic> initDb(String name, int version) async {
  return null;
}

/// 保存数据（存根）
Future<void> put(
  dynamic db,
  String storeName,
  String key,
  String value,
) async {}

/// 获取数据（存根）
Future<String?> get(dynamic db, String storeName, String key) async {
  return null;
}

/// 删除数据（存根）
Future<void> delete(dynamic db, String storeName, String key) async {}
