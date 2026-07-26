/// S8: 加密审计日志（ADR 08 T2/T8 — Trust State 审计）
///
/// 所有安全相关事件写入 append-only 哈希链日志，达成两个目标：
/// - **可独立审计**：审计员调用 [verifyChain] 即可校验日志完整性，无需信任运行时。
/// - **防篡改**：每条事件的 [AuditEvent.eventHash] 绑定前一条的 hash（SHA-256
///   哈希链），任何对历史事件的修改/删除/插入都会破坏链连续性而被检测。
///
/// 记录的事件类型见 [AuditEventType]：identity 固定/变化、capability 降级、
/// KDF 迁移、设备验证、会话建立。
///
/// **哈希链边界（诚实声明）**：链可检测对**非尾部**历史的任何修改/插入/删除。
/// 尾部截断（删除最后若干条）本身不破坏剩余链的自洽性，需外部锚定（如周期性
/// 把头哈希提交到不可写存储/服务端透明日志）才能检测——这是 CT/ Sigsum 类
/// 透明日志的标准做法，属未来 S 阶段范畴。
///
/// 存储位于现有 SQLCipher DB（继承静态加密）。本类自持 `crypto_audit_log` 表，
/// 与 [CryptoStore] 平行（各自 ensureSchema）。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 安全审计事件类型。
class AuditEventType {
  AuditEventType._();

  /// S3 TOFU：首次固定对端 identity fingerprint。
  static const String identityPinned = 'identity_pinned';

  /// S3 TOFU：对端 identity fingerprint 变化（可能换机或 MITM）。
  static const String identityChanged = 'identity_changed';

  /// S6：对端协商能力降级（可能降级攻击）。
  static const String capabilityDowngraded = 'capability_downgraded';

  /// S7：KDF 版本迁移。
  static const String kdfMigrated = 'kdf_migrated';

  /// ADR 06：设备 trust_state 通过某种 VerificationMethod 达成。
  static const String trustStateVerified = 'trust_state_verified';

  /// Olm 会话建立（X3DH 完成）。
  static const String sessionEstablished = 'session_established';
}

/// 单条审计事件。
class AuditEvent {
  AuditEvent({
    required this.seq,
    required this.eventType,
    required this.peerUid,
    required this.peerDeviceId,
    required this.detail,
    required this.prevHash,
    required this.eventHash,
    required this.createdAt,
  });

  final int seq;
  final String eventType;
  final String peerUid;
  final String peerDeviceId;
  final String detail;
  final String prevHash;
  final String eventHash;
  final int createdAt;
}

/// append-only 哈希链审计日志。
class CryptoAuditLog {
  CryptoAuditLog(this._db);

  final Database _db;

  /// 创世事件（seq=1）的 prev_hash 固定值。
  static const String genesisHash = 'GENESIS';

  /// 幂等建表。
  Future<void> ensureSchema() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS crypto_audit_log (
        seq            INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type     TEXT NOT NULL,
        peer_uid       TEXT NOT NULL DEFAULT '',
        peer_device_id TEXT NOT NULL DEFAULT '',
        detail         TEXT NOT NULL DEFAULT '',
        prev_hash      TEXT NOT NULL,
        event_hash     TEXT NOT NULL,
        created_at     INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
      )
    ''');
  }

  /// 追加一条事件，自动计算哈希链。
  ///
  /// [eventHash] = SHA-256(seq | event_type | peer_uid | peer_device_id |
  ///                       detail | prev_hash | created_at)
  Future<void> append(
    String eventType, {
    String peerUid = '',
    String peerDeviceId = '',
    String detail = '',
  }) async {
    final prevHash = await _lastEventHash();
    final now = DateTime.now().millisecondsSinceEpoch;
    // seq 由 AUTOINCREMENT 决定；先取下一个 seq 用于哈希绑定
    final nextSeq = await _nextSeq();

    final eventHash = _computeHash(
      seq: nextSeq,
      eventType: eventType,
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
      detail: detail,
      prevHash: prevHash,
      createdAt: now,
    );

    await _db.rawInsert(
      '''INSERT INTO crypto_audit_log
         (event_type, peer_uid, peer_device_id, detail, prev_hash, event_hash, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [eventType, peerUid, peerDeviceId, detail, prevHash, eventHash, now],
    );
  }

  /// 读取最近 [limit] 条事件（按 seq 升序）。
  Future<List<AuditEvent>> recent({required int limit}) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM crypto_audit_log ORDER BY seq ASC LIMIT ?',
      [limit],
    );
    return rows.map(_fromRow).toList();
  }

  /// 校验整条哈希链完整性。
  ///
  /// 逐条重算 event_hash 并比对，同时验证 prev_hash 链连续性。
  /// 任何篡改（修改/删除/插入）都会返回 false。空日志返回 true。
  Future<bool> verifyChain() async {
    final rows = await _db.rawQuery(
      'SELECT * FROM crypto_audit_log ORDER BY seq ASC',
    );
    if (rows.isEmpty) return true;

    var expectedPrev = genesisHash;
    var expectedSeq = 1;
    for (final row in rows) {
      final e = _fromRow(row);
      // 链连续性：seq 必须连续（检测删除/插入）
      if (e.seq != expectedSeq) return false;
      // prev_hash 必须等于前一条的 event_hash
      if (e.prevHash != expectedPrev) return false;
      // 重算 event_hash 必须匹配（检测字段篡改）
      final recomputed = _computeHash(
        seq: e.seq,
        eventType: e.eventType,
        peerUid: e.peerUid,
        peerDeviceId: e.peerDeviceId,
        detail: e.detail,
        prevHash: e.prevHash,
        createdAt: e.createdAt,
      );
      if (recomputed != e.eventHash) return false;

      expectedPrev = e.eventHash;
      expectedSeq++;
    }
    return true;
  }

  // ─── 内部辅助 ────────────────────────────────────────────────────────────────

  Future<String> _lastEventHash() async {
    final rows = await _db.rawQuery(
      'SELECT event_hash FROM crypto_audit_log ORDER BY seq DESC LIMIT 1',
    );
    if (rows.isEmpty) return genesisHash;
    return rows.first['event_hash'] as String;
  }

  Future<int> _nextSeq() async {
    final rows = await _db.rawQuery(
      'SELECT MAX(seq) AS m FROM crypto_audit_log',
    );
    final m = rows.first['m'];
    return (m == null ? 0 : (m as int)) + 1;
  }

  String _computeHash({
    required int seq,
    required String eventType,
    required String peerUid,
    required String peerDeviceId,
    required String detail,
    required String prevHash,
    required int createdAt,
  }) {
    final payload =
        '$seq|$eventType|$peerUid|$peerDeviceId|$detail|$prevHash|$createdAt';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  AuditEvent _fromRow(Map<String, dynamic> row) {
    return AuditEvent(
      seq: row['seq'] as int,
      eventType: row['event_type'] as String,
      peerUid: row['peer_uid'] as String,
      peerDeviceId: row['peer_device_id'] as String,
      detail: row['detail'] as String,
      prevHash: row['prev_hash'] as String,
      eventHash: row['event_hash'] as String,
      createdAt: row['created_at'] as int,
    );
  }
}
