import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:synchronized/synchronized.dart';

enum C2gSendCheck { allowed, held, terminal, identityMismatch }

/// Serializes a local rejection with the final send for the same message.
abstract final class C2gSendGate {
  static final _entries = <(String, String), _Entry>{};

  static Future<T> run<T>(
    String ownerUid,
    String messageId,
    Future<T> Function() operation,
  ) async {
    final key = (ownerUid, messageId);
    final entry = _entries.putIfAbsent(key, _Entry.new);
    entry.users++;
    try {
      return await entry.lock.synchronized(operation);
    } finally {
      entry.users--;
      if (entry.users == 0 && identical(_entries[key], entry)) {
        _entries.remove(key);
      }
    }
  }

  /// Called inside [run], immediately before sending the frame.
  static Future<C2gSendCheck> check(
    String ownerUid,
    String messageId,
    String? peerId,
  ) async {
    final db = await SqliteService.to.db;
    if (db == null) throw StateError('message database unavailable');
    final rows = await db.rawQuery(
      'SELECT status, CAST(from_id AS TEXT) AS from_id, '
      'CAST(to_id AS TEXT) AS to_id, type, is_author '
      'FROM msg_c2g WHERE id = ? LIMIT 1',
      [messageId],
    );
    if (rows.isEmpty) return C2gSendCheck.allowed;
    final row = rows.single;
    if (row['from_id']?.toString() != ownerUid ||
        row['to_id']?.toString() != peerId ||
        row['type'] != 'C2G' ||
        row['is_author'] != 1) {
      return C2gSendCheck.identityMismatch;
    }
    final status = row['status'];
    if (status == null ||
        status == 0 ||
        status == IMBoyMessageStatus.sending ||
        status == IMBoyMessageStatus.pendingRetry) {
      return C2gSendCheck.allowed;
    }
    if (status == IMBoyMessageStatus.outcomeUnknown) {
      return C2gSendCheck.held;
    }
    return C2gSendCheck.terminal;
  }
}

class _Entry {
  final lock = Lock();
  int users = 0;
}
