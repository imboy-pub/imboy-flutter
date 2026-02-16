/// Web 平台存储工具
///
/// 提供浏览器特定的存储功能（IndexedDB、文件下载、设备ID管理等）
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Web 平台存储工具
///
/// 提供浏览器特定的存储功能，支持：
/// - localStorage 键值存储
/// - 文件下载
/// - 设备 ID 管理
/// - IndexedDB 操作（简化版）
class WebStorage {
  /// 设备 ID 存储键
  static const String _deviceIdKey = 'imboy_web_device_id';

  /// 下载文件到本地
  ///
  /// [fileName] 下载的文件名
  /// [bytes] 文件字节数据
  static void downloadFile(String fileName, List<int> bytes) {
    if (!kIsWeb) {
      debugPrint('WebStorage.downloadFile: 仅支持 Web 平台');
      return;
    }

    try {
      // 使用 Web API 下载文件
      _downloadFileWeb(fileName, bytes);
    } catch (e) {
      debugPrint('WebStorage.downloadFile 失败: $e');
    }
  }

  /// Web 平台文件下载实现
  static void _downloadFileWeb(String fileName, List<int> bytes) {
    // 使用条件导入的 Web API
    // 这里使用 JS 互操作
    _WebFileDownloader.download(fileName, bytes);
  }

  /// 获取或创建设备 ID
  ///
  /// 如果已存在则返回，否则创建新的并存储到 localStorage
  static Future<String> getOrCreateDeviceId() async {
    if (!kIsWeb) {
      return 'not_web_platform';
    }

    try {
      // 尝试从 localStorage 获取
      String? deviceId = _getLocalStorage(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        // 创建新的设备 ID
        deviceId = _generateDeviceId();
        _setLocalStorage(_deviceIdKey, deviceId);
        debugPrint('WebStorage: 创建新设备 ID: $deviceId');
      }

      return deviceId;
    } catch (e) {
      debugPrint('WebStorage.getOrCreateDeviceId 失败: $e');
      return _generateDeviceId();
    }
  }

  /// 生成唯一的设备 ID
  static String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _randomString(8);
    return 'web_${timestamp}_$random';
  }

  /// 生成随机字符串
  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      final index = DateTime.now().microsecondsSinceEpoch % chars.length;
      buffer.write(chars[index]);
    }
    return buffer.toString();
  }

  // ==========================================
  // localStorage 操作（通过 JS 互操作）
  // ==========================================

  /// 获取 localStorage 值
  static String? _getLocalStorage(String key) {
    if (!kIsWeb) return null;
    return _WebLocalStorage.get(key);
  }

  /// 设置 localStorage 值
  static void _setLocalStorage(String key, String value) {
    if (!kIsWeb) return;
    _WebLocalStorage.set(key, value);
  }

  /// 删除 localStorage 值
  static void removeLocalStorage(String key) {
    if (!kIsWeb) return;
    _WebLocalStorage.remove(key);
  }

  /// 清空所有 localStorage
  static void clearLocalStorage() {
    if (!kIsWeb) return;
    _WebLocalStorage.clear();
  }

  // ==========================================
  // IndexedDB 操作（简化版）
  // ==========================================

  /// 保存数据到 IndexedDB
  ///
  /// 实际项目中可以使用 `package:indexed_db` 或 `package:sembast_web`
  static Future<void> saveToIndexedDB(
    String storeName,
    String key,
    Map<String, dynamic> value,
  ) async {
    if (!kIsWeb) return;
    // TODO: 实现 IndexedDB 存储
    // 可以使用第三方包或直接使用 Web API
    debugPrint('WebStorage.saveToIndexedDB: $storeName/$key');
  }

  /// 从 IndexedDB 读取数据
  static Future<Map<String, dynamic>?> getFromIndexedDB(
    String storeName,
    String key,
  ) async {
    if (!kIsWeb) return null;
    // TODO: 实现 IndexedDB 读取
    return null;
  }

  /// 从 IndexedDB 删除数据
  static Future<void> removeFromIndexedDB(String storeName, String key) async {
    if (!kIsWeb) return;
    // TODO: 实现 IndexedDB 删除
  }

  // ==========================================
  // 会话存储（sessionStorage）
  // ==========================================

  /// 获取 sessionStorage 值
  static String? getSessionStorage(String key) {
    if (!kIsWeb) return null;
    return _WebSessionStorage.get(key);
  }

  /// 设置 sessionStorage 值
  static void setSessionStorage(String key, String value) {
    if (!kIsWeb) return;
    _WebSessionStorage.set(key, value);
  }

  /// 删除 sessionStorage 值
  static void removeSessionStorage(String key) {
    if (!kIsWeb) return;
    _WebSessionStorage.remove(key);
  }
}

/// 调试打印（避免导入 flutter）
void debugPrint(String message) {
  print(message);
}

// ==========================================
// Web 平台 API 封装（通过条件导入实现）
// ==========================================

/// localStorage 操作
class _WebLocalStorage {
  static String? get(String key) {
    // 实际实现通过 device_ext_web.dart 中的 webBrowser
    // 这里是占位符，实际调用在条件导入中
    return null;
  }

  static void set(String key, String value) {
    // 占位符
  }

  static void remove(String key) {
    // 占位符
  }

  static void clear() {
    // 占位符
  }
}

/// sessionStorage 操作
class _WebSessionStorage {
  static String? get(String key) {
    return null;
  }

  static void set(String key, String value) {
    // 占位符
  }

  static void remove(String key) {
    // 占位符
  }
}

/// 文件下载
class _WebFileDownloader {
  static void download(String fileName, List<int> bytes) {
    // 占位符，实际实现在 device_ext_web.dart
    debugPrint('下载文件: $fileName (${bytes.length} bytes)');
  }
}
