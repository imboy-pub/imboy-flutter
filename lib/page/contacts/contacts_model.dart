import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';

class ContactModel extends ISuspensionBean {
  ContactModel({
    this.id,
    this.account,
    required this.nickname,
    this.avatar,
    this.status,
    this.area,
    this.sign,
    this.nameIndex,
    this.namePinyin,
    this.bgColor,
    this.iconData,
    this.firstletter,
  });

  final String? id; // 用户ID
  final String? account; // 用户ID
  final String nickname; // 备注 or 昵称
  final String? avatar; // 用户头像
  final String? status; // offline | online |
  final String? area;
  final String? sign;

  String? nameIndex;
  String? namePinyin;
  Color? bgColor;
  IconData? iconData;
  String? firstletter;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return new ContactModel(
      id: json["id"],
      account: json["account"].toString(),
      nickname: json["nickname"].toString(),
      avatar: json["avatar"].toString(),
      status: json["status"]?.toString(),
      area: json["area"]?.toString(),
      sign: json["sign"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account': account,
        'nickname': nickname,
        'avatar': avatar,
        'firstletter': firstletter,
        'nameIndex': nameIndex,
        'namePinyin': namePinyin
      };

  @override
  String getSuspensionTag() => nameIndex!;

  @override
  String toString() => json.encode(this);
}
