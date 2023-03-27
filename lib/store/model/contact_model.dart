import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactModel extends ISuspensionBean {
  ContactModel({
    this.uid,
    required this.nickname,
    this.account = "",
    this.avatar = "",
    this.gender = 0,
    this.status,
    this.remark = "",
    this.region = "",
    this.sign = "",
    this.source = "",
    this.updateTime,
    this.isFriend = 1,
    // isFrom 好友关系发起人
    this.isFrom = 0,
    this.nameIndex = "",
    this.namePinyin,
    this.bgColor,
    this.iconData,
    this.firstLetter,
    this.onPressed,
    this.onLongPressed,
  });

  final String? uid; // 用户ID
  final String account; // 用户ID
  final String nickname; // 备注 or 昵称
  final String avatar; // 用户头像
  int gender; // 1 男  2 女  3 保密  0 未知
  final String? status; // offline | online |
  final String remark;
  final String region;
  final String sign;
  final String source;
  final int? updateTime;
  int isFriend;
  // isFrom 好友关系发起人
  int isFrom;

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
    String sourceTr = "";
    // 通过QQ好友添加
    // 通过群聊添加
    switch (source.toLowerCase()) {
      case 'visit_card':
        sourceTr = '个人名片'.tr;
        break;
      case 'qrcode':
        // sourceTr = 'source_qrcode'.tr;
        sourceTr = '通过扫一扫添加'.tr;
        break;
      case 'people_nearby':
        sourceTr = '附近的人'.tr;
        break;
    }
    return sourceTr;
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

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      uid: json["id"] ?? (json["uid"] ?? ""),
      account: json["account"].toString(),
      nickname: json["nickname"].toString(),
      avatar: json["avatar"].toString(),
      gender: json["gender"] ?? 0,
      status: json["status"] ?? '',
      remark: json["remark"].toString(),
      region: json["region"].toString(),
      source: json["source"].toString(),
      sign: json["sign"].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      updateTime: json["update_time"] ?? DateTime.now().millisecondsSinceEpoch,
      isFriend: json[ContactRepo.isFriend] ?? 0,
      isFrom: json[ContactRepo.isFrom] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': uid,
        'account': account,
        'nickname': nickname,
        'avatar': avatar,
        'gender': gender,
        'status': status,
        'remark': remark,
        'region': region,
        'sign': sign,
        'source': source,
        'update_time': updateTime,
        ContactRepo.isFriend: isFriend,
        ContactRepo.isFrom: isFrom,
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
