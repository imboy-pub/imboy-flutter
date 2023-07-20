import 'dart:convert';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

class ConversationModel {
  int id;
  final String peerId;
  String avatar;
  String title; // peerTitle
  String subtitle;
  String region;
  String sign;
  int lastTime;
  String lastMsgId;

  // 消息原数据
  Map<String, dynamic>? payload;

  // lastMsgStatus 10 发送中 sending;  11 已发送 send;
  final int? lastMsgStatus;
  int unreadNum;

  // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
  final String type;

  //
  String msgType;
  int isShow;

  RxBool selected = false.obs;

  ConversationModel({
    required this.id,
    required this.peerId,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.msgType,
    this.region = '',
    this.sign = '',
    this.lastTime = 0,
    this.lastMsgId = '',
    this.lastMsgStatus,
    required this.unreadNum,
    this.isShow = 1,
    this.payload, // 消息原数据
  });

  /// 会话内容计算
  String get content {
    // debugPrint("ConversationModel_content ${payload.toString()}");
    // 处理系统提示信息
    String sysPrompt = ChatLogic().parseSysPrompt(
      payload?['sys_prompt'] ?? '',
    );
    if (strNoEmpty(sysPrompt)) {
      return sysPrompt;
    }
    String str = '未知消息'.tr;
    if (msgType == "text") {
      return subtitle;
    } else if (msgType == 'quote') {
      return subtitle;
    } else if (msgType == 'image') {
      str = '图片'.tr;
    } else if (msgType == 'file') {
      str = '文件'.tr;
    } else if (msgType == 'audio') {
      str = '语音消息'.tr;
    } else if (msgType == 'video') {
      str = '视频'.tr;
    } else if (msgType == 'visit_card') {
      str = '个人名片'.tr;
      return "[$str]$subtitle";
    } else if (msgType == 'location') {
      str = '位置'.tr;
      return "[$str]$subtitle";
    } else if (msgType == 'peer_revoked') {
      return '"$title"${'撤回了一条消息'.tr}';
    } else if (msgType == 'my_revoked') {
      return '你撤回了一条消息'.tr;
    } else if (msgType == "custom") {
      str = subtitle;
    } else {}
    return "[$str]";
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    var payload = json[ConversationRepo.payload];
    if (payload is String) {
      payload = jsonDecode(payload);
    }
    return ConversationModel(
      id: json['id'] ?? 0,
      peerId: json['peer_id'],
      avatar: strEmpty(json['avatar']) ? '' : json['avatar'],
      title: json['title'].toString(),
      region: json['region'].toString(),
      sign: json['sign'].toString(),
      subtitle: json['subtitle'] ?? '',
      lastTime: json[ConversationRepo.lastTime] ?? 0,
      lastMsgId: json['last_msg_id'] ?? '',
      lastMsgStatus: json['last_msg_status'] ?? 11,
      unreadNum: json['unread_num'] ?? 0,
      type: json['type'].toString(),
      msgType: json[ConversationRepo.msgType].toString(),
      isShow: json['is_show'] ?? 1,
      payload: payload != null ? Map<String, dynamic>.from(payload) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        ConversationRepo.id: id,
        ConversationRepo.peerId: peerId,
        ConversationRepo.avatar: avatar,
        ConversationRepo.title: title,
        ConversationRepo.region: region,
        ConversationRepo.sign: sign,
        ConversationRepo.subtitle: subtitle,
        ConversationRepo.lastTime: lastTime,
        ConversationRepo.lastMsgId: lastMsgId,
        ConversationRepo.lastMsgStatus: lastMsgStatus,
        ConversationRepo.unreadNum: unreadNum,
        ConversationRepo.type: type,
        ConversationRepo.msgType: msgType,
        ConversationRepo.isShow: isShow,
        ConversationRepo.payload: payload,
      };
}
