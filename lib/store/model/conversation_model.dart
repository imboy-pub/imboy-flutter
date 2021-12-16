import 'package:imboy/helper/func.dart';

class ConversationModel {
  int id;
  final String cuid;
  final String typeId;
  final String avatar;
  final String title;
  String subtitle;
  final int? lasttime;
  // lastMsgStatus 10 发送中 sending;  11 已发送 send;
  final int? lastMsgStatus;
  int unreadNum;
  // 等价与 msg type: C2C C2G 等等，根据type显示item
  final String type;
  String msgtype;
  final int? isShow;

  ConversationModel({
    required this.id,
    required this.cuid,
    required this.typeId,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.msgtype,
    this.lasttime,
    this.lastMsgStatus,
    required this.unreadNum,
    this.isShow,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> json) {
    return new ConversationModel(
      id: json['id'] ?? 0,
      cuid: json['cuid'] ?? '',
      typeId: json['type_id'],
      avatar: strEmpty(json['avatar']) ? '' : json['avatar'],
      title: json['title'].toString(),
      subtitle: json['subtitle'] ?? '',
      lasttime: json['lasttime'] ?? 0,
      lastMsgStatus: json['last_msg_status'] ?? 11,
      unreadNum: json['unread_num'] == null ? 0 : json['unread_num'],
      type: json['type'].toString(),
      msgtype: json['msgtype'].toString(),
      isShow: json['is_show'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cuid': cuid,
        'type_id': typeId,
        'avatar': avatar,
        'title': title,
        'subtitle': subtitle,
        'lasttime': lasttime,
        'last_msg_status': lastMsgStatus,
        'unread_num': unreadNum,
        'type': type,
        'msgtype': msgtype,
        'is_show': isShow,
      };
}
