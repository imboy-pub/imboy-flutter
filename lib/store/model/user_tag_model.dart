import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class UserTagModel {
  int userId;
  int tagId;
  int scene;
  String name;
  String subtitle;

  /// 该标签下的引用/成员**计数**（非时间戳——UI 以 `(count)` 形式展示，
  /// 写入方直接赋 `selectedContact.length`）。R21-B：按普通整数解析，
  /// **排除在时间合同外**——不得进任何时间 parser（旧行为
  /// `parseTimestamp` 在 null/非数字时会回填当前时间，属 now 污染）。
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
      // 计数语义：普通整数解析（缺失 0），不回填 now、不做单位换算。
      refererTime: parseModelInt(data['referer_time']),
      // 本地 DB 行时间（legacy parseTimestamp，量级启发式存量——渐进迁移
      // 属 R21-B 后续批次，本波只切 referer_time）。
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
