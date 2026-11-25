part of 'message_actions.dart';

/// 域实体映射辅助（自 MessageActions 抽出的扩展，行为与调用方零变更）
extension MessageActionsDomainMapping on MessageActions {
  ddd.UserId _currentUserId() => ddd.UserId.parse(UserRepoLocal.to.currentUid);

  /// store 层 MessageModel → 充血域实体 Message 的边界映射（T1.5）。
  /// canRevoke/canEdit 不使用 id，但实体构造需 MessageId；空 id/fromId 将由
  /// 值对象构造期拒绝（抛错 → 调用方返回 false，安全且不可撤回/编辑）。
  ddd.Message _toDomainMessage(MessageModel msg) => ddd.Message(
    id: ddd.MessageId.parse(msg.id.toString()),
    fromId: ddd.UserId.parse(msg.fromId.toString()),
    msgType: msg.msgType ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(msg.createdAt),
    status: _domainStatus(msg.status),
  );

  /// store 层 IMBoyMessageStatus（int）→ 域 MessageStatus 枚举映射。
  /// 未知/null 落 error（非 sent → canRevoke/canEdit 返回 false，与原
  /// `status != IMBoyMessageStatus.sent` 行为一致）。
  ddd.MessageStatus _domainStatus(int? code) => switch (code) {
    IMBoyMessageStatus.sending => ddd.MessageStatus.sending,
    IMBoyMessageStatus.sent => ddd.MessageStatus.sent,
    IMBoyMessageStatus.delivered => ddd.MessageStatus.delivered,
    IMBoyMessageStatus.seen => ddd.MessageStatus.seen,
    IMBoyMessageStatus.peerRevoked ||
    IMBoyMessageStatus.myRevoked => ddd.MessageStatus.revoked,
    _ => ddd.MessageStatus.error,
  };
}
