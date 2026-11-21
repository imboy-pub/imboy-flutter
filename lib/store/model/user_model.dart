import 'dart:convert';

import 'package:geo_regions/geo_regions.dart';
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
    this.showOnlineStatus = false,
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
      // 在线状态默认隐藏；仅缺 key 时取默认，已存 false 仍解析为 false。
      showOnlineStatus: parseModelBool(
        json['show_online_status'],
        defaultValue: false,
      ),
      // 其他两个开关后端语义=缺省允许(true)；仅缺 key 时取默认，
      // 已存 false 仍解析为 false（不违反上方"勿 ?? true"警示）
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

  /// 个人资料封面背景图 object_key（scope=public，与 avatar 同机制）。
  String background;
  int gender;
  String region;

  /// 结构化地区身份（geo_regions 协议 §8，后端 user_agg 的 regionSelection）。
  ///
  /// 后端未提供、数据无效或协议版本不支持时为 null：不得假定该字段存在，
  /// [region] 旧字符串保持唯一权威展示（不猜测映射、不丢资料）。
  GeoSelection? regionSelection;

  /// 后端读侧状态机原值（user_agg:region_selection_status/2）：
  /// `resolved` / `empty` / `unresolved`；空串表示后端未提供该字段。
  ///
  /// 结构化数据存在但无法按当前协议解析时标 `unresolved`（保留旧字符串
  /// 原值并显式标记，等价后端对无效 selection 的读侧行为）。
  String regionSelectionStatus;
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
    this.background = '',
    this.gender = 0,
    this.region = "",
    this.regionSelection,
    this.regionSelectionStatus = '',
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
    final rawRegionSelection = json['regionSelection'];
    final parsedRegionSelection = _parseRegionSelection(rawRegionSelection);
    final selectionStatus = parseModelString(json['regionSelectionStatus']);
    return UserModel(
      uid: parseModelString(json['user_id'] ?? json['uid'] ?? json['id']),
      account: parseModelString(json['account']),
      email: parseModelString(json['email']),
      mobile: parseModelString(json['mobile']),
      nickname: parseModelString(json['nickname']),
      avatar: parseModelString(json['avatar']),
      background: parseModelString(json['background']),
      role: roleValue == null ? null : parseModelInt(roleValue),
      gender: parseModelInt(json['gender']),
      region: parseModelString(json['region']),
      regionSelection: parsedRegionSelection,
      // 保留后端状态原值；仅当结构化数据存在但无法按当前协议解析时
      // 标 unresolved（旧字符串原值不动，不猜测映射、不丢资料）。
      regionSelectionStatus: selectionStatus.isNotEmpty
          ? selectionStatus
          : (rawRegionSelection != null && parsedRegionSelection == null
                ? 'unresolved'
                : ''),
      sign: parseModelString(json['sign']),
      setting: parseModelJsonMap(json['setting']) ?? <String, dynamic>{},
      birthday: parseModelString(json['birthday']),
      profession: parseModelString(json['profession']),
      school: parseModelString(json['school']),
      interests: parseModelString(json['interests']),
    );
  }

  /// 结构化地区身份解析：接受协议 JSON map，或旧缓存中的 JSON 字符串
  /// （后端 decode_region_selection/1 两种形态都可能出现）。
  ///
  /// 无效/不支持版本 → null：不猜测、不崩溃、不丢资料，
  /// 由 [regionSelectionStatus] 标 unresolved。
  static GeoSelection? _parseRegionSelection(dynamic raw) {
    if (raw == null) return null;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      return parseSelection(Map<String, dynamic>.from(decoded));
    } on Exception {
      return null;
    } on Error {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["uid"] = uid;
    data["nickname"] = nickname;
    data["email"] = email;
    data["mobile"] = mobile;
    data["avatar"] = avatar;
    data["background"] = background;
    data["account"] = account;
    data["role"] = role;
    data["gender"] = gender;
    data["region"] = region;
    // 结构化身份以协议 map 形态序列化（JSON 安全），无则不虚构。
    data["regionSelection"] = regionSelection?.toMap();
    data["regionSelectionStatus"] = regionSelectionStatus;
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
