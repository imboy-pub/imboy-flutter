import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/notification_payload_rules.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:synchronized/synchronized.dart';

/// 通知点击响应回调类型
typedef NotificationTapCallback = void Function(String? payload);

/// 通知服务
///
/// 负责本地通知的显示和管理
/// 使用 flutter_local_notifications 插件实现
///
/// 迁移说明（2026-01-16）:
/// - 从 GetX 迁移到 Riverpod
/// - 移除单例模式，使用 Provider 管理
/// - 所有功能保持不变
///
/// 2026-03-14 更新:
/// - 添加通知点击跳转支持
/// - 添加会话消息通知专用方法
class NotificationService {
  static final _notificationLock = Lock();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 通知点击回调（可选）
  NotificationTapCallback? onTapCallback;

  /// 初始化通知服务
  ///
  /// 必须在使用前调用此方法
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/logo');

    // iOS 初始化设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    // 初始化插件
    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _isInitialized = true;
    iPrint('🔔 [Notification] 服务初始化完成');
  }

  /// 处理通知点击响应
  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    iPrint('🔔 [Notification] 通知被点击: payload=$payload');

    // 先调用自定义回调
    onTapCallback?.call(payload);

    // 处理通知点击跳转
    if (payload != null && payload.isNotEmpty) {
      _handleNavigation(payload);
    }
  }

  /// 处理通知点击后的导航
  ///
  /// 委托纯函数 [parseNotificationPayload] 解析（多键兼容 snake_case /
  /// camelCase），根据 sealed [NotificationParseResult] 分发路由。
  void _handleNavigation(String payload) {
    Map<String, dynamic> data;
    try {
      data = json.decode(payload) as Map<String, dynamic>;
    } on FormatException catch (e) {
      iPrint('❌ [Notification] 解析 payload JSON 失败: $e');
      return;
    } on TypeError catch (e) {
      iPrint('❌ [Notification] payload 不是 Map<String, dynamic>: $e');
      return;
    }

    final result = parseNotificationPayload(data);

    final context = navigatorKey.currentContext;
    if (context == null) {
      iPrint('⚠️ [Notification] 无法获取导航上下文');
      return;
    }

    switch (result) {
      case NotificationMessageRoute(:final peerId, :final chatType):
        iPrint('🔔 [Notification] 路由到聊天: peerId=$peerId chatType=$chatType');
        _navigateToChat(context, peerId, chatType);
      case NotificationFriendRequestRoute():
        iPrint('🔔 [Notification] 路由到新朋友页');
        context.push(result.toRoutePath());
      case NotificationGroupInviteRoute(:final groupId):
        iPrint('🔔 [Notification] 路由到群详情: groupId=$groupId');
        context.push(result.toRoutePath());
      case NotificationOrgInvitationRoute():
        iPrint('🔔 [Notification] 路由到我的组织邀请页');
        context.push(result.toRoutePath());
      case NotificationParseSkip(:final reason):
        iPrint('🔔 [Notification] 跳过路由: reason=$reason');
    }
  }

  /// 导航到聊天页面
  ///
  /// 路径格式：`/chat/$peerId?type=$chatType`
  /// 路由配置见 `app_router.dart` 的 `/chat/:peerId`，type 通过 query 参数传递。
  void _navigateToChat(dynamic context, String peerId, String chatType) {
    try {
      final path = '/chat/$peerId?type=$chatType';
      iPrint('🔔 [Notification] 导航到聊天页面: $path');
      if (context != null && context.mounted == true) {
        context.push(path);
      }
    } on Object catch (e) {
      iPrint('❌ [Notification] 导航到聊天页面失败: $e');
    }
  }

  /// 显示通知
  ///
  /// [title] 通知标题
  /// [body] 通知内容
  /// [id] 账号内通知标识；平台通知 ID 按账号隔离，默认使用时间戳
  /// [payload] 通知负载，用于传递额外数据
  /// Account messages retain the session captured before upstream async work.
  /// Only explicitly public device notices may be shown without a login.
  Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
    AuthSessionScope? session,
    AccountLocalTaskOwner? owner,
    bool devicePublic = false,
  }) async {
    final capturedSession = session ?? authSessionReader.current;
    final account = devicePublic
        ? AccountLocalTaskOwner.capture(uid: '')
        : owner ?? AccountLocalTaskOwner.capture(uid: capturedSession.uid);
    void requireCurrent(AccountLocalTask? task) {
      task?.throwIfCancelled();
      if (!devicePublic &&
          (!authSessionReader.isCurrent(capturedSession) ||
              account.uid != capturedSession.uid ||
              account != AccountLocalTaskOwner.capture())) {
        throw const AccountLocalTaskCancelledException();
      }
    }

    requireCurrent(null);
    Future<void> showOwned(AccountLocalTask? task) =>
        _notificationLock.synchronized(() async {
          requireCurrent(task);
          await _showOwned(
            account,
            () => requireCurrent(task),
            title: title,
            body: body,
            id: id,
            payload: payload,
          );
        });
    if (devicePublic) {
      await showOwned(null);
    } else {
      await AccountLocalTaskRegistry.instance.run<void>(
        account,
        operation: showOwned,
      );
    }
  }

  Future<void> _showOwned(
    AccountLocalTaskOwner owner,
    void Function() requireCurrent, {
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    requireCurrent();
    final group = owner.uid.isEmpty ? 'imboy-device' : _accountGroup(owner);
    var notificationId =
        int.parse(
          sha256
              .convert(
                utf8.encode(
                  '$group:${id ?? DateTime.now().microsecondsSinceEpoch}',
                ),
              )
              .toString()
              .substring(0, 8),
          radix: 16,
        ) &
        0x7fffffff;
    if (_supportsActiveNotifications) {
      final active = await _plugin.getActiveNotifications();
      // Avoid replacing another account's notification even on an ID collision.
      while (active.any(
        (item) => item.id == notificationId && item.groupKey != group,
      )) {
        notificationId = (notificationId + 1) & 0x7fffffff;
      }
    }
    requireCurrent();

    // 构建通知详情
    final androidDetails = AndroidNotificationDetails(
      'imboy_notification_channel',
      'ImBoy 通知',
      channelDescription: 'ImBoy 应用的通知频道',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      groupKey: group,
      tag: group,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: group,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // 显示通知
    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
    try {
      requireCurrent();
    } on AccountLocalTaskCancelledException {
      // The OS may finish an already-entered write after cancellation. Remove
      // that exact account notification before releasing the task barrier.
      await _plugin.cancel(id: notificationId, tag: group);
      rethrow;
    }
  }

  /// 显示消息通知（专用方法）
  ///
  /// 用于在收到新消息时显示系统通知
  ///
  /// [senderName] 发送者昵称
  /// [content] 消息内容（已格式化）
  /// [conversationUk3] 会话 UK3
  /// [peerId] 对方 ID（用户 ID 或群组 ID）
  /// [chatType] 会话类型（C2C 或 C2G）
  /// [senderAvatar] 发送者头像（可选）
  Future<void> showMessageNotification({
    required String senderName,
    required String content,
    required String conversationUk3,
    required String peerId,
    required String chatType,
    String? senderAvatar,
    AuthSessionScope? session,
    AccountLocalTaskOwner? owner,
  }) async {
    // 构建通知负载（用于点击跳转）
    // payload key `chatType` 与 `_handleNavigation` 消费端保持同步
    final payload = json.encode({
      'type': 'message',
      'conversationUk3': conversationUk3,
      'peerId': peerId,
      'chatType': chatType,
    });

    // 使用会话 UK3 的哈希值作为通知 ID（同一会话的消息复用通知）
    final notificationId = conversationUk3.hashCode;

    await show(
      id: notificationId,
      title: senderName,
      body: content,
      payload: payload,
      session: session,
      owner: owner,
    );

    iPrint(
      '🔔 [Notification] 消息通知已显示: sender=$senderName, '
      'uk3=$conversationUk3, id=$notificationId',
    );
  }

  /// 显示好友请求通知
  ///
  /// [requesterName] 请求者昵称
  /// [requesterId] 请求者 ID
  Future<void> showFriendRequestNotification({
    required String requesterName,
    required String requesterId,
  }) async {
    final payload = json.encode({
      'type': 'friend_request',
      'requesterId': requesterId,
    });

    await show(
      id: requesterId.hashCode,
      title: t.common.notificationFriendRequest,
      body: t.common.notificationFriendRequestBody(
        requesterName: requesterName,
      ),
      payload: payload,
    );
  }

  /// 显示群邀请通知
  ///
  /// [groupName] 群名称
  /// [inviterName] 邀请者昵称
  /// [groupId] 群 ID
  Future<void> showGroupInviteNotification({
    required String groupName,
    required String inviterName,
    required String groupId,
  }) async {
    final payload = json.encode({
      'type': 'group_invite',
      // 使用 group_id 显式键，避免与 message 通知的 peerId 语义混淆；
      // parseNotificationPayload 同时识别 group_id / groupId / peer_id 兜底。
      'group_id': groupId,
    });

    await show(
      id: groupId.hashCode,
      title: t.common.notificationGroupInvite,
      body: t.common.notificationGroupInviteBody(
        inviterName: inviterName,
        groupName: groupName,
      ),
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

  static bool get _supportsActiveNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static String _accountGroup(AccountLocalTaskOwner owner) =>
      'imboy-account:${owner.storageDigest}';

  Future<void> validateAccountRemoval() =>
      _notificationLock.synchronized(() async {
        if (!_supportsActiveNotifications) return;
        for (final item in await _plugin.getActiveNotifications()) {
          if (item.groupKey == 'imboy-device') continue;
          if (item.id == null ||
              !RegExp(r'^imboy-account:[a-f0-9]{64}$')
                  .hasMatch(item.groupKey ?? '')) {
            throw const AccountLocalDataOwnershipException();
          }
        }
      });

  Future<void> cancelAccount(AccountLocalTaskOwner owner) =>
      _notificationLock.synchronized(() async {
        if (!_supportsActiveNotifications) return;
        final group = _accountGroup(owner);
        for (final item in await _plugin.getActiveNotifications()) {
          if (item.groupKey != group) continue;
          if (item.id == null) throw const AccountLocalDataOwnershipException();
          await _plugin.cancel(id: item.id!, tag: item.tag);
        }
        if ((await _plugin.getActiveNotifications()).any(
          (item) => item.groupKey == group,
        )) {
          throw StateError('Account notifications could not be removed');
        }
      });

  /// 获取平台支持的活跃通知列表（Android / iOS / macOS）。
  Future<List<ActiveNotification>> getActiveNotifications() async {
    return _plugin.getActiveNotifications();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _plugin.cancelAll();
    _isInitialized = false;
  }
}
