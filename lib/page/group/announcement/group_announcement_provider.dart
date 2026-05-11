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

  /// 最近一次 load/refresh/loadMore 失败的错误提示（null = 无错误 / 已消费）。
  /// 仅对 UI 暴露"列表加载失败"语义，不包含 publish/delete 等副作用失败
  /// （后者由 UI 侧按 bool 返回值直接 toast）。对齐 A-2 moment_notify 模式。
  final String? errorMessage;

  const GroupAnnouncementState({
    this.announcements = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.currentUserRole = 0,
    this.errorMessage,
  });

  /// copyWith 语义：`errorMessage` 默认保留旧值（传 null 不覆盖，与其他字段一致）；
  /// 调用方若要显式清错，传 `clearError: true`。
  GroupAnnouncementState copyWith({
    List<AnnouncementModel>? announcements,
    bool? isLoading,
    bool? hasMore,
    int? page,
    int? currentUserRole,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupAnnouncementState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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

  /// 消费完 errorMessage 后清除（配合 UI ref.listen 消费后调用）。
  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  /// 加载公告列表
  Future<void> loadAnnouncements({bool isRefresh = false}) async {
    final currentPage = isRefresh ? 1 : state.page;

    if (isRefresh) {
      state = state.copyWith(
        page: 1,
        hasMore: true,
        isLoading: true,
        clearError: true,
      );
    }

    if (!state.hasMore) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // B-6-1 修复：后端无 /v1/group/notice/list 路由，正确路径是
      // /v1/group_notice/page（imboy_router.erl:355；handler page/3 GET）。
      // QS: gid/page/size；响应 payload: {list,total,page,size}。
      final response = await HttpClient.client.get(
        '/v1/group_notice/page',
        queryParameters: {
          'gid': groupId,
          'page': currentPage,
          'size': pageSize,
        },
      );

      if (response.code == 0) {
        final payload = response.payload ?? <String, dynamic>{};
        final rawList = payload['items'] ?? payload['list'] ?? <dynamic>[];
        final list = (rawList is List ? rawList : const <Map>[])
            .whereType<Map>()
            .map(
              (e) => AnnouncementModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();

        // #28 Gap #1 修复：后端 SELECT 未带 publisher_name，fromJson 已将
        // publisherName 回退到 publisherId（TSID 数字串）。此处再通过本地
        // 群成员表异步补齐昵称；发布者必是群成员，故查本地 SQLite 免走 N+1 网络。
        final resolvedList = await resolveAnnouncementNicknames(list, (
          publisherId,
        ) async {
          final member = await GroupMemberRepo().findByUserId(
            groupId,
            publisherId,
          );
          return member?.nickname;
        });

        final updatedList = isRefresh
            ? resolvedList
            : [...state.announcements, ...resolvedList];

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
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'load_failed: code=${response.code}',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'load_failed: $e');
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
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    );
    return DateTimeHelper.dateTimeFmt(dateTime);
  }
}
