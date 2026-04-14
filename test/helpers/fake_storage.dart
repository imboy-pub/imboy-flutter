// 测试辅助：内存键值对存储桩
// Test helper: in-memory key-value store stub
//
// 用于单元测试中替换 StorageService 的 duck-typed fake。
// StorageService.getString 和 setString 通过动态分派调用，
// 此 fake 提供相同签名实现，不依赖 SharedPreferences。
//
// Used in unit tests as a duck-typed fake for StorageService.
// Matches the method signatures called by AppUpgradeDismissState
// and AppVersionTracker without requiring SharedPreferences.
library;

class FakeStorage {
  final Map<String, String> _data = {};

  /// 返回存储值；未命中时返回空字符串（与 StorageService.getString 行为一致）。
  /// Returns stored value; empty string when key absent (matches StorageService).
  String getString(String key) => _data[key] ?? '';

  /// 写入字符串值。
  void setString(String key, String value) => _data[key] = value;

  /// 删除指定键。
  void remove(String key) => _data.remove(key);

  /// 清空所有数据（用于 setUp / tearDown）。
  void clear() => _data.clear();
}
