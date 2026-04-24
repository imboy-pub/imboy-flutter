import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';

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
  void _handleNavigation(String payload) {
    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final conversationUk3 = data['conversationUk3'] as String?;
      final peerId = data['peerId'] as String?;
      // 会话类型 (C2C/C2G)。payload key 从旧名 `msgType` 迁移到 `chatType`；
      // 在 `showMessageNotification` 生产端保持同步。
      final chatType = data['chatType'] as String?;

      iPrint('🔔 [Notification] 解析导航数据: type=$type, uk3=$conversationUk3, peerId=$peerId');

      // 获取导航上下文
      final context = navigatorKey.currentContext;
      if (context == null) {
        iPrint('⚠️ [Notification] 无法获取导航上下文');
        return;
      }

      // 根据通知类型进行导航
      switch (type) {
        case 'message':
          // 消息通知：跳转到聊天页面
          if (conversationUk3 != null && peerId != null && chatType != null) {
            _navigateToChat(context, conversationUk3, peerId, chatType);
          }
          break;
        case 'friend_request':
          // 好友请求：跳转到新朋友页面
          context.push('/contact/new_friend');
          break;
        case 'group_invite':
          // 群邀请：跳转到群详情
          if (peerId != null) {
            context.push('/group/$peerId/detail');
          }
          break;
        default:
          iPrint('🔔 [Notification] 未知通知类型: $type');
      }
    } catch (e) {
      iPrint('❌ [Notification] 解析导航数据失败: $e');
    }
  }

  /// 导航到聊天页面
  void _navigateToChat(
    dynamic context,
    String conversationUk3,
    String peerId,
    String chatType,
  ) {
    try {
      // 构建聊天页面路径
      // 格式: /chat/{peerId}?type={chatType}
      // 注意：路由配置是 /chat/:peerId，type 通过 query 参数传递
      final path = '/chat/$peerId?type=$chatType';
      iPrint('🔔 [Notification] 导航到聊天页面: $path');

      // 使用 go_router 导航
      if (context != null && context.mounted) {
        context.push(path);
      }
    } catch (e) {
      iPrint('❌ [Notification] 导航到聊天页面失败: $e');
    }
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

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
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
      title: '好友请求',
      body: '$requesterName 请求添加您为好友',
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
      'peerId': groupId,
    });

    await show(
      id: groupId.hashCode,
      title: '群邀请',
      body: '$inviterName 邀请您加入群组 $groupName',
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
