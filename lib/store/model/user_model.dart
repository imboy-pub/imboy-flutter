import 'package:get/get.dart';

class UserSettingModel {
  // allow_search 用户允许被搜索 1 是  2 否
  bool allowSearch;
  // 附近的人可见
  bool peopleNearbyVisible;

  // 聊天状态 hide online offline
  String chatState; //

  UserSettingModel({
    required this.allowSearch,
    required this.peopleNearbyVisible,
    this.chatState = '',
  });

  factory UserSettingModel.fromJson(Map<String, dynamic> json) {
    return UserSettingModel(
      allowSearch: json['allow_search'] ?? true,
      peopleNearbyVisible: json['people_nearby_visible'] ?? false,
      chatState: json['chat_state'] ?? 'hide',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allow_search': allowSearch,
      'people_nearby_visible': peopleNearbyVisible,
      'chat_state': chatState,
    };
  }
}

class UserModel {
  String uid;
  String account;
  String nickname;
  String email;
  String mobile;
  String avatar;
  int gender;
  String region;
  int? role;
  String sign;
  Map<String, dynamic>? setting;

  UserModel({
    required this.uid,
    required this.account,
    this.email = '',
    this.mobile = '',
    this.nickname = '',
    this.avatar = '',
    this.gender = 0,
    this.region = "",
    this.role,
    this.sign = '',
    this.setting,
  });

  String get genderTitle {
    if (gender == 1) {
      return 'male'.tr;
    } else if (gender == 2) {
      return 'female'.tr;
    } else if (gender == 3) {
      return "keep_secret".tr;
    }
    return 'unknown'.tr;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var g = json["gender"] ?? 0;
    return UserModel(
      uid: json["uid"] ?? json["id"],
      account: json["account"] ?? '',
      email: json["email"] ?? '',
      mobile: json["mobile"] ?? '',
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
    data["email"] = email;
    data["mobile"] = mobile;
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
