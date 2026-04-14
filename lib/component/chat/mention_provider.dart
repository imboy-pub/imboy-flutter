/// @提及功能状态管理
///
/// 使用 Riverpod 管理 @提及功能的候选项列表和当前状态
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/component/chat/mention_ranking.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/mention_frequency_repo.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

/// @提及状态 Notifier（使用 Riverpod 3.x Notifier）
///
/// 注：`MentionState` 已上移至 [mention_model.dart] 以便纯单元测试。
class MentionNotifier extends Notifier<MentionState> {
  /// C2 缓存 TTL（D13）：5 分钟内复用同群的发言频次聚合结果。
  static const int _freqCacheTtlMs = 5 * 60 * 1000;

  /// C2 时间窗口（D2）：近 30 天。
  static const int _freqWindowMs = 30 * 24 * 60 * 60 * 1000;

  /// 按 conversation_uk3 缓存聚合结果；Notifier 生命周期内有效。
  final Map<String, ({int expiresAt, Map<String, int> counts})> _freqCache = {};

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
      final rawCandidates = members.map((m) => MentionCandidate(
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

      // C2：按近 30 天发言频率重排候选（失败静默退化为原排序）
      final ranked = await _rankByFrequency(
        rawCandidates,
        groupId: groupId,
        currentUid: currentUid,
      );

      state = state.copyWith(
        candidates: ranked,
        currentUserRole: currentUserRole,
        showAllMention: currentUserRole >= 3, // 管理员和群主可以使用 @所有人
        isLoading: false,
        userIdToName: userIdToName,
        currentUserId: currentUid, // C6: 用于 filteredCandidates 排除自己
      );
    } on Exception catch (e) {
      iPrint('loadGroupMembers failed: ${e.runtimeType}');
      state = state.copyWith(isLoading: false);
    }
  }

  /// C2：按近 30 天发言频次重排候选列表。失败/无数据时原样返回。
  Future<List<MentionCandidate>> _rankByFrequency(
    List<MentionCandidate> candidates, {
    required String groupId,
    required String currentUid,
  }) async {
    try {
      final uk3 = ConversationUk3Generator.generateSmart(
        type: 'C2G',
        currentUserId: currentUid,
        peerId: groupId,
      );
      final counts = await _getFreqCounts(uk3);
      if (counts.isEmpty) return candidates;
      return MentionRanking.sortByFrequency(candidates, counts);
    } on Exception catch (e) {
      iPrint('mention frequency ranking failed: ${e.runtimeType}');
      return candidates;
    }
  }

  /// 查询群聊消息频次，带 TTL 缓存（D13）。
  Future<Map<String, int>> _getFreqCounts(String conversationUk3) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _freqCache[conversationUk3];
    if (cached != null && cached.expiresAt > now) {
      return cached.counts;
    }
    final db = await SqliteService.to.db;
    if (db == null) return const {};
    final counts = await MentionFrequencyRepo.queryWith(
      db,
      conversationUk3: conversationUk3,
      sinceMs: now - _freqWindowMs,
    );
    _freqCache[conversationUk3] =
        (expiresAt: now + _freqCacheTtlMs, counts: counts);
    return counts;
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
