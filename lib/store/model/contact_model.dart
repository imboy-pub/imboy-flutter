import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ContactModel extends ISuspensionBean {
  ContactModel(
      {this.uid,
      this.account,
      required this.nickname,
      this.avatar,
      this.gender = 0,
      this.status,
      this.remark = "",
      this.region = "",
      this.sign = "",
      this.updateTime,
      this.isFriend,
      this.nameIndex,
      this.namePinyin,
      this.bgColor,
      this.iconData,
      this.firstletter,
      this.onPressed,
      this.onLongPressed});

  final String? uid; // 用户ID
  final String? account; // 用户ID
  final String nickname; // 备注 or 昵称
  final String? avatar; // 用户头像
  int gender; // 1 男  2 女  3 保密  0 未知
  final String? status; // offline | online |
  final String remark;
  final String region;
  final String sign;
  final int? updateTime;
  int? isFriend;

  String? nameIndex;
  String? namePinyin;
  Color? bgColor;
  IconData? iconData;
  String? firstletter;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

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
      sign: json["sign"].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      updateTime: json["update_time"] ?? DateTime.now().millisecondsSinceEpoch,
      isFriend: json["is_friend"] ?? 0,
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
        'update_time': updateTime,
        'is_friend': isFriend,
        //
        'firstletter': firstletter,
        'nameIndex': nameIndex,
        'namePinyin': namePinyin
      };

  @override
  String getSuspensionTag() => nameIndex!;

  @override
  String toString() => json.encode(this);
}
