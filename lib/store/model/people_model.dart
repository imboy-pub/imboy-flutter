import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';

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

  /// 注册时间（user.created_at；毫秒，0=未知）。
  ///
  /// R10：与好友关系时间 [friendCreatedAt] 语义分开。后端 epgsql 的
  /// rfc3339 codec 把 PG timestamptz 输出为带 offset 的 RFC3339 字符串，
  /// 按 [ApiTime.parseIsoZoned] 明确合同解析；缺失/非法（含纯数字字符串、
  /// 无 zone 形态）为 0，**绝不回填当前时间**——UI 以 `> 0` 决定显示。
  int registeredAt;

  /// 好友关系建立时间（friend.created_at；毫秒，0=未知/非好友）。
  ///
  /// 后端 location_logic 对非好友显式填整数 0；非 0 值为 RFC3339 字符串。
  /// 附近的人/好友列表展示好友关系语义时用本字段，不得串用注册时间。
  int friendCreatedAt;

  /// 账号类型：0=真人 1=AI 助手 2=官方机器人（服务端只读投影，见 BotBadge）
  int accountType;

  PeopleModel({
    required Object id, // userId or other
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
    this.registeredAt = 0,
    this.friendCreatedAt = 0,
    this.accountType = 0,
  }) : id = channelDecimalId(id, allowZero: true, allowNegative: true) ?? '0';

  factory PeopleModel.fromJson(Map<String, dynamic> json) {
    return PeopleModel(
      id: (json["uid"] ?? json["id"] ?? 0) as Object,
      account: parseModelString(json["account"]),
      nickname: parseModelString(json["nickname"]),
      avatar: parseModelString(json["avatar"]),
      gender: parseModelInt(json["gender"]),
      region: parseModelString(json["region"]),
      sign: parseModelString(json["sign"]),
      distance: parseModelDouble(json["distance"]),
      distanceUnit: parseModelString(json["unit"], defaultValue: "m"),
      isFriend: parseModelBool(json['is_friend']),
      remark: parseModelString(json['remark']),
      registeredAt:
          ApiTime.parseIsoZoned(json['created_at']?.toString() ?? '')
              ?.millisecondsSinceEpoch ??
          0,
      friendCreatedAt:
          ApiTime.parseIsoZoned(json['friend_created_at']?.toString() ?? '')
              ?.millisecondsSinceEpoch ??
          0,
      accountType: parseModelInt(json['account_type']),
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
    data['registered_at'] = registeredAt;
    data['friend_created_at'] = friendCreatedAt;
    data['account_type'] = accountType;
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
