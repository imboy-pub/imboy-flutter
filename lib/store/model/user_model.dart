import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class UserSettingModel {
  // allow_search 用户允许被搜索 1 是  2 否
  bool allowSearch;
  // 附近的人可见
  bool peopleNearbyVisible;

  // 聊天状态 hide online offline
  String chatState;

  // 字体大小设置
  String fontSize;

  // 是否启用"可视阈值已读"（隐私开关）
  bool enableVisibilityRead;
  // 可视阈值（0~1），消息可见比例达到该阈值后开始计时
  double visibilityReadFraction;
  // 可视阈值已读的停留时长（毫秒）
  int visibilityReadDelayMs;

  // 是否显示在线状态
  bool showOnlineStatus;
  // 是否允许通过手机号添加
  bool allowAddByPhone;
  // 是否允许通过二维码添加
  bool allowAddByQR;

  UserSettingModel({
    required this.allowSearch,
    required this.peopleNearbyVisible,
    this.chatState = '',
    this.fontSize = 'normal',
    this.enableVisibilityRead = true,
    this.visibilityReadFraction = 0.6,
    this.visibilityReadDelayMs = 400,
    this.showOnlineStatus = true,
    this.allowAddByPhone = true,
    this.allowAddByQR = true,
  });

  factory UserSettingModel.fromJson(Map<String, dynamic> json) {
    // 注意：不要使用 ?? true 作为默认值，这会导致用户关闭开关后被自动打开
    // 使用显式解析，支持 bool/int/string 并且避免运行时类型异常
    return UserSettingModel(
      // allow_search 后端值域 1=开 2=关（非 0/1 bool）：
      // parseModelBool 的 `num != 0` 会把 2(关) 误解析为 true(开)（QA#18）
      allowSearch: json['allow_search'] is num
          ? json['allow_search'] == 1
          : parseModelBool(json['allow_search']),
      peopleNearbyVisible: parseModelBool(json['people_nearby_visible']),
      chatState: parseModelString(json['chat_state'], defaultValue: 'hide'),
      fontSize: parseModelString(json['font_size'], defaultValue: 'normal'),
      enableVisibilityRead: parseModelBool(
        json['enable_visibility_read'],
        defaultValue: true,
      ),
      visibilityReadFraction: parseModelDouble(
        json['visibility_read_fraction'],
        defaultValue: 0.6,
      ),
      visibilityReadDelayMs: parseModelInt(
        json['visibility_read_delay_ms'],
        defaultValue: 400,
      ),
      // 三个开关后端语义=缺省允许(true)；仅缺 key 时取默认，
      // 已存 false 仍解析为 false（不违反上方"勿 ?? true"警示）
      showOnlineStatus: parseModelBool(
        json['show_online_status'],
        defaultValue: true,
      ),
      allowAddByPhone: parseModelBool(
        json['allow_add_by_phone'],
        defaultValue: true,
      ),
      allowAddByQR: parseModelBool(json['allow_add_by_qr'], defaultValue: true),
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
      'show_online_status': showOnlineStatus,
      'allow_add_by_phone': allowAddByPhone,
      'allow_add_by_qr': allowAddByQR,
    };
  }
}

class UserModel {
  /// 用户 ID（后端为 bigint，此处以 String 承载以兼容 flutter_chat_ui 的 UserID 契约；
  /// parseModelString 会在 fromJson 阶段将数字安全转为字符串）
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

  // 扩展信息
  String birthday;
  String profession;
  String school;
  String interests;

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
    this.birthday = '',
    this.profession = '',
    this.school = '',
    this.interests = '',
  });

  String get genderTitle {
    if (gender == 1) {
      return t.main.male;
    } else if (gender == 2) {
      return t.main.female;
    } else if (gender == 3) {
      return t.main.keepSecret;
    }
    return t.common.unknown;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'];
    return UserModel(
      uid: parseModelString(json['user_id'] ?? json['uid'] ?? json['id']),
      account: parseModelString(json['account']),
      email: parseModelString(json['email']),
      mobile: parseModelString(json['mobile']),
      nickname: parseModelString(json['nickname']),
      avatar: parseModelString(json['avatar']),
      role: roleValue == null ? null : parseModelInt(roleValue),
      gender: parseModelInt(json['gender']),
      region: parseModelString(json['region']),
      sign: parseModelString(json['sign']),
      setting: parseModelJsonMap(json['setting']) ?? <String, dynamic>{},
      birthday: parseModelString(json['birthday']),
      profession: parseModelString(json['profession']),
      school: parseModelString(json['school']),
      interests: parseModelString(json['interests']),
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
    data["birthday"] = birthday;
    data["profession"] = profession;
    data["school"] = school;
    data["interests"] = interests;
    return data;
  }

  /// toJson 是 toMap 的别名，方便调用
  Map<String, dynamic> toJson() => toMap();
}
