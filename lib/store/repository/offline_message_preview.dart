part of 'offline_message_writer.dart';

/// WebSocket API v2.0: 根据消息 status 和 payload 生成会话预览
///
/// 方案 D: 检查 status 字段（30=peer_revoked, 31=my_revoked）
({String msgType, String subtitle}) _derivePreview(
  String msgType,
  int? status,
  Map<String, dynamic> payload,
) {
  // 【重构】使用 MessageTypeNormalizer 做类型合法性校验
  final effectiveMsgType = MessageTypeNormalizer.normalize(
    msgType: msgType,
    payload: payload,
  );

  if (kDebugMode) {
    func_helper.iPrint(
      '🔍 [DEBUG _derivePreview] 输入: msgType="$msgType", effective=$effectiveMsgType',
    );
  }

  // 方案 D: 检查 status 字段（撤回状态 30-39）
  if (IMBoyMessageStatus.isRevokedStatus(status)) {
    // status = 30 (peer_revoked) 或 31 (my_revoked)
    // 保留原始 msg_type，让会话列表知道原始内容类型
    if (status == IMBoyMessageStatus.peerRevoked) {
      return (msgType: msgType, subtitle: '[${t.common.otherRevokedMessage}]');
    } else {
      return (msgType: msgType, subtitle: '[${t.common.youRevokedMessage}]');
    }
  }

  // 内容摘要全类型收口到 messagePreviewText（与会话列表/通知同一条链）。
  // 原白名单缺 groupTask/groupVote/groupSchedule/redPacket/transfer/
  // visitCard/expression/imageMulti/channelCard，这些类型一律落 default
  // 写成「[消息]」，下游按 subtitle 展示就与消息内容脱节。
  final subtitle = messagePreviewText(effectiveMsgType, payload);

  if (kDebugMode) {
    func_helper.iPrint(
      '🔍 [DEBUG _derivePreview] 返回: msgType=$effectiveMsgType',
    );
  }
  return (msgType: effectiveMsgType, subtitle: subtitle);
}
