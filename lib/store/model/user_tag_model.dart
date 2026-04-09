import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class UserTagModel {
  int userId;
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
      userId: parseModelInt(data['user_id']),
      tagId: parseModelInt(data['tag_id'] ?? data['id']),
      scene: parseModelInt(data['scene']),
      name: parseModelString(data['name']),
      subtitle: parseModelString(data['subtitle']),
      refererTime: DateTimeHelper.parseTimestamp(data['referer_time']),
      updatedAt: DateTimeHelper.parseTimestamp(data['updated_at']),
      createdAt: DateTimeHelper.parseTimestamp(data['created_at']),
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
