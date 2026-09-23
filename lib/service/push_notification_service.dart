/// 推送通知服务
///
/// 管理远程推送 token 的获取、注册和生命周期。
/// 支持方案:
/// - 本地通知 (flutter_local_notifications) — 始终启用
/// - FCM 远程推送 — 自动检测 Firebase 配置，有则启用（Android 记 fcm、iOS 记 apns）
/// - JPush 远程推送 — [setToken] 注入 RegistrationID（plugin 接线后启用，记 jpush）
///
/// 使用方式:
/// 1. 在 AppInitializer 中调用 PushNotificationService.initialize()
/// 2. 用户登录后调用 registerToken()（UserRepoLocal.loginAfter 已接线）
/// 3. 用户登出时调用 unregisterToken()（UserRepoLocal.quitLogin 已接线）
///
/// 后端字段合同（EPGZ-07）：device_type = 设备 OS（android/ios/web），
/// platform = 推送通道 provider（fcm/apns/web_push/jpush）——两个语义
/// 独立，不得混用（历史错位：曾把 device_type 值塞进 platform）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:go_router/go_router.dart';

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/notification.dart';
import 'package:imboy/service/notification_payload_rules.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/push_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 推送通知管理服务
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;

  final PushApi _api = PushApi();
  final NotificationService _notificationService = NotificationService();

  /// 当前推送 token（FCM token、APNs device token 或 JPush RegistrationID）
  String? _pushToken;
  String? get pushToken => _pushToken;

  /// 当前 token 对应的推送通道 provider（后端 platform 字段值）
  String? _providerId;
  String? get providerId => _providerId;

  /// 是否已注册到后端
  bool _isRegistered = false;
  bool get isRegistered => _isRegistered;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  /// FCM 是否初始化成功
  bool _fcmEnabled = false;
  bool get fcmEnabled => _fcmEnabled;

  /// 测试专用：重置 token 注册状态（单例跨用例复用，防状态串扰；
  /// 不触碰 FCM 订阅——单测环境本就不经过 initialize()）。
  @visibleForTesting
  void resetForTest() {
    _pushToken = null;
    _providerId = null;
    _isRegistered = false;
  }

  /// device_type 字段值：设备 OS（后端值域 android/ios/web）
  static String deviceTypeId({required bool isIOS}) =>
      isIOS ? 'ios' : 'android';

  /// FCM 通道的 platform 字段值：iOS 经 APNs 投递记 apns，Android 记 fcm
  static String fcmProviderId({required bool isIOS}) => isIOS ? 'apns' : 'fcm';

  /// JPush 通道的 platform 字段值（一期仅 Android）
  static const String jpushProviderId = 'jpush';

  /// 初始化推送服务
  ///
  /// 自动检测 Firebase 配置是否存在：
  /// - 有配置：初始化 FCM，获取远程推送 token
  /// - 无配置：graceful skip，仅使用本地通知
  Future<void> initialize() async {
    iPrint('[Push] 推送服务初始化...');

    // 整体加 15 秒超时：Huawei/中国设备访问 Google FCM 可能无限等待
    try {
      await _tryInitFcm().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          logger.w('[Push] FCM 初始化超时 (15s)，降级为本地通知模式');
          _fcmEnabled = false;
        },
      );
    } catch (e) {
      logger.w('[Push] FCM 初始化异常降级: $e');
      _fcmEnabled = false;
    }

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
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      final messaging = FirebaseMessaging.instance;

      // 请求推送权限 (iOS 必需，Android 13+ 也需要)
      final settings = await messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 5));
      iPrint('[Push] 权限状态: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        iPrint('[Push] 用户拒绝推送权限，跳过 FCM');
        return;
      }

      // 获取 FCM token（华为设备访问 Google 服务器可能超时）
      _pushToken = await messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          iPrint('[Push] FCM token 获取超时，降级为本地通知模式');
          return null;
        },
      );
      iPrint('[Push] FCM token 获取成功: ${_pushToken != null}');
      _providerId = _pushToken != null
          ? fcmProviderId(isIOS: Platform.isIOS)
          : null;

      // 监听 token 刷新
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        iPrint('[Push] Token 已刷新');
        _pushToken = newToken;
        _providerId = fcmProviderId(isIOS: Platform.isIOS);
        if (UserRepoLocal.to.isLoggedIn) {
          _registerTokenToServer(
            newToken,
            providerId: _providerId ?? fcmProviderId(isIOS: Platform.isIOS),
          );
        }
      });

      // 前台消息处理
      _onMessageSub = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      // 后台消息处理 (点击通知打开 app)
      _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      _fcmEnabled = true;
    } catch (e) {
      // Firebase 未配置或初始化失败 — graceful skip
      // 常见原因: 缺少 google-services.json / GoogleService-Info.plist
      iPrint('[Push] FCM 初始化跳过: $e');
      _fcmEnabled = false;
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
  }

  /// 向后端注册推送 token
  ///
  /// 在用户登录成功（UserRepoLocal.loginAfter）或 token 刷新时调用。
  /// 如果没有 push token (FCM 未配置且 JPush 未接线), 静默返回。
  Future<void> registerToken() async {
    if (_pushToken == null || _pushToken!.isEmpty) {
      iPrint('[Push] 无推送 token，跳过注册');
      return;
    }

    if (!UserRepoLocal.to.isLoggedIn) {
      iPrint('[Push] 用户未登录，跳过注册');
      return;
    }

    await _registerTokenToServer(
      _pushToken!,
      providerId: _providerId ?? defaultProviderId(),
    );
  }

  /// 注销推送 token
  ///
  /// 在用户登出时调用（UserRepoLocal.quitLogin 在清除本地登录态前调用，
  /// 请求依赖登录态；后端按 (uid, device_id) 下线 token）。
  ///
  /// FULL-06 修正（plan §7「logout 后旧 token 不再投递」）：登出可能发生在
  /// **上一次注册之后的另一个进程生命周期**里（App 重启/被系统回收后重新
  /// 打开，用户在登录页直接登出）。此时进程内 `_isRegistered` 已归零，但
  /// 服务端那条活跃 token 行还在——只按 `_isRegistered` 判据就会**静默跳过
  /// 注销**，旧 token 继续被投递到一台已登出的设备上。
  /// 判据因此改为 [hasServerBinding]（进程内状态 **或** 持久化注册记录），
  /// 同时保留「从未注册过则不发多余请求」的幂等语义。
  Future<void> unregisterToken() async {
    if (!hasServerBinding()) return;
    if (!UserRepoLocal.to.isLoggedIn) {
      iPrint('[Push] 未登录，跳过 token 注销');
      return;
    }

    try {
      final success = await _api.unregister(deviceId: deviceId);
      if (success) {
        _isRegistered = false;
        await _clearPersistedRegistration();
        iPrint('[Push] Token 注销成功');
      }
    } catch (e) {
      iPrint('[Push] Token 注销失败: $e');
    }
  }

  /// 本设备是否「在服务端有活跃绑定」（含**本进程之前**的会话）
  ///
  /// 覆盖窗口：注册成功 → App 重启 → 登出。只信 `_isRegistered` 会漏掉这段。
  bool hasServerBinding() =>
      _isRegistered || _persistedRegisteredDeviceId() == deviceId;

  /// 手动设置推送 token（用于非 FCM 的推送方案）
  ///
  /// 例如华为推送、小米推送、JPush 等国内厂商推送服务。
  /// [providerId] 为该通道在后端的 platform 值（jpush 等），
  /// 缺省按 [jpushProviderId] 处理（一期非 FCM 通道仅 JPush）。
  Future<void> setToken(String token, {String? providerId}) async {
    _pushToken = token;
    _providerId = providerId ?? jpushProviderId;
    if (UserRepoLocal.to.isLoggedIn) {
      await _registerTokenToServer(token, providerId: _providerId!);
    }
  }

  /// 无显式 provider 时的兜底通道（Android 一期客户场景：FCM 不可达）
  String defaultProviderId() =>
      Platform.isIOS ? fcmProviderId(isIOS: true) : jpushProviderId;

  /// 向后端注册 token（device_type 与 platform 两个语义分开传）
  Future<void> _registerTokenToServer(
    String token, {
    required String providerId,
  }) async {
    try {
      final deviceType = deviceTypeId(isIOS: Platform.isIOS);
      final success = await _api.register(
        token: token,
        deviceType: deviceType,
        platform: providerId,
        deviceId: deviceId,
      );
      if (success) {
        _isRegistered = true;
        await _persistRegistration();
        iPrint('[Push] Token 注册成功: platform=$providerId');
      } else {
        iPrint('[Push] Token 注册失败');
      }
    } catch (e) {
      iPrint('[Push] Token 注册异常: $e');
    }
  }

  /// 落持久化注册记录（**只写 device_id**，绝不写 token/RegistrationID：
  /// 推送 token 是凭据，普通存储不得承载；见 Keys.pushRegisteredDeviceId）。
  Future<void> _persistRegistration() async {
    try {
      await StorageService.to.setString(Keys.pushRegisteredDeviceId, deviceId);
    } catch (e) {
      iPrint('[Push] 注册记录落盘失败（进程内状态仍有效）: $e');
    }
  }

  Future<void> _clearPersistedRegistration() async {
    try {
      await StorageService.to.remove(Keys.pushRegisteredDeviceId);
    } catch (e) {
      iPrint('[Push] 注册记录清理失败: $e');
    }
  }

  /// 读持久化注册记录；值为 device_id，空/异常一律按「无记录」处理。
  String? _persistedRegisteredDeviceId() {
    try {
      final value = StorageService.to.getString(Keys.pushRegisteredDeviceId);
      return value.isEmpty ? null : value;
    } catch (_) {
      // StorageService 尚未初始化（极早期启动/异常路径）→ 退回进程内状态
      return null;
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
    // EPGZ-07：登出后不导航——通知点击只对已登录会话生效，
    // 防止登出残留通知把用户带回会话页（§7.4「登出后不导航」）。
    if (!UserRepoLocal.to.isLoggedIn) {
      iPrint('[Push] 用户未登录，忽略通知点击导航');
      return;
    }
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      if (retry < 5) {
        // 冷启动时路由器尚未挂载，延迟重试
        Future<dynamic>.delayed(const Duration(milliseconds: 500), () {
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
      case NotificationOrgInvitationRoute():
        iPrint('[Push] 导航到我的组织邀请页');
        context.go(result.toRoutePath());
      case NotificationParseSkip(:final reason):
        iPrint('[Push] 跳过路由: reason=$reason');
    }
  }
}
