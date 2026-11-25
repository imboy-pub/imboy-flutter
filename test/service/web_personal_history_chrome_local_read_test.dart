@TestOn('chrome')
library;

/// FL-04:LOCAL:07/:08 个人云端历史 Web 边界（chrome + 真桥接 + 真 WASM SQLite）。
///
/// 本文件覆盖本地读模型/断网/状态矩阵域：
/// - :06.2 Web 密集接收/分页恢复：与原生同一业务结果，平台差异仅注入层。
/// - 恢复行读模型：最新 scoped 行 + accepted facts、按请求 ID 选旧持久行。
/// - :07.3 断网后本地历史可读、可翻页；busy 显式失败（不伪装成功）。
/// - :08.1 四维状态优先级矩阵（MH-01 §10.9：删除进度>等待密钥>同步失败>
///   云端关闭>本地空态）。
/// - :08.2 晚到/重复事件不回退持久进度；恢复行不产生新投递 ACK（§8/MSG-H08）。
/// - :08.3 会话切换后各会话进度准确。
///
/// 共享 fixture/harness 见 web_personal_history_chrome_support.dart。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_state.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';

import 'web_personal_history_chrome_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = WebPersonalHistoryChromeHarness();
  setUpAll(h.setUpAll);
  setUp(h.setUp);

  test(
    'restored copy uses the newest scoped row with accepted facts',
    () async {
      const conv = 'conv-restored-copy';
      final current = fixtureEvent(2, conv, 'edited', actionVersion: 1)
        ..['accepted_message'] = {
          'from_id': '9007199254740993',
          'to_id': '9007199254740995',
          'conv_seq': 2,
          'action_version': 1,
        };
      h.server.events.addAll([
        fixtureEvent(1, conv, 'edited'),
        current,
        fixtureEvent(3, conv, 'removed'),
        fixtureEvent(4, conv, 'removed', deleted: true, actionVersion: 1),
        fixtureEvent(5, 'other-conversation', 'unrelated'),
      ]);
      final client = PersonalHistoryApiClient(transport: h.server.call);
      final page = await client.changes(cursor: 0);
      expect(page.events[1].acceptedMessage, (
        fromId: '9007199254740993',
        toId: '9007199254740995',
        sequence: 2,
        actionVersion: 1,
      ));
      expect(
        (await h.engine.syncOnce()).kind,
        PersonalHistorySyncOutcomeKind.synced,
      );
      final rows = await h.store.readRestoredRows(
        domain: h.domain,
        generation: 3,
        conversationId: conv,
      );
      expect(rows.single['msg_id'], 'edited');
      expect(rows.single['action_version'], 1);
      final requested = await h.store.readRestoredRowsForPage(
        domain: h.domain,
        generation: 3,
        conversationId: conv,
        messageIds: ['edited', 'removed', 'unrelated'],
      );
      expect(requested.single['msg_id'], 'edited');
      expect(requested.single['action_version'], 1);
      expect(
        await h.store.readRestoredRowsForPage(
          domain: h.domain,
          generation: 3,
          conversationId: conv,
          messageIds: ['removed', 'unrelated'],
        ),
        isEmpty,
      );
      expect(
        await h.store.readRestoredRows(
          domain: h.domain,
          generation: 4,
          conversationId: conv,
        ),
        isEmpty,
      );
    },
  );

  test('snapshot page selects older durable rows by requested IDs', () async {
    const conv = 'conv-paginated-restored-copy';
    h.server.events.addAll([
      for (var seq = 1; seq <= 51; seq++)
        fixtureEvent(seq, conv, 'message-$seq'),
    ]);
    expect(
      (await h.engine.syncOnce()).kind,
      PersonalHistorySyncOutcomeKind.synced,
    );
    final olderPage = await h.store.readRestoredRowsForPage(
      domain: h.domain,
      generation: 3,
      conversationId: conv,
      messageIds: ['message-1'],
    );
    expect(olderPage.single['msg_id'], 'message-1');
    final before = olderPage.single['row'] as String;
    final stamped = await h.store.stampRestoredRowsForPage(
      domain: h.domain,
      generation: 3,
      conversationId: conv,
      stamps: [
        (
          msgId: 'message-1',
          actionVersion: 0,
          previous: before,
          stamped: '{"_personal_history_verified_conv_seq":1}',
        ),
        (
          msgId: 'message-51',
          actionVersion: 0,
          previous: 'stale',
          stamped: '{"_personal_history_verified_conv_seq":51}',
        ),
      ],
      requireCurrent: () {},
    );
    expect(stamped, {'message-1'});
    expect(
      (await h.store.readRestoredRowsForPage(
        domain: h.domain,
        generation: 3,
        conversationId: conv,
        messageIds: ['message-1'],
      )).single['row'],
      '{"_personal_history_verified_conv_seq":1}',
    );
    final checkpoint = await h.store.readCheckpoint(h.domain);
    expect(checkpoint?.cursor, 51);
    expect(h.server.ackedCursors, [51]);
  });

  test('reset hint asks for rescan without acknowledging a cursor', () async {
    h.server.resetHint = true;

    expect(
      (await h.engine.syncOnce()).kind,
      PersonalHistorySyncOutcomeKind.rescanRequired,
    );
    expect(await h.store.readCheckpoint(h.domain), isNull);
    expect(h.server.ackedCursors, isEmpty);
  });

  test(':07.3 offline keeps local history readable and paginated', () async {
    h.server.events.addAll([
      for (var i = 1; i <= 5; i++) fixtureEvent(i, 'conv-off', 'off-$i'),
    ]);
    final synced = await h.engine.syncOnce();
    expect(synced.kind, PersonalHistorySyncOutcomeKind.synced);
    h.server.offline = true;

    // 断网：同步失败（不伪装成功），读路径不依赖网络。
    final failed = await h.engine.syncOnce();
    expect(failed.kind, PersonalHistorySyncOutcomeKind.failed);
    final rows = await h.restoredRows('conv-off');
    expect(rows, hasLength(5));
    expect(rows.map((r) => r['msg_id']), [
      'off-1',
      'off-2',
      'off-3',
      'off-4',
      'off-5',
    ]);
    // 本地翻页：before 游标语义（按 msg_id 排序翻页完整、无重复无丢失）。
    final page1 = await h.db.rawQuery(
      'SELECT msg_id FROM personal_history_restored_row '
      'WHERE conversation_id = ? ORDER BY msg_id ASC LIMIT 2',
      ['conv-off'],
    );
    final page2 = await h.db.rawQuery(
      'SELECT msg_id FROM personal_history_restored_row '
      'WHERE conversation_id = ? AND msg_id > ? ORDER BY msg_id ASC LIMIT 2',
      ['conv-off', page1.last['msg_id']],
    );
    expect(page1.map((r) => r['msg_id']), ['off-1', 'off-2']);
    expect(page2.map((r) => r['msg_id']), ['off-3', 'off-4']);

    // busy 同型：显式失败，不改写已持久进度。
    final busyCheckpoint = await h.store.readCheckpoint(h.domain);
    expect(busyCheckpoint!.cursor, 5);
    final state = ChatState().copyWith(
      personalHistoryCloudEnabled: true,
      personalHistorySyncStatus: PersonalHistorySyncStatus.failed,
      personalHistoryLocalPresent: true,
    );
    expect(
      state.personalHistoryVisibility,
      PersonalHistoryVisibility.syncFailed,
    );
  });

  test(':08.1 four-dimension priority matrix (MH-01 §10.9)', () {
    // 删除进度 > 等待密钥 > 同步失败 > 云端关闭 > 本地空态。
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.pending,
        syncStatus: PersonalHistorySyncStatus.waitingKey,
        cloudEnabled: false,
        localPresent: false,
      ),
      PersonalHistoryVisibility.deletionProgress,
    );
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.none,
        syncStatus: PersonalHistorySyncStatus.waitingKey,
        cloudEnabled: false,
        localPresent: false,
      ),
      PersonalHistoryVisibility.waitingKey,
    );
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.none,
        syncStatus: PersonalHistorySyncStatus.failed,
        cloudEnabled: false,
        localPresent: false,
      ),
      PersonalHistoryVisibility.syncFailed,
    );
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.none,
        syncStatus: PersonalHistorySyncStatus.idle,
        cloudEnabled: false,
        localPresent: true,
      ),
      PersonalHistoryVisibility.cloudOff,
    );
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.none,
        syncStatus: PersonalHistorySyncStatus.idle,
        cloudEnabled: true,
        localPresent: false,
      ),
      PersonalHistoryVisibility.localEmpty,
    );
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.none,
        syncStatus: PersonalHistorySyncStatus.syncing,
        cloudEnabled: true,
        localPresent: true,
      ),
      PersonalHistoryVisibility.none,
    );
    // 删除完结（备份到期）不再遮蔽其他维度。
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.backupExpiry,
        syncStatus: PersonalHistorySyncStatus.idle,
        cloudEnabled: false,
        localPresent: true,
      ),
      PersonalHistoryVisibility.cloudOff,
    );
    // 清理失败回到删除进度优先。
    expect(
      resolvePersonalHistoryVisibility(
        deletionPhase: PersonalHistoryDeletionPhase.failed,
        syncStatus: PersonalHistorySyncStatus.idle,
        cloudEnabled: true,
        localPresent: true,
      ),
      PersonalHistoryVisibility.deletionProgress,
    );
  });

  test(':08.2 late/duplicate events never regress durable progress', () async {
    h.server.events.addAll([
      fixtureEvent(1, 'conv-b', 'b-1'),
      fixtureEvent(2, 'conv-b', 'b-2'),
    ]);
    final first = await h.engine.syncOnce();
    expect(first.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(first.applied, 2);

    // 晚到重复：同 seq 重投 + 内容漂移的旧版本，不得回退已合并行/检查点。
    // 场景=持久确认失败/ACK 丢失后客户端从旧水位重拉（服务端按已确认
    // 水位重发 pending），本地账本把重发 seq 幂等跳过。
    h.server.events.clear();
    h.server.events.addAll([
      fixtureEvent(2, 'conv-b', 'b-2', actionVersion: 9),
      fixtureEvent(3, 'conv-b', 'b-3'),
    ]);
    await h.db.rawUpdate(
      'UPDATE personal_history_sync_state SET acked_cursor = 1 WHERE domain = ?',
      [h.domain],
    );
    final second = await h.engine.syncOnce();
    expect(second.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(second.duplicates, 1, reason: '晚到 seq=2 必须幂等跳过');
    expect(second.applied, 1);
    final checkpoint = await h.store.readCheckpoint(h.domain);
    expect(checkpoint!.cursor, 3);
    final rows = await h.restoredRows('conv-b');
    expect(rows, hasLength(3));
    final row2 = rows.firstWhere((r) => r['msg_id'] == 'b-2');
    // 首次合并版本胜出（稳定合并版本，MSG-H15），旧版本不回退进度。
    expect((row2['row'] as String).contains('plain-b-2'), isTrue);

    // 恢复行不产生新投递 ACK：全程只出现 status/changes/ack-cursor 调用。
    expect(
      h.server.calls.every(
        (c) =>
            c.contains('/status') ||
            c.contains('/changes') ||
            c.contains('/ack-cursor'),
      ),
      isTrue,
    );
  });

  test(':08.3 conversation switch keeps per-conversation progress', () async {
    h.server.events.addAll([
      fixtureEvent(1, 'conv-x', 'x-1'),
      fixtureEvent(2, 'conv-y', 'y-1'),
      fixtureEvent(3, 'conv-x', 'x-2', deleted: true),
      fixtureEvent(4, 'conv-y', 'y-2'),
    ]);
    final outcome = await h.engine.syncOnce();
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(outcome.applied, 4);

    // 会话切换后各归其位：conv-x 1 行 + 1 tombstone；conv-y 2 行。
    final xRows = await h.restoredRows('conv-x');
    final yRows = await h.restoredRows('conv-y');
    expect(xRows.map((r) => r['msg_id']), ['x-1']);
    expect(yRows.map((r) => r['msg_id']), ['y-1', 'y-2']);
    expect(await h.store.isTombstoned('conv-x', 'x-2'), isTrue);
    expect(await h.store.isTombstoned('conv-y', 'y-1'), isFalse);

    // chat_state 切会话不动个人历史四维状态（正交通道）。
    final state = ChatState()
        .copyWith(currentConversationId: 'conv-x')
        .copyWith(
          personalHistoryCloudEnabled: true,
          personalHistoryLocalPresent: true,
        )
        .copyWith(currentConversationId: 'conv-y');
    expect(state.personalHistoryCloudEnabled, isTrue);
    expect(state.personalHistoryLocalPresent, isTrue);
    expect(state.currentConversationId, 'conv-y');
  });

  test(
    ':06.2 web dense receive: pages merge atomically with stable order',
    () async {
      h.server.events.addAll([
        for (var i = 1; i <= 9; i++) fixtureEvent(i, 'conv-dense', 'dense-$i'),
        fixtureEvent(10, 'conv-dense', 'dense-10', deleted: true),
      ]);
      final outcome = await h.engine.syncOnce();
      expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(outcome.applied, 10);
      final rows = await h.restoredRows('conv-dense');
      expect(rows, hasLength(9));
      final ids = rows.map((r) => r['msg_id'] as String).toList();
      expect(ids, ids.toList()..sort(), reason: '列表稳定（权威序）');
      expect(await h.store.isTombstoned('conv-dense', 'dense-10'), isTrue);

      // 晚到全量重放：从旧水位整体重发，全部幂等跳过，游标与行不变
      // （与原生 :06 同一业务结果）。
      await h.db.rawUpdate(
        'UPDATE personal_history_sync_state SET acked_cursor = 0 WHERE domain = ?',
        [h.domain],
      );
      final replay = await h.engine.syncOnce();
      expect(replay.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(replay.duplicates, 10);
      expect(replay.applied, 0);
      final after = await h.restoredRows('conv-dense');
      expect(after, hasLength(9));
      final checkpoint = await h.store.readCheckpoint(h.domain);
      expect(checkpoint!.cursor, 10);
    },
  );
}
