import 'dart:convert';

class UserCollectModel {
  String userId;
  int kind;
  String kindId;
  String source;
  String remark;

  int updatedAt;
  int createdAt;

  Map<String, dynamic> info;

  UserCollectModel({
    required this.userId,
    required this.kind,
    required this.kindId,
    required this.source,
    required this.remark,
    required this.updatedAt,
    required this.createdAt,
    required this.info,
  });

  factory UserCollectModel.fromJson(Map<String, dynamic> json) {
    var info1 = json['info'] ?? '{}';
    try {
      if (info1 is String) {
        info1 = jsonDecode(info1);
      }
    } catch (e) {
      info1 = {};
    }
    return UserCollectModel(
      userId: json['user_id'],
      kind: json['kind'],
      kindId: json['kind_id'],
      source: json['source'] ?? '',
      remark: json['remark'] ?? '',
      updatedAt: json['updated_at'] ?? 0,
      createdAt: json['created_at'],
      info: info1,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['kind'] = kind;
    data['kind_id'] = kindId;
    data['source'] = source;
    data['remark'] = remark;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    data['info'] = info;
    return data;
  }
}
