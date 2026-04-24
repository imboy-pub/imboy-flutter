/// @提及功能数据模型
///
/// 用于群聊中 @提及用户的数据结构
library;

import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'package:imboy/theme/default/app_colors.dart';

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

  /// 检查是否是管理员或群主（admin/owner/vice_owner）
  bool get isAdmin => isGroupAdmin(role);

  /// 获取角色显示文本
  String get roleText => groupRoleLabel(role);

  /// 获取角色标签背景颜色
  Color roleBackgroundColor(ColorScheme colorScheme) =>
      groupRoleBgColor(role, colorScheme);

  /// 获取角色标签文字颜色
  Color roleTextColor(ColorScheme colorScheme) =>
      groupRoleFgColor(role, colorScheme);

  /// 是否显示角色标签（admin/owner/vice_owner 才显示）
  bool get showRoleBadge => isGroupAdmin(role);

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

/// 获取角色显示文本（i18n：复用 t.groupOwner / t.groupAdmin / t.groupGuest）
String groupRoleLabel(int role) {
  switch (role) {
    case 4:
      return t.groupOwner;
    case 3:
      return t.groupAdmin;
    case 2:
      return t.groupGuest;
    default:
      return '';
  }
}

/// 获取角色标签背景颜色
/// DESIGN.md 双蓝策略：群主用 iosOrange 强调（区分品牌蓝）/ 管理员用 primary
Color groupRoleBgColor(int role, ColorScheme colorScheme) {
  switch (role) {
    case 4:
      return AppColors.iosOrange.withValues(alpha: 0.1);
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
      return AppColors.iosOrange;
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

/// @提及状态
///
/// 保存群成员候选列表、关键词过滤、当前用户角色等。
/// 放在 model 层是为了让其可被纯单元测试覆盖（不传递依赖到
/// SQLite / 文件选择器 等 data-layer 代码）。
class MentionState {
  /// 候选成员列表
  final List<MentionCandidate> candidates;

  /// 当前群组ID
  final String groupId;

  /// 是否显示 @所有人 选项
  final bool showAllMention;

  /// 当前用户在群中的角色
  final int currentUserRole;

  /// 搜索关键词
  final String keyword;

  /// 是否正在加载
  final bool isLoading;

  /// 用户ID到显示名称的映射
  final Map<String, String> userIdToName;

  /// 当前登录用户的 ID
  ///
  /// 用于在 [filteredCandidates] 中排除自己（C6：`@自己禁用`）。
  /// 为空字符串时不做排除，保持向后兼容。
  final String currentUserId;

  const MentionState({
    this.candidates = const [],
    this.groupId = '',
    this.showAllMention = false,
    this.currentUserRole = 1,
    this.keyword = '',
    this.isLoading = false,
    this.userIdToName = const {},
    this.currentUserId = '',
  });

  MentionState copyWith({
    List<MentionCandidate>? candidates,
    String? groupId,
    bool? showAllMention,
    int? currentUserRole,
    String? keyword,
    bool? isLoading,
    Map<String, String>? userIdToName,
    String? currentUserId,
  }) {
    return MentionState(
      candidates: candidates ?? this.candidates,
      groupId: groupId ?? this.groupId,
      showAllMention: showAllMention ?? this.showAllMention,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      keyword: keyword ?? this.keyword,
      isLoading: isLoading ?? this.isLoading,
      userIdToName: userIdToName ?? this.userIdToName,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  /// 当前用户是否是管理员（admin/owner/vice_owner）
  bool get isAdmin => isGroupAdmin(currentUserRole);

  /// 获取过滤后的候选列表
  ///
  /// 先排除当前用户（C6），再按关键词模糊匹配。
  List<MentionCandidate> get filteredCandidates {
    final base = currentUserId.isEmpty
        ? candidates
        : candidates.where((c) => c.userId != currentUserId).toList();
    if (keyword.isEmpty) {
      return base;
    }
    final lowered = keyword.toLowerCase();
    return base
        .where((c) => c.displayName.toLowerCase().contains(lowered))
        .toList();
  }
}

// `MentionParseResult` 已随 `MentionTextFormatter.parseMentions` 在 slice-B-2
// (refactor-cleaner) 一并移除 —— 曾是唯一消费者且该消费者本身为死代码。
// 消息气泡 @ 渲染现走 `mention_text_reducer.dart` → markdown 方案。
