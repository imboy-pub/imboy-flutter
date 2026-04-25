/// 推送通知服务
///
/// 管理远程推送 token 的获取、注册和生命周期。
/// 支持方案:
/// - 本地通知 (flutter_local_notifications) — 始终启用
/// - FCM 远程推送 — 自动检测 Firebase 配置，有则启用
///
/// 使用方式:
/// 1. 在 AppInitializer 中调用 PushNotificationService.initialize()
/// 2. 用户登录后调用 registerToken()
/// 3. 用户登出时调用 unregisterToken()
library;

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:go_router/go_router.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/notification.dart';
import 'package:imboy/service/notification_payload_rules.dart';
import 'package:imboy/store/api/push_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 推送通知管理服务
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance =
      PushNotificationService._();
  static PushNotificationService get instance => _instance;

  final PushApi _api = PushApi();
  final NotificationService _notificationService = NotificationService();

  /// 当前推送 token（FCM token 或 APNs device token）
  String? _pushToken;
  String? get pushToken => _pushToken;

  /// 是否已注册到后端
  bool _isRegistered = false;
  bool get isRegistered => _isRegistered;

  /// FCM 是否初始化成功
  bool _fcmEnabled = false;
  bool get fcmEnabled => _fcmEnabled;

  /// 初始化推送服务
  ///
  /// 自动检测 Firebase 配置是否存在：
  /// - 有配置：初始化 FCM，获取远程推送 token
  /// - 无配置：graceful skip，仅使用本地通知
  Future<void> initialize() async {
    iPrint('[Push] 推送服务初始化...');

    // 尝试初始化 FCM，失败则 graceful fallback
    await _tryInitFcm();

    if (_fcmEnabled) {
      iPrint('[Push] 推送服务初始化完成 (FCM 模式)');
    } else {
      iPrint('[Push] 推送服务初始化完成 (本地通知模式)');
    }
  }

  /// 尝试初始化 Firebase Cloud Messaging
  ///
  /// 如果 Firebase 配置文件不存在（开发环境），
  /// 会捕获异常并 graceful skip，不影响应用正常运行。
  Future<void> _tryInitFcm() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      // 请求推送权限 (iOS 必需，Android 13+ 也需要)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      iPrint('[Push] 权限状态: ${settings.authorizationStatus}');

      if (settings.authorizationStatus ==
          AuthorizationStatus.denied) {
        iPrint('[Push] 用户拒绝推送权限，跳过 FCM');
        return;
      }

      // 获取 FCM token
      _pushToken = await messaging.getToken();
      iPrint('[Push] FCM token 获取成功: ${_pushToken != null}');

      // 监听 token 刷新
      messaging.onTokenRefresh.listen((newToken) {
        iPrint('[Push] Token 已刷新');
        _pushToken = newToken;
        if (UserRepoLocal.to.isLoggedIn) {
          _registerTokenToServer(newToken);
        }
      });

      // 前台消息处理
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 后台消息处理 (点击通知打开 app)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _fcmEnabled = true;
    } catch (e) {
      // Firebase 未配置或初始化失败 — graceful skip
      // 常见原因: 缺少 google-services.json / GoogleService-Info.plist
      iPrint('[Push] FCM 初始化跳过: $e');
      _fcmEnabled = false;
    }
  }

  /// 向后端注册推送 token
  ///
  /// 在用户登录成功或 token 刷新时调用。
  /// 如果没有 push token (FCM 未配置), 静默返回。
  Future<void> registerToken() async {
    if (_pushToken == null || _pushToken!.isEmpty) {
      iPrint('[Push] 无推送 token，跳过注册');
      return;
    }

    if (!UserRepoLocal.to.isLoggedIn) {
      iPrint('[Push] 用户未登录，跳过注册');
      return;
    }

    await _registerTokenToServer(_pushToken!);
  }

  /// 注销推送 token
  ///
  /// 在用户登出时调用
  Future<void> unregisterToken() async {
    if (!_isRegistered) return;

    try {
      final success = await _api.unregister(deviceId: deviceId);
      if (success) {
        _isRegistered = false;
        iPrint('[Push] Token 注销成功');
      }
    } catch (e) {
      iPrint('[Push] Token 注销失败: $e');
    }
  }

  /// 手动设置推送 token（用于非 FCM 的推送方案）
  ///
  /// 例如华为推送、小米推送等国内厂商推送服务
  Future<void> setToken(String token) async {
    _pushToken = token;
    if (UserRepoLocal.to.isLoggedIn) {
      await _registerTokenToServer(token);
    }
  }

  /// 向后端注册 token
  Future<void> _registerTokenToServer(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final success = await _api.register(
        token: token,
        platform: platform,
        deviceId: deviceId,
      );
      if (success) {
        _isRegistered = true;
        iPrint('[Push] Token 注册成功: platform=$platform');
      } else {
        iPrint('[Push] Token 注册失败');
      }
    } catch (e) {
      iPrint('[Push] Token 注册异常: $e');
    }
  }

  /// 处理前台推送消息
  ///
  /// FCM 在前台收到消息时不会自动显示通知，
  /// 需要通过 flutter_local_notifications 手动展示。
  void _handleForegroundMessage(RemoteMessage message) {
    iPrint('[Push] 前台消息: ${message.messageId}');
    final notification = message.notification;
    if (notification != null) {
      _notificationService.show(
        title: notification.title ?? '',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// 处理通知点击（从后台/关闭状态打开 app）
  ///
  /// 冷启动时路由器可能尚未就绪，需要延迟重试。
  /// 委托纯函数 [parseNotificationPayload] 解析（与本地通知共享 schema）。
  void _handleNotificationTap(RemoteMessage message) {
    iPrint('[Push] 通知点击: ${message.messageId}');
    // RemoteMessage.data 是 Map<String, String>；转 dynamic 以适配纯函数签名
    final data = Map<String, dynamic>.from(message.data);
    final result = parseNotificationPayload(data);
    _navigateByResult(result);
  }

  /// 根据解析结果路由（含冷启动重试）
  void _navigateByResult(NotificationParseResult result, [int retry = 0]) {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      if (retry < 5) {
        // 冷启动时路由器尚未挂载，延迟重试
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateByResult(result, retry + 1);
        });
        return;
      }
      iPrint('[Push] 导航失败: context 在 $retry 次重试后仍不可用');
      return;
    }

    switch (result) {
      case NotificationMessageRoute(:final peerId, :final chatType):
        iPrint('[Push] 导航到会话: peerId=$peerId chatType=$chatType');
        context.go(result.toRoutePath());
      case NotificationFriendRequestRoute():
        iPrint('[Push] 导航到新朋友页');
        context.go(result.toRoutePath());
      case NotificationGroupInviteRoute(:final groupId):
        iPrint('[Push] 导航到群详情: groupId=$groupId');
        context.go(result.toRoutePath());
      case NotificationParseSkip(:final reason):
        iPrint('[Push] 跳过路由: reason=$reason');
    }
  }
}
