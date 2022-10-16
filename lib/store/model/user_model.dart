import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

class UserModel {
  String uid;
  String account;
  String nickname;
  String avatar;
  int gender;
  String region;
  int? role;
  String sign;

  UserModel({
    required this.uid,
    required this.account,
    this.nickname = "",
    this.avatar = defAvatar,
    this.gender = 0,
    this.region = "",
    this.role,
    this.sign = "",
  });

  String get genderTitle {
    if (gender == 1) {
      return "男".tr;
    } else if (gender == 2) {
      return "女".tr;
    } else if (gender == 3) {
      return "保密".tr;
    }
    return "未知".tr;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var g = json["gender"] ?? 0;
    return UserModel(
      uid: json["uid"],
      account: json["account"] ?? '',
      nickname: json["nickname"],
      avatar: json["avatar"] ?? '',
      role: json["role"]?.toInt(),
      gender: g is String ? int.parse(g) : g,
      region: json["region"] ?? '',
      sign: json["sign"] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["uid"] = uid;
    data["nickname"] = nickname;
    data["avatar"] = avatar;
    data["account"] = account;
    data["role"] = role;
    data["gender"] = gender;
    data["region"] = region;
    data["sign"] = sign;
    return data;
  }
}
