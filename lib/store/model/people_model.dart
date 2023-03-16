import 'package:imboy/config/const.dart';

class PeopleModel {
  String id;
  String account;
  String nickname;
  String avatar;
  int gender;
  String region;
  String sign;
  double distince;
  String distinceUnit;
  bool isFriend;

  PeopleModel({
    required this.id,
    this.distince = -1,
    this.distinceUnit = "m",
    required this.account,
    this.nickname = "",
    this.avatar = defAvatar,
    this.sign = "",
    this.gender = 0,
    this.region = "",
    this.isFriend = false,
  });

  factory PeopleModel.fromJson(Map<String, dynamic> json) {
    var g = json["gender"] ?? 0;
    return PeopleModel(
      id: json["id"],
      account: json["account"] ?? '',
      nickname: json["nickname"],
      avatar: json["avatar"] ?? '',
      gender: g is String ? int.parse(g) : g,
      region: json["region"] ?? '',
      sign: json["sign"] ?? '',
      distince: double.parse(json["distince"]),
      distinceUnit: json["unit"] ?? "m",
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
    data["distince"] = "$distince";
    data["unit"] = distinceUnit;
    return data;
  }
}
