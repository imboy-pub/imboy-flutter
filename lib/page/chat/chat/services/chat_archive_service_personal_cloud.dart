part of 'chat_archive_service.dart';

// =============================================================================
// 个人云端历史同步引擎（FL-04；MH-01 §2/§5/§8；真服务合验在 MH-06）。
//
// 单趟语义（syncOnce）：
//  1. GET status —— 默认 OFF 不产生任何拉取/ACK（MSG-H01）。
//  2. GET changes(cursor) → 解密（密钥未就绪 → 显式 waitingKey，不静默跳过）。
//  3. 同一 SQLite 提交：合并行 + tombstone + 单调检查点（§5）。
//  4. 真实 VFS 持久确认（Web 注入 durableConfirm）成功后才 POST ack-cursor；
//     确认失败 → 保留旧持久状态与游标、拒绝 ACK（fail-closed，无「半确认」）。
//  5. 恢复行不产生新投递 ACK（本域与投递队列平行，§0；MSG-H08）。
//
// 上行队列（enqueueUpload/flushUploads）：幂等键去重、只重试当前代次；
// 账号/环境/代次切换由 isCurrent 围栏中止旧任务（MSG-H22）。
// =============================================================================

/// 单趟同步结果。
enum PersonalHistorySyncOutcomeKind {
  /// 云端关闭（默认 OFF）：无任何拉取/ACK。
  cloudOff,

  /// 已关闭上传与恢复，等待在线清理。
  purgePending,

  /// 授权已打开，当前代次尚未建立恢复密钥包。
  setupRequired,

  /// 已授权并验证本代次密钥包。
  cloudEnabled,

  /// 完整同步成功（含 ACK）。
  synced,

  /// 解密密钥未就绪：云端有事件但暂不可用（四维状态 → waitingKey）。
  waitingKey,

  /// 变更游标已超出服务端窗口，需要有界重扫。
  rescanRequired,

  /// VFS 持久确认失败：旧持久状态与游标保留，ACK 被拒绝。
  durabilityFailed,

  /// 事务已持久，但 ack-cursor 请求失败（服务端幂等，下趟补 ACK）。
  ackFailed,

  /// 上行队列部分成功（可重试项保留）。
  uploadPartial,

  /// 会话/账号/代次变更中止。
  aborted,

  /// 其他 fail-closed 失败。
  failed,
}

class PersonalHistorySyncOutcome {
  const PersonalHistorySyncOutcome({
    required this.kind,
    this.applied = 0,
    this.duplicates = 0,
    this.cursor = 0,
    this.uploaded = 0,
    this.recoveredText = const [],
    this.canContinueSnapshot = false,
    this.error,
  });

  final PersonalHistorySyncOutcomeKind kind;
  final int applied;
  final int duplicates;
  final int cursor;
  final int uploaded;
  final List<String> recoveredText;
  final bool canContinueSnapshot;
  final Object? error;
}

/// 个人云端历史同步引擎（无 UI 依赖；引擎可注入合同 fixture 驱动）。
class PersonalHistorySyncEngine {
  PersonalHistorySyncEngine({
    required this.client,
    required this.store,
    required this.domain,
    required this.decrypt,
    required this.isCurrent,
    this.durableConfirm,
    this.maxPages = 50,
  });

  final PersonalHistoryApiClient client;
  final PersonalHistoryLocalStore store;
  final String domain;

  /// 解密注入：返回 null 表示密钥未就绪（waitingKey）；抛错表示密文/AAD
  /// 校验失败（fail-closed，不推进游标，MSG-H19）。
  final Future<Map<String, dynamic>?> Function(PersonalHistoryEvent event)
  decrypt;

  /// 账号/环境/代次围栏：false 时中止并保留全部持久状态。
  final bool Function() isCurrent;

  /// Web 注入的真实 VFS 持久确认（bridge barrier）；null = 原生语义
  /// （SQL 提交即持久）。
  final Future<void> Function()? durableConfirm;

  final int maxPages;

  /// 单趟下行同步。
  Future<PersonalHistorySyncOutcome> syncOnce({
    PersonalHistoryStatus? expectedAuthorization,
  }) async {
    try {
      final status = await client.status();
      if (!isCurrent()) {
        return const PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.aborted,
        );
      }
      if (!status.enabled) {
        return const PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.cloudOff,
        );
      }
      if (expectedAuthorization != null &&
          (status.domain != domain ||
              !status.authorizesSameScope(expectedAuthorization))) {
        return const PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.aborted,
        );
      }
      final checkpoint = await store.readCheckpoint(domain);
      if (!isCurrent() ||
          (checkpoint != null && checkpoint.generation > status.generation)) {
        return const PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.aborted,
        );
      }
      // 代次变更：换新代次的 change log 起点（旧代次账本随 purge 失效）。
      var cursor = 0;
      if (checkpoint != null && checkpoint.generation == status.generation) {
        cursor = checkpoint.cursor;
      }
      final accountRecovery =
          expectedAuthorization != null &&
          client.clientInstance?.isNotEmpty == true;
      var totalApplied = 0;
      var totalDuplicates = 0;
      var pages = 0;
      int? recoveredAccountCursor;
      while (pages < maxPages) {
        if (!isCurrent()) {
          return const PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.aborted,
          );
        }
        final page = await client.changes(
          cursor: cursor,
          accountRecovery: accountRecovery,
        );
        if (!isCurrent() || page.generation != status.generation) {
          return const PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.aborted,
          );
        }
        if (page.resetHint) {
          if (!accountRecovery || recoveredAccountCursor != null) {
            return PersonalHistorySyncOutcome(
              kind: PersonalHistorySyncOutcomeKind.rescanRequired,
              applied: totalApplied,
              duplicates: totalDuplicates,
              cursor: cursor,
            );
          }
          final recovered = await _recoverAccountSnapshot(status, cursor);
          if (recovered.kind != PersonalHistorySyncOutcomeKind.synced) {
            return recovered;
          }
          totalApplied += recovered.applied;
          totalDuplicates += recovered.duplicates;
          recoveredAccountCursor = cursor = recovered.cursor;
          continue;
        }
        final localEvents = await _decryptLocalEvents(page.events);
        if (localEvents == null) {
          return PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.waitingKey,
            applied: totalApplied,
            duplicates: totalDuplicates,
            cursor: cursor,
          );
        }
        if (expectedAuthorization != null) {
          final live = await client.status();
          if (!isCurrent() || !live.authorizesSameScope(status)) {
            return const PersonalHistorySyncOutcome(
              kind: PersonalHistorySyncOutcomeKind.aborted,
            );
          }
        }
        final nextCursor = page.nextCursor ?? cursor;
        final result = await store.applyEvents(
          domain: domain,
          generation: status.generation,
          events: localEvents,
          proposedCursor: nextCursor,
          allowGenerationAdvance: expectedAuthorization != null,
          allowSuppression: accountRecovery,
          applyEvent: _applyMergedRow,
          isCurrent: isCurrent,
        );
        totalApplied += result.applied;
        totalDuplicates += result.duplicates;
        cursor = result.cursor;
        if (page.nextCursor == null || page.events.isEmpty) break;
        pages++;
      }
      // 真实 VFS 持久确认后才允许 ACK；确认失败 = 无「半确认」（§5/§10.8）。
      final confirm = durableConfirm;
      if (confirm != null) {
        try {
          await confirm();
        } on Object {
          return PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.durabilityFailed,
            applied: totalApplied,
            duplicates: totalDuplicates,
            cursor: cursor,
          );
        }
      }
      if (!isCurrent()) {
        return const PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.aborted,
        );
      }
      if (cursor != recoveredAccountCursor) {
        await client.ackCursor(cursor, generation: status.generation);
      }
      return PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.synced,
        applied: totalApplied,
        duplicates: totalDuplicates,
        cursor: cursor,
      );
    } on PersonalHistoryApiException catch (e) {
      return PersonalHistorySyncOutcome(
        kind: e.code == PersonalHistoryErrorCode.transientFailure || e.retryable
            ? PersonalHistorySyncOutcomeKind.failed
            : PersonalHistorySyncOutcomeKind.failed,
        error: e,
      );
    } on StateError catch (e) {
      return PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.aborted,
        error: e,
      );
    } on Object catch (e) {
      return PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.failed,
        error: e,
      );
    }
  }

  Future<List<PersonalHistoryLocalEvent>?> _decryptLocalEvents(
    List<PersonalHistoryEvent> events,
  ) async {
    final local = <PersonalHistoryLocalEvent>[];
    for (final event in events) {
      final hasBody = !event.deleted && !event.suppressed;
      final plaintext = hasBody ? await decrypt(event) : null;
      if (!isCurrent()) throw StateError('personal history owner changed');
      if (hasBody && plaintext == null) return null;
      local.add(
        PersonalHistoryLocalEvent(
          seq: event.seq,
          conversationId: event.conversationId,
          msgId: event.msgId,
          actionVersion: event.actionVersion,
          deleted: event.deleted,
          suppressed: event.suppressed,
          plaintext: plaintext,
        ),
      );
    }
    return local;
  }

  Future<PersonalHistorySyncOutcome> _recoverAccountSnapshot(
    PersonalHistoryStatus status,
    int startingCursor,
  ) async {
    String? token;
    final issuedTokenDigests = <Digest>{};
    var applied = 0;
    var duplicates = 0;
    var pagesSinceBarrier = 0;
    while (true) {
      if (!isCurrent()) throw StateError('personal history owner changed');
      final page = await client.accountSnapshot(pageToken: token);
      if (!isCurrent() || page.generation != status.generation) {
        throw const PersonalHistoryApiException(
          PersonalHistoryErrorCode.generationExpired,
          0,
        );
      }
      final nextToken = page.pageToken;
      if (nextToken != null &&
          !issuedTokenDigests.add(sha256.convert(utf8.encode(nextToken)))) {
        throw const PersonalHistoryApiException(
          PersonalHistoryErrorCode.malformedRequest,
          0,
        );
      }
      final events = await _decryptLocalEvents(page.events);
      if (events == null) {
        return PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.waitingKey,
          applied: applied,
          duplicates: duplicates,
          cursor: startingCursor,
        );
      }
      await _requireSnapshotGrant(status);
      final merged = await store.applyEvents(
        domain: domain,
        generation: status.generation,
        events: events,
        proposedCursor: startingCursor,
        expectedCursor: startingCursor,
        allowGenerationAdvance: true,
        commitCheckpoint: false,
        allowSuppression: true,
        applyEvent: _applyMergedRow,
        isCurrent: isCurrent,
      );
      applied += merged.applied;
      duplicates += merged.duplicates;
      token = nextToken;
      if (token == null) {
        return _completeAccountSnapshot(
          status: status,
          startingCursor: startingCursor,
          cursor: page.recoveryCursor!,
          completionToken: page.completionToken!,
          applied: applied,
          duplicates: duplicates,
        );
      }
      if (++pagesSinceBarrier == 8) {
        final durable = await _confirmSnapshotDurable();
        if (!durable) {
          return PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.durabilityFailed,
            applied: applied,
            duplicates: duplicates,
            cursor: startingCursor,
          );
        }
        pagesSinceBarrier = 0;
      }
    }
  }

  Future<PersonalHistorySyncOutcome> _completeAccountSnapshot({
    required PersonalHistoryStatus status,
    required int startingCursor,
    required int cursor,
    required String completionToken,
    required int applied,
    required int duplicates,
  }) async {
    if (cursor < startingCursor) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedRequest,
        0,
      );
    }
    if (!await _confirmSnapshotDurable()) {
      return PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.durabilityFailed,
        applied: applied,
        duplicates: duplicates,
        cursor: startingCursor,
      );
    }
    await _requireSnapshotGrant(status);
    try {
      await client.ackCursor(
        cursor,
        generation: status.generation,
        completionToken: completionToken,
      );
    } on PersonalHistoryApiException catch (error) {
      return PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.ackFailed,
        applied: applied,
        duplicates: duplicates,
        cursor: startingCursor,
        error: error,
      );
    }
    if (!isCurrent()) throw StateError('personal history owner changed');
    await store.applyEvents(
      domain: domain,
      generation: status.generation,
      events: const [],
      proposedCursor: cursor,
      expectedCursor: startingCursor,
      allowGenerationAdvance: true,
      applyEvent: _applyMergedRow,
      isCurrent: isCurrent,
    );
    final durable = await _confirmSnapshotDurable();
    return PersonalHistorySyncOutcome(
      kind: durable
          ? PersonalHistorySyncOutcomeKind.synced
          : PersonalHistorySyncOutcomeKind.durabilityFailed,
      applied: applied,
      duplicates: duplicates,
      cursor: durable ? cursor : startingCursor,
    );
  }

  Future<void> _requireSnapshotGrant(PersonalHistoryStatus status) async {
    if (!isCurrent()) throw StateError('personal history owner changed');
    final live = await client.status();
    if (!isCurrent() || !live.authorizesSameScope(status)) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.generationExpired,
        0,
      );
    }
  }

  Future<bool> _confirmSnapshotDurable() async {
    try {
      await durableConfirm?.call();
      return true;
    } on Object {
      return false;
    }
  }

  /// 合并行落库（恢复投影表；与投递链无关，不触发通知/未读/投递 ACK）。
  Future<void> _applyMergedRow(
    Transaction txn,
    PersonalHistoryLocalEvent event,
    String domain,
    int generation,
  ) async {
    final plaintext = event.plaintext;
    if (plaintext == null) return;
    await txn.insert('personal_history_restored_row', {
      'domain': domain,
      'generation': generation,
      'conversation_id': event.conversationId,
      'msg_id': event.msgId,
      'action_version': event.actionVersion,
      'row': jsonEncode(plaintext),
      'merged_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 上行队列冲刷：幂等键上传；transient 可重试；代次过期/未开启移除旧项。
  Future<PersonalHistorySyncOutcome> flushUploads({
    required int generation,
    int limit = 32,
    Set<String>? attemptedThisRun,
  }) async {
    var uploaded = 0;
    var retryableLeft = false;
    try {
      final pending = await store.pendingUploads(
        domain,
        generation,
        limit: limit,
        excluding: attemptedThisRun ?? const {},
      );
      for (final row in pending) {
        if (!isCurrent()) {
          return PersonalHistorySyncOutcome(
            kind: PersonalHistorySyncOutcomeKind.aborted,
            uploaded: uploaded,
          );
        }
        final key = row['idempotency_key'] as String;
        attemptedThisRun?.add(key);
        try {
          await client.upload({
            'conversation_id': row['conversation_id'],
            'msg_id': row['msg_id'],
            'action_version': row['action_version'],
            'conv_seq': row['conv_seq'],
            'generation': generation,
            'ciphertext': row['ciphertext'],
            'envelope_meta': jsonDecode(row['envelope_meta'] as String),
            'client_ts': row['client_ts'],
          });
          await store.removeUpload(key);
          uploaded++;
        } on PersonalHistoryApiException catch (e) {
          if (e.retryable) {
            await store.markUploadAttempted(key);
            retryableLeft = true;
          } else if (e.code == PersonalHistoryErrorCode.generationExpired ||
              e.code == PersonalHistoryErrorCode.notEnabled ||
              e.code == PersonalHistoryErrorCode.purgeInProgress) {
            // 旧代次/关闭后迟到上传：按合同丢弃（防复活，MSG-H22）。
            await store.removeUpload(key);
          } else {
            await store.markUploadAttempted(key);
            retryableLeft = true;
          }
        }
      }
      if (!isCurrent()) {
        return PersonalHistorySyncOutcome(
          kind: PersonalHistorySyncOutcomeKind.aborted,
          uploaded: uploaded,
        );
      }
      if (!retryableLeft &&
          (pending.length == limit || attemptedThisRun != null)) {
        final rest = await store.pendingUploads(domain, generation, limit: 1);
        retryableLeft = rest.isNotEmpty;
      }
    } on Object catch (e) {
      return PersonalHistorySyncOutcome(
        kind: PersonalHistorySyncOutcomeKind.failed,
        uploaded: uploaded,
        error: e,
      );
    }
    return PersonalHistorySyncOutcome(
      kind: retryableLeft
          ? PersonalHistorySyncOutcomeKind.uploadPartial
          : PersonalHistorySyncOutcomeKind.synced,
      uploaded: uploaded,
    );
  }
}
