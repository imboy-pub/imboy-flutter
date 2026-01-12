import 'package:imboy/i18n/strings.g.dart';

class UserSettingModel {
  // allow_search 用户允许被搜索 1 是  2 否
  bool allowSearch;
  // 附近的人可见
  bool peopleNearbyVisible;

  // 聊天状态 hide online offline
  String chatState;
  
  // 字体大小设置
  String fontSize;

  // 是否启用“可视阈值已读”（隐私开关）
  bool enableVisibilityRead;
  // 可视阈值（0~1），消息可见比例达到该阈值后开始计时
  double visibilityReadFraction;
  // 可视阈值已读的停留时长（毫秒）
  int visibilityReadDelayMs;

  UserSettingModel({
    required this.allowSearch,
    required this.peopleNearbyVisible,
    this.chatState = '',
    this.fontSize = 'normal',
    this.enableVisibilityRead = true,
    this.visibilityReadFraction = 0.6,
    this.visibilityReadDelayMs = 400,
  });

  factory UserSettingModel.fromJson(Map<String, dynamic> json) {
    // 解析数值工具
    double toDouble(dynamic v, double dft) {
      if (v == null) return dft;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? dft;
      return dft;
    }
    int toInt(dynamic v, int dft) {
      if (v == null) return dft;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? dft;
      return dft;
    }
    return UserSettingModel(
      allowSearch: json['allow_search'] ?? true,
      peopleNearbyVisible: json['people_nearby_visible'] ?? false,
      chatState: json['chat_state'] ?? 'hide',
      fontSize: json['font_size'] ?? 'normal',
      enableVisibilityRead: json['enable_visibility_read'] ?? true,
      visibilityReadFraction: toDouble(json['visibility_read_fraction'], 0.6),
      visibilityReadDelayMs: toInt(json['visibility_read_delay_ms'], 400),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allow_search': allowSearch,
      'people_nearby_visible': peopleNearbyVisible,
      'chat_state': chatState,
      'font_size': fontSize,
      'enable_visibility_read': enableVisibilityRead,
      'visibility_read_fraction': visibilityReadFraction,
      'visibility_read_delay_ms': visibilityReadDelayMs,
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
      return t.male;
    } else if (gender == 2) {
      return t.female;
    } else if (gender == 3) {
      return t.keepSecret;
    }
    return t.unknown;
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
