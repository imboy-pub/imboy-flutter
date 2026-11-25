part of 'message_repo_sqlite.dart';

// 服务端权威排序补齐域（R07 phase1，W-W2 拆分）：MessageRepo 的
// backfillServerOrderFacts 实现与结果类型。仅为代码物理拆分，行为零变化。

/// [MessageRepo.backfillServerOrderFacts] 的结果（R07 phase1）。
class ServerOrderBackfillResult {
  const ServerOrderBackfillResult({
    required this.rowExists,
    required this.convSeqApplied,
    required this.acceptedAtApplied,
  });

  /// msg_id 在本表是否有行。
  final bool rowExists;

  /// 本次调用是否实际写入了 conv_seq（仅当列为 NULL 且传入了值）。
  final bool convSeqApplied;

  /// 本次调用是否实际写入了 accepted_at（仅当列为 NULL 且传入了值）。
  final bool acceptedAtApplied;

  @override
  String toString() =>
      'ServerOrderBackfillResult(rowExists: $rowExists, '
      'convSeqApplied: $convSeqApplied, acceptedAtApplied: $acceptedAtApplied)';
}

/// [MessageRepo.backfillServerOrderFacts] 的实现（同库顶层函数，repo 传入宿主实例）。
Future<ServerOrderBackfillResult> _backfillServerOrderFactsImpl(
  MessageRepo repo, {
  required String msgId,
  int? convSeq,
  int? acceptedAt,
  Transaction? txn,
}) async {
  if (convSeq == null && acceptedAt == null) {
    throw ArgumentError(
      'backfillServerOrderFacts: convSeq/acceptedAt 至少提供一个，'
      '否则无补齐目标（拒绝空操作误用）',
    );
  }

  Future<List<Map<String, Object?>>> readRow() {
    final sel =
        'SELECT ${MessageColumns.convSeq} AS seq, '
        '${MessageColumns.acceptedAt} AS accepted '
        'FROM ${repo.tableName} WHERE id = ? LIMIT 1';
    if (txn != null) return txn.rawQuery(sel, [msgId]);
    // 禁查询缓存：补齐判定必须读最新落库值
    return repo._db.rawQuery(sel, [msgId], false);
  }

  final rows = await readRow();
  if (rows.isEmpty) {
    return const ServerOrderBackfillResult(
      rowExists: false,
      convSeqApplied: false,
      acceptedAtApplied: false,
    );
  }
  final currentSeq = rows.first['seq'] as int?;
  final currentAccepted = rows.first['accepted'] as int?;
  final applySeq = convSeq != null && currentSeq == null;
  final applyAccepted = acceptedAt != null && currentAccepted == null;
  if (!applySeq && !applyAccepted) {
    // 幂等快速路径：无可补字段，不触碰库
    return ServerOrderBackfillResult(
      rowExists: true,
      convSeqApplied: false,
      acceptedAtApplied: false,
    );
  }

  // COALESCE 原子语义：仅 NULL 列接受新值；未传/已有值列保持不变
  final updateSql =
      'UPDATE ${repo.tableName} SET '
      '${MessageColumns.convSeq} = COALESCE(${MessageColumns.convSeq}, ?), '
      '${MessageColumns.acceptedAt} = COALESCE(${MessageColumns.acceptedAt}, ?) '
      'WHERE id = ?';
  final updateArgs = [convSeq, acceptedAt, msgId];
  if (txn != null) {
    await txn.rawUpdate(updateSql, updateArgs);
  } else {
    await repo._db.execute(updateSql, updateArgs);
  }
  return ServerOrderBackfillResult(
    rowExists: true,
    convSeqApplied: applySeq,
    acceptedAtApplied: applyAccepted,
  );
}
