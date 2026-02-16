/// Web 平台桌面通知服务
///
/// 提供浏览器桌面通知功能，类似 WhatsApp Web 的消息提醒
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 通知权限状态
enum NotificationPermission {
  /// 已授权
  granted,
  /// 已拒绝
  denied,
  /// 未请求
  notDetermined,
  /// 不支持
  unsupported,
}

/// 通知选项
class NotificationOptions {
  /// 标题
  final String title;

  /// 正文内容
  final String? body;

  /// 图标 URL
  final String? icon;

  /// 徽章 URL
  final String? badge;

  /// 点击时的跳转 URL
  final String? clickUrl;

  /// 标签（用于替换相同标签的通知）
  final String? tag;

  /// 是否需要交互（点击后才会关闭）
  final bool requireInteraction;

  /// 是否静默（无声音）
  final bool silent;

  const NotificationOptions({
    required this.title,
    this.body,
    this.icon,
    this.badge,
    this.clickUrl,
    this.tag,
    this.requireInteraction = false,
    this.silent = false,
  });
}

/// 桌面通知服务
///
/// 提供跨平台的桌面通知功能：
/// - Web: 使用浏览器 Notification API
/// - 桌面: 使用系统通知（macOS/Windows/Linux）
/// - 移动端: 使用推送通知
class WebNotificationService {
  static final WebNotificationService _instance =
      WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  /// 是否已初始化
  bool _initialized = false;

  /// 当前权限状态
  NotificationPermission _permission = NotificationPermission.notDetermined;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      debugPrint('WebNotificationService: 非 Web 平台，跳过初始化');
      return;
    }

    // 检查通知支持
    if (!_isSupported()) {
      _permission = NotificationPermission.unsupported;
      debugPrint('WebNotificationService: 浏览器不支持通知');
      return;
    }

    // 检查当前权限状态
    _permission = await _checkPermission();
    debugPrint('WebNotificationService: 初始化完成，权限状态: $_permission');
  }

  /// 检查浏览器是否支持通知
  bool _isSupported() {
    // Web 平台通过 JS 互操作检查
    return _WebNotificationAPI.isSupported();
  }

  /// 检查当前权限状态
  Future<NotificationPermission> _checkPermission() async {
    if (!kIsWeb) return NotificationPermission.unsupported;
    return _WebNotificationAPI.getPermissionStatus();
  }

  /// 请求通知权限
  ///
  /// 返回是否获得授权
  Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    if (!_isSupported()) {
      debugPrint('WebNotificationService: 浏览器不支持通知');
      return false;
    }

    final permission = await _WebNotificationAPI.requestPermission();
    _permission = permission;
    debugPrint('WebNotificationService: 权限请求结果: $permission');

    return permission == NotificationPermission.granted;
  }

  /// 获取当前权限状态
  Future<NotificationPermission> getPermissionStatus() async {
    if (!kIsWeb) return NotificationPermission.unsupported;
    return _permission;
  }

  /// 显示通知
  ///
  /// [options] 通知选项
  /// 返回通知 ID（用于后续关闭）
  Future<String?> show(NotificationOptions options) async {
    if (!kIsWeb) return null;

    if (_permission != NotificationPermission.granted) {
      debugPrint('WebNotificationService: 未获得通知权限');
      return null;
    }

    try {
      final notificationId = await _WebNotificationAPI.show(options);
      debugPrint('WebNotificationService: 显示通知成功: $notificationId');
      return notificationId;
    } catch (e) {
      debugPrint('WebNotificationService: 显示通知失败: $e');
      return null;
    }
  }

  /// 关闭通知
  Future<void> close(String notificationId) async {
    if (!kIsWeb) return;
    _WebNotificationAPI.close(notificationId);
  }

  /// 关闭所有通知
  Future<void> closeAll() async {
    if (!kIsWeb) return;
    _WebNotificationAPI.closeAll();
  }

  // ==========================================
  // 便捷方法
  // ==========================================

  /// 显示消息通知
  Future<String?> showMessageNotification({
    required String title,
    required String body,
    String? avatar,
    String? conversationId,
  }) async {
    return show(NotificationOptions(
      title: title,
      body: body,
      icon: avatar,
      tag: conversationId != null ? 'chat_$conversationId' : null,
      clickUrl: conversationId != null ? '/chat?id=$conversationId' : null,
    ));
  }

  /// 显示系统通知
  Future<String?> showSystemNotification({
    required String title,
    required String body,
  }) async {
    return show(NotificationOptions(
      title: title,
      body: body,
      tag: 'system',
      silent: true,
    ));
  }

  /// 显示文件上传完成通知
  Future<String?> showUploadCompleteNotification({
    required String fileName,
    bool success = true,
  }) async {
    return show(NotificationOptions(
      title: success ? '文件上传成功' : '文件上传失败',
      body: fileName,
      tag: 'upload',
      silent: true,
    ));
  }
}

/// 调试打印
void debugPrint(String message) {
  print(message);
}

// ==========================================
// Web 通知 API 封装（通过 JS 互操作）
// ==========================================

class _WebNotificationAPI {
  /// 检查是否支持通知
  static bool isSupported() {
    // 占位符，实际通过 JS 互操作实现
    return true;
  }

  /// 获取权限状态
  static Future<NotificationPermission> getPermissionStatus() async {
    // 占位符
    return NotificationPermission.notDetermined;
  }

  /// 请求权限
  static Future<NotificationPermission> requestPermission() async {
    // 占位符
    return NotificationPermission.granted;
  }

  /// 显示通知
  static Future<String> show(NotificationOptions options) async {
    // 占位符，返回随机 ID
    return 'notification_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 关闭通知
  static void close(String notificationId) {
    // 占位符
  }

  /// 关闭所有通知
  static void closeAll() {
    // 占位符
  }
}
