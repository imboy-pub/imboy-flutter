part of 'group_announcement_logic.dart';

class GroupAnnouncementState {
  // 状态属性
  final RxList<AnnouncementModel> announcements = <AnnouncementModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;

  // 构造函数
  GroupAnnouncementState();
}

// 群组公告数据模型（临时定义，实际应该放在 store/model 中）
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
