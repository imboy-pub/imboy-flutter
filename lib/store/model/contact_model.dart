import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

String getSourceTr(String source) {
  debugPrint("getSourceTr $source");
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
    case 'null':
      sourceTr = '';
      break;
    default:
      sourceTr = source;
      break;
  }
  return sourceTr;
}

class ContactModel extends ISuspensionBean {
  ContactModel({
    required this.peerId,
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
    this.categoryId = 0,
    this.nameIndex = "",
    this.namePinyin,
    this.bgColor,
    this.iconData,
    this.firstLetter,
    this.onPressed,
    this.onLongPressed,
  });

  final String peerId; // 联系人用户ID
  final String account; // 联系人用户账号
  final String nickname; // 联系人用户 备注 or 昵称
  final String avatar; // 用户头像
  int gender; // 1 男  2 女  3 保密  0 未知
  final String? status; // offline | online |
  final String remark;
  final String region;
  final String sign;
  final String source; // visit_card | qrcode | people_nearby
  final int? updateTime;
  int isFriend;
  // isFrom 好友关系发起人
  int isFrom;
  int categoryId;

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

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    var isFrom = json[ContactRepo.isFrom] ?? 0;

    return ContactModel(
      peerId: json["id"] ?? (json[ContactRepo.peerId] ?? ""),
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
      updateTime:
          json[ContactRepo.updateTime] ?? DateTimeHelper.currentTimeMillis(),
      isFriend: json[ContactRepo.isFriend] ?? 0,
      categoryId: json[ContactRepo.categoryId] ?? 0,
      isFrom: int.tryParse('$isFrom') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        ContactRepo.peerId: peerId,
        'account': account,
        'nickname': nickname,
        'avatar': avatar,
        'gender': gender,
        'status': status,
        'remark': remark,
        'region': region,
        'sign': sign,
        'source': source,
        ContactRepo.updateTime: updateTime,
        ContactRepo.isFriend: isFriend,
        ContactRepo.isFrom: isFrom,
        ContactRepo.categoryId: categoryId,
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
