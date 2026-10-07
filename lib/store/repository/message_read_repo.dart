import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// Applies local read receipts without counting replayed or foreign messages.
class MessageReadRepo {
  static Future<({int unreadNum, List<String> msgIds})> apply(
    Database db,
    ConversationModel conversation,
    List<String> msgIds,
  ) => db.transaction((txn) async {
    final table = MessageRepo.getTableName(conversation.type);
    final matched = <String>[];
    var newlyRead = 0;
    for (final id in msgIds.toSet()) {
      final rows = await txn.query(
        table,
        columns: [MessageRepo.isAuthor, MessageRepo.status],
        where: '${MessageRepo.id}=? AND ${MessageRepo.conversationUk3}=?',
        whereArgs: [id, conversation.uk3],
      );
      if (rows.isEmpty ||
          (rows.first[MessageRepo.status] as int) > IMBoyMessageStatus.seen) {
        continue;
      }
      matched.add(id);
      final changed = await txn.update(
        table,
        {MessageRepo.status: IMBoyMessageStatus.seen},
        where:
            '${MessageRepo.id}=? AND ${MessageRepo.conversationUk3}=? '
            'AND ${MessageRepo.status}<?',
        whereArgs: [id, conversation.uk3, IMBoyMessageStatus.seen],
      );
      if (rows.first[MessageRepo.isAuthor] == 0) newlyRead += changed;
    }
    final unread = await _decrementUnread(txn, conversation.id, newlyRead);
    return (unreadNum: unread, msgIds: List<String>.unmodifiable(matched));
  });

  static Future<int> _decrementUnread(
    Transaction txn,
    int conversationId,
    int count,
  ) async {
    await txn.rawUpdate(
      'UPDATE ${ConversationRepo.tableName} '
      'SET ${ConversationRepo.unreadNum}=MAX(0,${ConversationRepo.unreadNum}-?) '
      'WHERE ${ConversationRepo.id}=?',
      [count, conversationId],
    );
    final rows = await txn.query(
      ConversationRepo.tableName,
      columns: [ConversationRepo.unreadNum],
      where: '${ConversationRepo.id}=?',
      whereArgs: [conversationId],
    );
    return rows.single[ConversationRepo.unreadNum] as int;
  }
}
