import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

///
class UserModel {
  String uid;
  String nickname;
  String avatar;
  String account;
  String gender;
  String region;
  int? role;
  String? token;
  String? refreshtoken;
  String sign;

  UserModel({
    required this.uid,
    this.nickname = "",
    this.avatar = defAvatar,
    required this.account,
    this.gender = "0",
    this.region = "",
    this.role,
    this.token,
    this.refreshtoken,
    this.sign = "",
  });

  String get genderTitle {
    if (gender == "1") {
      return "男".tr;
    } else if (gender == "2") {
      return "女".tr;
    } else if (gender == "3") {
      return "保密".tr;
    }
    return "未知".tr;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json["uid"],
      nickname: json["nickname"],
      avatar: json["avatar"] ?? '',
      account: json["account"],
      role: json["role"]?.toInt(),
      gender: json["gender"].toString(),
      region: json["region"] ?? '',
      token: json["token"] ?? '',
      refreshtoken: json["refreshtoken"] ?? '',
      sign: json["sign"] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data["uid"] = uid;
    data["nickname"] = nickname;
    data["avatar"] = avatar;
    data["account"] = account;
    data["role"] = role;
    data["gender"] = gender;
    data["region"] = region;
    data["token"] = token;
    data["refreshtoken"] = refreshtoken;
    data["sign"] = sign;
    return data;
  }
}
