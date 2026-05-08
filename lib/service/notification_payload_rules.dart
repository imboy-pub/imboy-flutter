/// 通知 payload 解析与路由规则（纯函数模块）
///
/// 用途：
/// - 统一 **本地通知 (`flutter_local_notifications`)** 与 **FCM 远程推送
///   (`firebase_messaging`)** 两条通知路径的 payload schema。
/// - 提供 sealed Result 表达解析结果，避免在调用侧用 `Map` 字段 null 检查驱动路由。
///
/// 设计要点（KISS / YAGNI / DRY）：
/// 1. **零外部依赖**：仅 `dart:core`，可在任何 Dart 进程（含纯单测）下运行，
///    不触碰 `firebase_messaging` / `flutter_local_notifications` 单例链。
/// 2. **多键兼容**：客户端历史本地通知用 camelCase（`conversationUk3` / `chatType`），
///    后端 FCM 倾向 snake_case（`conversation_uk3` / `chat_type`）；
///    本模块同时识别两种风格 + 旧 FCM 键 `conversation_id`，迁移期不破坏现状。
/// 3. **显式 notify_type**：取代旧 FCM 隐式 `containsKey('conversation_id')` 判别，
///    新增 `friend_request` / `group_invite` 显式分支。
/// 4. **不做副作用**：仅返回 sealed Result + 路径字符串，**不调用 GoRouter**，
///    路由跳转由调用侧（`NotificationService` / `PushNotificationService`）负责。
library;

/// 通知类别（对齐 `notify_type` 字段）
enum NotificationType {
  /// 聊天消息（C2C 或 C2G）
  message,

  /// 好友请求
  friendRequest,

  /// 群组邀请
  groupInvite,

  /// 未知 / 未携带 notify_type 字段
  unknown,
}

/// 通知 payload 解析结果（sealed）
sealed class NotificationParseResult {
  const NotificationParseResult();
}

/// 消息类通知：路由到 `/chat/$peerId?type=$chatType`
final class NotificationMessageRoute extends NotificationParseResult {
  const NotificationMessageRoute({
    required this.peerId,
    required this.chatType,
    this.conversationUk3,
    this.title,
  });

  final String peerId;

  /// `'C2C'` / `'C2G'`，缺省时由调用侧默认 `'C2C'`
  final String chatType;

  final String? conversationUk3;
  final String? title;

  /// 构造路由路径（与现有 `/chat/:peerId?type=` 路由对齐）
  String toRoutePath() => '/chat/$peerId?type=$chatType';
}

/// 好友请求通知：路由到 `/contact/new_friend`
final class NotificationFriendRequestRoute extends NotificationParseResult {
  const NotificationFriendRequestRoute({this.requesterId});

  final String? requesterId;

  String toRoutePath() => '/contact/new_friend';
}

/// 群邀请通知：路由到 `/group/detail/$groupId`
///
/// 注意：路由顺序是 `/group/detail/:groupId`（来自 `app_router.dart:374`），
/// 不是旧版误写的 `/group/$groupId/detail`。
final class NotificationGroupInviteRoute extends NotificationParseResult {
  const NotificationGroupInviteRoute({
    required this.groupId,
    this.inviterName,
    this.groupName,
  });

  final String groupId;
  final String? inviterName;
  final String? groupName;

  String toRoutePath() => '/group/detail/$groupId';
}

/// 缺少必要字段或 type 未知：调用侧仅记日志、不跳转
final class NotificationParseSkip extends NotificationParseResult {
  const NotificationParseSkip(this.reason);

  /// 原因：`'missing_peer_id'` / `'missing_group_id'` / `'unknown_type'` / `'empty_payload'`
  final String reason;
}

/// 推断通知类别
///
/// 优先读 `notify_type` 显式字段；旧 FCM payload 仅有 `conversation_id` 时
/// 兜底视作 `message`；都不满足返回 `unknown`。
NotificationType resolveNotificationType(Map<String, dynamic> data) {
  if (data.isEmpty) return NotificationType.unknown;
  final raw = (data['notify_type'] ?? data['type'])?.toString().trim();
  switch (raw) {
    case 'message':
      return NotificationType.message;
    case 'friend_request':
      return NotificationType.friendRequest;
    case 'group_invite':
      return NotificationType.groupInvite;
  }
  // 兼容旧 FCM payload：含 conversation_id 兜底为 message
  if (_pickFirstNonEmpty(data, const [
        'peer_id',
        'peerId',
        'conversation_id',
        'conversation_uk3',
        'conversationUk3',
      ]) !=
      null) {
    return NotificationType.message;
  }
  return NotificationType.unknown;
}

/// 从 payload Map 解析路由结果
///
/// **多键兼容矩阵**：
/// - peerId: `peer_id` | `peerId` | `conversation_id`（旧 FCM 时兜底）
/// - chatType: `chat_type` | `chatType` | `type`（旧 FCM 时是 `'C2C'`）
/// - conversationUk3: `conversation_uk3` | `conversationUk3`
/// - groupId: `group_id` | `groupId` | `peer_id` | `peerId`
NotificationParseResult parseNotificationPayload(Map<String, dynamic> data) {
  if (data.isEmpty) {
    return const NotificationParseSkip('empty_payload');
  }
  final type = resolveNotificationType(data);
  switch (type) {
    case NotificationType.message:
      final peerId = _pickFirstNonEmpty(data, const [
        'peer_id',
        'peerId',
        'conversation_id',
      ]);
      if (peerId == null) {
        return const NotificationParseSkip('missing_peer_id');
      }
      // chat_type 在新 schema 是 'C2C'/'C2G'；
      // 旧 FCM payload 用 'type' 字段承载 chatType，因 resolveNotificationType
      // 已识别此种情况进入 message 分支，这里读 'type' 做兜底；缺省 'C2C'。
      final chatType =
          _pickFirstNonEmpty(data, const ['chat_type', 'chatType', 'type']) ??
          'C2C';
      return NotificationMessageRoute(
        peerId: peerId,
        chatType: chatType,
        conversationUk3: _pickFirstNonEmpty(data, const [
          'conversation_uk3',
          'conversationUk3',
        ]),
        title: _pickFirstNonEmpty(data, const ['title']),
      );
    case NotificationType.friendRequest:
      return NotificationFriendRequestRoute(
        requesterId: _pickFirstNonEmpty(data, const [
          'requester_id',
          'requesterId',
        ]),
      );
    case NotificationType.groupInvite:
      final groupId = _pickFirstNonEmpty(data, const [
        'group_id',
        'groupId',
        'peer_id',
        'peerId',
      ]);
      if (groupId == null) {
        return const NotificationParseSkip('missing_group_id');
      }
      return NotificationGroupInviteRoute(
        groupId: groupId,
        inviterName: _pickFirstNonEmpty(data, const [
          'inviter_name',
          'inviterName',
        ]),
        groupName: _pickFirstNonEmpty(data, const ['group_name', 'groupName']),
      );
    case NotificationType.unknown:
      return const NotificationParseSkip('unknown_type');
  }
}

/// 取 keys 中首个非空（去空白后非空）字符串值
String? _pickFirstNonEmpty(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final v = data[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isEmpty) continue;
    return s;
  }
  return null;
}
