import 'dart:convert' as json;

import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储服务 - 基于 SharedPreferences
/// Local storage service based on SharedPreferences
///
/// 职责：
/// - 提供键值对存储功能（字符串、布尔值、整数、列表、Map等）
/// - 支持数据持久化
/// - 提供类型安全的读写方法
///
/// 使用方式：
/// ```dart
/// // 初始化（在应用启动时调用）
/// await StorageService.init();
///
/// // 存储数据
/// await StorageService.to.setString('key', 'value');
/// await StorageService.to.setBool('is_logged_in', true);
///
/// // 读取数据
/// String value = StorageService.to.getString('key');
/// bool isLoggedIn = StorageService.to.getBool('is_logged_in');
/// ```
///
/// 迁移说明：
/// - 已从 GetxService 迁移为标准 Dart 单例模式
/// - 移除了 GetX 依赖
class StorageService {
  // 单例实例
  static StorageService? _instance;

  // SharedPreferences 实例
  static SharedPreferences? _prefs;

  /// 获取单例实例
  /// Get singleton instance
  static StorageService get to {
    _instance ??= StorageService._internal();
    return _instance!;
  }

  /// 私有构造函数
  /// Private constructor
  StorageService._internal();

  /// 初始化存储服务
  /// Initialize storage service
  ///
  /// 必须在应用启动时调用，通常在 AppInitializer.initialize() 中
  /// Must be called during app startup, typically in AppInitializer.initialize()
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 存储字符串
  /// Store string value
  Future<bool> setString(String key, String value) async {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return await _prefs!.setString(key, value);
  }

  /// 存储 Map 对象（自动序列化为 JSON）
  /// Store Map object (automatically serialized to JSON)
  static Future<bool> setMap(String key, Map<String, dynamic> value) async {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return await _prefs!.setString(key, json.jsonEncode(value));
  }

  /// 获取 Map 对象（自动从 JSON 反序列化）
  /// Get Map object (automatically deserialized from JSON)
  static Map<String, dynamic> getMap(String key) {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    String? val = _prefs!.getString(key);
    if (val == '' || val == null) {
      return {};
    }
    try {
      return json.jsonDecode(val) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// 存储布尔值
  /// Store boolean value
  Future<bool> setBool(String key, bool value) async {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return await _prefs!.setBool(key, value);
  }

  /// 存储字符串列表
  /// Store string list
  Future<bool> setList(String key, List<String> value) async {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return await _prefs!.setStringList(key, value);
  }

  /// 获取字符串值
  /// Get string value
  String getString(String key) {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!.getString(key) ?? '';
  }

  /// 获取布尔值（可空）
  /// Get boolean value (nullable)
  bool? getBool(String key) {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!.getBool(key);
  }

  /// 获取字符串列表
  /// Get string list
  List<String> getList(String key) {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!.getStringList(key) ?? [];
  }

  /// 获取字符串列表（可空）
  /// Get string list (nullable)
  List<String>? getStringList(String key) {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!.getStringList(key);
  }

  /// 删除指定键的值
  /// Remove value for given key
  Future<bool> remove(String key) async {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return await _prefs!.remove(key);
  }

  /// 清空所有存储
  /// Clear all stored data
  Future<bool> clear() async {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return await _prefs!.clear();
  }

  /// 检查是否包含某个键
  /// Check if key exists
  bool containsKey(String key) {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!.containsKey(key);
  }

  /// 获取所有键
  /// Get all keys
  Set<String> getKeys() {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!.getKeys();
  }
}
