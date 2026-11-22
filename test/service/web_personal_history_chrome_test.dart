@TestOn('chrome')
library;

/// FL-04:LOCAL:07/:08 个人云端历史 Web 边界（chrome + 真桥接 + 真 WASM SQLite）。
///
/// 覆盖（对齐 fl-next-prep/fl04-plan.md case matrix）：
/// - :06.2 Web 密集接收/分页恢复：与原生同一业务结果，平台差异仅注入层。
/// - :07.2 VFS 持久确认失败 → 不发送 ACK、不产生「半确认」（MH-01 §5/§10.8；
///   真实双 context VFS 持久性反例由 browser_sqlite_storage_bridge_chrome_test
///   的 be08 探针 7 子例覆盖，本文件复用同一 origin 的真桥接做引擎级验证）。
/// - :07.3 断网后本地历史可读、可翻页；busy 显式失败（不伪装成功）。
/// - :08.1 四维状态优先级矩阵（MH-01 §10.9：删除进度>等待密钥>同步失败>
///   云端关闭>本地空态）。
/// - :08.2 晚到/重复事件不回退持久进度；恢复行不产生新投递 ACK（§8/MSG-H08）。
/// - :08.3 会话切换后各会话进度准确。
/// - 上行队列：幂等键去重、transient 重试、只重试当前代次（MSG-H22）。
///
/// 真服务（/personal-history/*）全链路合验在 MH-06；本文件按冻结合同
/// （mh01-personal-history-contract v1.1 §2/§10）驱动合同级 fixture。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_state.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/config/env.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart' as common;

import '../env_test_pin.dart';

/// 合同级 fixture 服务端：按冻结合同出页/受理 ACK/幂等上传。
/// （PersonalHistoryTransport 是 typedef；本类的 call 即该签名实现。）
class _FixtureServer {
  _FixtureServer({required this.generation, required this.events});

  final int generation;
  final List<Map<String, dynamic>> events;

  final calls = <String>[];
  final ackedCursors = <int>[];
  final uploadedKeys = <String>[];
  final uploadedBodies = <Map<String, dynamic>>[];
  int maxIssuedCursor = 0;
  bool offline = false;

  Map<String, dynamic> _ok([Map<String, dynamic>? payload]) => {
    'code': 0,
    'payload': payload ?? const {},
  };

  Map<String, dynamic> _error(String code) => {
    'code': 1,
    'payload': {'error': code},
  };

  Future<PersonalHistoryTransportResult> call(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) async {
    if (offline) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.transientFailure,
        0,
      );
    }
    calls.add('$method $path');
    if (path.endsWith('/status')) {
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok({
          'state': 'ON',
          'generation': generation,
          'upload_cursor': 0,
        }),
        headers: {'cache-control': 'no-store'},
      );
    }
    if (path.endsWith('/changes')) {
      final cursor = (queryParameters?['cursor'] as int? ?? 0);
      final pending =
          events.where((event) => (event['seq'] as int) > cursor).toList()
            ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
      final page = pending.take(3).toList();
      final nextCursor = page.isEmpty ? null : page.last['seq'] as int;
      if (nextCursor != null && nextCursor > maxIssuedCursor) {
        maxIssuedCursor = nextCursor;
      }
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok({'events': page, 'next_cursor': nextCursor}),
      );
    }
    if (path.endsWith('/ack-cursor')) {
      final cursor = (data as Map)['cursor'] as int;
      if (cursor > maxIssuedCursor) {
        return PersonalHistoryTransportResult(
          httpStatus: 409,
          body: _error('malformed_request'),
        );
      }
      ackedCursors.add(cursor);
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok({'accepted': true, 'advanced_to': cursor}),
      );
    }
    if (path.endsWith('/upload')) {
      final body = Map<String, dynamic>.from(data as Map);
      final key = '${body['conversation_id']}|${body['msg_id']}';
      uploadedKeys.add(key);
      // §2.3 幂等：重复上传返回原结果不覆盖。
      final repeated = uploadedBodies.any(
        (prev) =>
            prev['conversation_id'] == body['conversation_id'] &&
            prev['msg_id'] == body['msg_id'],
      );
      uploadedBodies.add(body);
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok({
          'result': repeated ? 'stored' : 'stored',
          'idempotent_replay': repeated,
          'generation': generation,
        }),
      );
    }
    throw StateError('unexpected fixture path: $path');
  }
}

Map<String, dynamic> _event(
  int seq,
  String conversationId,
  String msgId, {
  bool deleted = false,
  int actionVersion = 0,
}) => {
  'seq': seq,
  'conversation_id': conversationId,
  'msg_id': msgId,
  'action_version': actionVersion,
  'conv_seq': seq,
  'key_version': 1,
  'ciphertext': 'Y2lwaGVydGV4dA==',
  'envelope_meta': {
    'alg': 'aes-256-gcm',
    'key_version': 1,
    'nonce': 'bm9uY2U',
    'aad': 'YWFk',
  },
  'deleted': deleted,
  'created_at': 1700000000000 + seq,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late AccountLocalTaskOwner owner;
  late common.Database db;
  late _FixtureServer server;
  late PersonalHistoryLocalStore store;
  late PersonalHistorySyncEngine engine;
  late String databaseName;
  late String domain;
  var domainSeq = 0;

  setUpAll(() async {
    pinLoopbackTestEnv();
    uid = 'fl04web${DateTime.now().millisecondsSinceEpoch}';
    owner = AccountLocalTaskOwner(
      uid: uid,
      environment: init.currentEnv,
      endpoint: Env().apiBaseUrl,
    );
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: uid,
      Keys.currentUser: '{"uid": "$uid"}',
      LoginAccountHistoryService.storageKey:
          '{"version":1,"accounts":[{"uid":"$uid",'
          '"environment":"${owner.environment}","endpoint":"${owner.endpoint}",'
          '"aliases":["$uid"],"storageOwnershipVerified":true}]}',
    });
    await prepareWebWriter();
    await StorageService.init();
  });

  setUp(() async {
    db = (await SqliteService.to.db)!;
    databaseName = SqliteService.databaseNameForUid(uid);
    domain = 'fl04-chrome-test-${domainSeq++}';
    server = _FixtureServer(generation: 3, events: []);
    store = PersonalHistoryLocalStore(() async => db);
    engine = PersonalHistorySyncEngine(
      client: PersonalHistoryApiClient(transport: server.call),
      store: store,
      domain: domain,
      decrypt: (event) async => {
        'msg_id': event.msgId,
        'conversation_id': event.conversationId,
        'seq': event.seq,
        'text': 'plain-${event.msgId}',
      },
      isCurrent: () => true,
      durableConfirm: () async {
        await browserSqliteStorageBridge.durableAccountBarrier(
          db,
          databaseName: databaseName,
        );
      },
    );
  });

  Future<List<Map<String, Object?>>> restoredRows([
    String? conversationId,
  ]) async {
    if (conversationId == null) {
      return db.rawQuery(
        'SELECT * FROM personal_history_restored_row ORDER BY msg_id ASC',
      );
    }
    return db.rawQuery(
      'SELECT * FROM personal_history_restored_row '
      'WHERE conversation_id = ? ORDER BY msg_id ASC',
      [conversationId],
    );
  }

  test('session change during decryption aborts before persisting', () async {
    const conversationId = 'conv-logout-during-decrypt';
    server.events.add(_event(1, conversationId, 'm-1'));
    final decryptStarted = Completer<void>();
    final decryptResult = Completer<Map<String, dynamic>?>();
    var isCurrent = true;
    final pending = PersonalHistorySyncEngine(
      client: PersonalHistoryApiClient(transport: server.call),
      store: store,
      domain: domain,
      decrypt: (event) {
        decryptStarted.complete();
        return decryptResult.future;
      },
      isCurrent: () => isCurrent,
    ).syncOnce();
    await decryptStarted.future;
    isCurrent = false;
    decryptResult.complete({'text': 'late result'});

    expect((await pending).kind, PersonalHistorySyncOutcomeKind.aborted);
    expect(await store.readCheckpoint(domain), isNull);
    expect(await restoredRows(conversationId), isEmpty);
    expect(server.ackedCursors, isEmpty);
  });

  test(
    ':07.2 VFS confirm failure refuses ACK; confirm success then acks once',
    () async {
      server.events.addAll([
        _event(1, 'conv-a', 'm-1'),
        _event(2, 'conv-a', 'm-2'),
        _event(3, 'conv-a', 'm-3'),
        _event(4, 'conv-a', 'm-4'),
      ]);
      // 阶段一：持久确认失败（VFS 故障注入）→ 无 ACK、无「半确认」。
      var confirmFailures = 1;
      final failingEngine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(transport: server.call),
        store: store,
        domain: domain,
        decrypt: engineDecrypt,
        isCurrent: () => true,
        durableConfirm: () async {
          if (confirmFailures > 0) {
            confirmFailures--;
            throw const BrowserSqliteStoragePoisoned();
          }
          await browserSqliteStorageBridge.durableAccountBarrier(
            db,
            databaseName: databaseName,
          );
        },
      );
      final failed = await failingEngine.syncOnce();
      expect(failed.kind, PersonalHistorySyncOutcomeKind.durabilityFailed);
      expect(server.ackedCursors, isEmpty, reason: 'VFS 确认失败必须拒绝 ack-cursor');
      expect(server.calls.where((c) => c.contains('ack-cursor')), isEmpty);

      // 阶段二：真实桥接 barrier 通过 → ACK 恰一次，游标=检查点。
      // 说明：确认失败后 SQL 状态可能已前跳（模拟故障不回滚内存态）——
      // 若 VFS 真失败（桥接 poison），重载后回到旧游标幂等重放，两条路径
      // 都收敛到同一检查点（seq 主键去重保证恰一次业务效果）。
      final outcome = await engine.syncOnce();
      expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(server.ackedCursors, [4]);
      final checkpoint = await store.readCheckpoint(domain);
      expect(checkpoint, (generation: 3, cursor: 4));
      final convARows = await restoredRows('conv-a');
      expect(convARows.map((r) => r['msg_id']), ['m-1', 'm-2', 'm-3', 'm-4']);
    },
  );

  test(':07.3 offline keeps local history readable and paginated', () async {
    server.events.addAll([
      for (var i = 1; i <= 5; i++) _event(i, 'conv-off', 'off-$i'),
    ]);
    final synced = await engine.syncOnce();
    expect(synced.kind, PersonalHistorySyncOutcomeKind.synced);
    server.offline = true;

    // 断网：同步失败（不伪装成功），读路径不依赖网络。
    final failed = await engine.syncOnce();
    expect(failed.kind, PersonalHistorySyncOutcomeKind.failed);
    final rows = await restoredRows('conv-off');
    expect(rows, hasLength(5));
    expect(rows.map((r) => r['msg_id']), [
      'off-1',
      'off-2',
      'off-3',
      'off-4',
      'off-5',
    ]);
    // 本地翻页：before 游标语义（按 msg_id 排序翻页完整、无重复无丢失）。
    final page1 = await db.rawQuery(
      'SELECT msg_id FROM personal_history_restored_row '
      'WHERE conversation_id = ? ORDER BY msg_id ASC LIMIT 2',
      ['conv-off'],
    );
    final page2 = await db.rawQuery(
      'SELECT msg_id FROM personal_history_restored_row '
      'WHERE conversation_id = ? AND msg_id > ? ORDER BY msg_id ASC LIMIT 2',
      ['conv-off', page1.last['msg_id']],
    );
    expect(page1.map((r) => r['msg_id']), ['off-1', 'off-2']);
    expect(page2.map((r) => r['msg_id']), ['off-3', 'off-4']);

    // busy 同型：显式失败，不改写已持久进度。
    final busyCheckpoint = await store.readCheckpoint(domain);
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
    server.events.addAll([
      _event(1, 'conv-b', 'b-1'),
      _event(2, 'conv-b', 'b-2'),
    ]);
    final first = await engine.syncOnce();
    expect(first.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(first.applied, 2);

    // 晚到重复：同 seq 重投 + 内容漂移的旧版本，不得回退已合并行/检查点。
    // 场景=持久确认失败/ACK 丢失后客户端从旧水位重拉（服务端按已确认
    // 水位重发 pending），本地账本把重发 seq 幂等跳过。
    server.events.clear();
    server.events.addAll([
      _event(2, 'conv-b', 'b-2', actionVersion: 9),
      _event(3, 'conv-b', 'b-3'),
    ]);
    await db.rawUpdate(
      'UPDATE personal_history_sync_state SET acked_cursor = 1 WHERE domain = ?',
      [domain],
    );
    final second = await engine.syncOnce();
    expect(second.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(second.duplicates, 1, reason: '晚到 seq=2 必须幂等跳过');
    expect(second.applied, 1);
    final checkpoint = await store.readCheckpoint(domain);
    expect(checkpoint!.cursor, 3);
    final rows = await restoredRows('conv-b');
    expect(rows, hasLength(3));
    final row2 = rows.firstWhere((r) => r['msg_id'] == 'b-2');
    // 首次合并版本胜出（稳定合并版本，MSG-H15），旧版本不回退进度。
    expect((row2['row'] as String).contains('plain-b-2'), isTrue);

    // 恢复行不产生新投递 ACK：全程只出现 status/changes/ack-cursor 调用。
    expect(
      server.calls.every(
        (c) =>
            c.contains('/status') ||
            c.contains('/changes') ||
            c.contains('/ack-cursor'),
      ),
      isTrue,
    );
  });

  test(':08.3 conversation switch keeps per-conversation progress', () async {
    server.events.addAll([
      _event(1, 'conv-x', 'x-1'),
      _event(2, 'conv-y', 'y-1'),
      _event(3, 'conv-x', 'x-2', deleted: true),
      _event(4, 'conv-y', 'y-2'),
    ]);
    final outcome = await engine.syncOnce();
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(outcome.applied, 4);

    // 会话切换后各归其位：conv-x 1 行 + 1 tombstone；conv-y 2 行。
    final xRows = await restoredRows('conv-x');
    final yRows = await restoredRows('conv-y');
    expect(xRows.map((r) => r['msg_id']), ['x-1']);
    expect(yRows.map((r) => r['msg_id']), ['y-1', 'y-2']);
    expect(await store.isTombstoned('conv-x', 'x-2'), isTrue);
    expect(await store.isTombstoned('conv-y', 'y-1'), isFalse);

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
      server.events.addAll([
        for (var i = 1; i <= 9; i++) _event(i, 'conv-dense', 'dense-$i'),
        _event(10, 'conv-dense', 'dense-10', deleted: true),
      ]);
      final outcome = await engine.syncOnce();
      expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(outcome.applied, 10);
      final rows = await restoredRows('conv-dense');
      expect(rows, hasLength(9));
      final ids = rows.map((r) => r['msg_id'] as String).toList();
      expect(ids, ids.toList()..sort(), reason: '列表稳定（权威序）');
      expect(await store.isTombstoned('conv-dense', 'dense-10'), isTrue);

      // 晚到全量重放：从旧水位整体重发，全部幂等跳过，游标与行不变
      // （与原生 :06 同一业务结果）。
      await db.rawUpdate(
        'UPDATE personal_history_sync_state SET acked_cursor = 0 WHERE domain = ?',
        [domain],
      );
      final replay = await engine.syncOnce();
      expect(replay.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(replay.duplicates, 10);
      expect(replay.applied, 0);
      final after = await restoredRows('conv-dense');
      expect(after, hasLength(9));
      final checkpoint = await store.readCheckpoint(domain);
      expect(checkpoint!.cursor, 10);
    },
  );

  test(
    'upload queue: idempotent enqueue, transient retry, generation fence',
    () async {
      // 幂等键去重：同键两次入队只保留一行。
      await store.enqueueUpload(
        domain: domain,
        generation: 3,
        conversationId: 'conv-up',
        msgId: 'up-1',
        actionVersion: 0,
        convSeq: 1,
        ciphertext: 'Y2lwaGVydGV4dA==',
        envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
        clientTs: 1700000000000,
      );
      await store.enqueueUpload(
        domain: domain,
        generation: 3,
        conversationId: 'conv-up',
        msgId: 'up-1',
        actionVersion: 0,
        convSeq: 1,
        ciphertext: 'Y2lwaGVydGV4dA==',
        envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
        clientTs: 1700000000000,
      );
      await store.enqueueUpload(
        domain: domain,
        generation: 3,
        conversationId: 'conv-up',
        msgId: 'up-2',
        actionVersion: 0,
        convSeq: 2,
        ciphertext: 'Y2lwaGVydGV4dA==',
        envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
        clientTs: 1700000000001,
      );
      var pending = await store.pendingUploads(domain, 3);
      expect(pending, hasLength(2));

      // transient_failure：up-1 成功移除；up-2 保留待重试。
      final uploadClient = _UploadFixtureServerDelegate(server);
      final flushEngine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(transport: uploadClient.call),
        store: store,
        domain: domain,
        decrypt: engineDecrypt,
        isCurrent: () => true,
      );
      final flushed = await flushEngine.flushUploads(generation: 3);
      expect(flushed.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(flushed.uploaded, 1);
      pending = await store.pendingUploads(domain, 3);
      expect(pending.map((r) => r['msg_id']), ['up-2']);
      expect(pending.single['attempts'], 1);

      // 代次变更（g4）：旧代次行不再重试（账号/撤销后中止旧任务）。
      expect(await store.pendingUploads(domain, 4), isEmpty);

      // 账号切换中途：isCurrent=false 中止冲刷且不误删队列。
      final abortEngine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(transport: server.call),
        store: store,
        domain: domain,
        decrypt: engineDecrypt,
        isCurrent: () => false,
      );
      final aborted = await abortEngine.flushUploads(generation: 3);
      expect(aborted.kind, PersonalHistorySyncOutcomeKind.aborted);
      expect(await store.pendingUploads(domain, 3), isNotEmpty);
    },
  );
}

/// 引擎默认解密注入（fixture 恒成功）。
Future<Map<String, dynamic>?> engineDecrypt(PersonalHistoryEvent event) async =>
    {
      'msg_id': event.msgId,
      'conversation_id': event.conversationId,
      'seq': event.seq,
      'text': 'plain-${event.msgId}',
    };

/// 上行 fixture：第一条上传成功、其后 transient_failure（可安全重试）。
class _UploadFixtureServerDelegate {
  _UploadFixtureServerDelegate(this._inner);
  final _FixtureServer _inner;
  var successes = 0;

  Future<PersonalHistoryTransportResult> call(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) async {
    if (path.endsWith('/upload')) {
      successes++;
      if (successes > 1) {
        throw const PersonalHistoryApiException(
          PersonalHistoryErrorCode.transientFailure,
          503,
        );
      }
    }
    return _inner.call(
      method,
      path,
      queryParameters: queryParameters,
      data: data,
    );
  }
}
