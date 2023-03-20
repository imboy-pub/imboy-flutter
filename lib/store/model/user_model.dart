import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

class UserSettingModel {
  // 附近的人可见
  bool peopleNearbyVisible;

  // 聊天状态 hide online offline
  String chatState; //

  UserSettingModel({
    required this.peopleNearbyVisible,
    this.chatState = '',
  });

  factory UserSettingModel.fromJson(Map<String, dynamic> json) {
    return UserSettingModel(
      peopleNearbyVisible: json['people_nearby_visible'] ?? false,
      chatState: json['chat_state'] ?? 'hide',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'people_nearby_visible': peopleNearbyVisible,
      'chat_state': chatState,
    };
  }
}

class UserModel {
  String uid;
  String account;
  String nickname;
  String avatar;
  int gender;
  String region;
  int? role;
  String sign;
  Map<String, dynamic>? setting;

  UserModel({
    required this.uid,
    required this.account,
    this.nickname = "",
    this.avatar = defAvatar,
    this.gender = 0,
    this.region = "",
    this.role,
    this.sign = "",
    this.setting,
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
      setting: json["setting"] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["uid"] = uid;
    data["nickname"] = nickname;
    data["avatar"] = avatar;
    data["account"] = account;
    data["role"] = role;
    data["gender"] = gender;
    data["region"] = region;
    data["sign"] = sign;
    data["setting"] = setting;
    return data;
  }
}
