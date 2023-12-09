class UserTagModel {
  String userId;
  int tagId;
  int scene;
  String name;
  String subtitle;
  int refererTime;
  int updatedAt;
  int createdAt;

  UserTagModel({
    required this.userId,
    required this.tagId,
    required this.scene,
    required this.name,
    required this.subtitle,
    required this.refererTime,
    required this.updatedAt,
    required this.createdAt,
  });

  factory UserTagModel.fromJson(Map<String, dynamic> data) {
    return UserTagModel(
      userId: data['user_id'],
      tagId: data['tag_id'] ?? (data['id'] ?? 0),
      scene: data['scene'] ?? 0,
      name: data['name'] ?? '',
      subtitle: data['subtitle'] ?? '',
      refererTime: data['referer_time'] ?? 0,
      updatedAt: data['updated_at'] ?? 0,
      createdAt: data['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['tag_id'] = tagId;
    data['userId'] = userId;
    data['scene'] = scene;
    data['name'] = name;
    data['subtitle'] = subtitle;
    data['referer_time'] = refererTime;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    return data;
  }
}
