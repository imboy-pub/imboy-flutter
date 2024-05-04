import 'dart:convert';

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class ConversationModel {
  int id;
  // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
  final String type;
  // CREATE UNIQUE INDEX uk_cv_Type_From_To ON conversation ("type",user_id,peer_id)
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

  //
  String msgType;
  int isShow;

  RxBool selected = false.obs;

  // 如果 title 为空，零时计算title
  String computeTitle = '';
  // 如果 avatar 为空，零时计算avatar
  List<String> computeAvatar = [];

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

  // CREATE UNIQUE INDEX uk_cv_Type_From_To ON conversation ("type",user_id,peer_id)
  String get uk3 {
    return "${type}_${UserRepoLocal.to.currentUid}_$peerId".toLowerCase();
  }
  /// 会话内容计算
  String get content {
    // debugPrint("ConversationModel_content ${payload.toString()}");
    // 处理系统提示信息
    String sysPrompt = Get.find<ChatLogic>().parseSysPrompt(
      payload?['sys_prompt'] ?? '',
    );
    if (strNoEmpty(sysPrompt)) {
      return sysPrompt;
    }
    String str = 'unknown_message'.tr;
    if (msgType == 'text' || msgType == '') {
      return subtitle;
    } else if (msgType == 'quote') {
      return subtitle;
    } else if (msgType == 'image') {
      str = 'image'.tr;
    } else if (msgType == 'file') {
      // str = '文件';
      str = 'file'.tr;
    } else if (msgType == 'audio') {
      str = 'voice_message'.tr;
    } else if (msgType == 'video') {
      str = 'video'.tr;
    } else if (msgType == 'webrtc_audio') {
      str = 'voice_call'.tr;
    } else if (msgType == 'webrtc_video') {
      str = 'video_call'.tr;
    } else if (msgType == 'visit_card') {
      str = 'personal_card'.tr;
      return "[$str]$subtitle";
    } else if (msgType == 'location') {
      str = 'location'.tr;
      return "[$str]$subtitle";
    } else if (msgType == 'peer_revoked') {
      return '"$title"${'message_was_withdrawn'.tr}';
    } else if (msgType == 'my_revoked') {
      return 'you_withdrew_a_message'.tr;
    } else if (msgType == 'custom') {
      str = subtitle;
    } else if (msgType == 'empty') {
      return '';
    } else {}
    return "[$str]";
  }

  int get lastTimeLocal =>
      lastTime + DateTime.now().timeZoneOffset.inMilliseconds;

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
