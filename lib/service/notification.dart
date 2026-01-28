import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知服务
///
/// 负责本地通知的显示和管理
/// 使用 flutter_local_notifications 插件实现
///
/// 迁移说明（2026-01-16）:
/// - 从 GetX 迁移到 Riverpod
/// - 移除单例模式，使用 Provider 管理
/// - 所有功能保持不变
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初始化通知服务
  ///
  /// 必须在使用前调用此方法
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/logo');

    // iOS 初始化设置（目前注释掉，如需要可启用）
    // final iosSettings = DarwinInitializationSettings(
    //   requestAlertPermission: true,
    //   requestBadgePermission: true,
    //   requestSoundPermission: true,
    // );

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      // iOS: iosSettings,
    );

    // 初始化插件
    await _plugin.initialize(
      settings: initializationSettings,
      // onDidReceiveNotificationResponse: (NotificationResponse response) {
      //   // 处理通知点击事件
      //   _handleNotificationResponse(response);
      // },
    );

    _isInitialized = true;
  }

  /// 显示通知
  ///
  /// [title] 通知标题
  /// [body] 通知内容
  /// [id] 通知ID，默认使用时间戳生成唯一ID
  /// [payload] 通知负载，用于传递额外数据
  Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 构建通知详情
    const androidDetails = AndroidNotificationDetails(
      'imboy_notification_channel',
      'ImBoy 通知',
      channelDescription: 'ImBoy 应用的通知频道',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS 通知详情（目前注释掉）
    // const iosDetails = DarwinNotificationDetails(
    //   presentAlert: true,
    //   presentBadge: true,
    //   presentSound: true,
    // );

    final details = NotificationDetails(
      android: androidDetails,
      // iOS: iosDetails,
    );

    // 显示通知
    await _plugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch >> 10,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// 取消指定ID的通知
  ///
  /// [id] 通知ID
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 获取活跃通知列表（仅Android）
  Future<List<ActiveNotification>> getActiveNotifications() async {
    // 注意：此方法仅在 Android 平台有效
    // iOS 平台需要使用其他方法
    return [];
  }

  /// 释放资源
  Future<void> dispose() async {
    await _plugin.cancelAll();
    _isInitialized = false;
  }
}
