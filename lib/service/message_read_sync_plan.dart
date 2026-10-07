import 'package:flutter/foundation.dart';

import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// message_read_sync S2C 事件的本地处理计划（Q04-F05：c2c→c2g 泛化）。
///
/// 事件来源：WebSocket S2C 帧 action=message_read_sync，由服务端在
/// msg_c2c_logic.erl 的 handle_read_receipt 落库后推送给阅读者本人
/// （多端未读数一致，T18/MSG-P1-6）。c2g 会话的同类事件由本计划
/// 服务端群事件使用 conversation_type/gid，旧事件使用 type/peer；
/// 缺少显式类型的旧事件由本地会话表判定。
class MessageReadSyncPlan {
  /// 目标会话类型（MessageFlowType.c2c / c2g）
  final String conversationType;

  /// 会话对端标识：c2c = 对方 uid；c2g = 群 gid
  final String peer;

  /// 被同步已读的消息 id 集合（服务端原样顺序，单调性由下游游标保证）
  final List<String> msgIds;

  const MessageReadSyncPlan({
    required this.conversationType,
    required this.peer,
    required this.msgIds,
  });

  /// 解析 message_read_sync payload 为处理计划；无法解析时返回 null。
  ///
  /// 消息 id 集合（与服务端 msg_c2c_logic.erl 的消费契约对齐）：
  /// - payload.msg_ids 批量优先——服务端现役契约中顶层 msg_id 是回执
  ///   自身的新 Xid，并非被读消息 id；
  /// - msg_ids 缺失/为空时回落单值 msg_id（旧契约兼容，此时 msg_id
  ///   才是被读消息 id）。
  ///
  /// 会话类型决策：
  /// - payload.conversation_type 显式声明优先，兼容旧 payload.type；
  /// - 缺失或非 C2C/C2G 值时由 [lookupConversationType] 按本地会话表
  ///   判定（生产实现：C2C 先于 C2G，保证既有 c2c 事件行为不变）；
  /// - 两者都无法判定返回 null（未知会话不误标记）。
  static Future<MessageReadSyncPlan?> build(
    Map<String, dynamic> payload, {
    Future<String?> Function(String peer)? lookupConversationType,
  }) async {
    final explicitType =
        normalizeConversationType(payload['conversation_type']) ??
        normalizeConversationType(payload['type']);
    final peer = parseModelString(
      explicitType == MessageFlowType.c2g
          ? payload['gid'] ?? payload['peer']
          : payload['peer'],
    );
    if (peer.isEmpty) return null;

    final msgIds = _parseMsgIds(payload);
    if (msgIds.isEmpty) return null;

    final conversationType =
        explicitType ?? await lookupConversationType?.call(peer);
    if (conversationType == null) return null;

    return MessageReadSyncPlan(
      conversationType: conversationType,
      peer: peer,
      msgIds: msgIds,
    );
  }

  /// 提取被读消息 id 集合：msg_ids 批量优先，回落单值 msg_id。
  static List<String> _parseMsgIds(Map<String, dynamic> payload) {
    final raw = payload['msg_ids'];
    if (raw is List) {
      final ids = [
        for (final e in raw)
          if (parseModelString(e).isNotEmpty) parseModelString(e),
      ];
      if (ids.isNotEmpty) return ids;
    }
    final single = parseModelString(payload['msg_id']);
    return single.isEmpty ? const <String>[] : <String>[single];
  }

  /// 规范化会话类型：仅认 C2C/C2G（已读同步不涉及其他流向），
  /// 其余值（缺失/CHANNEL/...）返回 null 交由本地查找兜底。
  @visibleForTesting
  static String? normalizeConversationType(Object? value) {
    final s = value?.toString().toUpperCase() ?? '';
    if (s == MessageFlowType.c2c) return MessageFlowType.c2c;
    if (s == MessageFlowType.c2g) return MessageFlowType.c2g;
    return null;
  }
}
