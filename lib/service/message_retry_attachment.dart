part of 'message_retry.dart';

/// 附件出站重试闸门（自 MessageRetry 类抽出的扩展，行为与调用方零变更）
extension MessageRetryAttachmentGate on MessageRetry {
  // A missing server result is not proof that an attachment message was unsent.
  bool _isAttachmentMessage(MessageModel message) => {
    'file',
    'image',
    'image_multi',
    'video',
    'audio',
    'voice',
    'location',
    'custom',
  }.contains(message.msgType);

  Future<bool> _claimAttachmentDispatch(
    MessageModel message,
    bool Function() isCurrent,
  ) => AttachmentUploadTaskRepo().claimOutboxDispatch(
    message.id,
    UserRepoLocal.to.currentUid,
    isCurrent: isCurrent,
  );

  Future<bool> _attachmentRetryBlocked(
    MessageModel message,
    bool Function() sessionValid, {
    MsgApi? api,
  }) async {
    if (!_isAttachmentMessage(message)) return false;
    final actor = UserRepoLocal.to;
    final uid = actor.currentUid;
    final uploads = AttachmentUploadTaskRepo();
    final rows = await uploads.findByAnchor(message.id, uid);
    if (!sessionValid()) return true;
    // V5 日志行的 business_intent 可为 NULL（纯上传 journal，如转发的明文
    // 附件重上传）——不属于 outbox 协议，与「无 V5 上传任务」同判，不阻断
    // 派发，也不走 isCommitted 复原（复原只对受协议管理的行有意义）。
    final managed = rows.where((row) => row.businessIntent != null).toList();
    if (managed.isEmpty) {
      return false; // Historical/plain-journal attachments have no V5 intent.
    }
    if (managed.every(
      (row) =>
          row.stage == AttachmentUploadStage.confirmed &&
          {
            'outbox_ready',
            'dispatch_reserved_v2',
          }.contains((jsonDecode(row.businessIntent!) as Map)['state']),
    )) {
      return false;
    }
    final committed = await (api ?? MsgApi()).isCommitted(
      chatType: _normalizeMessageType(message.type ?? '').toLowerCase(),
      peerId: message.toId.toString(),
      messageId: message.id,
    );
    if (!sessionValid() || actor.currentUid != uid) return true;
    final chatType = _normalizeMessageType(message.type ?? '').toLowerCase();
    Future<bool> reconcile() async {
      if (!sessionValid() || actor.currentUid != uid) return true;
      final changed = committed
          ? await uploads.reconcileOutboxCommitted(
              message.id,
              uid,
              isCurrent: sessionValid,
            )
          : await uploads.markOutboxUnknown(
              message.id,
              uid,
              chatType,
              isCurrent: sessionValid,
            );
      if (!changed || !sessionValid()) return true;
      final messages = getMessageRepo(message.type ?? '');
      if (!sessionValid()) return true;
      final updated = await messages.find(message.id);
      if (updated != null && sessionValid()) {
        if (committed) {
          ServerAckReceipts.announceVerified(
            message: updated,
            ownerUid: uid,
            generation: actor.sessionGeneration,
            isCurrent: sessionValid,
          );
        }
        final display = await updated.toTypeMessage();
        if (!sessionValid()) return true;
        AppEventBus.fireData([display], 'List<Message>');
      }
      return true;
    }

    return chatType == 'c2g'
        ? C2gSendGate.run(uid, message.id, reconcile)
        : reconcile();
  }
}
