import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';

import 'contact_model.dart';

class DenylistModel extends ISuspensionBean {
  DenylistModel({
    required this.deniedUid,
    required this.nickname,
    required this.account,
    required this.avatar,
    required this.gender,
    required this.remark,
    required this.region,
    required this.sign,
    required this.source,
    required this.createdAt,

    //
    this.nameIndex = "",
    this.namePinyin,
  });

  final String deniedUid; // 被列入名单的用户ID
  final String account; // 被列入名单的 用户账号
  final String nickname; // 备注 or 昵称
  final String avatar; // 用户头像
  int gender; // 1 男  2 女  3 保密  0 未知
  final String remark;
  final String region;
  final String sign;
  final String source; // 朋友来源 visitCard | qrcode | people_nearby
  int createdAt;

  //
  String nameIndex;
  String? namePinyin;

  /// 联系人来源描述
  String get sourceTr {
    return getSourceTr(source);
  }

  /// 联系人title显示规则： remark > nickname > account
  String get title {
    if (strNoEmpty(remark)) {
      return remark;
    } else if (strNoEmpty(nickname)) {
      return nickname;
    } else {
      return account;
    }
  }

  factory DenylistModel.fromJson(Map<String, dynamic> json) {
    final avatar = parseModelString(json[UserDenylistRepo.avatar]);
    return DenylistModel(
      deniedUid: parseModelString(
        json["id"] ?? json[UserDenylistRepo.deniedUid],
      ),
      account: parseModelString(json[UserDenylistRepo.account]),
      nickname: parseModelString(json[UserDenylistRepo.nickname]),
      avatar: avatar,
      remark: parseModelString(json[UserDenylistRepo.remark]),

      sign: parseModelString(json[UserDenylistRepo.sign]),
      // 单位毫秒，13位时间戳  1561021145560
      createdAt: DateTimeHelper.parseTimestamp(
        json[UserDenylistRepo.createdAt],
      ),

      gender: parseModelInt(json[UserDenylistRepo.gender]),
      region: parseModelString(json[UserDenylistRepo.region]),

      source: parseModelString(json[UserDenylistRepo.source]),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': deniedUid,
    UserDenylistRepo.deniedUid: deniedUid,
    'account': account,
    'nickname': nickname,
    'avatar': avatar,
    'gender': gender,
    'remark': remark,
    'region': region,
    'sign': sign,
    'source': source,
    UserDenylistRepo.createdAt: createdAt,
    //
    'nameIndex': nameIndex,
    'namePinyin': namePinyin,
  };

  @override
  String getSuspensionTag() => nameIndex;

  @override
  String toString() => json.encode(this);
}
