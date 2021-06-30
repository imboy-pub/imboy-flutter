import 'package:flutter/material.dart';

class Contact {
  Contact({
    @required this.identifier,
    @required this.avatar,
    @required this.account,
    @required this.name,
    @required this.nameIndex,
    this.sign,
    this.status,
  });

  final String identifier; // 用户ID
  final String avatar; // 用户头像
  final String account; // 账号
  final String name; // 备注 or 昵称
  final String nameIndex; // 备注 or 昵称 索引
  final String sign;
  final String status;
}
