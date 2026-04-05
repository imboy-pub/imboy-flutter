class LiveRoomModel {
  /// 后端 hashids 编码后的 ID（字符串）
  final String id;
  final String userId;
  final String title;
  final String cover;
  final String streamKey;
  final int status; // 0=idle, 1=live, 2=ended
  final int viewerCount;
  final int tagId;
  final int scene;
  final int updatedAt;
  final int createdAt;

  const LiveRoomModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.cover,
    required this.streamKey,
    required this.status,
    required this.viewerCount,
    required this.tagId,
    required this.scene,
    required this.updatedAt,
    required this.createdAt,
  });

  factory LiveRoomModel.fromJson(Map<String, dynamic> data) {
    return LiveRoomModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      cover: data['cover']?.toString() ?? '',
      streamKey: data['stream_key']?.toString() ?? '',
      status: (data['status'] as num?)?.toInt() ?? 0,
      viewerCount: (data['viewer_count'] as num?)?.toInt() ?? 0,
      tagId: (data['tag_id'] as num?)?.toInt() ?? 0,
      scene: (data['scene'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updated_at'] as num?)?.toInt() ?? 0,
      createdAt: (data['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'cover': cover,
      'stream_key': streamKey,
      'status': status,
      'viewer_count': viewerCount,
      'tag_id': tagId,
      'scene': scene,
      'updated_at': updatedAt,
      'created_at': createdAt,
    };
  }

  bool get isLive => status == 1;
}
