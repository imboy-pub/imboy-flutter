import 'dart:convert';

import 'package:imboy/store/model/model_parse_utils.dart';

/// 正交频道访问模型字段含义：
///
/// visibility  (谁能发现)
///   0 = public    公开可发现
///   1 = private   私有不可发现
///
/// access_type (是否付费，语义别名 monetization)
///   0 = free      免费
///   1 = paid      付费
///
/// join_policy (怎么加入)
///   0 = open      直接加入
///   1 = invite    邀请加入
///   2 = approval  审批加入（v1 fail-closed，未实现）
///   3 = purchase  购买加入
///
/// 组合矩阵：
///   C1: public  + free  + open     → 公开免费
///   C2: private + free  + invite   → 私有免费（邀请制）
///   C3: public  + paid  + purchase → 公开付费
///   C4: private + paid  + purchase → 私有付费

/// 用户在频道中的角色
enum ChannelUserRole {
  none, // 无角色 (0) - 非订阅者
  subscriber, // 订阅者 (0) - 从订阅角度
  editor, // 编辑 (1) - 可以发布消息
  admin, // 管理员 (2) - 可以管理频道
  creator // 创建者 (3) - 最高权限
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
/// - 加入方式：visibility/access_type/join_policy 正交三字段决定
/// - 发言权限：仅管理员/指定编辑
///
/// 后端 API 已从单个 type 列迁移为三个正交字段（迁移 00000072）：
/// visibility, access_type, join_policy。后端不再返回 type 字段。
class ChannelModel {
  /// 服务端没有返回完整访问策略时使用的哨兵值。
  ///
  /// `channel.type` 已删除，不能再把缺失字段猜成公开免费；调用方必须
  /// 将未知或未支持组合按 fail-closed 处理。
  static const int unknownAccessPolicy = -1;

  final int id;
  final String name;
  final String? description;
  final String? avatar;

  // 正交访问模型三字段（替代旧 type 枚举）
  final int visibility; // 0=public, 1=private
  final int accessType; // 0=free, 1=paid
  final int joinPolicy; // 0=open, 1=invite, 2=approval, 3=purchase

  final String? customId;
  final int creatorId;
  final int subscriberCount;
  final bool isVerified;
  final List<String>? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 用户相关字段
  final ChannelUserRole userRole;
  final bool isSubscribed;

  /// 付费频道内容权益：只由服务端购买订单状态决定，不等同于订阅关系。
  final bool hasPurchased;

  // 付费频道价格字段（仅 access_type == paid 时有意义）
  // price 单位：分（与钱包余额一致），currency 默认 CNY。
  // 后端通过 channel_price LEFT JOIN 返回，DB 存「元」，接口已转换为「分」。
  final int price;
  final String currency;

  ChannelModel({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    this.visibility = unknownAccessPolicy,
    this.accessType = unknownAccessPolicy,
    this.joinPolicy = unknownAccessPolicy,
    this.customId,
    required this.creatorId,
    this.subscriberCount = 0,
    this.isVerified = false,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.userRole = ChannelUserRole.none,
    this.isSubscribed = false,
    this.hasPurchased = false,
    this.price = 0,
    this.currency = 'CNY',
  });

  // ---- 计算属性 ----

  /// 是否是管理中的频道（用户有管理权限）
  bool get isManaged => userRole.isAdmin;

  /// 用户是否可以发布消息
  bool get canPublish => userRole.canPublish;

  /// 是否为付费频道且后端已返回有效价格
  bool get hasPrice => accessType == 1 && price > 0;

  /// 是否为当前 v1 支持的访问组合（C1-C4）。
  bool get hasSupportedAccessPolicy {
    if (visibility != 0 && visibility != 1) return false;
    return (accessType == 0 &&
            ((visibility == 0 && joinPolicy == 0) ||
                (visibility == 1 && joinPolicy == 1))) ||
        (accessType == 1 && joinPolicy == 3);
  }

  /// 是否公开可见。未知策略绝不按公开展示。
  bool get isPublic => hasSupportedAccessPolicy && visibility == 0;

  /// 是否私有
  bool get isPrivate => hasSupportedAccessPolicy && visibility == 1;

  /// 是否付费
  bool get isPaid => hasSupportedAccessPolicy && accessType == 1;

  /// 价格（元），便于 UI 展示
  double get priceYuan => price / 100.0;

  // ---- 工厂方法 ----

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    final parsedCustomId = parseModelNullableString(json['custom_id']);
    final parsedId = parseModelInt(json['id']);
    return ChannelModel(
      id: parsedId,
      name: parseModelString(json['name']),
      description: parseModelNullableString(json['description']),
      avatar: parseModelNullableString(json['avatar']),
      visibility: parseModelInt(
        json['visibility'],
        defaultValue: unknownAccessPolicy,
      ),
      accessType: parseModelInt(
        json['access_type'],
        defaultValue: unknownAccessPolicy,
      ),
      joinPolicy: parseModelInt(
        json['join_policy'],
        defaultValue: unknownAccessPolicy,
      ),
      customId: parsedCustomId,
      // 后端返回 creator_uid 或 creator_id
      creatorId: parseModelInt(json['creator_uid'] ?? json['creator_id']),
      subscriberCount: parseModelInt(json['subscriber_count']),
      isVerified: parseModelBool(json['is_verified']),
      tags: parseModelStringList(json['tags']),
      createdAt: json['created_at'] != null
          ? parseModelDateTime(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? parseModelDateTime(json['updated_at'])
          : DateTime.now(),
      userRole: ChannelUserRole.fromInt(parseModelInt(json['user_role'])),
      isSubscribed: parseModelBool(json['is_subscribed']),
      hasPurchased: parseModelBool(json['has_purchased']),
      price: parseModelInt(json['price']),
      currency: parseModelString(json['currency'], defaultValue: 'CNY'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'visibility': visibility,
      'access_type': accessType,
      'join_policy': joinPolicy,
      'custom_id': customId,
      'creator_id': creatorId,
      'subscriber_count': subscriberCount,
      'is_verified': isVerified ? 1 : 0,
      'tags': tags,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'user_role': userRole.toInt(),
      'is_subscribed': isSubscribed ? 1 : 0,
      'has_purchased': hasPurchased ? 1 : 0,
      'price': price,
      'currency': currency,
    };
  }

  /// 从 SQLite Map 创建
  factory ChannelModel.fromMap(Map<String, dynamic> map) {
    final parsedCustomId = parseModelNullableString(map['custom_id']);
    final parsedId = parseModelInt(map['id']);
    return ChannelModel(
      id: parsedId,
      name: parseModelString(map['name']),
      description: parseModelNullableString(map['description']),
      avatar: parseModelNullableString(map['avatar']),
      visibility: parseModelInt(
        map['visibility'],
        defaultValue: unknownAccessPolicy,
      ),
      accessType: parseModelInt(
        map['access_type'],
        defaultValue: unknownAccessPolicy,
      ),
      joinPolicy: parseModelInt(
        map['join_policy'],
        defaultValue: unknownAccessPolicy,
      ),
      customId: parsedCustomId,
      creatorId: parseModelInt(map['creator_id']),
      subscriberCount: parseModelInt(map['subscriber_count']),
      isVerified: parseModelBool(map['is_verified']),
      tags: parseModelStringList(map['tags']),
      createdAt: parseModelDateTime(map['created_at']),
      updatedAt: parseModelDateTime(map['updated_at']),
      userRole: ChannelUserRole.fromInt(parseModelInt(map['user_role'])),
      isSubscribed: parseModelBool(map['is_subscribed']),
      hasPurchased: parseModelBool(map['has_purchased']),
      // 容错读取：旧 SQLite 表可能无 price/currency 列，缺失时退化为默认值。
      price: parseModelInt(map['price']),
      currency: parseModelString(map['currency'], defaultValue: 'CNY'),
    );
  }

  /// 转换为 SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'visibility': visibility,
      'access_type': accessType,
      'join_policy': joinPolicy,
      'custom_id': customId,
      'creator_id': creatorId,
      'subscriber_count': subscriberCount,
      'is_verified': isVerified ? 1 : 0,
      'tags': tags != null ? jsonEncode(tags) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'user_role': userRole.toInt(),
      'is_subscribed': isSubscribed ? 1 : 0,
      // 购买权益必须随频道快照持久化；否则重启后已付款用户会重新看到 paywall。
      'has_purchased': hasPurchased ? 1 : 0,
    };
  }

  /// 复制并修改部分字段
  ChannelModel copyWith({
    int? id,
    String? name,
    String? description,
    String? avatar,
    int? visibility,
    int? accessType,
    int? joinPolicy,
    String? customId,
    int? creatorId,
    int? subscriberCount,
    bool? isVerified,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    ChannelUserRole? userRole,
    bool? isSubscribed,
    bool? hasPurchased,
    int? price,
    String? currency,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      visibility: visibility ?? this.visibility,
      accessType: accessType ?? this.accessType,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      customId: customId ?? this.customId,
      creatorId: creatorId ?? this.creatorId,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      isVerified: isVerified ?? this.isVerified,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userRole: userRole ?? this.userRole,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      hasPurchased: hasPurchased ?? this.hasPurchased,
      price: price ?? this.price,
      currency: currency ?? this.currency,
    );
  }

  @override
  String toString() {
    return 'ChannelModel(id: $id, name: $name, '
        'v:$visibility at:$accessType jp:$joinPolicy, '
        'subscribers: $subscriberCount, role: $userRole)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
