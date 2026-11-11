/// 导出类型准入 —— 纯函数 + 稳定 reason code（W1-C / chat_export_share_v1）。
///
/// 冻结契约来源：PLAN_SNAPSHOT §4.4 类型矩阵「导出」列。
///
/// | 消息类别                     | 导出                 | reason code                      |
/// |------------------------------|----------------------|----------------------------------|
/// | text / textStream            | 支持（全文）         | ok                               |
/// | image / imageMulti           | 仅描述               | ok                               |
/// | voice(audio) / video / file  | 类型与文件名         | ok                               |
/// | location / expression        | 文本描述             | ok                               |
/// | quote                        | 可见文本扁平化       | ok                               |
/// | 其余用户可见类型（名片/链接/ | 安全描述             | ok                               |
/// | 频道卡/群协作卡/custom 等）  |                      |                                  |
/// | 系统/控制（含 revoked）      | 拒绝                 | rejected_system_or_control       |
/// | WebRTC                       | 拒绝                 | rejected_webrtc                  |
/// | E2EE 失败占位                | 拒绝                 | rejected_e2ee_failed             |
/// | 发送中 / 发送失败            | 拒绝                 | rejected_status_sending / _failed|
/// | 阅后即焚                     | 拒绝                 | rejected_burn_after_read         |
/// | 红包、转账                   | 拒绝                 | rejected_payment                 |
/// | 需实时 ACL 的业务卡片        | 拒绝（保守）         | rejected_realtime_acl_card       |
///
/// reason code 是机器可读契约（W2-E/W3-J UI 与测试依赖），**只增不改语义**。
library;

import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 导出准入结果（不可变）。
class ChatExportAdmission {
  const ChatExportAdmission._(this.allowed, this.reasonCode);

  /// 是否允许导出。
  final bool allowed;

  /// 稳定 reason code（见库文档矩阵；允许导出时恒为 'ok'）。
  final String reasonCode;

  /// 允许导出。
  static const ChatExportAdmission ok = ChatExportAdmission._(true, 'ok');

  /// 系统/控制消息（C2S/S2C action 值被历史落库为 msg_type，含 revoked）。
  static const ChatExportAdmission rejectedSystemOrControl =
      ChatExportAdmission._(false, 'rejected_system_or_control');

  /// WebRTC 通话消息。
  static const ChatExportAdmission rejectedWebrtc = ChatExportAdmission._(
    false,
    'rejected_webrtc',
  );

  /// E2EE 解密失败占位行。
  static const ChatExportAdmission rejectedE2eeFailed = ChatExportAdmission._(
    false,
    'rejected_e2ee_failed',
  );

  /// 发送中（status == sending），正文可能未完整。
  static const ChatExportAdmission rejectedStatusSending =
      ChatExportAdmission._(false, 'rejected_status_sending');

  /// 发送失败（status == error），不保证与对端一致。
  static const ChatExportAdmission rejectedStatusFailed = ChatExportAdmission._(
    false,
    'rejected_status_failed',
  );

  /// 阅后即焚消息，v1 拒绝导出。
  static const ChatExportAdmission rejectedBurnAfterRead =
      ChatExportAdmission._(false, 'rejected_burn_after_read');

  /// 红包/转账（金额类敏感信息），v1 拒绝导出。
  static const ChatExportAdmission rejectedPayment = ChatExportAdmission._(
    false,
    'rejected_payment',
  );

  /// 需实时 ACL 校验的业务卡片，v1 保守拒绝（计划允许「安全摘要或拒绝」）。
  static const ChatExportAdmission rejectedRealtimeAclCard =
      ChatExportAdmission._(false, 'rejected_realtime_acl_card');
}

/// 协议/历史别称归一表。真源是 `MessageTypeNormalizer.aliasOf` +
/// `_canonical`（service/message_type_normalizer.dart），此处本地内联同一
/// 映射以保持导出核心纯 Dart、零日志副作用（normalize() 会 iPrint）。
/// 新增别称时两处同步。
const Map<String, String> _kTypeAliases = <String, String>{
  // 'audio'：protobuf 通道/收藏链路的协议别称，渲染真值为 voice
  MessageType.audio: MessageType.voice,
  // 2026-10-30 前「频道消息→分享到聊天」的历史私有 msg_type
  MessageType.legacyChannelMessage: MessageType.channelCard,
  // 历史脏数据可能以下划线命名持久化（messagePreviewText 同款双 case）
  'webrtc_audio': MessageType.webrtcAudio,
  'webrtc_video': MessageType.webrtcVideo,
};

/// 归一导出用 msg_type：trim + 协议别称映射（audio→voice 等）。
String normalizeChatExportMsgType(String raw) {
  final t = raw.trim();
  return _kTypeAliases[t] ?? t;
}

/// 系统/控制类型全集：C2S/S2C action 值（历史版本可能落库为 msg_type）
/// + 'revoked' 撤回占位。这些类型没有可导出的用户内容。
const Set<String> _kSystemOrControlTypes = <String>{
  // C2S 上行动作
  C2SAction.messageRead,
  C2SAction.messageReadAck,
  C2SAction.messageRevoke,
  C2SAction.messageRevokeAck,
  C2SAction.messageEdit,
  C2SAction.messageEditAck,
  C2SAction.messageInput,
  C2SAction.e2eeRoomKey,
  C2SAction.messageReaction,
  // S2C 系统动作
  S2CAction.pullOfflineMsg,
  S2CAction.c2cRevoke,
  S2CAction.c2cDelEveryone,
  S2CAction.c2gDelEveryone,
  S2CAction.c2gDelForMe,
  S2CAction.groupMemberJoin,
  S2CAction.groupDissolve,
  S2CAction.groupMemberLeave,
  S2CAction.groupMemberAlias,
  S2CAction.applyFriend,
  S2CAction.applyFriendConfirm,
  S2CAction.userCancel,
  S2CAction.inDenylist,
  S2CAction.notAFriend,
  S2CAction.online,
  S2CAction.offline,
  S2CAction.hide,
  S2CAction.loggedAnotherDevice,
  S2CAction.deviceForceOffline,
  S2CAction.pleaseRefreshToken,
  S2CAction.appUpgrade,
  S2CAction.momentNew,
  S2CAction.momentLike,
  S2CAction.momentComment,
  S2CAction.momentDeleted,
  // 撤回占位（messagePreviewText 'revoked' 同款字面量）
  'revoked',
};

/// 评估单条消息能否导出（纯函数）。
///
/// 判定优先级（多重命中时取最前者，保证 reason code 确定）：
/// E2EE 失败占位 → 发送状态（sending/error）→ 阅后即焚 → 类型桶。
ChatExportAdmission evaluateChatExportAdmission(ChatExportEntry entry) {
  if (entry.e2eeFailedPlaceholder) {
    return ChatExportAdmission.rejectedE2eeFailed;
  }
  if (entry.status == MessageStatus.sending) {
    return ChatExportAdmission.rejectedStatusSending;
  }
  if (entry.status == MessageStatus.error) {
    return ChatExportAdmission.rejectedStatusFailed;
  }
  if (entry.burnAfterRead) {
    return ChatExportAdmission.rejectedBurnAfterRead;
  }
  final type = normalizeChatExportMsgType(entry.msgType);
  if (_kSystemOrControlTypes.contains(type)) {
    return ChatExportAdmission.rejectedSystemOrControl;
  }
  if (type == MessageType.webrtcAudio || type == MessageType.webrtcVideo) {
    return ChatExportAdmission.rejectedWebrtc;
  }
  if (type == MessageType.redPacket || type == MessageType.transfer) {
    return ChatExportAdmission.rejectedPayment;
  }
  if (type == MessageType.businessActionCard) {
    return ChatExportAdmission.rejectedRealtimeAclCard;
  }
  return ChatExportAdmission.ok;
}
