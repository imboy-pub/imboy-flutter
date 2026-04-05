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

  static int _parseTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is int) {
      if (value > 1000000000000) return value;
      if (value > 1000000000) return value * 1000;
      return value;
    }
    if (value is String) {
      final intVal = int.tryParse(value);
      if (intVal != null) {
        if (intVal > 1000000000000) return intVal;
        if (intVal > 1000000000) return intVal * 1000;
        return intVal;
      }
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        return dt.millisecondsSinceEpoch;
      }
    }
    return 0;
  }

  static int? _parseOptionalTimestamp(dynamic value) {
    if (value == null) return null;
    final parsed = _parseTimestamp(value);
    return parsed > 0 ? parsed : null;
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final publisherId = (json['publisher_id'] ?? json['user_id'] ?? '')
        .toString();
    final publisherName = (json['publisher_name'] ?? json['creator_name'] ?? '')
        .toString();

    return AnnouncementModel(
      id: (json['id'] ?? json['notice_id'] ?? '').toString(),
      groupId: (json['group_id'] ?? '').toString(),
      content: (json['content'] ?? json['body'] ?? '').toString(),
      publisherId: publisherId,
      publisherName: publisherName.isEmpty ? publisherId : publisherName,
      createdAt: _parseTimestamp(json['created_at']),
      expiredAt: _parseOptionalTimestamp(json['expired_at']),
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

  String _buildNoticeTitle(String content) {
    final firstLine = content.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return '群公告';
    if (firstLine.length <= 20) return firstLine;
    return '${firstLine.substring(0, 20)}...';
  }

  String _toRfc3339(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: false,
    ).toUtc().toIso8601String();
  }

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
      final expirationMillis =
          expiredAt ??
          DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch;
      final response = await HttpClient.client.post(
        '/v1/group_notice/add',
        data: {
          'gid': groupId,
          'title': _buildNoticeTitle(content),
          'body': content,
          'status': 1,
          'expired_at': _toRfc3339(expirationMillis),
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
