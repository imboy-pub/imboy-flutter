/// 多选可选性 traits 提取（chat_multi_select_v1 / W1-A；W5-G1 G1-7 自
/// chat_message_item.dart 抽离，行为零变化）。
///
/// 从 flutter_chat_core [Message] 提取多选可选性 traits（UI 边界映射），
/// 供 ChatPage（长按菜单入口）、多选接线（chat_multi_select_wiring.dart）
/// 与消息行（chat_message_item.dart）共用。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/modules/messaging/domain/message_status.dart'
    as domain_msg;
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 从 flutter_chat_core [Message] 提取多选可选性 traits（UI 边界映射）。
///
/// 字段口径与 W1-A handoff 一致：
/// - msgType=`metadata['msg_type']`（S2C/系统行可为 null → 不可选）；
///   元数据缺 msg_type 时按消息类兜底（TextMessage='text' 等，与
///   message_model_mapper 的 msg_type → 消息类映射互逆）—— 否则裸
///   TextMessage（metadata 只带 peer_id/burn 标志）会被误判为不可选；
/// - status：flutter_chat_core 状态映射域 [domain_msg.MessageStatus]，
///   null 映射为 sent（与 chat_page `resolveLongPressCapabilities` 同口径）；
/// - e2eeFailed=`metadata['_e2ee_failed'] == true`；
/// - burnReadAt=`metadata['burn_read_at']`（int，null 当 0）。
MessageSelectionTraits messageSelectionTraitsOf(Message message) {
  final meta = message.metadata;
  return MessageSelectionTraits(
    msgType: _multiSelectMsgTypeOf(message),
    status: switch (message.status) {
      MessageStatus.error => domain_msg.MessageStatus.error,
      MessageStatus.sending => domain_msg.MessageStatus.sending,
      MessageStatus.delivered => domain_msg.MessageStatus.delivered,
      MessageStatus.seen => domain_msg.MessageStatus.seen,
      MessageStatus.sent || null => domain_msg.MessageStatus.sent,
    },
    e2eeFailed: meta?['_e2ee_failed'] == true,
    burnReadAt: parseModelNullableInt(meta?['burn_read_at']) ?? 0,
  );
}

String? _multiSelectMsgTypeOf(Message message) {
  final metaType = message.metadata?['msg_type']?.toString();
  if (metaType != null && metaType.isNotEmpty) {
    return metaType;
  }
  // CustomMessage/SystemMessage 的类型完全由 metadata 驱动，无兜底
  // （null → 不可选，fail-closed）。
  if (message is TextMessage) return MessageType.text;
  if (message is ImageMessage) return MessageType.image;
  if (message is FileMessage) return MessageType.file;
  if (message is VideoMessage) return MessageType.video;
  if (message is AudioMessage) return MessageType.audio;
  return null;
}
