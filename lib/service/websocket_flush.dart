part of 'websocket.dart';

/// 消息队列冲刷逻辑（自 WebSocketService 抽出的扩展，行为与调用方零变更）
extension WebSocketQueueFlush on WebSocketService {
  /// 发送积压消息（优化版：加边界、异常、速率限制、并发防护）
  Future<void> _flushMessageQueue() async {
    if (!isWebWriterReady) return;
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      const int maxBatch = 10;
      const Duration minDelay = Duration(milliseconds: 30);

      int sentCount = 0;
      final deferred = <QueuedMessage>{};
      final session = UserRepoLocal.to;
      final ownerUid = session.currentUid;
      final generation = session.sessionGeneration;
      bool current() =>
          isWebWriterReady &&
          ownerUid.isNotEmpty &&
          session.currentUid == ownerUid &&
          session.isCurrentSession(generation) &&
          !session.isClearingSession;

      while (!_messageQueue.isEmpty && _status == SocketStatus.connected) {
        if (_channel == null || !current()) break;
        final queued = _messageQueue.reserveByPriority(
          eligible: (entry) =>
              !entry.quarantined &&
              !deferred.contains(entry) &&
              entry.ownerUid == ownerUid &&
              entry.sessionGeneration == generation,
        );
        if (queued == null) break;

        final selectedChannel = _channel;
        if (selectedChannel == null) {
          _messageQueue.releaseReservation(queued);
          break;
        }
        String? attemptAnchor;
        String? attemptToken;
        var began = false;
        var sinkInvoked = false;
        try {
          try {
            final outbound = OutboundMessage.parse(queued.data);
            final decoded = outbound.data;
            final queuedId = outbound.isControlAck ? null : outbound.id;
            if (queuedId != null && queuedId.isNotEmpty) {
              final uploads = AttachmentUploadTaskRepo();
              await uploads.claimOutboxDispatch(
                queuedId,
                ownerUid,
                isCurrent: current,
              );
              if (!current()) break;
              attemptAnchor = queuedId;
              attemptToken = _outboxAttemptToken();
              final permitted = await uploads.beginOutboxSend(
                queuedId,
                ownerUid,
                isCurrent: current,
                attemptToken: attemptToken,
              );
              began = permitted;
              if (permitted) await afterOutboxBeginForTest?.call();
              if (!current()) break;
              if (!permitted) {
                final chatType = decoded?['type']?.toString().toLowerCase();
                final peerId = decoded?['to']?.toString();
                Future<_QueueReconcileResult> reconcile() async {
                  if (chatType == 'c2g') {
                    final check = await C2gSendGate.check(
                      ownerUid,
                      queuedId,
                      peerId,
                    );
                    if (!current()) return _QueueReconcileResult.stale;
                    if (check == C2gSendCheck.terminal) {
                      return _QueueReconcileResult.terminal;
                    }
                    if (check == C2gSendCheck.identityMismatch) {
                      return _QueueReconcileResult.deferred;
                    }
                  }
                  var committed = false;
                  if ((chatType == 'c2c' || chatType == 'c2g') &&
                      peerId != null &&
                      peerId.isNotEmpty) {
                    try {
                      final lookup = outboxCommittedForTest;
                      committed =
                          await (lookup != null
                                  ? lookup(chatType!, peerId, queuedId)
                                  : MsgApi().isCommitted(
                                      chatType: chatType!,
                                      peerId: peerId,
                                      messageId: queuedId,
                                    ))
                              .timeout(const Duration(seconds: 2));
                    } on Object {
                      committed = false;
                    }
                  }
                  if (!current()) return _QueueReconcileResult.stale;
                  if (!committed ||
                      !await uploads.reconcileOutboxCommitted(
                        queuedId,
                        ownerUid,
                        isCurrent: current,
                      )) {
                    return _QueueReconcileResult.deferred;
                  }
                  final messages = MessageRepo(
                    tableName: MessageRepo.getTableName(
                      chatType!.toUpperCase(),
                    ),
                  );
                  final result = await messages.find(queuedId);
                  if (!current()) return _QueueReconcileResult.stale;
                  if (result != null) {
                    ServerAckReceipts.announceVerified(
                      message: result,
                      ownerUid: ownerUid,
                      generation: generation,
                      isCurrent: current,
                    );
                  }
                  return _QueueReconcileResult.completed;
                }

                final result = chatType == 'c2g'
                    ? await C2gSendGate.run(ownerUid, queuedId, reconcile)
                    : await reconcile();
                if (result == _QueueReconcileResult.stale) break;
                if (result == _QueueReconcileResult.completed ||
                    result == _QueueReconcileResult.terminal) {
                  _messageQueue.removeAccepted(queued);
                } else {
                  deferred.add(queued);
                }
                continue;
              }
            }
            if (!current() ||
                _status != SocketStatus.connected ||
                !identical(_channel, selectedChannel)) {
              if (began && current()) {
                await AttachmentUploadTaskRepo().cancelUnsentOutboxAttempt(
                  attemptAnchor!,
                  ownerUid,
                  attemptToken!,
                  isCurrent: current,
                );
              }
              break;
            }
            final result = await _guardedSend(
              message: queued.data,
              messageId: queuedId,
              ownerUid: ownerUid,
              current: () =>
                  current() &&
                  _status == SocketStatus.connected &&
                  identical(_channel, selectedChannel),
              send: () {
                final payload = _outboundPayload(outbound);
                final sink = selectedChannel.sink;
                requireWebWriter();
                sinkInvoked = true;
                sink.add(payload);
              },
            );
            if (result != _C2gSendResult.sent) {
              if (began && current()) {
                await AttachmentUploadTaskRepo().cancelUnsentOutboxAttempt(
                  attemptAnchor!,
                  ownerUid,
                  attemptToken!,
                  isCurrent: current,
                );
              }
              if (result == _C2gSendResult.terminal && current()) {
                _messageQueue.removeAccepted(queued);
                continue;
              }
              if ((result == _C2gSendResult.held ||
                      result == _C2gSendResult.conflict) &&
                  current()) {
                deferred.add(queued);
                continue;
              }
              break;
            }
            _messageQueue.removeAccepted(queued);
          } catch (_) {
            if (began && !sinkInvoked && current()) {
              await AttachmentUploadTaskRepo().cancelUnsentOutboxAttempt(
                attemptAnchor!,
                ownerUid,
                attemptToken!,
                isCurrent: current,
              );
            }
            rethrow;
          } finally {
            _messageQueue.releaseReservation(queued);
          }
          sentCount++;
          if (sentCount >= maxBatch) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            sentCount = 0;
          } else {
            await Future<void>.delayed(minDelay);
          }
        } catch (e) {
          iPrint('> ws: flushMessageQueue failed: ${e.runtimeType}');
          if (!current()) break;
          // sink.add 失败通常意味着 channel 已死（而非单条消息本身的问题），
          // 继续发送其余消息大概率会重复失败。主动清理并调度重连，而不是
          // 被动等待 onError/onDone（可能迟迟不触发，导致 _status 停留在
          // connected 但实际发不出消息的"僵尸连接"，队列永久卡住）。
          _cancelStream();
          _updateStatus(SocketStatus.disconnected);
          _scheduleReconnection();
          break;
        }
        if (_status != SocketStatus.connected) break;
      }
    } finally {
      _isFlushing = false;
    }
  }
}
