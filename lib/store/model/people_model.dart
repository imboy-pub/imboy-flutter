class PeopleModel {
  String id;
  String account;
  String nickname;
  String avatar;
  int gender;
  String region;
  String sign;
  double distance;
  String distanceUnit;
  bool? isFriend;
  String remark;
  int createdAt;


  int get createdAtLocal =>
      createdAt + DateTime.now().timeZoneOffset.inMilliseconds;

  PeopleModel({
    required this.id, // userId or other
    this.distance = -1,
    this.distanceUnit = 'm',
    required this.account,
    this.nickname = '',
    this.avatar = '',
    this.sign = '',
    this.gender = 0,
    this.region = '',
    this.isFriend,
    this.remark = '',
    this.createdAt = 0,
  });

  factory PeopleModel.fromJson(Map<String, dynamic> json) {
    var g = json["gender"] ?? 0;
    var dist = json["distance"] ?? 0.0;
    return PeopleModel(
      id: json["id"],
      account: json["account"] ?? '',
      nickname: json["nickname"],
      avatar: json["avatar"] ?? '',
      gender: g is String ? int.parse(g) : g,
      region: json["region"] ?? '',
      sign: json["sign"] ?? '',
      distance: dist is double ? dist : double.parse(dist.toString()),
      distanceUnit: json["unit"] ?? "m",
      isFriend: json['is_friend'],
      remark: json['remark'] ?? '',
      createdAt: json['created_at'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["id"] = id;
    data["nickname"] = nickname;
    data["avatar"] = avatar;
    data["account"] = account;
    data["gender"] = gender;
    data["region"] = region;
    data["sign"] = sign;
    data["distance"] = "$distance";
    data["unit"] = distanceUnit;
    data['is_friend'] = isFriend;
    data['remark'] = remark;
    data['created_at'] = createdAt;
    return data;
  }

  String get title {
    if (remark.isNotEmpty) {
      return remark;
    }
    if (nickname.isNotEmpty) {
      return nickname;
    }
    return account;
  }
}
