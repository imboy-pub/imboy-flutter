part of 'message_repo_sqlite.dart';

// FTS 索引域（W-W2 拆分）：MessageRepo 的延迟重索引实现与行快照。
// 仅为代码物理拆分，行为零变化；私有成员经同库可见性直接访问。

/// 行更新前预读的 FTS 相关旧值（contentless 索引清理依赖建索引时原值）。
class _FtsRowSnapshot {
  const _FtsRowSnapshot({
    required this.textContent,
    required this.conversationUk3,
  });

  /// 旧 payload/msg_type 抽取出的可索引文本。
  final String textContent;

  /// 旧会话键。
  final String conversationUk3;
}

/// [MessageRepo._reindexFts] 的实现（同库顶层函数，repo 传入宿主实例）。
Future<void> _reindexFtsImpl(
  MessageRepo repo,
  String id,
  String targetTable, {
  String? oldText,
  String? oldConversationUk3,
}) async {
  final session = UserRepoLocal.to;
  final uid = session.currentUid;
  final generation = session.sessionGeneration;
  bool isCurrent() =>
      session.currentUid == uid &&
      session.isCurrentSession(generation) &&
      !session.isClearingSession;
  try {
    await MessageRepo._ftsReindexLock.synchronized(() async {
      if (!isCurrent()) return;
      final target = targetTable == repo.tableName
          ? repo
          : MessageRepo(tableName: targetTable);
      final row = await target.find(id);
      if (row == null || !isCurrent()) return;
      final ftsType = targetTable == MessageRepo.c2cTable ? 'C2C' : 'C2G';
      final textContent = MessageFtsRepo.extractTextContent(
        row.msgType ?? '',
        row.payloadMap,
      );
      // 撤回状态区间 (30..39)，与 v38 FTS 表达式保持一致
      final revoked =
          row.status != null && row.status! >= 30 && row.status! < 40;
      final fts = MessageFtsRepo();
      if (revoked || textContent.isEmpty) {
        // 撤回/无可索引文本：清掉既有索引行，而不是原样跳过
        // （否则撤回/清空后的消息仍然可被搜到）。contentless FTS 的
        // 'delete' 命令需要**建立索引时的原值**，因此优先使用行更新
        // 前预读的旧文本/旧会话键；预读缺失时退化为当前行值
        // （仅对"值未变"的撤回场景有效，旧文本已变的历史残留交由
        // v38 重建收敛）。
        await fts.removeFromIndex(
          type: ftsType,
          id: id,
          conversationUk3: oldConversationUk3 ?? row.conversationUk3,
          textContent: oldText ?? textContent,
          rowid: row.autoId,
        );
        return;
      }
      await fts.indexMessage(
        type: ftsType,
        id: id,
        conversationUk3: row.conversationUk3,
        textContent: textContent,
        rowid: row.autoId,
      );
    });
  } on Object catch (e) {
    AppLogger.error(
      '[message_repo_sqlite] FTS reindex after update failed: '
      'errType=${e.runtimeType}',
    );
  }
}
