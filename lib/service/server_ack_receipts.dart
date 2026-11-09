/// Receipts are recorded only by the validated server-ACK persistence path.
library;

import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart'
    show Database, DatabaseExecutor, ConflictAlgorithm;
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/message_model.dart';

class ServerAckReceipts {
  static final _receipts = <String>{};
  static void removeAccount(String uid) =>
      _receipts.removeWhere((key) => key.startsWith('$uid:'));
  static String _key(
    String uid,
    int generation,
    String id,
    String conversation,
  ) => '$uid:$generation:$id:$conversation';
  static bool contains(
    String uid,
    int generation,
    String id,
    String conversation,
  ) => _receipts.contains(_key(uid, generation, id, conversation));

  static Future<void> persistReceipt(
    DatabaseExecutor tx,
    String uid,
    String id,
    String type,
    String conversation,
  ) async {
    await tx.execute(
      'CREATE TABLE IF NOT EXISTS server_ack_receipt '
      '(user_id TEXT NOT NULL, anchor TEXT NOT NULL, chat_type TEXT NOT NULL, '
      'conversation TEXT NOT NULL, PRIMARY KEY(user_id, anchor, chat_type))',
    );
    await tx.insert('server_ack_receipt', {
      'user_id': uid,
      'anchor': id,
      'chat_type': type,
      'conversation': conversation,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> restoreDurable(String uid, int generation) async {
    final actor = UserRepoLocal.to;
    bool current() =>
        uid.isNotEmpty &&
        actor.currentUid == uid &&
        actor.isCurrentSession(generation) &&
        !actor.isAuthTransitioning;
    if (!current()) return;
    final db = await SqliteService.to.db;
    if (db == null || !current()) return;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['server_ack_receipt'],
    );
    if (tables.isEmpty || !current()) return;
    final receipts = await db.query(
      'server_ack_receipt',
      where: 'user_id = ?',
      whereArgs: [uid],
    );
    for (final receipt in receipts) {
      if (!current()) return;
      final type = receipt['chat_type'] as String;
      if (!{'C2C', 'C2G', 'C2S'}.contains(type)) continue;
      final message = await MessageRepo(
        tableName: MessageRepo.getTableName(type),
      ).find(receipt['anchor'] as String);
      if (message != null &&
          message.conversationUk3 == receipt['conversation'] &&
          current()) {
        announceVerified(
          message: message,
          ownerUid: uid,
          generation: generation,
          isCurrent: current,
        );
      }
    }
  }

  /// Validate the persisted outbound identity and commit every durable ACK effect
  /// together before in-memory retry removal or receipt notification.
  static Future<bool> persist({
    required Database db,
    required String ackId,
    required String ackType,
    required String ownerUid,
    required int expectedAutoId,
    required String expectedPeerId,
    bool requireAttempt = true,
    required bool Function() isCurrent,
  }) async {
    final match = RegExp(r'^(C2C|C2G|C2S)_SERVER_ACK$').firstMatch(ackType);
    if (match == null || ackId.isEmpty || ownerUid.isEmpty || !isCurrent()) {
      return false;
    }
    final chatType = match.group(1)!;
    final table = MessageRepo.getTableName(chatType);
    return db.transaction((tx) async {
      if (!isCurrent()) throw StateError('ack session changed');
      final rows = await tx.query(
        table,
        columns: [
          'auto_id',
          'id',
          'type',
          'to_id',
          'from_id',
          'is_author',
          'status',
          'conversation_uk3',
        ],
        where: 'id = ?',
        whereArgs: [ackId],
        limit: 1,
      );
      if (rows.length != 1) return false;
      final row = rows.single;
      final status = row['status'] as int?;
      var storedPeer = row['to_id'].toString();
      if (chatType == 'C2S') {
        final peerTables = await tx.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          ['c2s_message_peer'],
        );
        if (peerTables.isNotEmpty) {
          final peers = await tx.query(
            'c2s_message_peer',
            columns: ['peer'],
            where: 'user_id = ? AND message_id = ? AND auto_id = ?',
            whereArgs: [ownerUid, ackId, expectedAutoId],
            limit: 1,
          );
          if (peers.isNotEmpty) storedPeer = peers.single['peer'] as String;
        }
      }
      if (row['auto_id'] != expectedAutoId ||
          storedPeer != expectedPeerId ||
          row['type'] != chatType ||
          row['from_id'].toString() != ownerUid ||
          row['is_author'] != 1 ||
          (row['conversation_uk3']?.toString().isEmpty ?? true) ||
          !{
            IMBoyMessageStatus.sending,
            IMBoyMessageStatus.pendingRetry,
            IMBoyMessageStatus.error,
          }.contains(status)) {
        return false;
      }
      if (requireAttempt) {
        final attemptTables = await tx.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          ['message_send_attempt'],
        );
        if (attemptTables.isEmpty) return false;
        final attempts = await tx.query(
          'message_send_attempt',
          columns: ['token'],
          where: 'user_id = ? AND anchor = ?',
          whereArgs: [ownerUid, ackId],
          limit: 1,
        );
        if (attempts.isEmpty) return false;
      }
      final tables = await tx.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (?, ?)",
        ['attachment_upload_task', 'crypto_outbox'],
      );
      final names = tables.map((t) => t['name']).toSet();
      if (names.contains('attachment_upload_task')) {
        final uploads = await tx.query(
          'attachment_upload_task',
          where: 'anchor_msg_id = ? AND user_id = ?',
          whereArgs: [ackId, ownerUid],
        );
        for (final upload in uploads) {
          final intent = jsonDecode(
            upload['business_intent'] as String,
          ) as Map<String, dynamic>;
          if (upload['stage'] != 'confirmed' ||
              !{
                'dispatch_intent',
                'commit_unknown',
              }.contains(intent['state']) ||
              intent['author_id']?.toString() != ownerUid ||
              intent['chat_type']?.toString().toUpperCase() != chatType) {
            return false;
          }
        }
        for (final upload in uploads) {
          final intent = jsonDecode(
            upload['business_intent'] as String,
          ) as Map<String, dynamic>;
          await tx.update(
            'attachment_upload_task',
            {
              'business_intent': jsonEncode({...intent, 'state': 'committed'}),
            },
            where: 'id = ? AND user_id = ?',
            whereArgs: [upload['id'], ownerUid],
          );
        }
      }
      final count = await tx.update(
        table,
        {'status': IMBoyMessageStatus.sent},
        where: 'id = ? AND status = ? AND from_id = ?',
        whereArgs: [ackId, status, ownerUid],
      );
      if (count != 1) throw StateError('ack message CAS failed');
      if (names.contains('crypto_outbox')) {
        await tx.rawUpdate(
          "UPDATE crypto_outbox SET status = 'sent', sent_at = ? WHERE id = ? AND status = 'pending'",
          [DateTime.now().millisecondsSinceEpoch, ackId],
        );
      }
      await persistReceipt(
        tx,
        ownerUid,
        ackId,
        chatType,
        row['conversation_uk3'] as String,
      );
      if (!isCurrent()) throw StateError('ack session changed');
      return true;
    });
  }

  static void announceVerified({
    required MessageModel message,
    required String ownerUid,
    required int generation,
    required bool Function() isCurrent,
  }) {
    final ackType = '${message.type}_SERVER_ACK';
    if (!record(
      message: message,
      ackId: message.id,
      ackType: ackType,
      ownerUid: ownerUid,
      generation: generation,
      isCurrent: isCurrent,
      emit: AppEventBus.fire,
    )) {
      return;
    }
    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: message.id,
        messageType: ackType,
        reason: 'server_ack',
        ownerUid: ownerUid,
        sessionGeneration: generation,
      ),
    );
  }

  static bool record({
    required MessageModel? message,
    required String ackId,
    required String ackType,
    required String ownerUid,
    required int generation,
    required bool Function() isCurrent,
    required void Function(MessageSentEvent) emit,
  }) {
    if (!isCurrent() ||
        message == null ||
        !{
          IMBoyMessageStatus.sent,
          IMBoyMessageStatus.delivered,
          IMBoyMessageStatus.seen,
        }.contains(message.status) ||
        message.type == null ||
        message.id != ackId ||
        message.fromId.toString() != ownerUid ||
        ackType != '${message.type}_SERVER_ACK' ||
        message.conversationUk3.isEmpty) {
      return false;
    }
    final key = _key(ownerUid, generation, ackId, message.conversationUk3);
    if (_receipts.contains(key)) return false;
    if (_receipts.length >= 1024) _receipts.remove(_receipts.first);
    _receipts.add(key);
    emit(
      MessageSentEvent(
        messageId: ackId,
        messageType: message.type!,
        conversationUk3: message.conversationUk3,
        serverTimestamp: 0,
        sendDuration: 0,
      ),
    );
    return true;
  }
}
