import 'dart:async' show unawaited;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/group/announcement/announcement_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

export 'package:imboy/page/group/announcement/announcement_model.dart'
    show AnnouncementModel;
export 'package:imboy/page/group/announcement/announcement_permission_rules.dart'
    show canManageAnnouncement;

part 'group_announcement_provider.g.dart';

/// 群组公告状态
class GroupAnnouncementState {
  final List<AnnouncementModel> announcements;
  final bool isLoading;
  final bool hasMore;
  final int page;
  /// 当前登录用户在本群的角色（0 = 未加载 / 不在群）。
  /// 由 [GroupAnnouncementNotifier._loadCurrentRole] 异步填充。
  final int currentUserRole;

  const GroupAnnouncementState({
    this.announcements = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.currentUserRole = 0,
  });

  GroupAnnouncementState copyWith({
    List<AnnouncementModel>? announcements,
    bool? isLoading,
    bool? hasMore,
    int? page,
    int? currentUserRole,
  }) {
    return GroupAnnouncementState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      currentUserRole: currentUserRole ?? this.currentUserRole,
    );
  }
}

/// 群组公告 Notifier
@Riverpod(keepAlive: false)
class GroupAnnouncementNotifier extends _$GroupAnnouncementNotifier {
  final int pageSize = 20;

  @override
  GroupAnnouncementState build(String groupId) {
    return const GroupAnnouncementState();
  }

  /// 加载公告列表
  Future<void> loadAnnouncements({bool isRefresh = false}) async {
    final currentPage = isRefresh ? 1 : state.page;

    if (isRefresh) {
      state = state.copyWith(page: 1, hasMore: true, isLoading: true);
    }

    if (!state.hasMore) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final response = await HttpClient.client.get(
        '/v1/group/notice/list',
        queryParameters: {
          'gid': groupId,
          'page': currentPage,
          'size': pageSize,
        },
      );

      if (response.code == 0) {
        final payload = response.payload ?? <String, dynamic>{};
        final rawList = payload['items'] ?? payload['list'] ?? [];
        final list = (rawList is List ? rawList : const [])
            .whereType<Map>()
            .map(
              (e) => AnnouncementModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();

        final updatedList = isRefresh
            ? list
            : [...state.announcements, ...list];

        final total = payload['total'] is int ? payload['total'] as int : null;
        final size = payload['size'] is int ? payload['size'] as int : pageSize;
        final hasMore = total != null
            ? currentPage * size < total
            : list.length >= pageSize;

        state = state.copyWith(
          announcements: updatedList,
          hasMore: hasMore,
          page: currentPage + 1,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
        // 可以考虑添加错误状态
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      // 可以考虑添加错误状态
    }
  }

  /// 异步加载当前用户在本群的角色，写入 state.currentUserRole。
  /// 失败时静默回退，保持 0（安全默认：无权限）。
  Future<void> _loadCurrentRole() async {
    try {
      final uid = UserRepoLocal.to.currentUid;
      final member = await GroupMemberRepo().findByUserId(groupId, uid);
      if (member != null) {
        state = state.copyWith(currentUserRole: member.role);
      }
    } catch (_) {
      // 静默失败：保持 currentUserRole=0，UI 不显示管理操作
    }
  }

  /// 下拉刷新
  Future<void> onRefresh() async {
    // 角色加载与数据加载并行，互不阻塞
    unawaited(_loadCurrentRole());
    await loadAnnouncements(isRefresh: true);
  }

  /// 加载更多
  Future<void> onLoadMore() async {
    if (!state.isLoading && state.hasMore) {
      await loadAnnouncements();
    }
  }

  /// 发布公告
  Future<bool> publishAnnouncement(String content, {int? expiredAt}) async {
    if (content.trim().isEmpty) {
      return false;
    }

    try {
      final expirationMillis =
          expiredAt ??
          DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch;
      final response = await HttpClient.client.post(
        '/v1/group_notice/add',
        data: {
          'gid': groupId,
          'title': buildNoticeTitle(content),
          'body': content,
          'status': 1,
          'expired_at': toRfc3339(expirationMillis),
        },
      );

      if (response.code == 0) {
        // 刷新列表
        await loadAnnouncements(isRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 删除公告
  Future<bool> deleteAnnouncement(String announcementId) async {
    try {
      final response = await HttpClient.client.post(
        '/v1/group_notice/delete',
        data: {'notice_id': announcementId},
      );

      if (response.code == 0) {
        // 从列表中移除
        final updatedList = state.announcements
            .where((a) => a.id != announcementId)
            .toList();
        state = state.copyWith(announcements: updatedList);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 格式化时间（使用多语言相对时间格式化）
  String formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return DateTimeHelper.dateTimeFmt(dateTime);
  }
}
