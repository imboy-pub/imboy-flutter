import 'dart:convert';

class NewFriendModel {
  NewFriendModel({
    this.uid = "",
    required this.to,
    required this.from,
    required this.nickname,
    this.avatar,
    this.status = 0,
    this.updateTime,
    required this.createTime,
    this.msg = '',
    required this.payload,
  });

  final String uid; // 当前用户ID
  final String from; // 发送中ID
  final String to; // 接收者ID
  final String nickname; // 昵称
  final String? avatar; // 用户头像
  int status; //
  String msg;
  final int? updateTime;
  final int createTime;
  final String payload;

  String get uk {
    return from + to;
  }

  factory NewFriendModel.fromJson(Map<String, dynamic> json) {
    var status = json["status"] ?? 0;
    return NewFriendModel(
      uid: json["uid"],
      from: json["from"] ?? json["fromid"],
      to: json["to"] ?? json["toid"],
      nickname: json["nickname"].toString(),
      avatar: json["avatar"].toString(),
      status: status is String ? int.parse(status) : status,
      msg: json["msg"].toString(),
      // 单位毫秒，13位时间戳  1561021145560
      updateTime: json["update_time"] ?? DateTime.now().millisecondsSinceEpoch,
      createTime: json["create_time"],
      payload: json["payload"],
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
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
