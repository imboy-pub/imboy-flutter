part of 'chat_event_subscription_manager.dart';

/// 已确认图片刷新（自 ChatEventSubscriptionManager 抽出的扩展，行为与调用方零变更）
extension ChatEventConfirmedImageRefresh on ChatEventSubscriptionManager {
  Future<void> _refreshConfirmedImage(MessageSentEvent event) async {
    final owner = authSessionReader.current;
    bool current() =>
        !_disposed &&
        isCurrent?.call() != false &&
        authSessionReader.isCurrent(owner);
    if (!current() ||
        event.messageType != chatType ||
        event.conversationUk3 != conversationUk3 ||
        !ServerAckReceipts.contains(
          owner.uid,
          owner.generation,
          event.messageId,
          conversationUk3,
        )) {
      return;
    }
    final service = widgetRef.read(chatProvider.notifier).chatService;
    if (service == null ||
        !service.messages.any(
          (m) =>
              m.id == event.messageId &&
              m is ImageMessage &&
              m.authorId == owner.uid &&
              m.status == MessageStatus.sending &&
              m.metadata?['conversation_uk3'] == conversationUk3,
        ) ||
        !_refreshingCoreSent.add(event.messageId)) {
      return;
    }
    try {
      if (!{'C2C', 'C2G'}.contains(chatType)) return;
      Map<String, Object?>? canonical;
      const delays = [100, 250, 500, 1000, 2000, 4000, 8000, 16000, 30000];
      var attempt = 0;
      while (true) {
        if (!current() ||
            widgetRef.read(chatProvider.notifier).chatService != service ||
            !service.messages.any(
              (m) =>
                  m.id == event.messageId &&
                  m is ImageMessage &&
                  m.authorId == owner.uid &&
                  m.status == MessageStatus.sending &&
                  m.metadata?['conversation_uk3'] == conversationUk3,
            )) {
          return;
        }
        try {
          final db = await SqliteService.to.db.timeout(
            const Duration(seconds: 5),
          );
          if (!current() ||
              widgetRef.read(chatProvider.notifier).chatService != service) {
            return;
          }
          if (db == null) throw StateError('message database unavailable');
          final rows = await db
              .query(
                MessageRepo.getTableName(chatType),
                columns: [
                  'id',
                  'type',
                  'CAST(from_id AS TEXT) AS from_id',
                  'CAST(to_id AS TEXT) AS to_id',
                  'msg_type',
                  'conversation_uk3',
                  'status',
                ],
                where: 'id = ?',
                whereArgs: [event.messageId],
                limit: 2,
              )
              .timeout(const Duration(seconds: 5));
          if (rows.length != 1) return;
          canonical = rows.single;
          break;
        } on Object catch (error) {
          if (!current()) return;
          if (attempt == 0) {
            iPrint(
              '[chat_event_subscription_manager] confirmed image refresh: ${error.runtimeType}',
            );
          }
          final delay =
              delays[attempt < delays.length ? attempt : delays.length - 1];
          attempt++;
          await _waitCoreRetry(event.messageId, Duration(milliseconds: delay));
        }
      }
      final status = switch (canonical['status']) {
        IMBoyMessageStatus.sent => MessageStatus.sent,
        IMBoyMessageStatus.delivered => MessageStatus.delivered,
        IMBoyMessageStatus.seen => MessageStatus.seen,
        _ => null,
      };
      if (!current() ||
          canonical['id'] != event.messageId ||
          canonical['from_id'] != owner.uid ||
          canonical['to_id'] != peerId ||
          canonical['type'] != chatType ||
          canonical['msg_type'] != 'image' ||
          canonical['conversation_uk3'] != conversationUk3 ||
          status == null ||
          widgetRef.read(chatProvider.notifier).chatService != service) {
        return;
      }
      final index = service.messages.indexWhere((m) => m.id == event.messageId);
      if (index < 0) return;
      final old = service.messages[index];
      if (old is! ImageMessage ||
          old.authorId != owner.uid ||
          old.status != MessageStatus.sending ||
          old.metadata?['conversation_uk3'] != conversationUk3) {
        return;
      }
      await service.updateMessage(old, old.copyWith(status: status));
    } on Object catch (error) {
      iPrint(
        '[chat_event_subscription_manager] confirmed image refresh: ${error.runtimeType}',
      );
    } finally {
      _refreshingCoreSent.remove(event.messageId);
    }
  }
}
