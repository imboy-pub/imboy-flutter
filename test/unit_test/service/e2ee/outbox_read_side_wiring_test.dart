// E2EE-027 outbox 读侧接线实证（2026-08-02）。
//
// == 关闭两个残留（evidence/E2EE-027-followup.md §4.1）==
//
// 1. 「重发 byte-for-byte 相同且 ratchet 只推进一次」：
//    本测试证明 MessageRetry 重发**复用库中已提交信封**——发送事件里的
//    e2ee 与落库信封逐字节一致。harness 不含任何加密服务，
//    若重发路径重新加密会当场爆炸，故通过即证「不重新 encrypt」。
// 2. 「confirmOutbox 零生产调用者」：
//    已接入 ACK 单一汇聚点（RemoveFromRetryQueueRequestedEvent 监听），
//    仅 server_ack 可确认；停止重试、拒绝和消息操作不得消费恢复数据。
//
// 守护（空验证）：对照组必须同时成立——
// - 若重发事件根本没出网（harness 没驱动起来），用例 1 的绿无意义，
//   故用例 1 先断言出网再比内容；
// - 用例 3 证明 outbox 表缺失时移除事件照样生效（卫生动作不阻断 ACK）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 与 retry_plaintext_guard_integration_test 同一份最小 DDL。
const String _msgC2cDdl = '''
  CREATE TABLE msg_c2c (
    auto_id INTEGER PRIMARY KEY AUTOINCREMENT,
    id INTEGER,
    type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    payload TEXT,
    created_at INTEGER,
    is_author INTEGER,
    status INTEGER,
    conversation_uk3 TEXT,
    topic_id INTEGER,
    msg_type TEXT,
    action TEXT,
    e2ee TEXT,
    sender_did TEXT
  )
''';

const String _contactDdl = '''
  CREATE TABLE contact (
    user_id INTEGER,
    peer_id INTEGER,
    nickname TEXT,
    avatar TEXT,
    account TEXT,
    status INTEGER,
    remark TEXT,
    tag TEXT,
    region TEXT,
    sign TEXT,
    source TEXT,
    gender INTEGER,
    is_friend INTEGER,
    is_from INTEGER,
    category_id INTEGER,
    account_type TEXT,
    last_seen_at INTEGER,
    updated_at INTEGER
  )
''';

/// v3 per-device fan-out 信封（生产 e2ee 字段形状；内容为确定性占位，
/// 本测试只验重发保真，不验解密）。
Map<String, dynamic> _v3Envelope() => {
  'meta_version': 3,
  'fan_out': 'per_device',
  'e2ee_suite': 'OLM.V1',
  'devices': {
    'did-peer-1': {
      'ciphertext': 'Q0lQSEVSVEVYVA',
      'header': {'session_ref': 'sess-1', 'epoch_or_counter': 1},
    },
  },
  'protected_header': {'message_id': 'm-1', 'sender_uid': 1001},
};

/// Observe the real SQLite UPDATE completion, rather than guessing how many
/// Dart event turns an FFI database operation needs. Only ACK SQL uses this
/// handle; fixture setup and assertions use the underlying database directly.
class _AckDatabase implements Database {
  _AckDatabase(this.delegate, {this.holdUpdate = false});

  final Database delegate;
  final bool holdUpdate;
  final updateStarted = Completer<void>();
  final releaseUpdate = Completer<void>();
  final confirmed = Completer<void>();
  final probed = Completer<void>();
  int openChecks = 0;

  @override
  bool get isOpen {
    openChecks++;
    return delegate.isOpen;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final rows = await delegate.rawQuery(sql, arguments);
    if (!probed.isCompleted) probed.complete();
    return rows;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    if (!updateStarted.isCompleted) updateStarted.complete();
    if (holdUpdate) await releaseUpdate.future;
    try {
      final changed = await delegate.rawUpdate(sql, arguments);
      if (!confirmed.isCompleted) confirmed.complete();
      return changed;
    } on Object catch (error, stack) {
      if (!confirmed.isCompleted) confirmed.completeError(error, stack);
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageRetry retry;
  final sendRequests = <WebSocketMessageSendRequestEvent>[];
  late Database db;
  late StreamSubscription<WebSocketMessageSendRequestEvent> sendSubscription;

  setUp(() async {
    // Retry/outbox work belongs to the sender's active account session.
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    await db.execute(_contactDdl);
    // 重发路径经 send-gate 读 attachment_upload_task（迁移 v33 建表，
    // 内存库需自带；attachment_send_gate/message_send_attempt 由仓储
    // CREATE IF NOT EXISTS 自建）。缺表会让 claim 查询抛错 → 重试循环
    // 空转 → 30s 超时（CI sqlite-ffi 失败形态）。
    await db.execute(
      'CREATE TABLE attachment_upload_task ('
      'id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, business_intent TEXT,'
      'scope TEXT, scope_ref TEXT, file_name TEXT, mime TEXT, plain_size INTEGER,'
      'plain_sha256 TEXT, object_key TEXT, stage TEXT, cipher TEXT, binding_hash TEXT,'
      'key_ref TEXT, ciphertext_sha256 TEXT, last_error TEXT, created_at INTEGER,'
      'updated_at INTEGER, upload_path TEXT)',
    );
    await db.insert('contact', {
      'user_id': 1001,
      'peer_id': 2002,
      'nickname': 'peer',
      'avatar': '',
      'account': 'acc',
      'status': 1,
      'remark': '',
      'tag': '',
      'region': '',
      'sign': '',
      'source': '',
      'gender': 1,
      'is_friend': 1,
      'is_from': 0,
      'category_id': 0,
      'updated_at': 1751850000000,
    });
    SqliteService.setDbForTest(db);
    expect(await SqliteService.to.db, isNotNull);
    retry = MessageRetry.instance;
    await retry.debugWaitForIdle();
    sendSubscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(sendRequests.add);
  });

  tearDown(() async {
    await retry.debugWaitForIdle();
    retry.dispose();
    await sendSubscription.cancel();
    sendRequests.clear();
    SqliteService.setDbForTest(null);
    await db.close();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Future<void> insertEncryptedRow(String id, Map<String, dynamic> e2ee) async {
    await db.insert('msg_c2c', {
      'id': id,
      'type': 'C2C',
      'from_id': 1001,
      'to_id': 2002,
      'payload': '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'is_author': 1,
      'status': 41, // IMBoyMessageStatus.error=41（在重试状态集内）
      'conversation_uk3': 'C2C_1001_2002',
      'topic_id': 0,
      'msg_type': 'text',
      'action': '',
      'e2ee': jsonEncode(e2ee),
    });
  }

  /// 把队列中该消息的退避间隔拨到已到期（与 062 harness 的 _makeDue 同法）。
  void makeDue(String id) {
    final info = retry.getRetryInfo(id);
    if (info == null) return;
    info.lastRetryTime -=
        RetryPolicy.messageSendIntervalAt(info.retryCount) + 1000;
  }

  Future<void> driveRetry(String id) async {
    retry.addToRetryQueue(id, 'C2C');
    makeDue(id);
    await retry.retryFailedMessages();
    await pumpEventQueue();
  }

  Future<void> deliverRemoval(String id, String reason) async {
    // Observe delivery after MessageRetry's synchronous listener has run.
    final delivered = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
        .firstWhere((event) => event.messageId == id && event.reason == reason);
    // Exercise the real business-rejection producers, not just their labels.
    if (reason == 'not_a_friend') {
      await MessageActions.handleNotAFriendError(msgId: id, chatType: 'C2C');
    } else if (reason == 'in_denylist') {
      await MessageActions.handleDenylistError(msgId: id, chatType: 'C2C');
    } else {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: id,
          messageType: reason == 'server_ack' ? 'C2C_SERVER_ACK' : 'C2C',
          reason: reason,
        ),
      );
    }
    await delivered;
  }

  Future<void> expectRecoverable(
    CryptoStore store,
    String id,
    Map<String, dynamic>? original,
  ) async {
    expect(original?['status'], 'pending');
    expect(original?['sent_at'], isNull);
    expect(await store.getOutboxEntry(id), original);
    await store.purgeOutbox(olderThanMs: 0);
    expect(await store.getOutboxEntry(id), original);
    expect(await store.pendingOutbox(), contains(equals(original)));
  }

  test('重发复用已提交信封：e2ee 与落库逐字节一致（不重新加密）', () async {
    final envelope = _v3Envelope();
    await insertEncryptedRow('msg-resend-1', envelope);

    await driveRetry('msg-resend-1');

    // 守护①：必须先有出网事件，否则后面的比对全是空对空
    final sent = sendRequests.where((e) => e.messageId == 'msg-resend-1');
    expect(sent, hasLength(1), reason: '重发事件未出网，harness 未驱动起重投');

    final frame = jsonDecode(sent.first.message) as Map<String, dynamic>;
    final resentE2ee = frame['e2ee'];
    // e2ee 在库中按 jsonEncode 存，发送帧应为 Map 或等价可比对结构
    final resentMap = resentE2ee is String
        ? jsonDecode(resentE2ee) as Map<String, dynamic>
        : (resentE2ee as Map).cast<String, dynamic>();
    expect(resentMap, envelope);
    expect(
      jsonEncode(resentMap),
      jsonEncode(envelope),
      reason: 'byte-for-byte 不一致',
    );
  });

  test('ACK 移除事件汇聚时确认 outbox（pending → sent）', () async {
    final observed = _AckDatabase(db, holdUpdate: true);
    SqliteService.setDbForTest(observed);
    final store = CryptoStore(db);
    await store.ensureSchema();
    await store.insertOutbox(
      id: 'msg-resend-1',
      payload: jsonEncode(_v3Envelope()),
    );
    expect((await store.getOutboxEntry('msg-resend-1'))?['status'], 'pending');

    retry.addToRetryQueue('msg-resend-1', 'C2C');
    expect(retry.getRetryInfo('msg-resend-1'), isNotNull);
    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: 'msg-resend-1',
        messageType: 'C2C_SERVER_ACK',
        reason: 'server_ack',
      ),
    );
    try {
      await observed.updateStarted.future;
      // The event was handled, but native SQLite completion is independent of
      // pumpEventQueue. Force this ordering instead of relying on CI timing.
      await pumpEventQueue();
      expect(retry.getRetryInfo('msg-resend-1'), isNull);
      expect(observed.confirmed.isCompleted, isFalse);
      expect(
        (await store.getOutboxEntry('msg-resend-1'))?['status'],
        'pending',
      );
    } finally {
      observed.releaseUpdate.complete();
      await observed.confirmed.future;
    }

    final entry = await store.getOutboxEntry('msg-resend-1');
    expect(entry?['status'], 'sent', reason: 'ACK 移除未联动确认 outbox');
    expect(entry?['sent_at'], isA<int>());
    expect(entry?['payload'], jsonEncode(_v3Envelope()));
  });

  for (final staleField in ['ownerUid', 'sessionGeneration']) {
    test('过期 ACK 不确认 outbox：$staleField', () async {
      final observed = _AckDatabase(db);
      SqliteService.setDbForTest(observed);
      final store = CryptoStore(db);
      await store.ensureSchema();
      await store.insertOutbox(id: 'stale-ack', payload: '{}');
      retry.addToRetryQueue('stale-ack', 'C2C');
      final pending = retry.getRetryInfo('stale-ack');
      expect(pending, isNotNull);
      final event = RemoveFromRetryQueueRequestedEvent(
        messageId: 'stale-ack',
        messageType: 'C2C_SERVER_ACK',
        reason: 'server_ack',
        ownerUid: staleField == 'ownerUid' ? 'stale-owner' : null,
        sessionGeneration: staleField == 'sessionGeneration'
            ? UserRepoLocal.to.sessionGeneration - 1
            : null,
      );
      // Registered after MessageRetry: delivery observes its synchronous guard.
      final delivered = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
          .firstWhere((candidate) => identical(candidate, event));
      AppEventBus.fire(event);
      await delivered;
      expect(retry.getRetryInfo('stale-ack'), same(pending));
      expect(observed.probed.isCompleted, isFalse);
      expect(observed.updateStarted.isCompleted, isFalse);
      expect((await store.getOutboxEntry('stale-ack'))?['status'], 'pending');
    });
  }

  test('outbox 表缺失时移除事件照样生效（卫生动作不阻断 ACK）', () async {
    // 不建 crypto_outbox 表：_confirmOutboxQuietly 应只记日志
    final observed = _AckDatabase(db);
    SqliteService.setDbForTest(observed);
    retry.addToRetryQueue('msg-ghost', 'C2C');

    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: 'msg-ghost',
        messageType: 'C2C_SERVER_ACK',
        reason: 'server_ack',
      ),
    );
    await observed.probed.future;
    expect(observed.updateStarted.isCompleted, isFalse);

    // 移除生效即通过（确认失败不得阻断）；队列中不应再有该 id
    expect(retry.getRetryInfo('msg-ghost'), isNull);
  });

  for (final reason in [
    'not_a_friend',
    'in_denylist',
    'revoked',
    'edited',
    'ws_action_ack',
    'ws_action_error',
    'success', // The event constructor's default is not proof of delivery.
    'SERVER_ACK', // Only the production reason is accepted.
    'unknown_reason',
    '',
    'client_ack_confirm',
  ]) {
    test('非发送确认及重复事件保留 outbox 恢复数据：$reason', () async {
      const id = 'not-confirmed';
      final store = CryptoStore(db);
      await store.ensureSchema();
      await store.insertOutbox(id: id, payload: jsonEncode(_v3Envelope()));
      final original = await store.getOutboxEntry(id);
      retry.addToRetryQueue(id, 'C2C');
      final pending = retry.getRetryInfo(id);
      final observed = _AckDatabase(db);
      SqliteService.setDbForTest(observed);

      for (var delivery = 0; delivery < 2; delivery++) {
        await deliverRemoval(id, reason);
        // The db getter runs synchronously before confirmation's first await.
        // Drain an incorrectly started confirmation too: the old implementation
        // must fail on persisted state, without racing SQLite or teardown.
        if (observed.openChecks > 0) await observed.confirmed.future;
        expect(
          retry.getRetryInfo(id),
          reason == 'client_ack_confirm' ? same(pending) : isNull,
        );
        await expectRecoverable(store, id, original);
        expect(observed.openChecks, 0);
      }
    });
  }

  test('拒绝后真实 ACK 可确认，重复 ACK 不改写已确认记录', () async {
    const id = 'rejected-then-confirmed';
    final store = CryptoStore(db);
    await store.ensureSchema();
    await store.insertOutbox(id: id, payload: jsonEncode(_v3Envelope()));
    final original = await store.getOutboxEntry(id);
    retry.addToRetryQueue(id, 'C2C');
    final rejected = _AckDatabase(db);
    SqliteService.setDbForTest(rejected);
    await deliverRemoval(id, 'not_a_friend');
    if (rejected.openChecks > 0) await rejected.confirmed.future;
    expect(retry.getRetryInfo(id), isNull);
    await expectRecoverable(store, id, original);

    final confirmed = _AckDatabase(db);
    SqliteService.setDbForTest(confirmed);
    await deliverRemoval(id, 'server_ack');
    await confirmed.confirmed.future;
    expect((await store.getOutboxEntry(id))?['status'], 'sent');
    expect((await store.getOutboxEntry(id))?['payload'], original?['payload']);

    // A fixed old timestamp makes an accidental duplicate write observable
    // without relying on the wall clock moving between the two events.
    await db.update(
      'crypto_outbox',
      {'sent_at': 123},
      where: 'id = ?',
      whereArgs: [id],
    );
    final once = await store.getOutboxEntry(id);
    final duplicate = _AckDatabase(db);
    SqliteService.setDbForTest(duplicate);
    await deliverRemoval(id, 'server_ack');
    await duplicate.confirmed.future;
    expect(await store.getOutboxEntry(id), once);
    expect(await store.pendingOutbox(), isEmpty);
    await store.purgeOutbox(olderThanMs: 0);
    expect(await store.getOutboxEntry(id), isNull);
  });

  test('ACK 写入等待期间的拒绝事件不启动另一笔确认', () async {
    const id = 'ack-rejection-race';
    final store = CryptoStore(db);
    await store.ensureSchema();
    await store.insertOutbox(id: id, payload: jsonEncode(_v3Envelope()));
    final original = await store.getOutboxEntry(id);
    retry.addToRetryQueue(id, 'C2C');
    final ack = _AckDatabase(db, holdUpdate: true);
    SqliteService.setDbForTest(ack);
    await deliverRemoval(id, 'server_ack');
    await ack.updateStarted.future;
    try {
      final rejection = _AckDatabase(db);
      SqliteService.setDbForTest(rejection);
      await deliverRemoval(id, 'in_denylist');
      if (rejection.openChecks > 0) await rejection.confirmed.future;
      expect(rejection.updateStarted.isCompleted, isFalse);
      await expectRecoverable(store, id, original);
      expect(retry.getRetryInfo(id), isNull);
    } finally {
      ack.releaseUpdate.complete();
      await ack.confirmed.future;
    }
    expect((await store.getOutboxEntry(id))?['status'], 'sent');
  });

  test('数据库不可用时 ACK 仍停止重试且保留恢复数据', () async {
    const id = 'unavailable-db';
    final store = CryptoStore(db);
    await store.ensureSchema();
    await store.insertOutbox(id: id, payload: jsonEncode(_v3Envelope()));
    final original = await store.getOutboxEntry(id);
    retry.addToRetryQueue(id, 'C2C');
    SqliteService.setDbUnavailableForTest();
    await deliverRemoval(id, 'server_ack');
    expect(retry.getRetryInfo(id), isNull);
    await expectRecoverable(store, id, original);
  });

  test('真实 outbox UPDATE 错误不阻断 ACK 出队且不破坏 pending', () async {
    // Existing optional table with a missing column: this reaches a real SQL
    // error, unlike the absent-table fast path above.
    await db.execute(
      'CREATE TABLE crypto_outbox (id TEXT PRIMARY KEY, payload TEXT, '
      'status TEXT, created_at INTEGER)',
    );
    const id = 'broken-outbox-schema';
    final store = CryptoStore(db);
    await store.insertOutbox(id: id, payload: jsonEncode(_v3Envelope()));
    final original = await store.getOutboxEntry(id);
    retry.addToRetryQueue(id, 'C2C');
    final observed = _AckDatabase(db);
    SqliteService.setDbForTest(observed);
    final failed = expectLater(
      observed.confirmed.future,
      throwsA(isA<DatabaseException>()),
    );
    await deliverRemoval(id, 'server_ack');
    await failed;
    expect(retry.getRetryInfo(id), isNull);
    await expectRecoverable(store, id, original);
  });
}
