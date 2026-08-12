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

/// 事务存储自身不可用（DB 故障/锁超时/schema 缺失）。
///
/// 与"校验未通过"严格区分：方向上两者都 fail-closed，但**分类必须准确**——
/// 把存储事故报成 `replay_detected` 会让运维把 DB 故障误判为重放攻击
/// （提案 25 §5.2）。服务层将其归类为 `crypto_store_unavailable`，
/// 语义同 [OlmStateCommitException]：可重试，非永久失败。
class CryptoStoreUnavailableException implements Exception {
  const CryptoStoreUnavailableException(this.message);
  final String message;
  @override
  String toString() => 'CryptoStoreUnavailableException: $message';
}

/// 密码学状态事务存储。
///
/// 五张表：
/// - `crypto_olm_session`: per-peer Olm session pickle（ratchet 状态）
/// - `crypto_outbox`: 已加密待发送的消息（崩溃恢复重发）
/// - `crypto_inbox_dedupe`: 已处理入站消息 ID（防重复 ratchet advance）
/// - `crypto_identity_pin`: TOFU identity fingerprint 固定（S3）
/// - `crypto_capability_hwm`: 协商协议等级高水位（S6 降级检测）
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

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_identity_pin (
        peer_uid       TEXT NOT NULL,
        peer_device_id TEXT NOT NULL,
        fingerprint    TEXT NOT NULL,
        pinned_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        PRIMARY KEY (peer_uid, peer_device_id)
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_capability_hwm (
        peer_uid       TEXT NOT NULL,
        peer_device_id TEXT NOT NULL,
        protocol       TEXT NOT NULL,
        updated_at     INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        PRIMARY KEY (peer_uid, peer_device_id)
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_session_sequence (
        session_id    TEXT PRIMARY KEY,
        last_sequence INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
      )
    ''');
  }

  // ─── Replay, Counter and Epoch Sequence tracking ───────────────────────────

  /// 获取 Session 的最新已处理序列号（防重放与乱序）。
  Future<int> getLastSequence(String sessionId) async {
    final List<Map<String, dynamic>> results = await _db.rawQuery(
      'SELECT last_sequence FROM crypto_session_sequence WHERE session_id = ?',
      [sessionId],
    );
    if (results.isEmpty) return 0;
    return results.first['last_sequence'] as int? ?? 0;
  }

  /// 更新 Session 的最新已处理序列号。
  Future<void> updateLastSequence(String sessionId, int sequence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawInsert(
      '''INSERT INTO crypto_session_sequence (session_id, last_sequence, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(session_id)
         DO UPDATE SET last_sequence = excluded.last_sequence, updated_at = excluded.updated_at''',
      [sessionId, sequence, now],
    );
  }

  /// 严格事务单向自增：在同一个 SQLite 事务中读取并更新序列号，
  /// 返回 true 表示合法且已更新，返回 false 表示重放。
  ///
  /// 这可以彻底防范高并发 WebSocket 连接下的 TOCTOU（先读后写）竞态条件。
  ///
  /// ⚠️ **当前无生产调用方**（E2EE-025 选项 C，已人工签字）：Olm/Megolm 的
  /// 重放防护由 `message_id` dedupe + ratchet 语义承担，接收侧不做序列检查。
  /// 保留本原语是给 MLS 用的，但 **MLS 不得直接复用**——本实现是**严格单调**，
  /// 而 ADR 15 §7.2（修订后仅适用于 MLS）要求 IPsec 式**滑动窗口**
  /// （high-water mark + bitmap + resync）。严格单调会误杀离线批量与乱序投递。
  ///
  /// 存储故障不再伪装成重放：抛 [CryptoStoreUnavailableException]，
  /// 由调用方归类为 `crypto_store_unavailable`（提案 25 §5.2 / ADR 15 §7.1）。
  Future<bool> checkAndUpdateSequence(String sessionId, int sequence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      return await _db.transaction((txn) async {
        final List<Map<String, dynamic>> results = await txn.rawQuery(
          'SELECT last_sequence FROM crypto_session_sequence WHERE session_id = ?',
          [sessionId],
        );
        final lastSeq = results.isEmpty
            ? 0
            : (results.first['last_sequence'] as int? ?? 0);
        if (sequence <= lastSeq) {
          return false; // 拒绝：重放或旧序列
        }

        await txn.rawInsert(
          '''INSERT INTO crypto_session_sequence (session_id, last_sequence, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(session_id)
             DO UPDATE SET last_sequence = excluded.last_sequence, updated_at = excluded.updated_at''',
          [sessionId, sequence, now],
        );
        return true; // 校验成功且原子持久化
      });
    } on Object catch (e) {
      // 方向仍是 fail-closed（不放行），但**分类必须准确**：把 DB 故障报成
      // `replay_detected` 会让运维把存储事故误判为攻击（提案 25 §5.2）。
      throw CryptoStoreUnavailableException('sequence check failed: $e');
    }
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

  /// 清除单个对端设备的 Olm session。
  ///
  /// 对端重装/换机后可能复用 device_id，但 identity key 已经变化；旧
  /// ratchet 不能继续发送到新身份。TOFU 指纹由上层保留，下一次建会话时
  /// 仍会触发身份变更确认，而不是静默信任新 key。
  Future<void> deleteSession({
    required String peerUid,
    required String peerDeviceId,
  }) async {
    await _db.rawDelete(
      'DELETE FROM crypto_olm_session WHERE peer_uid = ? AND peer_device_id = ?',
      [peerUid, peerDeviceId],
    );
  }

  /// 清除全部 Olm session（登出/换号）。
  ///
  /// E2EE-030 起 ratchet 状态只存在于本表（不再双写 SecureStorage），
  /// 故 [E2eeSecretInventory] 的 `olm_` 前缀擦除不再覆盖它，登出必须走这里。
  Future<void> deleteAllSessions() async {
    await _db.rawDelete('DELETE FROM crypto_olm_session');
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

  /// 独立 outbox 写入（不关联 session，PFv3 信封在 [E2eeOutboundRouter] 层提交）。
  ///
  /// 崩溃恢复：加密后先写 immutable outbox，提交成功才允许发送。
  ///
  /// 读侧接线状态（2026-08-02）：`confirmOutbox` 已接入 ACK 单一汇聚点
  /// （`MessageRetry` 的 RemoveFromRetryQueueRequestedEvent 监听）。重发路径
  /// 实测为**复用库中已提交信封**（不重新加密），验收项「byte-for-byte 相同
  /// 且 ratchet 只推进一次」经 `test/service/e2ee/outbox_read_side_wiring_test.dart`
  /// 实证。残留见 evidence/E2EE-027-followup.md（原子性属 ADR 02 冻结项）。
  Future<void> insertOutbox({
    required String id,
    required String payload,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawInsert(
      '''INSERT INTO crypto_outbox (id, payload, status, created_at)
         VALUES (?, ?, 'pending', ?)
         ON CONFLICT(id) DO UPDATE SET payload = excluded.payload''',
      [id, payload, now],
    );
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

  // ─── Identity Pin（S3: TOFU）─────────────────────────────────────────────────

  /// 固定对端设备 identity fingerprint（Trust On First Use）。
  ///
  /// 首次通信时写入；后续通信比对。用户确认换机后可覆盖（UPSERT）。
  Future<void> pinIdentity({
    required String peerUid,
    required String peerDeviceId,
    required String fingerprint,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawInsert(
      '''INSERT INTO crypto_identity_pin (peer_uid, peer_device_id, fingerprint, pinned_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(peer_uid, peer_device_id)
         DO UPDATE SET fingerprint = excluded.fingerprint, pinned_at = excluded.pinned_at''',
      [peerUid, peerDeviceId, fingerprint, now],
    );
  }

  /// 加载已固定的 fingerprint。未固定过的对端返回 null。
  Future<String?> loadPinnedFingerprint({
    required String peerUid,
    required String peerDeviceId,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT fingerprint FROM crypto_identity_pin WHERE peer_uid = ? AND peer_device_id = ?',
      [peerUid, peerDeviceId],
    );
    if (rows.isEmpty) return null;
    return rows.first['fingerprint'] as String?;
  }

  // ─── Capability HWM（S6: 降级检测）────────────────────────────────────────────

  /// 记录对端设备协商协议高水位（UPSERT）。
  Future<void> persistCapabilityHwm({
    required String peerUid,
    required String peerDeviceId,
    required String protocol,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawInsert(
      '''INSERT INTO crypto_capability_hwm (peer_uid, peer_device_id, protocol, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(peer_uid, peer_device_id)
         DO UPDATE SET protocol = excluded.protocol, updated_at = excluded.updated_at''',
      [peerUid, peerDeviceId, protocol, now],
    );
  }

  /// 加载对端设备历史最高协商协议。无记录返回 null。
  Future<String?> loadCapabilityHwm({
    required String peerUid,
    required String peerDeviceId,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT protocol FROM crypto_capability_hwm WHERE peer_uid = ? AND peer_device_id = ?',
      [peerUid, peerDeviceId],
    );
    if (rows.isEmpty) return null;
    return rows.first['protocol'] as String?;
  }
}
