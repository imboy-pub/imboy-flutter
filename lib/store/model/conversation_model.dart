import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

class ConversationModel {
  int id;
  final String peerId;
  final String avatar;
  final String title;
  String subtitle;
  String region;
  String sign;
  final int? lasttime;
  String lastMsgId;
  // lastMsgStatus 10 发送中 sending;  11 已发送 send;
  final int? lastMsgStatus;
  int unreadNum;
  // 等价与 msg type: C2C C2G S2C 等等，根据type显示item
  final String type;
  //
  String msgtype;
  final int? isShow;

  ConversationModel({
    required this.id,
    required this.peerId,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.msgtype,
    this.region = '',
    this.sign = '',
    this.lasttime,
    this.lastMsgId = '',
    this.lastMsgStatus,
    required this.unreadNum,
    this.isShow,
  });

  /// 会话内容计算
  String get content {
    String str = '未知消息'.tr;
    if (msgtype == "text") {
      return subtitle;
    } else if (msgtype == "image") {
      str = '图片'.tr;
    } else if (msgtype == "file") {
      str = '文件'.tr;
    } else if (msgtype == "audio") {
      str = '语音消息'.tr;
    } else if (msgtype == "video") {
      str = '视频'.tr;
    } else if (msgtype == "peer_revoked") {
      return '"${title}"' + '撤回了一条消息'.tr;
    } else if (msgtype == "my_revoked") {
      return '你撤回了一条消息'.tr;
    } else if (msgtype == "custom") {
      str = subtitle;
    } else {}
    return "[$str]";
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? 0,
      peerId: json['peer_id'],
      avatar: strEmpty(json['avatar']) ? '' : json['avatar'],
      title: json['title'].toString(),
      region: json['region'].toString(),
      sign: json['sign'].toString(),
      subtitle: json['subtitle'] ?? '',
      lasttime: json['lasttime'] ?? 0,
      lastMsgId: json['last_msg_id'] ?? '',
      lastMsgStatus: json['last_msg_status'] ?? 11,
      unreadNum: json['unread_num'] ?? 0,
      type: json['type'].toString(),
      msgtype: json['msgtype'].toString(),
      isShow: json['is_show'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'peer_id': peerId,
        'avatar': avatar,
        'title': title,
        'region': region,
        'sign': sign,
        'subtitle': subtitle,
        'lasttime': lasttime,
        'last_msg_id': lastMsgId,
        'last_msg_status': lastMsgStatus,
        'unread_num': unreadNum,
        'type': type,
        'msgtype': msgtype,
        'is_show': isShow,
      };
}
