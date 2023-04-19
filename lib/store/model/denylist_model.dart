import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/denylist_repo_sqlite.dart';

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
    this.bgColor,
    this.iconData,
    this.firstLetter,
    this.onPressed,
    this.onLongPressed,
  });

  final String deniedUid; // 被列入名单的用户ID
  final String account; // 被列入名单的 用户账号
  final String nickname; // 备注 or 昵称
  final String avatar; // 用户头像
  int gender; // 1 男  2 女  3 保密  0 未知
  final String remark;
  final String region;
  final String sign;
  final String source; // 朋友来源 visit_card | qrcode | people_nearby
  int? createdAt;

  //
  String nameIndex;
  String? namePinyin;
  Color? bgColor;
  Widget? iconData;
  String? firstLetter;
  bool selected = false;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

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
    String avatar = json[DenylistRepo.avatar] ?? '';
    if (strEmpty(avatar)) {
      avatar = defAvatar;
    }
    return DenylistModel(
      deniedUid: json["id"] ?? (json[DenylistRepo.deniedUid] ?? ""),
      account: json[DenylistRepo.account].toString(),
      nickname: json[DenylistRepo.nickname].toString(),
      avatar: avatar,
      remark: json[DenylistRepo.remark].toString(),

      sign: json[DenylistRepo.sign].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      createdAt:
          json[DenylistRepo.createdAt] ?? DateTimeHelper.currentTimeMillis(),

      gender: json[DenylistRepo.gender] ?? 0,
      region: json[DenylistRepo.region].toString(),

      source: json[DenylistRepo.source].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': deniedUid,
        DenylistRepo.deniedUid: deniedUid,
        'account': account,
        'nickname': nickname,
        'avatar': avatar,
        'gender': gender,
        'remark': remark,
        'region': region,
        'sign': sign,
        'source': source,
        DenylistRepo.createdAt: createdAt,
        //
        'firstLetter': firstLetter,
        'nameIndex': nameIndex,
        'namePinyin': namePinyin
      };

  @override
  String getSuspensionTag() => nameIndex;

  @override
  String toString() => json.encode(this);
}
