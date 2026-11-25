part of 'message_repo_sqlite.dart';

// =============================================================================
// 个人云端历史本地载体（FL-04；MH-01 §10.8：ack-cursor/检查点必须落账号 SQL DB，
// 禁用 SharedPreferences 存本域游标；§5 同一 SQLite 提交 = 消息+tombstone+检查点）。
//
// 表结构按需幂等建表（CREATE TABLE IF NOT EXISTS），不动 _dbVersion/迁移清单：
// 个人历史域是账号级独立存储，与投递队列平行的独立表族（§0）。
// =============================================================================

/// 个人历史域本地事件（存储层最小形状；业务解密在引擎层完成）。
class PersonalHistoryLocalEvent {
  const PersonalHistoryLocalEvent({
    required this.seq,
    required this.conversationId,
    required this.msgId,
    required this.actionVersion,
    required this.deleted,
    required this.plaintext,
    this.suppressed = false,
  });

  final int seq;
  final String conversationId;
  final String msgId;
  final int actionVersion;

  /// tombstone 事件（MSG-H15 稳定删除表达）。
  final bool deleted;

  /// Account recovery removal of a no-longer-proven restored version.
  final bool suppressed;

  /// 引擎解密后的明文行（deleted/suppressed 事件为空）。
  final Map<String, dynamic>? plaintext;
}

/// 一次事务化合并的结果。
class PersonalHistoryApplyResult {
  const PersonalHistoryApplyResult({
    required this.applied,
    required this.duplicates,
    required this.cursor,
    required this.generation,
  });

  /// 实际生效（新 seq）事件数。
  final int applied;

  /// 晚到/重复（seq 已合并过）被幂等跳过的事件数。
  final int duplicates;

  /// 事务提交后的持久检查点（单调，只进不退）。
  final int cursor;

  final int generation;
}

/// 个人历史域 SQL 载体（唯一 writer 事务边界由 sqflite Database 提供；
/// Web 平台的 VFS 持久确认在引擎层注入，见 PersonalHistorySyncEngine）。
class PersonalHistoryLocalStore {
  PersonalHistoryLocalStore(this._dbOpener, {String? nativeOwnerDigest})
    : _nativePrefix = _ownerPrefix(nativeOwnerDigest);

  final String _nativePrefix;

  static String _ownerPrefix(String? digest) {
    if (digest == null) return '';
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw ArgumentError('Invalid native personal history owner');
    }
    return 'native:$digest:';
  }

  String _projectionDomain(String domain) => '$_nativePrefix$domain';

  String _tombstoneConversation(
    String projectionDomain,
    String conversationId,
  ) => _nativePrefix.isEmpty
      ? conversationId
      : '$projectionDomain|$conversationId';

  final Future<Database?> Function() _dbOpener;

  static const String stateTable = 'personal_history_sync_state';
  static const String mergedEventTable = 'personal_history_merged_event';
  static const String tombstoneTable = 'personal_history_tombstone';
  static const String uploadQueueTable = 'personal_history_upload_queue';

  /// JS 安全整数上界（与 276-279 DDL 同域）。
  static const int maxSafeInteger = 9007199254740991;

  Future<Database?> _db() async {
    final db = await _dbOpener();
    if (db != null && db.isOpen) {
      // §10.8：本域检查点载体=账号 SQL DB；按 domain 主键（同账号可同时
      // 挂多部署实例，§0 三元隔离），代次+游标随行。
      await db.execute(
        'CREATE TABLE IF NOT EXISTS $stateTable ('
        'domain TEXT PRIMARY KEY, '
        'generation INTEGER NOT NULL, '
        'acked_cursor INTEGER NOT NULL DEFAULT 0, '
        'updated_at INTEGER NOT NULL)',
      );
      // §2.4：change log 按 账号/实例/代次 隔离且单调——去重账本以
      // (domain, generation, seq) 为主键（跨代次重开是全新日志，不共享 seq 账）。
      await db.execute(
        'CREATE TABLE IF NOT EXISTS $mergedEventTable ('
        'domain TEXT NOT NULL, '
        'generation INTEGER NOT NULL, '
        'seq INTEGER NOT NULL, '
        'conversation_id TEXT NOT NULL, '
        'msg_id TEXT NOT NULL, '
        'action_version INTEGER NOT NULL, '
        'merged_at INTEGER NOT NULL, '
        'PRIMARY KEY (domain, generation, seq))',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS $tombstoneTable ('
        'conversation_id TEXT NOT NULL, '
        'msg_id TEXT NOT NULL, '
        'deleted_at INTEGER NOT NULL, '
        'PRIMARY KEY (conversation_id, msg_id))',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS '
        'personal_history_restored_row ('
        'domain TEXT NOT NULL, '
        'generation INTEGER NOT NULL, '
        'conversation_id TEXT NOT NULL, '
        'msg_id TEXT NOT NULL, '
        'action_version INTEGER NOT NULL, '
        'row TEXT NOT NULL, '
        'merged_at INTEGER NOT NULL, '
        'PRIMARY KEY (domain, generation, conversation_id, msg_id, action_version))',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS $uploadQueueTable ('
        'idempotency_key TEXT PRIMARY KEY, '
        'conversation_id TEXT NOT NULL, '
        'msg_id TEXT NOT NULL, '
        'action_version INTEGER NOT NULL, '
        'conv_seq INTEGER NOT NULL, '
        'ciphertext TEXT NOT NULL, '
        'envelope_meta TEXT NOT NULL, '
        'domain TEXT NOT NULL, '
        'generation INTEGER NOT NULL, '
        'client_ts INTEGER NOT NULL, '
        'attempts INTEGER NOT NULL DEFAULT 0)',
      );
    }
    return db;
  }

  /// 当前持久检查点（域+代次）；无记录返回 null。
  Future<({int generation, int cursor})?> readCheckpoint(String domain) async {
    final db = await _db();
    if (db == null) return null;
    final rows = await db.query(
      stateTable,
      columns: ['generation', 'acked_cursor'],
      where: 'domain = ?',
      whereArgs: [_projectionDomain(domain)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      generation: rows.first['generation'] as int,
      cursor: rows.first['acked_cursor'] as int,
    );
  }

  /// 事务化合并：业务行、tombstone、去重账与检查点在同一 SQLite 提交。
  ///
  /// - seq 主键去重：晚到/重复事件幂等跳过，不回退持久进度（§8.2）。
  /// - 代次围栏：显式确认更高代次时才重置游标；拒绝旧代次回写。
  /// - 检查点单调：仅当 proposedCursor 大于现值才推进。
  Future<PersonalHistoryApplyResult> applyEvents({
    required String domain,
    required int generation,
    required List<PersonalHistoryLocalEvent> events,
    required int proposedCursor,
    bool allowGenerationAdvance = false,
    bool commitCheckpoint = true,
    bool allowSuppression = false,
    int? expectedCursor,
    required Future<void> Function(
      Transaction txn,
      PersonalHistoryLocalEvent event,
      String domain,
      int generation,
    )
    applyEvent,
    bool Function()? isCurrent,
  }) async {
    final db = await _db();
    if (db == null) {
      throw StateError('personal history store unavailable');
    }
    if (generation < 0 ||
        generation > maxSafeInteger ||
        proposedCursor < 0 ||
        proposedCursor > maxSafeInteger) {
      throw ArgumentError('personal history cursor out of domain');
    }
    final projectionDomain = _projectionDomain(domain);
    return db.transaction((txn) async {
      if (isCurrent?.call() == false) {
        throw StateError('personal history session changed');
      }
      final state = await txn.query(
        stateTable,
        columns: ['generation', 'acked_cursor'],
        where: 'domain = ?',
        whereArgs: [projectionDomain],
        limit: 1,
      );
      final recordedGeneration = state.isEmpty
          ? null
          : state.single['generation'] as int;
      final advancesGeneration =
          recordedGeneration != null && recordedGeneration != generation;
      if (recordedGeneration != null &&
          advancesGeneration &&
          (!allowGenerationAdvance || recordedGeneration > generation)) {
        throw StateError('personal history generation changed');
      }
      final currentCursor = recordedGeneration == generation
          ? state.first['acked_cursor'] as int
          : 0;

      if (expectedCursor != null && currentCursor != expectedCursor) {
        throw StateError('personal history checkpoint changed during recovery');
      }

      var applied = 0;
      var duplicates = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final event in events) {
        var hidden = 0;
        if (event.suppressed) {
          if (!allowSuppression || event.deleted || event.plaintext != null) {
            throw StateError('invalid personal history account suppression');
          }
          // Even a previously merged event can lose its accepted source proof.
          hidden = await txn.delete(
            'personal_history_restored_row',
            where:
                'domain = ? AND generation = ? AND conversation_id = ? '
                'AND msg_id = ? AND action_version <= ?',
            whereArgs: [
              projectionDomain,
              generation,
              event.conversationId,
              event.msgId,
              event.actionVersion,
            ],
          );
        }
        final dedup = await txn.insert(mergedEventTable, {
          'domain': projectionDomain,
          'generation': generation,
          'seq': event.seq,
          'conversation_id': event.conversationId,
          'msg_id': event.msgId,
          'action_version': event.actionVersion,
          'merged_at': now,
          // 晚到/重复 seq：账本主键冲突 → 幂等跳过，不重复应用业务效果。
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (dedup == 0 && hidden == 0) {
          duplicates++;
          continue;
        }
        applied++;
        if (event.suppressed) continue;
        if (event.deleted) {
          await txn.insert(tombstoneTable, {
            'conversation_id': _tombstoneConversation(
              projectionDomain,
              event.conversationId,
            ),
            'msg_id': event.msgId,
            'deleted_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await applyEvent(txn, event, projectionDomain, generation);
        }
      }

      final nextCursor = commitCheckpoint && proposedCursor > currentCursor
          ? proposedCursor
          : currentCursor;
      if (commitCheckpoint &&
          (nextCursor != currentCursor ||
              advancesGeneration ||
              recordedGeneration == null)) {
        await txn.insert(stateTable, {
          'domain': projectionDomain,
          'generation': generation,
          'acked_cursor': nextCursor,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (isCurrent?.call() == false) {
        throw StateError('personal history session changed during merge');
      }
      return PersonalHistoryApplyResult(
        applied: applied,
        duplicates: duplicates,
        cursor: nextCursor,
        generation: generation,
      );
    });
  }

  /// Updates only rows that still match the snapshot verified by the caller.
  Future<Set<String>> stampRestoredRowsForPage({
    required String domain,
    required int generation,
    required String conversationId,
    required List<
      ({String msgId, int actionVersion, String previous, String stamped})
    >
    stamps,
    required void Function() requireCurrent,
  }) async {
    if (stamps.isEmpty) return const {};
    if (stamps.length > 50) {
      throw ArgumentError('Personal history snapshot page exceeds 50 rows');
    }
    final db = await _db();
    requireCurrent();
    if (db == null) return const {};
    return db.transaction((txn) async {
      final confirmed = <String>{};
      for (final stamp in stamps) {
        requireCurrent();
        final affected = await txn.rawUpdate(
          'UPDATE personal_history_restored_row AS r SET row = ? '
          'WHERE r.domain = ? AND r.generation = ? AND r.conversation_id = ? '
          'AND r.msg_id = ? AND r.action_version = ? AND r.row = ? '
          'AND NOT EXISTS (SELECT 1 FROM $tombstoneTable AS t '
          'WHERE t.conversation_id = r.conversation_id AND t.msg_id = r.msg_id) '
          'AND NOT EXISTS (SELECT 1 FROM personal_history_restored_row AS newer '
          'WHERE newer.domain = r.domain AND newer.generation = r.generation '
          'AND newer.conversation_id = r.conversation_id AND newer.msg_id = r.msg_id '
          'AND newer.action_version > r.action_version)',
          [
            stamp.stamped,
            domain,
            generation,
            conversationId,
            stamp.msgId,
            stamp.actionVersion,
            stamp.previous,
          ],
        );
        if (affected == 1) confirmed.add(stamp.msgId);
      }
      requireCurrent();
      return confirmed;
    });
  }

  /// Read only the locally merged rows named by one server snapshot page.
  Future<List<Map<String, Object?>>> readRestoredRowsForPage({
    required String domain,
    required int generation,
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return const [];
    if (messageIds.length > 50) {
      throw ArgumentError('Personal history snapshot page exceeds 50 rows');
    }
    final db = await _db();
    if (db == null) return const [];
    final placeholders = List.filled(messageIds.length, '?').join(', ');
    return db.rawQuery(
      'SELECT r.msg_id, r.action_version, r.row FROM personal_history_restored_row AS r '
      'WHERE r.domain = ? AND r.generation = ? AND r.conversation_id = ? '
      'AND r.msg_id IN ($placeholders) '
      'AND NOT EXISTS (SELECT 1 FROM $tombstoneTable AS t '
      'WHERE t.conversation_id = r.conversation_id AND t.msg_id = r.msg_id) '
      'AND NOT EXISTS (SELECT 1 FROM personal_history_restored_row AS newer '
      'WHERE newer.domain = r.domain AND newer.generation = r.generation '
      'AND newer.conversation_id = r.conversation_id AND newer.msg_id = r.msg_id '
      'AND newer.action_version > r.action_version)',
      [domain, generation, conversationId, ...messageIds],
    );
  }

  /// 本机个人云端恢复副本。墓碑和更高动作版本优先于旧正文。
  Future<List<Map<String, Object?>>> readRestoredRows({
    required String domain,
    required int generation,
    String? conversationId,
    ({int mergedAt, String messageId, String conversationId})? after,
    int limit = 50,
  }) async {
    final db = await _db();
    if (db == null) return const [];
    final columns = conversationId == null
        ? 'r.conversation_id, r.merged_at, '
        : '';
    final filters = [
      if (conversationId != null) 'AND r.conversation_id = ? ',
      if (after != null)
        'AND (r.merged_at, r.msg_id, r.conversation_id) < (?, ?, ?) ',
    ].join();
    final tombstoneConversation = _nativePrefix.isEmpty
        ? 'r.conversation_id'
        : "r.domain || '|' || r.conversation_id";
    return db.rawQuery(
      'SELECT ${columns}r.msg_id, r.action_version, r.row FROM personal_history_restored_row AS r '
      'WHERE r.domain = ? AND r.generation = ? $filters'
      'AND NOT EXISTS (SELECT 1 FROM $tombstoneTable AS t '
      'WHERE t.conversation_id = $tombstoneConversation AND t.msg_id = r.msg_id) '
      'AND NOT EXISTS (SELECT 1 FROM personal_history_restored_row AS newer '
      'WHERE newer.domain = r.domain AND newer.generation = r.generation '
      'AND newer.conversation_id = r.conversation_id AND newer.msg_id = r.msg_id '
      'AND newer.action_version > r.action_version) '
      'ORDER BY r.merged_at DESC, r.msg_id DESC, r.conversation_id DESC LIMIT ?',
      [
        _projectionDomain(domain),
        generation,
        ?conversationId,
        if (after != null) ...[
          after.mergedAt,
          after.messageId,
          after.conversationId,
        ],
        limit.clamp(1, 50),
      ],
    );
  }

  /// 本地 tombstone 查询（删除进度/可恢复范围提示）。
  Future<bool> isTombstoned(
    String conversationId,
    String msgId, {
    String? domain,
  }) async {
    if (_nativePrefix.isNotEmpty && domain == null) {
      throw ArgumentError('Missing native personal history domain');
    }
    final db = await _db();
    if (db == null) return false;
    final rows = await db.query(
      tombstoneTable,
      columns: ['deleted_at'],
      where: 'conversation_id = ? AND msg_id = ?',
      whereArgs: [
        _tombstoneConversation(_projectionDomain(domain ?? ''), conversationId),
        msgId,
      ],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 入待上传队列（幂等键 = domain|generation|conversation|msg_id 主键去重）。
  Future<void> enqueueUpload({
    required String domain,
    required int generation,
    required String conversationId,
    required String msgId,
    required int actionVersion,
    required int convSeq,
    required String ciphertext,
    required Map<String, dynamic> envelopeMeta,
    required int clientTs,
  }) async {
    final db = await _db();
    if (db == null) {
      throw StateError('personal history store unavailable');
    }
    await db.insert(uploadQueueTable, {
      'idempotency_key':
          '$_nativePrefix$domain|$generation|$conversationId|$msgId',
      'conversation_id': conversationId,
      'msg_id': msgId,
      'action_version': actionVersion,
      'conv_seq': convSeq,
      'ciphertext': ciphertext,
      'envelope_meta': jsonEncode(envelopeMeta),
      'domain': domain,
      'generation': generation,
      'client_ts': clientTs,
      'attempts': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 只取当前代次的待上行项（账号切换/撤销后旧代次行不再重试）。
  Future<List<Map<String, Object?>>> pendingUploads(
    String domain,
    int generation, {
    int limit = 32,
    Set<String> excluding = const {},
  }) async {
    final db = await _db();
    if (db == null) return const [];
    final filters = [
      'domain = ? AND generation = ?',
      if (_nativePrefix.isNotEmpty) 'substr(idempotency_key, 1, ?) = ?',
      if (excluding.isNotEmpty)
        'idempotency_key NOT IN (${List.filled(excluding.length, '?').join(', ')})',
    ];
    return db.query(
      uploadQueueTable,
      where: filters.join(' AND '),
      whereArgs: [
        domain,
        generation,
        if (_nativePrefix.isNotEmpty) ...[_nativePrefix.length, _nativePrefix],
        ...excluding,
      ],
      orderBy: _nativePrefix.isEmpty
          ? 'client_ts ASC'
          : 'attempts ASC, client_ts ASC, idempotency_key ASC',
      limit: limit,
    );
  }

  Future<void> markUploadAttempted(String idempotencyKey) async {
    if (!idempotencyKey.startsWith(_nativePrefix)) return;
    final db = await _db();
    if (db == null) return;
    await db.rawUpdate(
      'UPDATE $uploadQueueTable SET attempts = attempts + 1 '
      'WHERE idempotency_key = ?',
      [idempotencyKey],
    );
  }

  Future<void> removeUpload(String idempotencyKey) async {
    if (!idempotencyKey.startsWith(_nativePrefix)) return;
    final db = await _db();
    if (db == null) return;
    await db.delete(
      uploadQueueTable,
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
    );
  }
}
