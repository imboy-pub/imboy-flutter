import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

/// 会话数据模型
/// 纯数据模型，不包含响应式状态
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

  // 如果需要选中状态，应在 UI 层使用 Set 或 State 管理
  // bool selected = false;

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
    String sysPrompt = _parseSysPrompt(payload?['sys_prompt'] ?? '');
    if (strNoEmpty(sysPrompt)) {
      return sysPrompt;
    }
    String draftKey = "draft${type}_$peerId";
    String? draft = StorageService.to.getString(draftKey);
    if (strNoEmpty(draft)) {
      // 草稿显示：使用占位符格式，避免字符串拼接
      // 翻译键需要支持参数，例如：[{draft}]_color_red_{content}
      // 这里暂时保持原格式，因为涉及特殊的颜色标记语法
      return "[${t.tipDraft}]_color_red_$draft";
    }

    String str = t.unknownMessage;

    // 方案 D: 优先检查 lastMsgStatus 字段（撤回状态 30-39）
    if (lastMsgStatus != null) {
      if (lastMsgStatus == IMBoyMessageStatus.peerRevoked) {
        // 对方撤回 (status=30)
        if (title.isEmpty) {
          title = payload?['peer_name'] ?? '';
        }
        String suffix = '';
        if (title.length > 12) {
          title = title.substring(0, 12);
          suffix = '...';
        }
        String displayName = '"$title$suffix"';
        return t.messageWasWithdrawnWithTitle(param: displayName);
      } else if (lastMsgStatus == IMBoyMessageStatus.myRevoked) {
        // 自己撤回 (status=31)
        return t.youWithdrewAMessage;
      }
    }
    iPrint(
      "conversation_model_msgType $msgType, title $title, subtitle $subtitle,",
    );
    if (msgType == 'custom') {}
    // 普通消息类型
    if (msgType == 'text' || msgType == '') {
      return subtitle;
    } else if (msgType == 'quote') {
      return subtitle;
    } else if (msgType == 'image') {
      str = t.image;
    } else if (msgType == 'file') {
      str = t.file;
    } else if (msgType == 'voice') {
      str = t.voiceMessage;
    } else if (msgType == 'video') {
      str = t.video;
    } else if (msgType == 'webrtcAudio') {
      str = t.voiceCall;
    } else if (msgType == 'webrtcVideo') {
      str = t.videoCall;
    } else if (msgType == 'visitCard') {
      str = t.personalCard;
      return "[$str]$subtitle";
    } else if (msgType == 'location') {
      str = t.location;
      return "[$str]$subtitle";
    } else if (msgType == 'custom') {
      str = subtitle;
    } else if (msgType == 'empty') {
      return '';
    }
    return "[$str]";
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // iPrint("ConversationModel_payload 1 $payload");
    dynamic payload = json[ConversationRepo.payload];

    // Handle payload parsing
    if (payload is String || payload is Map) {
      payload = parseModelJsonMap(payload);
    } else if (payload != null && payload is! Map<String, dynamic>) {
      payload = null;
    }

    // 处理 last_time（可以是 DateTime、int 或 ISO8601 字符串）
    final rawLastTime = json['last_time'] ?? json[ConversationRepo.lastTime];
    final lastTime = parseModelDateTime(rawLastTime).millisecondsSinceEpoch;

    final avatarRaw = json[ConversationRepo.avatar];
    final avatarValue = parseModelString(avatarRaw);
    final msgTypeRaw = json[ConversationRepo.msgType];

    // iPrint("ConversationModel_payload 2 $payload");
    return ConversationModel(
      id: parseModelInt(json[ConversationRepo.id]),
      peerId: parseModelString(json[ConversationRepo.peerId]),
      avatar: avatarValue,
      title: parseModelString(json[ConversationRepo.title]),
      region: parseModelString(json[ConversationRepo.region]),
      sign: parseModelString(json[ConversationRepo.sign]),
      subtitle: parseModelString(json[ConversationRepo.subtitle]),
      lastTime: lastTime,
      lastMsgId: parseModelString(json[ConversationRepo.lastMsgId]),
      lastMsgStatus: parseModelInt(
        json[ConversationRepo.lastMsgStatus],
        defaultValue: 11,
      ),
      unreadNum: parseModelInt(json[ConversationRepo.unreadNum]),
      type: parseModelString(json[ConversationRepo.type]),
      msgType: parseModelString(msgTypeRaw),
      isShow: parseModelInt(json[ConversationRepo.isShow], defaultValue: 1),
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

  /// 解析系统提示信息（静态方法，避免依赖 Get.find）
  static String _parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      return t.sendMsgRejected;
    } else if (sysPrompt == 'not_a_friend') {
      return t.sendMsgNotFriendTips;
    }
    return sysPrompt;
  }
}
