part of 'dual_account_message_flow_test.dart';

/// 离线批量断言（J01 收尾）：本地库中本轮 23 条离线 marker
/// 1) 恰好 N 条消息（各一份，无重复无缺失）；2) 按 conv_seq（服务端序列）
/// 升序与序号 01..N 完全一致。这是落库证据，UI 上屏证据由调用方的
/// _waitForMarker（末条）先行取得。
/// j01r7 实证：LIKE 会捎带 typing 草稿回显行（action=message_input 的
/// payload 内嵌不完整草稿，如 ...j01r7-2），必须按完整序号 marker 提取
/// 并跳过非消息行，只对真实消息行断言。
Future<void> _assertOfflineBatchViaDb(WidgetTester tester) async {
  const seqCol = 'conv_seq';
  final markerRe = RegExp('P0-OFFLINE-$_runId-(\\d{2})');
  final rows = await SqliteService.to.query(
    MessageRepo.c2cTable,
    columns: [...MessageRepo.c2cColumns, seqCol],
    where: '${MessageRepo.payload} LIKE ?',
    whereArgs: ['%P0-OFFLINE-$_runId-%'],
    orderBy: '$seqCol ASC',
  );
  final expected = List.generate(
    _offlineCount,
    (i) => 'P0-OFFLINE-$_runId-${(i + 1).toString().padLeft(2, '0')}',
  );
  // 完整序号 marker → (conv_seq, 重复次数)；不含完整 marker 的行是
  // typing 草稿/action 回显，不计入批断言。
  final seqByMarker = <String, int?>{};
  var skippedEchoRows = 0;
  for (final row in rows) {
    final payload = '${row[MessageRepo.payload]}';
    final m = markerRe.firstMatch(payload);
    if (m == null) {
      skippedEchoRows++;
      continue;
    }
    final marker = m.group(0)!;
    if (!expected.contains(marker)) {
      fail('发现本轮命名空间外的完整 marker：$marker');
    }
    if (seqByMarker.containsKey(marker)) {
      fail('离线消息重复落库：$marker 出现多次（各一份契约被破坏）');
    }
    seqByMarker[marker] = row[seqCol] as int?;
  }
  flowLog(
    '离线批量提取：消息 ${seqByMarker.length}/$_offlineCount，'
    '跳过草稿/action 回显行 $skippedEchoRows',
  );
  final missing = expected.where((m) => !seqByMarker.containsKey(m)).toList();
  if (missing.isNotEmpty) {
    fail('离线消息缺失：${missing.join(', ')}（共 ${missing.length} 条未落库）');
  }
  final actualInSeqOrder = seqByMarker.keys.toList();
  final missingSeq = <String>[];
  for (final e in seqByMarker.entries) {
    if (e.value == null) missingSeq.add(e.key);
  }
  if (missingSeq.isNotEmpty) {
    fail('以下消息 conv_seq 为空，无法证明服务端序列：${missingSeq.join(', ')}');
  }
  for (var i = 0; i < expected.length; i++) {
    if (actualInSeqOrder[i] != expected[i]) {
      fail(
        '服务端序列错位：conv_seq 第${i + 1}条应为 ${expected[i]}，'
        '实际 ${actualInSeqOrder[i]}（全序：${actualInSeqOrder.join(' → ')}）',
      );
    }
  }
  flowLog('离线批量 DB 断言完成：$_offlineCount 条消息各一份、conv_seq 升序与序号一致');
}

/// 已读标记持久化断言（J01 g3）：「已读/未读重启不反弹」。
/// 接收方的已读是可视阈值驱动（enableVisibilityRead + VisibilityDetector +
/// 每条消息延迟计时，仅对实际滚入视口的消息触发 markAsRead→seen(21) 并
/// 按 MessageReadRepo.apply 扣减会话 unread_num），23 条批量里滚出视口的
/// 消息允许保持未读，因此本断言不要求「全部已读」，只要求已读状态
/// 单调不回退：
/// 1) 短暂等待可视已读落定后，快照本轮 N 条的 seen 数与会话 unread_num；
/// 2) 离开并重进会话（页级重启代理，与普通闭环的重进同口径）后复查：
///    seen 数不得减少、unread_num 不得增加 —— 已读不反弹；
/// 3) 任何消息进入 error(41) 立即失败。
///
/// 进程级「已读→重启 App→仍已读」由合同 dual-sequential 接收阶段重放覆盖：
/// 同 TEST_DUAL_RUN_ID 再执行一次 receiver 即为新进程读同一持久化库，
/// 重放轮再次取得快照并与本轮单调口径比对（execution_contract.json basis
/// 已登记该重放口径；重放轮不重发消息，离线批量 DB 断言直接命中已落库行）。
Future<void> _assertReadStatePersisted(WidgetTester tester) async {
  final markerRe = RegExp('P0-OFFLINE-$_runId-(\\d{2})');

  Future<Map<String, int>> statusByMarker() async {
    final rows = await SqliteService.to.query(
      MessageRepo.c2cTable,
      columns: MessageRepo.c2cColumns,
      where: '${MessageRepo.payload} LIKE ?',
      whereArgs: ['%P0-OFFLINE-$_runId-%'],
    );
    final statusByMarker = <String, int>{};
    for (final row in rows) {
      final m = markerRe.firstMatch('${row[MessageRepo.payload]}');
      if (m == null) continue; // typing 草稿/action 回显行不计入
      final raw = row[MessageRepo.status];
      statusByMarker[m.group(0)!] = raw is int
          ? raw
          : int.tryParse('$raw') ?? -1;
    }
    return statusByMarker;
  }

  Future<int> unreadNumOfConversation() async {
    final rows = await SqliteService.to.query(
      ConversationRepo.tableName,
      columns: [ConversationRepo.unreadNum],
      where: '${ConversationRepo.peerId} = ? AND ${ConversationRepo.type} = ?',
      whereArgs: [_peerUid, 'C2C'],
      limit: 1,
    );
    if (rows.isEmpty) return -1;
    final raw = rows.first[ConversationRepo.unreadNum];
    return raw is int ? raw : int.tryParse('$raw') ?? -1;
  }

  String describe(Map<String, int> snapshot, int unread) {
    final notSeen = snapshot.entries
        .where((e) => e.value != IMBoyMessageStatus.seen)
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    return 'unread_num=$unread，非 seen=[$notSeen]';
  }

  // 1) 等待可视已读落定（在屏消息的延迟计时 + 回执 flush 给足窗口）。
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  var snapshot = <String, int>{};
  var unread = -1;
  var prevReadCount = -1;
  var stableRounds = 0;
  while (DateTime.now().isBefore(deadline) && stableRounds < 3) {
    snapshot = await statusByMarker();
    unread = await unreadNumOfConversation();
    if (snapshot.values.any((s) => s == IMBoyMessageStatus.error)) {
      fail('离线批量消息进入 error，无法完成已读持久化断言：${describe(snapshot, unread)}');
    }
    final readCount = snapshot.values
        .where((s) => s == IMBoyMessageStatus.seen)
        .length;
    if (readCount == prevReadCount && readCount >= 0) {
      stableRounds++;
    } else {
      stableRounds = 0;
    }
    prevReadCount = readCount;
    await tester.pump(const Duration(milliseconds: 500));
  }
  final readCount = snapshot.values
      .where((s) => s == IMBoyMessageStatus.seen)
      .length;
  flowLog('已读状态快照：$readCount/$_offlineCount 条 seen(21)，会话 unread_num=$unread');

  // 2) 页级重启代理：离开并重进会话，复查已读不反弹。
  await _leaveChatPage(tester);
  await settle(tester, maxSeconds: 2);
  if (!await _openConversationTab(tester)) {
    fail('已读复查时无法回到会话列表');
  }
  final reopened = await _waitForPeerConversation(tester);
  if (reopened == null) fail('已读复查时未找到目标 C2C 会话');
  await safeTap(tester, reopened.first);
  if (!await _waitForChatPage(tester)) fail('已读复查时未进入聊天页面');
  // 重进后短窗口内复查：重进可能把更多消息滚入视口继续标记已读（允许），
  // 但已 seen 的条数不得减少、unread_num 不得增加（反弹即失败）。
  var after = <String, int>{};
  var afterUnread = -1;
  for (var i = 0; i < 10; i++) {
    after = await statusByMarker();
    afterUnread = await unreadNumOfConversation();
    if (after.values.any((s) => s == IMBoyMessageStatus.error)) {
      fail('重进后消息进入 error：${describe(after, afterUnread)}');
    }
    final afterReadCount = after.values
        .where((s) => s == IMBoyMessageStatus.seen)
        .length;
    if (afterReadCount >= readCount && afterUnread <= unread) break;
    await tester.pump(const Duration(milliseconds: 500));
  }
  final afterReadCount = after.values
      .where((s) => s == IMBoyMessageStatus.seen)
      .length;
  if (afterReadCount < readCount || afterUnread > unread) {
    fail(
      '重进后已读状态反弹：seen $readCount→$afterReadCount，'
      'unread_num $unread→$afterUnread',
    );
  }
  flowLog(
    '已读持久化断言通过：重进会话后 seen $readCount→$afterReadCount、'
    'unread_num $unread→$afterUnread（已读不反弹）',
  );
}

/// 跨账号残留断言（J01 g3）：B 账号经 TEST_FORCE_LOGOUT_BEFORE_LOGIN
/// 完成 A→B 登录切换后，设备本地不得残留 A 账号数据：
/// 1) 当前打开的库必须是 B 自己的 `${env}_${uid}.db`（防跨账号句柄串号；
///    user_repo_local 登出时按 uid 删除 A 库，B 登录应新建自己的库）；
/// 2) A 账号库文件（含 -wal/-shm/-journal sidecar）不得存在；
/// 3) B 库 conversation 表不得出现「peer_id=B 自己 uid」的会话行——
///    那是 A 视角的会话（A↔B 从 A 侧看 peer 是 B）串号进 B 库的直接证据；
///    B 自己视角的 A↔B 会话（peer_id=A）才是合法数据。
/// local wrapper 存储隔离拓扑下 2) 平凡成立（每进程独立临时命名空间）；
/// 持久化存储真机拓扑下该断言是登出清理失效的回归闸。
Future<void> _assertNoPeerAccountResidue() async {
  final currentUid = UserRepoLocal.to.currentUid;
  if (currentUid.isEmpty) {
    fail('跨账号残留检查前置失效：登录态为空');
  }
  if (currentUid == _peerUid) {
    fail('跨账号残留检查前置失效：当前登录 uid 与对端 uid 相同');
  }
  // 直接核对打开中的句柄：db getter 仅在 _openUid==当前 uid 时复用句柄
  // （漂移会关旧重开），此处同时拿到真实打开的文件路径。
  final db = await SqliteService.to.db;
  if (db == null || !db.isOpen) {
    fail('跨账号残留检查时数据库未打开（db 为 null 或已关闭）');
  }
  final dbPath = db.path;
  final expectedName = SqliteService.databaseNameForUid(currentUid);
  if (!dbPath.endsWith('/$expectedName') &&
      !dbPath.endsWith('\\$expectedName')) {
    fail('打开的数据库不是当前账号的库：$dbPath，期望文件名 $expectedName');
  }
  final dbDir = File(dbPath).parent;
  final peerDbName = SqliteService.databaseNameForUid(_peerUid);
  final residue = <String>[];
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final candidate = File(
      '${dbDir.path}${Platform.pathSeparator}$peerDbName$suffix',
    );
    if (await candidate.exists()) residue.add(candidate.path);
  }
  if (residue.isNotEmpty) {
    fail('发现对端账号数据库残留（登出未清理）：${residue.join('、')}');
  }
  final leaked = await SqliteService.to.query(
    ConversationRepo.tableName,
    columns: [ConversationRepo.id],
    where: '${ConversationRepo.peerId} = ?',
    whereArgs: [currentUid],
    limit: 1,
  );
  if (leaked.isNotEmpty) {
    fail(
      '发现 A 账号会话残留：当前库存在 peer_id=$currentUid 的会话行'
      '（对端视角会话串号进本账号库）',
    );
  }
  flowLog(
    '跨账号残留检查通过：打开的是本账号库 $expectedName，'
    '对端库 $peerDbName 无残留，无 peer_id=本账号 的串号会话行',
  );
}
