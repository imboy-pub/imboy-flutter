/// @提及功能数据模型
///
/// 用于群聊中 @提及用户的数据结构
library;

import 'package:flutter/material.dart';

/// @提及候选项
class MentionCandidate {
  /// 用户ID
  final String userId;

  /// 显示名称（昵称或群内别名）
  final String displayName;

  /// 头像URL
  final String avatar;

  /// 角色 (1=成员, 2=嘉宾, 3=管理员, 4=群主)
  final int role;

  /// 是否是 @所有人 选项
  final bool isAllMention;

  const MentionCandidate({
    required this.userId,
    required this.displayName,
    this.avatar = '',
    this.role = 1,
    this.isAllMention = false,
  });

  /// 创建 @所有人 选项
  factory MentionCandidate.all() {
    return const MentionCandidate(
      userId: 'all',
      displayName: '所有人',
      isAllMention: true,
      role: 0,
    );
  }

  /// 从 GroupMemberModel 转换
  factory MentionCandidate.fromGroupMember(Map<String, dynamic> json) {
    final alias = json['alias'] as String? ?? '';
    final nickname = json['nickname'] as String? ?? '';
    return MentionCandidate(
      userId: json['user_id'] as String? ?? '',
      displayName: alias.isNotEmpty ? alias : nickname,
      avatar: json['avatar'] as String? ?? '',
      role: json['role'] as int? ?? 1,
    );
  }

  /// 检查是否是管理员或群主
  bool get isAdmin => role >= 3;

  /// 获取角色显示文本
  String get roleText => groupRoleLabel(role);

  /// 获取角色标签背景颜色
  Color roleBackgroundColor(ColorScheme colorScheme) =>
      groupRoleBgColor(role, colorScheme);

  /// 获取角色标签文字颜色
  Color roleTextColor(ColorScheme colorScheme) =>
      groupRoleFgColor(role, colorScheme);

  /// 是否显示角色标签（角色 >= 3 才显示）
  bool get showRoleBadge => role >= 3;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'avatar': avatar,
    'role': role,
    'is_all_mention': isAllMention,
  };
}

/// Group 角色工具函数（可跨组件复用）
///
/// Group 角色值: 1=成员, 2=嘉宾, 3=管理员, 4=群主

/// 获取角色显示文本
String groupRoleLabel(int role) {
  switch (role) {
    case 4:
      return '群主';
    case 3:
      return '管理员';
    case 2:
      return '嘉宾';
    default:
      return '';
  }
}

/// 获取角色标签背景颜色
Color groupRoleBgColor(int role, ColorScheme colorScheme) {
  switch (role) {
    case 4:
      return const Color(0xFFFF9800).withValues(alpha: 0.1);
    case 3:
      return colorScheme.primary.withValues(alpha: 0.1);
    default:
      return colorScheme.surface;
  }
}

/// 获取角色标签文字颜色
Color groupRoleFgColor(int role, ColorScheme colorScheme) {
  switch (role) {
    case 4:
      return const Color(0xFFFF9800);
    case 3:
      return colorScheme.primary;
    default:
      return colorScheme.onSurfaceVariant;
  }
}

/// @提及数据
///
/// 用于存储在消息中的 @提及信息
class MentionData {
  /// 被 @ 的用户ID列表
  final List<String> mentionIds;

  /// @提及文本范围列表 (start, end)
  final List<MentionRange> ranges;

  const MentionData({
    this.mentionIds = const [],
    this.ranges = const [],
  });

  /// 是否包含 @所有人
  bool get hasAllMention => mentionIds.contains('all');

  /// 添加一个 @提及
  MentionData addMention(String userId, int start, int end) {
    final newIds = List<String>.from(mentionIds);
    if (!newIds.contains(userId)) {
      newIds.add(userId);
    }
    final newRanges = List<MentionRange>.from(ranges)
      ..add(MentionRange(start: start, end: end, userId: userId));
    return MentionData(mentionIds: newIds, ranges: newRanges);
  }

  /// 移除指定范围的 @提及
  MentionData removeRange(int start, int end) {
    final newRanges = ranges.where((r) => !(r.start == start && r.end == end)).toList();
    final rangeUserIds = newRanges.map((r) => r.userId).toSet();
    final newIds = mentionIds.where((id) => rangeUserIds.contains(id)).toList();
    return MentionData(mentionIds: newIds, ranges: newRanges);
  }

  /// 根据光标位置移除 @提及
  MentionData removeByCursorPosition(int position) {
    final newRanges = ranges.where((r) => !(position > r.start && position <= r.end)).toList();
    final rangeUserIds = newRanges.map((r) => r.userId).toSet();
    final newIds = mentionIds.where((id) => rangeUserIds.contains(id)).toList();
    return MentionData(mentionIds: newIds, ranges: newRanges);
  }

  Map<String, dynamic> toJson() => {
    'mention_ids': mentionIds,
    'ranges': ranges.map((r) => r.toJson()).toList(),
  };

  factory MentionData.fromJson(Map<String, dynamic> json) {
    final mentionIds = (json['mention_ids'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    final ranges = (json['ranges'] as List<dynamic>?)
        ?.map((e) => MentionRange.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return MentionData(mentionIds: mentionIds, ranges: ranges);
  }
}

/// @提及文本范围
class MentionRange {
  /// 开始位置（包含 @ 符号）
  final int start;

  /// 结束位置
  final int end;

  /// 关联的用户ID
  final String userId;

  const MentionRange({
    required this.start,
    required this.end,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'user_id': userId,
  };

  factory MentionRange.fromJson(Map<String, dynamic> json) {
    return MentionRange(
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
      userId: json['user_id'] as String? ?? '',
    );
  }
}

/// @提及解析结果
class MentionParseResult {
  /// 解析后的纯文本
  final String text;

  /// 提取的 @提及数据
  final MentionData mentionData;

  const MentionParseResult({
    required this.text,
    required this.mentionData,
  });
}
