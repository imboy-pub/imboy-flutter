part of 'message.dart';

/// 服务端 ACK 与 C2G 拒收处理（自 MessageService 抽出的扩展，行为与调用方零变更）。
extension MessageServiceServerAck on MessageService {
  /// Handle server-side ACK for sent messages
  /// 处理服务端发送确认
  Future<void> _receiveC2gRejection(
    Map<String, dynamic> data, {
    String? ownerUid,
    int? sessionGeneration,
  }) async {
    if (data['type'] != 'C2G_ERROR' ||
        int.tryParse(data['code']?.toString() ?? '') != 403) {
      return;
    }
    final id = parseModelString(data['id']);
    final actor = UserRepoLocal.to;
    final uid = ownerUid ?? actor.currentUid;
    final generation = sessionGeneration ?? actor.sessionGeneration;
    bool current() =>
        isWebWriterReady &&
        uid.isNotEmpty &&
        actor.currentUid == uid &&
        actor.isCurrentSession(generation) &&
        !actor.isClearingSession &&
        !actor.isAuthTransitioning;
    if (id.isEmpty || !current()) return;

    try {
      await C2gSendGate.run(uid, id, () async {
        if (!current()) return;
        final repo = getMessageRepo('C2G');
        final message = await repo.find(id);
        if (!current() || message == null) return;
        final db = await SqliteService.to.db;
        if (!current() || db == null) return;
        final held = await C2gRejectionHold.persist(
          db: db,
          messageId: id,
          ownerUid: uid,
          expectedAutoId: message.autoId,
          expectedPeerId: message.toId.toString(),
          isCurrent: current,
        );
        if (!held || !current()) return;
        AppEventBus.fire(
          RemoveFromRetryQueueRequestedEvent(
            messageId: id,
            messageType: 'C2G',
            reason: 'server_rejection_unknown',
            ownerUid: uid,
            sessionGeneration: generation,
          ),
        );
        final updated = await repo.find(id);
        if (!current() || updated == null) return;
        final display = await updated.toTypeMessage();
        if (!current()) return;
        AppEventBus.fireData([display], 'List<Message>');
        if (updated.status == IMBoyMessageStatus.outcomeUnknown) {
          _conversationNotifier.applyPersistedLastMessageStatus(
            ownerUid: uid,
            generation: generation,
            conversationUk3: updated.conversationUk3,
            messageId: id,
            status: IMBoyMessageStatus.outcomeUnknown,
          );
        }
      });
    } on Object catch (error) {
      iPrint(
        '[C2G_ERROR] cannot preserve uncertain outcome: ${error.runtimeType}',
      );
    }
  }

  Future<void> _receiveServerAck(
    Map<String, dynamic> data, {
    String? ownerUid,
    int? sessionGeneration,
  }) async {
    final uid = ownerUid ?? UserRepoLocal.to.currentUid;
    final id = parseModelString(data['id']);
    if (data['type'] == 'C2G_SERVER_ACK' && uid.isNotEmpty && id.isNotEmpty) {
      await C2gSendGate.run(
        uid,
        id,
        () => _receiveServerAckLocked(
          data,
          ownerUid: uid,
          sessionGeneration: sessionGeneration,
        ),
      );
      return;
    }
    await _receiveServerAckLocked(
      data,
      ownerUid: ownerUid,
      sessionGeneration: sessionGeneration,
    );
  }

  Future<void> _receiveServerAckLocked(
    Map<String, dynamic> data, {
    String? ownerUid,
    int? sessionGeneration,
  }) async {
    ownerUid ??= UserRepoLocal.to.currentUid;
    final generation = sessionGeneration ?? UserRepoLocal.to.sessionGeneration;
    final msgId = parseModelString(data['id']);
    final type = parseModelString(data['type']);
    if (msgId.isEmpty || type.isEmpty) return;

    // 【改进】添加SERVER_ACK接收日志
    iPrint('📥 [SERVER_ACK] 收到服务端ACK: msgId=$msgId, type=$type');

    bool current() =>
        ownerUid!.isNotEmpty &&
        UserRepoLocal.to.currentUid == ownerUid &&
        UserRepoLocal.to.isCurrentSession(generation) &&
        !UserRepoLocal.to.isAuthTransitioning;
    if (!current()) return;
    // 针对频道消息的特殊处理
    if (type == 'C2CH_SERVER_ACK') {
      try {
        final rawPayload = data['payload'];
        final payload = rawPayload is String
            ? (jsonDecode(
                    rewriteChannelIds(
                      '{"payload":$rawPayload}',
                      ChannelResponseShape.socket,
                    ),
                  ) as Map<String, dynamic>)['payload']
                  as Map<String, dynamic>?
            : parseModelJsonMap(rawPayload);
        if (payload != null && payload.containsKey('id')) {
          final realId = channelDecimalId(payload['id']);
          final localId = channelDecimalId(msgId, allowNegative: true);
          if (realId != null &&
              localId != null &&
              BigInt.parse(localId) < BigInt.zero) {
            final updated = await ChannelMessageRepo().updateMessageId(
              localId,
              realId,
            );
            if (!updated) {
              iPrint('[SERVER_ACK] 频道临时消息不存在，跳过确认事件');
              return;
            }
            iPrint('✅ [SERVER_ACK] 频道消息已确认: 临时ID $localId -> 真实ID $realId');
            AppEventBus.fire(
              ChannelStateChangedEvent(
                channelId: payload['channel_id']?.toString() ?? '',
                action: 'message_ack',
                payload: {'local_id': localId, 'real_id': realId},
              ),
            );
          }
        }
      } on Object catch (e) {
        iPrint('❌ [SERVER_ACK] 频道消息ACK处理异常: $e');
      }
      return;
    }

    if (!current()) return;
    final chatType = type.endsWith('_SERVER_ACK')
        ? type.substring(0, type.length - '_SERVER_ACK'.length)
        : '';
    if (!{'C2C', 'C2G', 'C2S'}.contains(chatType)) {
      iPrint('[SERVER_ACK] 暂无可验证的服务端结果接口，保留待确认: $msgId');
      return;
    }
    final repo = getMessageRepo(chatType);
    final candidate = await repo.find(msgId);
    if (!current() ||
        candidate == null ||
        candidate.id != msgId ||
        candidate.type != chatType ||
        candidate.fromId.toString() != ownerUid ||
        candidate.isAuthor != 1 ||
        candidate.conversationUk3.isEmpty ||
        (!{
              IMBoyMessageStatus.sending,
              IMBoyMessageStatus.pendingRetry,
              IMBoyMessageStatus.error,
            }.contains(candidate.status) &&
            !(chatType == 'C2G' &&
                candidate.status == C2gRejectionHold.outcomeUnknown))) {
      return;
    }
    final peerId = chatType == 'C2S'
        ? (await repo.findC2sPeer(msgId, ownerUid, candidate.autoId) ??
              candidate.toId)
        : candidate.toId;
    if (!current() || peerId.isEmpty || peerId == '0') return;
    final unprotected = await AttachmentUploadTaskRepo()
        .allowUnprotectedActionAck(msgId, ownerUid, isCurrent: current);
    if (!current()) return;
    final requiresProof = !unprotected || chatType == 'C2S';
    if (requiresProof) {
      bool verified;
      try {
        verified = await MsgApi()
            .isCommitted(
              chatType: chatType.toLowerCase(),
              peerId: peerId,
              messageId: msgId,
            )
            .timeout(const Duration(seconds: 3));
      } on Object {
        verified = false;
      }
      if (!current() || !verified) {
        iPrint('[SERVER_ACK] 服务端结果未获正证，保留待确认: $msgId');
        return;
      }
    }
    final db = await SqliteService.to.db;
    if (db == null || !current()) return;
    final historySession = authSessionReader.current;
    final historyOwner = AccountLocalTaskOwner.capture(uid: ownerUid);
    final trackHistory =
        chatType == 'C2C' &&
        historySession.uid == ownerUid &&
        historySession.generation == generation;
    var historyQueued = false;
    final persisted = await ServerAckReceipts.persist(
      db: db,
      ackId: msgId,
      ackType: type,
      ownerUid: ownerUid,
      expectedAutoId: candidate.autoId,
      expectedPeerId: peerId,
      requireAttempt: requiresProof,
      isCurrent: current,
      persistAcceptedC2c: !trackHistory
          ? null
          : (tx) async {
              final accepted = await repo.find(msgId, txn: tx);
              if (accepted == null) {
                throw StateError('accepted C2C message disappeared');
              }
              historyQueued = await recordAcceptedPersonalHistoryC2cText(
                transaction: tx,
                session: historySession,
                owner: historyOwner,
                message: accepted,
                sequence: MessageModel.parseConvSeq(data['conv_seq']),
                outbound: true,
              );
            },
    );
    if (!persisted || !current()) return;
    if (historyQueued) {
      await confirmAcceptedPersonalHistoryC2cText(historySession, historyOwner);
    }
    final msg = await repo.find(msgId);
    if (!current() || msg == null) return;
    if (!ServerAckReceipts.record(
      message: msg,
      ackId: msgId,
      ackType: type,
      ownerUid: ownerUid,
      generation: generation,
      isCurrent: current,
      emit: AppEventBus.fire,
    )) {
      return;
    }
    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: msgId,
        messageType: type,
        reason: 'server_ack',
        ownerUid: ownerUid,
        sessionGeneration: generation,
      ),
    );

    iPrint('✅ [SERVER_ACK] 消息状态已更新为 sent: msgId=$msgId');
    final display = await msg.toTypeMessage();
    await beforeAckUiPublishForTest?.call();
    if (!current()) return;
    AppEventBus.fireData([display], 'messages');
    await _conversationNotifier.updateConversationByMsgId(msgId, {
      ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
    });
  }
}
