import 'dart:convert';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';

class NewFriendModel {
  NewFriendModel({
    this.uid = "",
    required this.to,
    required this.from,
    required this.nickname,
    required this.source,
    this.avatar,
    this.status = 0,
    this.updatedAt = 0,
    required this.createdAt,
    this.msg = '',
    required this.payload,
  });

  final String uid; // 当前用户ID
  final String from; // 发送中ID
  final String to; // 接收者ID
  final String nickname; // 昵称
  final String source;
  final String? avatar; // 用户头像
  // 0 待验证  1 已添加  2 已过期
  int status; //
  String msg;
  final int updatedAt;
  final int createdAt;
  final String payload;

  int get updatedAtLocal =>
      updatedAt + DateTime.now().timeZoneOffset.inMilliseconds;

  int get createdAtLocal =>
      createdAt + DateTime.now().timeZoneOffset.inMilliseconds;

  String get uk {
    return from + to;
  }

  factory NewFriendModel.fromJson(Map<String, dynamic> json) {
    var status = json["status"] ?? 0;
    return NewFriendModel(
      source: json[NewFriendRepo.source] ?? '',
      uid: json[NewFriendRepo.uid],
      from: json[NewFriendRepo.from] ?? json['from'],
      to: json[NewFriendRepo.to] ?? json['to'],
      nickname: json[NewFriendRepo.nickname].toString(),
      avatar: json[NewFriendRepo.avatar].toString(),
      status: status is String ? int.parse(status) : status,
      msg: json[NewFriendRepo.msg].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      updatedAt: json[NewFriendRepo.updatedAt] ?? DateTimeHelper.utc(),
      createdAt: json[NewFriendRepo.createdAt],
      payload: json["payload"],
    );
  }

  Map<String, dynamic> toJson() => {
        NewFriendRepo.uid: uid,
        NewFriendRepo.from: from,
        NewFriendRepo.to: to,
        NewFriendRepo.nickname: nickname,
        NewFriendRepo.avatar: avatar,
        NewFriendRepo.status: status,
        NewFriendRepo.msg: msg,
        NewFriendRepo.updatedAt: updatedAt,
        NewFriendRepo.createdAt: createdAt,
        NewFriendRepo.payload: payload,
      };

  @override
  String toString() => json.encode(this);
}
