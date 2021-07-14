import 'package:flutter/material.dart';

class ContactModel {
  ContactModel({
    @required this.id,
    @required this.remark,
    @required this.account,
    @required this.nickname,
    @required this.avatar,
    this.status,
    this.sign,
    this.nameIndex,
  });

  final String id; // 用户ID
  final String status; // offline | online |
  final String remark; // 备注 or 昵称 索引
  final String avatar; // 用户头像
  final String account; // 账号
  final String nickname; // 备注 or 昵称
  final String sign;
  final String nameIndex;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return new ContactModel(
      id: json["id"],
      avatar: json["avatar"]?.toString(),
      account: json["account"]?.toString(),
      nickname: json["nickname"]?.toString(),
      remark: json["remark"]?.toString(),
      sign: json["sign"]?.toString(),
      status: json["status"]?.toString(),
    );
  }
}
