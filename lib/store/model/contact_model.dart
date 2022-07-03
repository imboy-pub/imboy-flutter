import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

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
    this.isfriend = 1,
    this.isfrom = 0,
    this.nameIndex = "",
    this.namePinyin,
    this.bgColor,
    this.iconData,
    this.firstletter,
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
  int isfriend;
  int isfrom;

  String nameIndex;
  String? namePinyin;
  Color? bgColor;
  IconData? iconData;
  String? firstletter;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  /// 联系人来源描述
  String get sourceTr {
    String sourceTr = "";
    // 通过QQ好友添加
    // 通过群聊添加
    switch (source.toLowerCase()) {
      case 'qrcode':
        // sourceTr = 'source_qrcode'.tr;
        sourceTr = '通过扫一扫添加'.tr;
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
      status: json["status"]?.toString(),
      remark: json["remark"].toString(),
      region: json["region"].toString(),
      source: json["source"].toString(),
      sign: json["sign"].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      updateTime: json["update_time"] ?? DateTime.now().millisecondsSinceEpoch,
      isfriend: json["isfriend"] ?? 0,
      isfrom: json["isfrom"] ?? 0,
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
        'isfriend': isfriend,
        'isfrom': isfrom,
        //
        'firstletter': firstletter,
        'nameIndex': nameIndex,
        'namePinyin': namePinyin
      };

  @override
  String getSuspensionTag() => nameIndex;

  @override
  String toString() => json.encode(this);
}
