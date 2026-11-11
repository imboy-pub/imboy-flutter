/// 多选消息可选性判定 —— 纯函数（纯 Dart，零外部依赖）。
///
/// W1-A / chat_multi_select_v1（RUN_ID=chat-multi-20261111）：输入消息的
/// msgType + 状态标志，输出 可选/不可选 + 稳定 reason code。判定依据冻结合同
/// PLAN_SNAPSHOT §4.4 类型矩阵：
///
/// - 可选（白名单）：text / image / imageMulti / voice / audio（voice 别名）/
///   video / file / location / expression / quote；
/// - 不可选：系统/控制类、WebRTC（webrtcAudio/webrtcVideo）、E2EE 解密失败
///   占位（metadata['_e2ee_failed']==true）、发送中/发送失败（status 非完成态）、
///   已撤回、阅后即焚（burn_read_at>0）、红包 redPacket、转账 transfer、
///   业务卡片（businessActionCard 等，v1 不承诺批量）。
///
/// reason code 是跨版本稳定契约（snake_case 字面量），供 W2-E UI 映射
/// i18n 文案与埋点；新增类型默认不可选（fail-closed），放宽需改冻结合同。
library;

import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 多选相关稳定 reason code 常量。
///
/// 这些字符串是对外契约（UI/i18n/日志依赖），不要重命名或复用旧值。
abstract final class MessageSelectionReason {
  /// 第 101 条拒绝（上限 100，冻结合同 §4.2）。
  static const String limitExceeded = 'limit_exceeded';

  /// 多选未激活时调用 toggle。
  static const String inactive = 'inactive';

  /// E2EE 解密失败占位行（安全优先级最高）。
  static const String e2eeFailed = 'e2ee_failed';

  /// 发送中（status=sending）。
  static const String statusSending = 'status_sending';

  /// 发送失败（status=error）。
  static const String statusFailed = 'status_failed';

  /// 已撤回（正文已不可转发）。
  static const String revoked = 'revoked';

  /// 阅后即焚（burn_read_at>0）。
  static const String burnAfterRead = 'burn_after_read';

  /// WebRTC 音频/视频通话信令。
  static const String webrtcCall = 'webrtc_call';

  /// 红包/转账（资金类，v1 不支持批量）。
  static const String paymentMessage = 'payment_message';

  /// 业务卡片（businessActionCard / linkCard / visitCard 等，需实时 ACL，
  /// v1 不承诺批量）。
  static const String businessCard = 'business_card';

  /// 其余一切类型：系统/控制类、textStream、custom、unsupported、null、
  /// 未知新类型（默认不可选，fail-closed）。
  static const String unsupportedType = 'unsupported_type';
}

/// 可选性判定的最小消息快照。
///
/// UI 边界（ChatPage/W2-E）从 `CustomMessage` 提取，不携带完整 Message ——
/// 领域层只关心这几个标志。字段语义：
/// - [msgType]：`metadata['msg_type']`（或 MessageModel.msgType），可为 null；
/// - [status]：域 [MessageStatus]（flutter_chat_core 状态在调用点做边界映射，
///   null 映射为 sent，与 `resolveLongPressCapabilities` 同口径）；
/// - [e2eeFailed]：`metadata['_e2ee_failed'] == true`（解密失败占位行）；
/// - [burnReadAt]：`metadata['burn_read_at']`，>0 即阅后即焚。
class MessageSelectionTraits {
  const MessageSelectionTraits({
    required this.msgType,
    required this.status,
    this.e2eeFailed = false,
    this.burnReadAt = 0,
  });

  /// 消息 msg_type；S2C/系统行可为 null。
  final String? msgType;

  /// 域消息状态。
  final MessageStatus status;

  /// 是否为 E2EE 解密失败占位行。
  final bool e2eeFailed;

  /// 阅后即焚时间戳（毫秒）；<=0 表示非阅后即焚。
  final int burnReadAt;
}

/// 判定结果：[selectable] 为 false 时 [reasonCode] 必为稳定 reason code。
class MessageSelectability {
  const MessageSelectability._(this.selectable, this.reasonCode);

  /// 是否可选（进入/加入多选）。
  final bool selectable;

  /// 不可选原因（稳定 snake_case code）；可选时为 null。
  final String? reasonCode;

  /// 可选单例。
  static const MessageSelectability ok = MessageSelectability._(true, null);

  /// 不可选工厂。
  const MessageSelectability.denied(String this.reasonCode)
    : selectable = false;
}

/// 冻结白名单：§4.4 中「逐条转发/合并转发/导出」三者均支持的基础类型。
const Set<String> _kSelectableMsgTypes = <String>{
  MessageType.text,
  MessageType.image,
  MessageType.imageMulti,
  MessageType.voice,
  // voice 的协议别称（protobuf 通道/收藏恢复链路产出 'audio'）。
  MessageType.audio,
  MessageType.video,
  MessageType.file,
  MessageType.location,
  MessageType.expression,
  MessageType.quote,
};

/// 业务卡片集合：需实时 ACL / 跳转态，v1 不承诺批量（§4.4 最后一行）。
const Set<String> _kBusinessCardMsgTypes = <String>{
  MessageType.businessActionCard,
  MessageType.linkCard,
  MessageType.channelCard,
  MessageType.legacyChannelMessage,
  MessageType.talkRecordCard,
  MessageType.visitCard,
  MessageType.groupSchedule,
  MessageType.groupVote,
  MessageType.groupTask,
  MessageType.groupNotice,
};

/// 判定一条消息能否进入/加入多选。
///
/// 判定顺序（多条同时命中时优先返回靠前者，保持 reason 稳定可预期）：
/// E2EE 失败占位 → 发送中/发送失败/已撤回 → 阅后即焚 → 类型白名单/分类。
MessageSelectability evaluateMessageSelectability(
  MessageSelectionTraits traits,
) {
  // 1. E2EE 解密失败占位：占位串不是真实内容，安全优先级最高。
  if (traits.e2eeFailed) {
    return const MessageSelectability.denied(MessageSelectionReason.e2eeFailed);
  }

  // 2. 状态标志：发送中/发送失败（§4.4「发送中/发送失败」行）与已撤回。
  switch (traits.status) {
    case MessageStatus.sending:
      return const MessageSelectability.denied(
        MessageSelectionReason.statusSending,
      );
    case MessageStatus.error:
      return const MessageSelectability.denied(
        MessageSelectionReason.statusFailed,
      );
    case MessageStatus.revoked:
      return const MessageSelectability.denied(MessageSelectionReason.revoked);
    case MessageStatus.sent:
    case MessageStatus.delivered:
    case MessageStatus.seen:
      break;
  }

  // 3. 阅后即焚：v1 不支持批量转发焚毁消息（§4.4）。
  if (traits.burnReadAt > 0) {
    return const MessageSelectability.denied(
      MessageSelectionReason.burnAfterRead,
    );
  }

  // 4. 类型矩阵：白名单可选；WebRTC/资金/业务卡片给出分类 reason；
  //    其余（系统/控制、textStream、custom、unsupported、null、未知新类型）
  //    一律不可选（fail-closed）。
  final type = traits.msgType;
  if (type == null) {
    return const MessageSelectability.denied(
      MessageSelectionReason.unsupportedType,
    );
  }
  if (_kSelectableMsgTypes.contains(type)) {
    return MessageSelectability.ok;
  }
  if (type == MessageType.webrtcAudio || type == MessageType.webrtcVideo) {
    return const MessageSelectability.denied(MessageSelectionReason.webrtcCall);
  }
  if (type == MessageType.redPacket || type == MessageType.transfer) {
    return const MessageSelectability.denied(
      MessageSelectionReason.paymentMessage,
    );
  }
  if (_kBusinessCardMsgTypes.contains(type)) {
    return const MessageSelectability.denied(
      MessageSelectionReason.businessCard,
    );
  }
  return const MessageSelectability.denied(
    MessageSelectionReason.unsupportedType,
  );
}
