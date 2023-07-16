import 'dart:convert';

class UserCollectModel {
  String userId;
  // Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  int kind;
  String kindId;
  String source;
  String remark;
  // 朋友标签，半角逗号分割，单个表情不超过14字符
  String tag;

  int updatedAt;
  int createdAt;

  Map<String, dynamic> info;

  UserCollectModel({
    required this.userId,
    required this.kind,
    required this.kindId,
    required this.source,
    required this.remark,
    required this.tag,
    required this.updatedAt,
    required this.createdAt,
    required this.info,
  });

  factory UserCollectModel.fromJson(Map<String, dynamic> data) {
    var info1 = data['info'] ?? {};
    try {
      if (info1 is String) {
        info1 = json.decode(info1);
      }
    } catch (e) {
      info1 = {};
    }
    return UserCollectModel(
      userId: data['user_id'],
      kind: data['kind'],
      kindId: data['kind_id'],
      source: data['source'] ?? '',
      remark: data['remark'] ?? '',
      tag: data['tag'] ?? '',
      updatedAt: data['updated_at'] ?? 0,
      createdAt: data['created_at'],
      info: Map<String, dynamic>.from(info1),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['kind'] = kind;
    data['kind_id'] = kindId;
    data['source'] = source;
    data['remark'] = remark;
    data['tag'] = tag;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    data['info'] = info;
    return data;
  }
}
