import 'package:imboy/store/model/message_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

/// Records a rejected attempt without claiming the message was not committed.
abstract final class C2gRejectionHold {
  static const int outcomeUnknown = IMBoyMessageStatus.outcomeUnknown;

  static Future<bool> persist({
    required Database db,
    required String messageId,
    required String ownerUid,
    required int expectedAutoId,
    required String expectedPeerId,
    required bool Function() isCurrent,
  }) async {
    if (messageId.isEmpty ||
        ownerUid.isEmpty ||
        expectedPeerId.isEmpty ||
        !isCurrent()) {
      return false;
    }
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('rejection session changed');
      final tables = await tx.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['message_send_attempt'],
      );
      if (tables.isEmpty) return false;
      final attempts = await tx.query(
        'message_send_attempt',
        columns: ['anchor'],
        where: 'user_id = ? AND anchor = ?',
        whereArgs: [ownerUid, messageId],
        limit: 1,
      );
      if (attempts.isEmpty) return false;
      final changed = await tx.update(
        'msg_c2g',
        {'status': outcomeUnknown},
        where:
            'id = ? AND auto_id = ? AND type = ? AND from_id = ? '
            'AND to_id = ? AND is_author = 1 AND conversation_uk3 IS NOT NULL '
            "AND conversation_uk3 != '' AND status IN (?, ?, ?)",
        whereArgs: [
          messageId,
          expectedAutoId,
          'C2G',
          ownerUid,
          expectedPeerId,
          IMBoyMessageStatus.sending,
          IMBoyMessageStatus.pendingRetry,
          IMBoyMessageStatus.error,
        ],
      );
      if (changed == 1) {
        final conversations = await tx.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          ['conversation'],
        );
        if (conversations.isNotEmpty) {
          await tx.update(
            'conversation',
            {'last_msg_status': outcomeUnknown},
            where:
                'user_id = ? AND peer_id = ? AND type = ? AND last_msg_id = ? '
                'AND (last_msg_status IS NULL OR last_msg_status IN (?, ?, ?, ?))',
            whereArgs: [
              ownerUid,
              expectedPeerId,
              'C2G',
              messageId,
              IMBoyMessageStatus.sending,
              IMBoyMessageStatus.pendingRetry,
              IMBoyMessageStatus.error,
              outcomeUnknown,
            ],
          );
        }
      }
      if (!isCurrent()) throw StateError('rejection session changed');
      return changed == 1;
    });
  }
}
