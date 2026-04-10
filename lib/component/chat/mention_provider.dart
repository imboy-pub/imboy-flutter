/// @提及功能状态管理
///
/// 使用 Riverpod 管理 @提及功能的候选项列表和当前状态
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// @提及状态
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

  const MentionState({
    this.candidates = const [],
    this.groupId = '',
    this.showAllMention = false,
    this.currentUserRole = 1,
    this.keyword = '',
    this.isLoading = false,
    this.userIdToName = const {},
  });

  MentionState copyWith({
    List<MentionCandidate>? candidates,
    String? groupId,
    bool? showAllMention,
    int? currentUserRole,
    String? keyword,
    bool? isLoading,
    Map<String, String>? userIdToName,
  }) {
    return MentionState(
      candidates: candidates ?? this.candidates,
      groupId: groupId ?? this.groupId,
      showAllMention: showAllMention ?? this.showAllMention,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      keyword: keyword ?? this.keyword,
      isLoading: isLoading ?? this.isLoading,
      userIdToName: userIdToName ?? this.userIdToName,
    );
  }

  /// 当前用户是否是管理员
  bool get isAdmin => currentUserRole >= 3;

  /// 获取过滤后的候选列表
  List<MentionCandidate> get filteredCandidates {
    if (keyword.isEmpty) {
      return candidates;
    }
    return candidates.where((c) =>
      c.displayName.toLowerCase().contains(keyword.toLowerCase())
    ).toList();
  }
}

/// @提及状态 Notifier（使用 Riverpod 3.x Notifier）
class MentionNotifier extends Notifier<MentionState> {
  @override
  MentionState build() {
    return const MentionState();
  }

  /// 加载群成员列表
  Future<void> loadGroupMembers(String groupId) async {
    if (groupId.isEmpty) {
      state = const MentionState();
      return;
    }

    state = state.copyWith(isLoading: true, groupId: groupId);

    try {
      // 从本地数据库加载群成员
      final repo = GroupMemberRepo();
      final members = await repo.page(
        where: '${GroupMemberRepo.groupId} = ? AND ${GroupMemberRepo.status} = ?',
        whereArgs: [groupId, 1],
        orderBy: '${GroupMemberRepo.role} DESC, ${GroupMemberRepo.nickname} ASC',
        limit: 500, // 限制最大数量
      );

      // 转换为 MentionCandidate 列表
      final candidates = members.map((m) => MentionCandidate(
        userId: m.userId.toString(),
        displayName: m.alias.isNotEmpty ? m.alias : m.nickname,
        avatar: m.avatar,
        role: m.role,
      )).toList();

      // 查找当前用户的角色
      final currentUid = UserRepoLocal.to.currentUid;
      int currentUserRole = 1;
      final userIdToName = <String, String>{};

      for (final m in members) {
        userIdToName[m.userId.toString()] = m.alias.isNotEmpty ? m.alias : m.nickname;
        if (m.userId.toString() == currentUid) {
          currentUserRole = m.role;
        }
      }

      state = state.copyWith(
        candidates: candidates,
        currentUserRole: currentUserRole,
        showAllMention: currentUserRole >= 3, // 管理员和群主可以使用 @所有人
        isLoading: false,
        userIdToName: userIdToName,
      );
    } on Exception catch (e) {
      iPrint('loadGroupMembers failed: ${e.runtimeType}');
      state = state.copyWith(isLoading: false);
    }
  }

  /// 更新搜索关键词
  void updateKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  /// 清空状态
  void clear() {
    state = const MentionState();
  }

  /// 获取用户显示名称
  String? getUserDisplayName(String userId) {
    return state.userIdToName[userId];
  }

  /// 根据显示名称获取用户ID
  String? getUserIdByDisplayName(String displayName) {
    for (final entry in state.userIdToName.entries) {
      if (entry.value == displayName) {
        return entry.key;
      }
    }
    return null;
  }

  /// 检查用户是否可以使用 @所有人
  bool canMentionAll() {
    return state.isAdmin;
  }
}

/// @提及状态 Provider
final mentionNotifierProvider = NotifierProvider.autoDispose<MentionNotifier, MentionState>(
  MentionNotifier.new,
);

/// @提及数据管理器
///
/// 用于管理输入框中的 @提及数据
class MentionDataManager extends Notifier<MentionData> {
  @override
  MentionData build() {
    return const MentionData();
  }

  /// 添加一个 @提及
  void addMention(String userId, int start, int end) {
    state = state.addMention(userId, start, end);
  }

  /// 移除指定范围的 @提及
  void removeRange(int start, int end) {
    state = state.removeRange(start, end);
  }

  /// 根据光标位置移除 @提及
  void removeByCursorPosition(int position) {
    state = state.removeByCursorPosition(position);
  }

  /// 重置数据
  void reset() {
    state = const MentionData();
  }

  /// 设置完整的 @提及数据
  void setMentionData(MentionData data) {
    state = data;
  }

  /// 获取当前消息的 mentions 字段
  List<String> getMentions() {
    return state.mentionIds;
  }
}

/// @提及数据 Provider
final mentionDataManagerProvider = NotifierProvider.autoDispose<MentionDataManager, MentionData>(
  MentionDataManager.new,
);
