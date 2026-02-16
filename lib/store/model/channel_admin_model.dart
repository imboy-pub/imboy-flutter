/// 频道管理员角色
enum ChannelAdminRole {
  editor, // 编辑：只能发布消息 (0)
  admin, // 管理员：可以管理订阅者、发布消息 (1)
  creator, // 创建者：拥有所有权限 (2)
}

/// 频道管理员模型
///
/// 存储频道的管理员信息
class ChannelAdminModel {
  final String channelId;
  final String userId;
  final ChannelAdminRole role;
  final DateTime addedAt;

  ChannelAdminModel({
    required this.channelId,
    required this.userId,
    this.role = ChannelAdminRole.editor,
    required this.addedAt,
  });

  factory ChannelAdminModel.fromJson(Map<String, dynamic> json) {
    return ChannelAdminModel(
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      role: ChannelAdminRole.values[json['role'] as int? ?? 0],
      addedAt: json['added_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['added_at'] as int)
          : DateTime.parse(json['added_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'user_id': userId,
      'role': role.index,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }

  /// 从 SQLite Map 创建
  factory ChannelAdminModel.fromMap(Map<String, dynamic> map) {
    return ChannelAdminModel(
      channelId: map['channel_id'] as String,
      userId: map['user_id'] as String,
      role: ChannelAdminRole.values[map['role'] as int? ?? 0],
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  /// 转换为 SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'user_id': userId,
      'role': role.index,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }

  /// 是否是创建者
  bool get isCreator => role == ChannelAdminRole.creator;

  /// 是否是管理员（包含创建者）
  bool get isAdmin =>
      role == ChannelAdminRole.admin || role == ChannelAdminRole.creator;

  /// 是否可以发布消息
  bool get canPublish => true; // 所有角色都可以发布消息

  /// 是否可以管理订阅者
  bool get canManageSubscribers => isAdmin;

  /// 是否可以管理其他管理员
  bool get canManageAdmins => isCreator;

  @override
  String toString() {
    return 'ChannelAdminModel(channelId: $channelId, userId: $userId, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelAdminModel &&
        other.channelId == channelId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(channelId, userId);
}
