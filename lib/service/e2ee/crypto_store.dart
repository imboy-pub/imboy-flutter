/// S2.3: Transactional CryptoStore — 原子性密码状态持久化
///
/// 解决 FlutterSecureStorage 平铺 KV 无事务保证的问题：
/// - 发送侧：ratchet advance + session persist + outbox write 在同一 SQLite 事务
/// - 接收侧：dedupe check + ratchet advance + session persist 在同一 SQLite 事务
/// - 崩溃恢复：outbox 中 pending 条目可安全重发，dedupe 防重复推进 ratchet
///
/// 存储位于现有 SQLCipher DB（继承静态加密），不再依赖 FlutterSecureStorage
/// 做 session pickle 持久化（master pickle key 仍留在 Keychain/Keystore）。
library;

import 'package:sqflite_sqlcipher/sqflite.dart';

/// 密码学状态事务存储。
///
/// 三张表：
/// - `crypto_olm_session`: per-peer Olm session pickle（ratchet 状态）
/// - `crypto_outbox`: 已加密待发送的消息（崩溃恢复重发）
/// - `crypto_inbox_dedupe`: 已处理入站消息 ID（防重复 ratchet advance）
class CryptoStore {
  CryptoStore(this._db);

  final Database _db;

  /// 幂等建表。生产路径在 DB onUpgrade 中调用；测试路径在 setUp 中调用。
  Future<void> ensureSchema() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_olm_session (
        peer_uid      TEXT NOT NULL,
        peer_device_id TEXT NOT NULL,
        pickle        TEXT NOT NULL,
        created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        updated_at    INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        PRIMARY KEY (peer_uid, peer_device_id)
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_outbox (
        id         TEXT PRIMARY KEY,
        payload    TEXT NOT NULL,
        status     TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        sent_at    INTEGER
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_inbox_dedupe (
        message_id   TEXT PRIMARY KEY,
        processed_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
      )
    ''');
  }

  // ─── Olm Session ───────────────────────────────────────────────────────────

  /// 持久化 Olm session pickle（UPSERT 语义）。
  Future<void> persistSession({
    required String peerUid,
    required String peerDeviceId,
    required String pickle,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawInsert(
      '''INSERT INTO crypto_olm_session (peer_uid, peer_device_id, pickle, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(peer_uid, peer_device_id)
         DO UPDATE SET pickle = excluded.pickle, updated_at = excluded.updated_at''',
      [peerUid, peerDeviceId, pickle, now, now],
    );
  }

  /// 加载 Olm session pickle。不存在返回 null。
  Future<String?> loadSession({
    required String peerUid,
    required String peerDeviceId,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT pickle FROM crypto_olm_session WHERE peer_uid = ? AND peer_device_id = ?',
      [peerUid, peerDeviceId],
    );
    if (rows.isEmpty) return null;
    return rows.first['pickle'] as String?;
  }

  // ─── Outbox（发送侧）────────────────────────────────────────────────────────

  /// 原子操作：ratchet advance（session persist）+ outbox 写入。
  ///
  /// 在同一事务内完成，崩溃时两者一起回滚——不会出现
  /// "ratchet 已推进但消息未记录"的不一致状态。
  Future<void> persistSessionWithOutbox({
    required String peerUid,
    required String peerDeviceId,
    required String pickle,
    required String outboxId,
    required String payload,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.rawInsert(
        '''INSERT INTO crypto_olm_session (peer_uid, peer_device_id, pickle, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(peer_uid, peer_device_id)
           DO UPDATE SET pickle = excluded.pickle, updated_at = excluded.updated_at''',
        [peerUid, peerDeviceId, pickle, now, now],
      );
      await txn.rawInsert(
        '''INSERT INTO crypto_outbox (id, payload, status, created_at)
           VALUES (?, ?, 'pending', ?)''',
        [outboxId, payload, now],
      );
    });
  }

  /// 确认 outbox 条目已发送。
  Future<void> confirmOutbox(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      "UPDATE crypto_outbox SET status = 'sent', sent_at = ? WHERE id = ?",
      [now, id],
    );
  }

  /// 获取单条 outbox 记录。
  Future<Map<String, dynamic>?> getOutboxEntry(String id) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM crypto_outbox WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 返回所有 pending 状态的 outbox 条目（崩溃恢复重发用）。
  Future<List<Map<String, dynamic>>> pendingOutbox() async {
    return _db.rawQuery(
      "SELECT * FROM crypto_outbox WHERE status = 'pending' ORDER BY created_at ASC",
    );
  }

  /// 清理已确认的 outbox 条目。[olderThanMs] 为 0 时清理所有已确认条目。
  Future<void> purgeOutbox({required int olderThanMs}) async {
    if (olderThanMs <= 0) {
      await _db.rawDelete("DELETE FROM crypto_outbox WHERE status = 'sent'");
    } else {
      final cutoff = DateTime.now().millisecondsSinceEpoch - olderThanMs;
      await _db.rawDelete(
        "DELETE FROM crypto_outbox WHERE status = 'sent' AND sent_at < ?",
        [cutoff],
      );
    }
  }

  // ─── Inbox Dedupe（接收侧）──────────────────────────────────────────────────

  /// 原子操作：dedupe 检查 + ratchet advance（session persist）。
  ///
  /// 返回 true 表示首次处理（已推进 ratchet）；
  /// 返回 false 表示重复消息（事务回滚，ratchet 未变）。
  Future<bool> dedupeAndPersistSession({
    required String messageId,
    required String peerUid,
    required String peerDeviceId,
    required String pickle,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db.transaction((txn) async {
        // INSERT 会因 PRIMARY KEY 冲突抛异常 → 事务回滚
        await txn.rawInsert(
          'INSERT INTO crypto_inbox_dedupe (message_id, processed_at) VALUES (?, ?)',
          [messageId, now],
        );
        await txn.rawInsert(
          '''INSERT INTO crypto_olm_session (peer_uid, peer_device_id, pickle, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?)
             ON CONFLICT(peer_uid, peer_device_id)
             DO UPDATE SET pickle = excluded.pickle, updated_at = excluded.updated_at''',
          [peerUid, peerDeviceId, pickle, now, now],
        );
      });
      return true;
    } catch (_) {
      // UNIQUE constraint violation → 重复消息，事务已回滚
      return false;
    }
  }

  /// 独立查询：消息是否已处理过。
  Future<bool> isDuplicate(String messageId) async {
    final rows = await _db.rawQuery(
      'SELECT 1 FROM crypto_inbox_dedupe WHERE message_id = ?',
      [messageId],
    );
    return rows.isNotEmpty;
  }

  /// 清理旧的 dedupe 记录。[olderThanMs] 为 0 时清理所有记录。
  Future<void> purgeDedupe({required int olderThanMs}) async {
    if (olderThanMs <= 0) {
      await _db.rawDelete('DELETE FROM crypto_inbox_dedupe');
    } else {
      final cutoff = DateTime.now().millisecondsSinceEpoch - olderThanMs;
      await _db.rawDelete(
        'DELETE FROM crypto_inbox_dedupe WHERE processed_at < ?',
        [cutoff],
      );
    }
  }
}
