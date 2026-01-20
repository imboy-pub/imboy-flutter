import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/helper/datetime.dart';

part 'group_announcement_provider.g.dart';

/// 群组公告数据模型
class AnnouncementModel {
  final String id;
  final String groupId;
  final String content;
  final String publisherId;
  final String publisherName;
  final int createdAt;
  final int? expiredAt;

  AnnouncementModel({
    required this.id,
    required this.groupId,
    required this.content,
    required this.publisherId,
    required this.publisherName,
    required this.createdAt,
    this.expiredAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      content: json['content'] ?? '',
      publisherId: json['publisher_id'] ?? '',
      publisherName: json['publisher_name'] ?? '',
      createdAt: json['created_at'] ?? 0,
      expiredAt: json['expired_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'content': content,
      'publisher_id': publisherId,
      'publisher_name': publisherName,
      'created_at': createdAt,
      'expired_at': expiredAt,
    };
  }
}

/// 群组公告状态
class GroupAnnouncementState {
  final List<AnnouncementModel> announcements;
  final bool isLoading;
  final bool hasMore;
  final int page;

  const GroupAnnouncementState({
    this.announcements = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
  });

  GroupAnnouncementState copyWith({
    List<AnnouncementModel>? announcements,
    bool? isLoading,
    bool? hasMore,
    int? page,
  }) {
    return GroupAnnouncementState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
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
        '/api/group/$groupId/announcements',
        queryParameters: {'page': currentPage, 'size': pageSize},
      );

      if (response.code == 0) {
        final payload = response.payload;
        final list = (payload['list'] as List)
            .map((e) => AnnouncementModel.fromJson(e))
            .toList();

        final updatedList = isRefresh
            ? list
            : [...state.announcements, ...list];

        final pagination = payload['pagination'];
        final hasMore = pagination['has_next'] ?? false;

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

  /// 下拉刷新
  Future<void> onRefresh() async {
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
      final response = await HttpClient.client.post(
        '/api/group/$groupId/announcement',
        data: {
          'content': content,
          if (expiredAt != null) 'expired_at': expiredAt,
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
      final response = await HttpClient.client.delete(
        '/api/group/$groupId/announcement/$announcementId',
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

  /// 格式化时间
  String formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    );
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
