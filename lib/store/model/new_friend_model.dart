import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewFriendModel {
  NewFriendModel({
    required this.from,
    required this.to,
    required this.nickname,
    this.avatar,
    this.status,
    this.updateTime,
    required this.createTime,
    this.msg = '',
    required this.payload,
    this.onPressed,
    this.onLongPressed,
  });

  final String from; // 用户ID
  final String to; // 用户ID
  final String nickname; // 备注 or 昵称
  final String? avatar; // 用户头像
  final String? status; // offline | online |
  String msg;
  final int? updateTime;
  final int createTime;
  final Map payload;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  factory NewFriendModel.fromJson(Map<String, dynamic> json) {
    return NewFriendModel(
      from: json["from"],
      to: json["to"].toString(),
      nickname: json["nickname"].toString(),
      avatar: json["avatar"].toString(),
      status: json["status"]?.toString(),
      msg: json["msg"].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      updateTime: json["update_time"] ?? DateTime.now().millisecondsSinceEpoch,
      createTime: json["create_time"],
      payload: json["payload"],
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'nickname': nickname,
        'avatar': avatar,
        'status': status,
        'msg': msg,
        'update_time': updateTime,
        'create_time': createTime,
        'payload': payload,
      };

  @override
  String toString() => json.encode(this);
}
