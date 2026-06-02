import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class PeopleModel {
  int id;
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
  int createdAt;

  PeopleModel({
    required this.id, // userId or other
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
    this.createdAt = 0,
  });

  factory PeopleModel.fromJson(Map<String, dynamic> json) {
    return PeopleModel(
      id: parseModelInt(json["uid"] ?? json["id"]),
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
      createdAt: DateTimeHelper.parseTimestamp(json['friend_created_at']),
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
    data['created_at'] = createdAt;
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
