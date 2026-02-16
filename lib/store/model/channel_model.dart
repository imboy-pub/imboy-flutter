import 'dart:convert';

/// 频道类型
enum ChannelType {
  public, // 公开频道 (0)
  private, // 私有频道 (1)
  paid, // 付费频道 (2)
}

/// 用户在频道中的角色
enum ChannelUserRole {
  none, // 无角色 (0) - 非订阅者
  subscriber, // 订阅者 (0) - 从订阅角度
  editor, // 编辑 (1) - 可以发布消息
  admin, // 管理员 (2) - 可以管理频道
  creator, // 创建者 (3) - 最高权限
  ;

  /// 从整数值获取角色
  static ChannelUserRole fromInt(int? value) {
    switch (value) {
      case 1:
        return ChannelUserRole.editor;
      case 2:
        return ChannelUserRole.admin;
      case 3:
        return ChannelUserRole.creator;
      case 0:
      default:
        return ChannelUserRole.none;
    }
  }

  /// 转换为整数值
  int toInt() {
    switch (this) {
      case ChannelUserRole.editor:
        return 1;
      case ChannelUserRole.admin:
        return 2;
      case ChannelUserRole.creator:
        return 3;
      case ChannelUserRole.none:
      case ChannelUserRole.subscriber:
        return 0;
    }
  }

  /// 是否可以发布消息
  bool get canPublish => this == editor || this == admin || this == creator;

  /// 是否可以管理频道
  bool get canManage => this == admin || this == creator;

  /// 是否是创建者
  bool get isCreator => this == creator;

  /// 是否是管理员（含创建者）
  bool get isAdmin => this == admin || this == creator;

  /// 获取角色显示名称
  String get displayName {
    switch (this) {
      case ChannelUserRole.creator:
        return '创建者';
      case ChannelUserRole.admin:
        return '管理员';
      case ChannelUserRole.editor:
        return '编辑';
      case ChannelUserRole.subscriber:
      case ChannelUserRole.none:
        return '订阅者';
    }
  }
}

/// 频道模型
///
/// Channel（频道）是一种单向关注型消息订阅机制
/// - 消息流向：单向（管理员 → 订阅者）
/// - 成员上限：无限制
/// - 加入方式：关注/订阅
/// - 发言权限：仅管理员/指定编辑
class ChannelModel {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final ChannelType type;
  final String? customId;
  final String creatorId;
  final int subscriberCount;
  final bool isVerified;
  final List<String>? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 用户相关字段
  final ChannelUserRole userRole;
  final bool isSubscribed;

  ChannelModel({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    this.type = ChannelType.public,
    this.customId,
    required this.creatorId,
    this.subscriberCount = 0,
    this.isVerified = false,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.userRole = ChannelUserRole.none,
    this.isSubscribed = false,
  });

  /// 是否是管理中的频道（用户有管理权限）
  bool get isManaged => userRole.isAdmin;

  /// 用户是否可以发布消息
  bool get canPublish => userRole.canPublish;

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    // 处理 is_verified 可能是 boolean 或 integer 的情况
    bool parseVerified(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false;
    }

    // 处理 tags 可能是 List 或 JSON String 的情况
    List<String>? parseTags(dynamic value) {
      if (value == null) return null;
      if (value is List) return List<String>.from(value);
      if (value is String && value.isNotEmpty) {
        try {
          return List<String>.from(jsonDecode(value) as List);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // 处理时间字段可能是 int 或 String 的情况
    DateTime parseDateTime(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.parse(value as String);
    }

    // 处理 is_subscribed 可能是 boolean 或 integer 的情况
    bool parseSubscribed(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1 || value > 0;
      return false;
    }

    return ChannelModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      type: ChannelType.values[json['type'] as int? ?? 0],
      customId: json['custom_id'] as String?,
      // 后端返回 creator_uid 或 creator_id
      creatorId: (json['creator_uid'] ?? json['creator_id'])?.toString() ?? '',
      subscriberCount: json['subscriber_count'] as int? ?? 0,
      isVerified: parseVerified(json['is_verified']),
      tags: parseTags(json['tags']),
      createdAt: json['created_at'] != null
          ? parseDateTime(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? parseDateTime(json['updated_at'])
          : DateTime.now(),
      userRole: ChannelUserRole.fromInt(json['user_role'] as int?),
      isSubscribed: parseSubscribed(json['is_subscribed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'type': type.index,
      'custom_id': customId,
      'creator_id': creatorId,
      'subscriber_count': subscriberCount,
      'is_verified': isVerified ? 1 : 0,
      'tags': tags,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'user_role': userRole.toInt(),
      'is_subscribed': isSubscribed ? 1 : 0,
    };
  }

  /// 从 SQLite Map 创建
  factory ChannelModel.fromMap(Map<String, dynamic> map) {
    List<String>? tagsList;
    if (map['tags'] != null && map['tags'].toString().isNotEmpty) {
      try {
        tagsList = List<String>.from(jsonDecode(map['tags'] as String) as List);
      } catch (_) {
        tagsList = null;
      }
    }

    return ChannelModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      avatar: map['avatar'] as String?,
      type: ChannelType.values[map['type'] as int? ?? 0],
      customId: map['custom_id'] as String?,
      creatorId: map['creator_id'] as String,
      subscriberCount: map['subscriber_count'] as int? ?? 0,
      isVerified: (map['is_verified'] as int? ?? 0) == 1,
      tags: tagsList,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      userRole: ChannelUserRole.fromInt(map['user_role'] as int?),
      isSubscribed: (map['is_subscribed'] as int? ?? 0) == 1,
    );
  }

  /// 转换为 SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'type': type.index,
      'custom_id': customId,
      'creator_id': creatorId,
      'subscriber_count': subscriberCount,
      'is_verified': isVerified ? 1 : 0,
      'tags': tags != null ? jsonEncode(tags) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'user_role': userRole.toInt(),
      'is_subscribed': isSubscribed ? 1 : 0,
    };
  }

  /// 复制并修改部分字段
  ChannelModel copyWith({
    String? id,
    String? name,
    String? description,
    String? avatar,
    ChannelType? type,
    String? customId,
    String? creatorId,
    int? subscriberCount,
    bool? isVerified,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    ChannelUserRole? userRole,
    bool? isSubscribed,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      type: type ?? this.type,
      customId: customId ?? this.customId,
      creatorId: creatorId ?? this.creatorId,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      isVerified: isVerified ?? this.isVerified,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userRole: userRole ?? this.userRole,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  @override
  String toString() {
    return 'ChannelModel(id: $id, name: $name, type: $type, subscribers: $subscriberCount, role: $userRole)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
