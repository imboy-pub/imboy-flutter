import 'dart:convert';

import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

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
    return ConversationUk3Generator.generateSmart(
      type: type,
      currentUserId: UserRepoLocal.to.currentUid,
      peerId: peerId,
    );
  }
  /// 会话内容计算
  String get content {
    // iPrint("ConversationModel_content msgType $msgType;  ${payload.toString()}");
    // 处理系统提示信息
    String sysPrompt = Get.find<ChatLogic>().parseSysPrompt(
      payload?['sys_prompt'] ?? '',
    );
    if (strNoEmpty(sysPrompt)) {
      return sysPrompt;
    }
    String draftKey = "draft${type}_$peerId";
    String? draft = StorageService.to.getString(draftKey);
    if (strNoEmpty(draft)) {
      return "[${'tipDraft'.tr}]_color_red_$draft";
    }

    String str = 'unknownMessage'.tr;
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
      str = 'voiceMessage'.tr;
    } else if (msgType == 'video') {
      str = 'video'.tr;
    } else if (msgType == 'webrtc_audio') {
      str = 'voiceCall'.tr;
    } else if (msgType == 'webrtc_video') {
      str = 'videoCall'.tr;
    } else if (msgType == 'visit_card') {
      str = 'personalCard'.tr;
      return "[$str]$subtitle";
    } else if (msgType == 'location') {
      str = 'location'.tr;
      return "[$str]$subtitle";
    } else if (msgType == 'peer_revoked') {
      if (title.isEmpty) {
        title = payload?['peer_name'] ?? '';
      }
      String suffix = '';
      if (title.length > 12) {
        title = title.substring(0, 12);
        suffix = '...';
      }
      return '"$title$suffix" ${'messageWasWithdrawn'.tr}';
    } else if (msgType == 'my_revoked') {
      return 'youWithdrewAMessage'.tr;
    } else if (msgType == 'custom') {
      str = subtitle;
    } else if (msgType == 'empty') {
      return '';
    } else {}
    return "[$str]";
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // iPrint("ConversationModel_payload 1 $payload");
    dynamic payload = json[ConversationRepo.payload] ?? json[ConversationRepo.payload];

    // Handle payload parsing
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (e) {
        payload = null;
      }
    }
    // 处理 last_time（可以是 DateTime、int 或 ISO8601 字符串）
    final rawLastTime = json['last_time'] ?? json[ConversationRepo.lastTime];
    int lastTime = DateTimeHelper.parseTimestamp(rawLastTime, defaultValue: 0);

    // iPrint("ConversationModel_payload 2 $payload");
    return ConversationModel(
      id: json[ConversationRepo.id]?.toInt() ?? 0,
      peerId: json[ConversationRepo.peerId]?.toString() ?? '',
      avatar: (json[ConversationRepo.avatar]?.toString() ?? '').isEmpty ? '' : json['avatar'].toString(),
      title: json[ConversationRepo.title]?.toString() ?? '',
      region: json[ConversationRepo.region]?.toString() ?? '',
      sign: json[ConversationRepo.sign]?.toString() ?? '',
      subtitle: json[ConversationRepo.subtitle]?.toString() ?? '',
      lastTime: lastTime,
      lastMsgId: json[ConversationRepo.lastMsgId]?.toString() ?? '',
      lastMsgStatus: json[ConversationRepo.lastMsgStatus]?.toInt() ?? 11,
      unreadNum: json[ConversationRepo.unreadNum]?.toInt() ?? 0,
      type: json[ConversationRepo.type]?.toString() ?? '',
      msgType: json[ConversationRepo.msgType] ?? json[ConversationRepo.msgType]?.toString() ?? '',
      isShow: json[ConversationRepo.isShow]?.toInt() ?? 1,
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

  factory ConversationModel.empty() => ConversationModel.fromJson({
    ConversationRepo.id: 0,
    ConversationRepo.peerId: "",
    ConversationRepo.avatar: "",
    ConversationRepo.title: "",
    ConversationRepo.region: "",
    ConversationRepo.sign: "",
    ConversationRepo.subtitle: 0,
    ConversationRepo.lastTime: "",
    ConversationRepo.lastMsgId: 0,
    ConversationRepo.lastMsgStatus: 0,
    ConversationRepo.unreadNum: "",
    ConversationRepo.type: 0,
    ConversationRepo.msgType: {},
  });

  ConversationModel copyWith({
    String? peerId,
    String? avatar,
    String? title,
    String? subtitle,
    int? lastTime,
    String? lastMsgId,
    int? lastMsgStatus,
    int? unreadNum,
    String? type,
    String? msgType,
    int? isShow,
    Map<String, dynamic>? payload,
  }) {
    return ConversationModel.fromJson({
      ConversationRepo.peerId: peerId ?? this.peerId,
      ConversationRepo.avatar: avatar ?? this.avatar,
      ConversationRepo.title: title ?? this.title,
      ConversationRepo.subtitle: subtitle ?? this.subtitle,
      ConversationRepo.lastTime: lastTime ?? this.lastTime,
      ConversationRepo.lastMsgId: lastMsgId ?? this.lastMsgId,
      ConversationRepo.lastMsgStatus: lastMsgStatus ?? this.lastMsgStatus,
      ConversationRepo.unreadNum: unreadNum ?? this.unreadNum,
      ConversationRepo.type: type ?? this.type,
      ConversationRepo.msgType: msgType ?? this.msgType,
      ConversationRepo.isShow: isShow ?? this.isShow,
      ConversationRepo.payload: payload ?? this.payload,
    });
  }
}
