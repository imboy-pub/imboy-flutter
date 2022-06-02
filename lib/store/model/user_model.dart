import 'package:get/get.dart';

///
class UserModel {
  String? uid;
  String? nickname;
  String? avatar;
  String? account;
  String? gender;
  String? area;
  int? role;
  String? token;
  String? refreshtoken;
  String? sign;

  UserModel({
    this.uid,
    this.nickname,
    this.avatar,
    this.account,
    this.gender,
    this.area,
    this.role,
    this.token,
    this.refreshtoken,
    this.sign,
  });

  String get genderTitle {
    if (this.gender == "1") {
      return "男".tr;
    } else if (this.gender == "2") {
      return "女".tr;
    } else if (this.gender == "3") {
      return "保密".tr;
    }
    return "未知";
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return new UserModel(
      uid: json["uid"],
      nickname: json["nickname"],
      avatar: json["avatar"] ?? '',
      account: json["account"],
      role: json["role"]?.toInt(),
      gender: json["gender"]?.toString(),
      area: json["area"]?.toString(),
      token: json["token"],
      refreshtoken: json["refreshtoken"],
      sign: json["sign"],
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
    data["area"] = area;
    data["token"] = token;
    data["refreshtoken"] = refreshtoken;
    data["sign"] = sign;
    return data;
  }
}
