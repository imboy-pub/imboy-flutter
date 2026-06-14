/// 用户相关事件定义
library;

import 'package:imboy/service/events/base_event.dart';

/// 用户登录事件
///
/// 当用户成功登录后发布
///
/// 示例：
/// ```dart
/// AppEventBus().fire(UserLoginEvent(
///   userId: '123',
///   username: 'imboy',
/// ));
/// ```
final class UserLoginEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 用户名
  final String username;

  const UserLoginEvent({required this.userId, required this.username});

  @override
  List<Object> get props => [userId, username];
}

/// 用户登出事件
///
/// 当用户主动登出或Token过期时发布
final class UserLogoutEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 登出原因
  final String? reason;

  const UserLogoutEvent({required this.userId, this.reason});

  @override
  List<Object?> get props => [userId, reason];
}

/// 用户信息更新事件
///
/// 当用户信息（昵称、头像等）更新时发布
final class UserInfoUpdateEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 更新的字段
  final Map<String, dynamic> updatedFields;

  const UserInfoUpdateEvent({
    required this.userId,
    required this.updatedFields,
  });

  @override
  List<Object> get props => [userId, updatedFields];
}

/// 用户状态变更事件
///
/// 当好友上线、下线、隐身时发布
final class UserStatusChangeEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 状态类型：online, offline, hide
  final String status;

  /// 用户昵称（可选，用于提示）
  final String? nickname;

  const UserStatusChangeEvent({
    required this.userId,
    required this.status,
    this.nickname,
  });

  @override
  List<Object?> get props => [userId, status, nickname];
}

/// 用户注销事件
///
/// 当好友账号注销时发布
final class UserCancelEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 用户昵称（可选，用于提示）
  final String? nickname;

  const UserCancelEvent({required this.userId, this.nickname});

  @override
  List<Object?> get props => [userId, nickname];
}

/// 用户被禁言事件
///
/// 当后端通过 WebSocket 通知当前用户被禁言时发布
final class UserMutedEvent extends AppEvent {
  /// 禁言到期时间戳（毫秒），0 表示永久禁言
  final int muteUntilMs;

  /// 禁言原因（可选）
  final String? reason;

  /// 会话 ID（可选，表示在哪个会话中被禁言）
  final String? conversationId;

  const UserMutedEvent({
    required this.muteUntilMs,
    this.reason,
    this.conversationId,
  });

  /// 剩余禁言分钟数
  int get remainingMinutes {
    if (muteUntilMs <= 0) return -1; // 永久
    final remaining = muteUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return 0;
    return (remaining / 60000).ceil();
  }

  /// 是否仍在禁言中
  bool get isMuted {
    if (muteUntilMs <= 0) return true; // 永久禁言
    return DateTime.now().millisecondsSinceEpoch < muteUntilMs;
  }

  @override
  List<Object?> get props => [muteUntilMs, reason, conversationId];

  @override
  String toString() {
    return 'UserMutedEvent(muteUntilMs: $muteUntilMs, reason: $reason, conversationId: $conversationId)';
  }
}

/// 用户禁言解除事件
///
/// 当禁言到期或被手动解除时发布
final class UserUnmutedEvent extends AppEvent {
  /// 会话 ID（可选）
  final String? conversationId;

  const UserUnmutedEvent({this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// 群成员被管理员禁言的广播事件（S2C `group_member_mute`）
///
/// 触发时机：群管理员 / 群主禁言某成员后，后端向群内所有成员广播。
///
/// **slice-1-finalize（2026-04-15）**：后端 `mute_notice/4` 已补 `user_id`
/// 字段。事件携带被禁言成员的 `userId`（TSID 字符串）；老后端不带时
/// 为空串，UI 层应据此跳过单成员定位，仅展示群级 toast。
final class GroupMemberMuteEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 被禁言成员的 user_id（TSID 字符串）；老后端 / 解析缺失时为 ''
  final String userId;

  /// 禁言到期时间戳（毫秒）
  final int muteUntilMs;

  /// 剩余秒数
  final int remainingSeconds;

  /// 可读禁言时长文案，如 "10分钟"
  final String durationText;

  /// 执行禁言的管理员昵称
  final String adminNickname;

  const GroupMemberMuteEvent({
    required this.gid,
    required this.muteUntilMs,
    required this.remainingSeconds,
    required this.durationText,
    required this.adminNickname,
    this.userId = '',
  });

  @override
  List<Object?> get props => [
    gid,
    userId,
    muteUntilMs,
    remainingSeconds,
    durationText,
    adminNickname,
  ];

  @override
  String toString() {
    return 'GroupMemberMuteEvent(gid: $gid, userId: $userId, '
        'muteUntilMs: $muteUntilMs, remainingSeconds: $remainingSeconds, '
        'durationText: $durationText, adminNickname: $adminNickname)';
  }
}

/// 群成员解禁的广播事件（slice-9b）。
///
/// 对应后端 `group_member_logic:unmute/3` 通过 `mute_notice/4` 下发
/// `mute_until == 0` 的解禁信号。UI 层应据此：
///   1. `userId` 非空 → 定位成员行，`GroupMemberRepo` 的 `mute_until` 已被 S2C 置 null
///   2. `userId` 空 → 仅展示群级 toast
final class GroupMemberUnmuteEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 被解禁成员的 user_id（TSID 字符串）；老后端 / 解析缺失时为 ''
  final String userId;

  /// 执行解禁的管理员昵称
  final String adminNickname;

  const GroupMemberUnmuteEvent({
    required this.gid,
    this.userId = '',
    this.adminNickname = '',
  });

  @override
  List<Object?> get props => [gid, userId, adminNickname];

  @override
  String toString() {
    return 'GroupMemberUnmuteEvent(gid: $gid, userId: $userId, '
        'adminNickname: $adminNickname)';
  }
}

/// 群成员角色变更的广播事件（S2C `group_member_role`）
///
/// 触发时机：群主/副群主/管理员通过 `update_role` 接口修改某成员的角色后，
/// 后端向群内所有成员广播。
///
/// 角色常量（对齐后端 `group_role.hrl`）：
///   1=普通成员 / 2=嘉宾 / 3=管理员 / 4=群主 / 5=副群主
final class GroupMemberRoleEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 被修改角色的成员 ID
  final int userId;

  /// 新角色（1..5）
  final int role;

  /// 角色文案（"普通成员" / "管理员" / ...）
  final String roleText;

  /// 被修改成员昵称
  final String nickname;

  /// 执行操作的管理员昵称
  final String adminNickname;

  /// 后端变更时间戳（秒级 epoch，0 表示后端未带）
  final int updatedAt;

  const GroupMemberRoleEvent({
    required this.gid,
    required this.userId,
    required this.role,
    required this.roleText,
    required this.nickname,
    required this.adminNickname,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    gid,
    userId,
    role,
    roleText,
    nickname,
    adminNickname,
    updatedAt,
  ];

  @override
  String toString() =>
      'GroupMemberRoleEvent(gid: $gid, userId: $userId, role: $role, '
      'roleText: $roleText, adminNickname: $adminNickname)';
}

/// 群资料编辑的广播事件（S2C `group_edit`）
///
/// 触发时机：群主/管理员通过 `POST /group/edit` 更新群资料
/// （title / avatar / introduction / type / join_limit /
/// content_limit / member_max / status 等）后，后端向所有群成员广播。
///
/// `updates` 是本次变更的字段集合（已剔除 gid），可能为空（表示仅
/// 触发「群被编辑」信号，无实际字段变化，一般不会出现，仅为兼容）。
final class GroupEditEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 本次变更的字段集合（不含 gid）
  final Map<String, dynamic> updates;

  const GroupEditEvent({required this.gid, required this.updates});

  @override
  List<Object?> get props => [gid, updates];

  @override
  String toString() => 'GroupEditEvent(gid: $gid, updates: $updates)';
}

/// 群公告发布的广播事件（S2C `group_notice_published`）
///
/// 触发时机：群主/管理员通过 `POST /v1/group/notice/publish` 发布新公告
/// 后，后端向所有群成员广播。UI 层（GroupAnnouncementProvider）可订阅此
/// 事件触发 REST 拉取刷新，或在聊天页显示 toast / 气泡提示。
///
/// 本切片不写本地 announcement 表（后端 REST-only，公告数据源仍为 REST）。
final class GroupNoticePublishedEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 公告 ID
  final int noticeId;

  /// 发布者用户 ID
  final int publisherId;

  /// 发布者昵称（可能为空串）
  final String publisherNickname;

  /// 公告标题（可能为空串）
  final String title;

  /// 公告正文（可能为空串）
  final String body;

  /// 过期时间戳（毫秒）；`null` 表示永不过期
  final int? expiredAt;

  /// 发布时间戳（毫秒）；0 表示未知
  final int publishedAt;

  const GroupNoticePublishedEvent({
    required this.gid,
    required this.noticeId,
    required this.publisherId,
    required this.publisherNickname,
    required this.title,
    required this.body,
    required this.expiredAt,
    required this.publishedAt,
  });

  @override
  List<Object?> get props => [
    gid,
    noticeId,
    publisherId,
    publisherNickname,
    title,
    body,
    expiredAt,
    publishedAt,
  ];

  @override
  String toString() =>
      'GroupNoticePublishedEvent(gid: $gid, noticeId: $noticeId, '
      'publisherId: $publisherId, title: $title)';
}
