part of 'message.dart';

/// Receipts update message rows and conversation heads in one transaction.
/// Chunked SQL avoids per-message writes and SQLite parameter-limit failures.
extension MessageReadReceipts on MessageService {
  Future<void> updateReadMessages(MessageRepo repo, List<String> ids) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    void requireCurrent() {
      if (uid.isEmpty ||
          session.currentUid != uid ||
          !session.isCurrentSession(generation) ||
          session.isAuthTransitioning) {
        throw StateError('read action session changed');
      }
    }

    requireCurrent();
    final uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) return;
    final messages = <MessageModel>[];
    final snapshots = <ConversationModel>[];
    await SqliteService.to.transaction((txn) async {
      final conversationIds = <int>{};
      for (var offset = 0; offset < uniqueIds.length; offset += 400) {
        requireCurrent();
        final end = (offset + 400).clamp(0, uniqueIds.length).toInt();
        final chunk = uniqueIds.sublist(offset, end);
        final targets = (await repo.findByIds(chunk, txn: txn))
            .where(
              (message) => !IMBoyMessageStatus.isRevokedStatus(message.status),
            )
            .toList();
        requireCurrent();
        // Receipts may race a local deletion or revocation. Missing/revoked
        // targets do not block the remaining IDs and must not be resurrected.
        if (targets.isEmpty) continue;
        final targetIds = targets.map((message) => message.id).toList();
        final updated = await repo.batchUpdateStatus(
          targetIds,
          IMBoyMessageStatus.seen,
          txn: txn,
        );
        requireCurrent();
        if (updated != targetIds.length) {
          throw StateError('read target update failed');
        }
        for (final message in targets) {
          message.status = IMBoyMessageStatus.seen;
        }
        messages.addAll(targets);
        final placeholders = List.filled(targetIds.length, '?').join(',');
        final where =
            '${ConversationRepo.userId} = ? AND '
            '${ConversationRepo.lastMsgId} IN ($placeholders)';
        final args = <Object?>[uid, ...targetIds];
        await txn.update(
          ConversationRepo.tableName,
          {ConversationRepo.lastMsgStatus: IMBoyMessageStatus.seen},
          where: where,
          whereArgs: args,
        );
        final rows = await txn.query(
          ConversationRepo.tableName,
          columns: [ConversationRepo.id],
          where: where,
          whereArgs: args,
        );
        conversationIds.addAll(
          rows.map((row) => row[ConversationRepo.id] as int),
        );
      }
      for (final id in conversationIds) {
        final snapshot = await _conversationRepo.findById(id, txn: txn);
        if (snapshot != null) snapshots.add(snapshot);
      }
      requireCurrent();
    });
    requireCurrent();
    SqliteService.to.clearQueryCache(repo.tableName);
    SqliteService.to.clearQueryCache(ConversationRepo.tableName);
    for (final snapshot in snapshots) {
      _conversationNotifier.applyConversationSnapshot(snapshot);
      AppEventBus.fireData(snapshot);
    }
    // Read receipts concern already-rendered messages; loading all models in
    // one query preserves the existing UI event contract without N lookups.
    final converted = await Future.wait(
      messages.map((msg) => msg.toTypeMessage()),
    );
    requireCurrent();
    if (converted.isNotEmpty) AppEventBus.fireData(converted, 'List<Message>');
  }
}
