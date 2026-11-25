@TestOn('chrome')
library;

/// FL-04:LOCAL:07/:08 个人云端历史 Web 边界（chrome + 真桥接 + 真 WASM SQLite）。
///
/// 本文件覆盖同步授权/ACK/上行域：
/// - 上行队列引用：事务内锁定、代次隔离（MSG-H22）。
/// - :06/:07 授权世代：会话切换中止、跨代不合并不 ACK、设备实例一致性、
///   撤权拒绝、显式授权代次（mh01-personal-history-contract v1.1 §2/§10）。
/// - :07.2 VFS 持久确认失败 → 不发送 ACK、不产生「半确认」（MH-01 §5/§10.8）。
/// - 上行队列：幂等键去重、transient 重试、只重试当前代次（MSG-H22）。
///
/// 共享 fixture/harness 见 web_personal_history_chrome_support.dart；
/// 本地读模型/矩阵域见 web_personal_history_chrome_local_read_test.dart；
/// 账号重置域见 web_personal_history_chrome_account_reset_test.dart。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/web_personal_history_upload_refs.dart';

import 'web_personal_history_chrome_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = WebPersonalHistoryChromeHarness();
  setUpAll(h.setUpAll);
  setUp(h.setUp);

  test(
    'locked references share the accepted row transaction and retry',
    () async {
      final scope = h.owner.preferenceKey(h.domain);
      final refs = WebPersonalHistoryUploadRefs(h.db, scope, () {});
      const first = (messageId: 'c2c-retry', sequence: null, outbound: true);
      const second = (messageId: 'c2c-locked', sequence: 7, outbound: false);
      expect(
        await refs.observe(enabled: false, domain: h.domain, generation: 0),
        isFalse,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(h.db, scope, first, () {}),
        isFalse,
      );
      expect(
        await h.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name LIKE 'web_personal_history_upload_%'",
        ),
        isEmpty,
      );

      expect(
        await refs.observe(enabled: true, domain: h.domain, generation: 3),
        isTrue,
      );
      await expectLater(
        h.db.transaction((txn) async {
          expect(
            await WebPersonalHistoryUploadRefs.enqueue(
              txn,
              scope,
              first,
              () {},
            ),
            isTrue,
          );
          throw StateError('ordinary source transaction rolled back');
        }),
        throwsStateError,
      );
      expect(await refs.pending(h.domain, 3), isEmpty);

      await h.db.transaction((txn) async {
        expect(
          await WebPersonalHistoryUploadRefs.enqueue(txn, scope, first, () {}),
          isTrue,
        );
        expect(
          await WebPersonalHistoryUploadRefs.enqueue(txn, scope, first, () {}),
          isFalse,
        );
        expect(
          await WebPersonalHistoryUploadRefs.enqueue(txn, scope, second, () {}),
          isTrue,
        );
      });
      await browserSqliteStorageBridge.durableAccountBarrier(
        h.db,
        databaseName: h.databaseName,
      );
      final reopened = WebPersonalHistoryUploadRefs(h.db, scope, () {});
      expect(await reopened.pending(h.domain, 3), [first, second]);
      await reopened.defer(h.domain, 3, first.messageId);
      expect(await reopened.pending(h.domain, 3), [second, first]);
      await reopened.remove(h.domain, 3, second.messageId);
      expect(await reopened.pending(h.domain, 3), [first]);
    },
  );

  test(
    'authoritative generation rotation isolates local upload references',
    () async {
      final scope = h.owner.preferenceKey(h.domain);
      final refs = WebPersonalHistoryUploadRefs(h.db, scope, () {});
      final other = WebPersonalHistoryUploadRefs(h.db, 'other-$scope', () {});
      const ref = (messageId: 'c2c-accepted', sequence: 3, outbound: true);
      expect(
        await refs.observe(enabled: true, domain: h.domain, generation: 3),
        isTrue,
      );
      expect(
        await other.observe(enabled: true, domain: h.domain, generation: 3),
        isTrue,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(h.db, scope, ref, () {}),
        isTrue,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(
          h.db,
          'other-$scope',
          ref,
          () {},
        ),
        isTrue,
      );
      expect(
        await refs.observe(enabled: false, domain: h.domain, generation: 4),
        isTrue,
      );
      expect(
        await refs.observe(enabled: true, domain: h.domain, generation: 3),
        isFalse,
      );
      expect(
        await refs.observe(enabled: true, domain: h.domain, generation: 4),
        isFalse,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(h.db, scope, ref, () {}),
        isFalse,
      );
      expect(await refs.pending(h.domain, 3), isEmpty);
      expect(await other.pending(h.domain, 3), [ref]);

      expect(
        await refs.observe(enabled: true, domain: h.domain, generation: 5),
        isTrue,
      );
      expect(await refs.pending(h.domain, 5), isEmpty);
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(h.db, scope, ref, () {}),
        isTrue,
      );
      expect(await refs.pending(h.domain, 5), [ref]);
      await refs.remove(h.domain, 3, ref.messageId);
      expect(await refs.pending(h.domain, 5), [ref]);
    },
  );

  test('session change during decryption aborts before persisting', () async {
    const conversationId = 'conv-logout-during-decrypt';
    h.server.events.add(fixtureEvent(1, conversationId, 'm-1'));
    final decryptStarted = Completer<void>();
    final decryptResult = Completer<Map<String, dynamic>?>();
    var isCurrent = true;
    final pending = PersonalHistorySyncEngine(
      client: PersonalHistoryApiClient(transport: h.server.call),
      store: h.store,
      domain: h.domain,
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
    expect(await h.store.readCheckpoint(h.domain), isNull);
    expect(await h.restoredRows(conversationId), isEmpty);
    expect(h.server.ackedCursors, isEmpty);
  });

  test(
    'changes page from a different generation is neither merged nor acked',
    () async {
      const conversationId = 'conv-generation-changed';
      h.server.changesGeneration = 4;
      h.server.events.add(fixtureEvent(1, conversationId, 'm-1'));

      expect(
        (await h.engine.syncOnce()).kind,
        PersonalHistorySyncOutcomeKind.aborted,
      );
      expect(await h.store.readCheckpoint(h.domain), isNull);
      expect(await h.restoredRows(conversationId), isEmpty);
      expect(h.server.ackedCursors, isEmpty);
    },
  );

  test(
    'recovery refuses a different authorization domain before changes',
    () async {
      final outcome = await h.engine.syncOnce(
        expectedAuthorization: const PersonalHistoryStatus(
          state: 'ON',
          generation: 3,
          domain: 'different-deployment',
        ),
      );

      expect(outcome.kind, PersonalHistorySyncOutcomeKind.aborted);
      expect(await h.store.readCheckpoint(h.domain), isNull);
      expect(h.server.changeInstances, isEmpty);
      expect(h.server.ackInstances, isEmpty);
    },
  );

  test('recovery uses the same device instance for changes and ack', () async {
    final client = PersonalHistoryApiClient(
      transport: h.server.call,
      clientInstance: 'new-browser-device',
    );
    final status = await client.status();
    // 账号恢复模式（设备实例 + 期望授权）下服务端按账号快照形状下发事件，
    // 必带 accepted_message；旧形状会被客户端判为 malformedRequest。
    h.server.events.add(
      fixtureEvent(1, 'conv-device-cursor', 'm-1')
        ..['accepted_message'] = {
          'from_id': '1',
          'to_id': '2',
          'conv_seq': 1,
          'action_version': 0,
        },
    );
    final outcome = await PersonalHistorySyncEngine(
      client: client,
      store: h.store,
      domain: h.domain,
      decrypt: engineDecrypt,
      isCurrent: () => true,
      durableConfirm: () => browserSqliteStorageBridge.durableAccountBarrier(
        h.db,
        databaseName: h.databaseName,
      ),
    ).syncOnce(expectedAuthorization: status);

    expect(status.domain, h.domain);
    expect(
      outcome.kind,
      PersonalHistorySyncOutcomeKind.synced,
      reason: 'outcome.error=${outcome.error}',
    );
    expect(h.server.changeInstances, everyElement('new-browser-device'));
    expect(h.server.changeInstances, isNotEmpty);
    expect(h.server.ackInstances, ['new-browser-device']);
    expect(h.server.ackedGenerations, [3]);
  });

  test(
    'fresh authorization advances generation and rejects late rollback',
    () async {
      final client = PersonalHistoryApiClient(transport: h.server.call);
      final previous = await client.status();
      h.server.events.add(fixtureEvent(4, 'conv-before-reopen', 'm-before'));
      expect(
        (await h.engine.syncOnce(expectedAuthorization: previous)).kind,
        PersonalHistorySyncOutcomeKind.synced,
      );
      expect(await h.store.readCheckpoint(h.domain), (
        generation: 3,
        cursor: 4,
      ));

      h.server.generation = 4;
      h.server.events
        ..clear()
        ..add(fixtureEvent(10005, 'conv-after-reopen', 'm-after'));
      final reopened = await client.status();
      expect(
        (await h.engine.syncOnce(expectedAuthorization: reopened)).kind,
        PersonalHistorySyncOutcomeKind.synced,
      );
      expect(await h.store.readCheckpoint(h.domain), (
        generation: 4,
        cursor: 10005,
      ));
      expect(await h.restoredRows('conv-before-reopen'), hasLength(1));
      expect(await h.restoredRows('conv-after-reopen'), hasLength(1));

      h.server.generation = 3;
      expect(
        (await h.engine.syncOnce(expectedAuthorization: previous)).kind,
        PersonalHistorySyncOutcomeKind.aborted,
      );
      expect(await h.store.readCheckpoint(h.domain), (
        generation: 4,
        cursor: 10005,
      ));
      expect(h.server.ackedGenerations, [3, 4]);
    },
  );

  test('revoked authorization after decrypt prevents merge and ack', () async {
    final client = PersonalHistoryApiClient(transport: h.server.call);
    final authorized = await client.status();
    const conversationId = 'conv-revoke-after-decrypt';
    h.server.events.add(fixtureEvent(1, conversationId, 'm-revoked'));
    final recovery = PersonalHistorySyncEngine(
      client: client,
      store: h.store,
      domain: h.domain,
      decrypt: (event) async {
        h.server.generation = 4;
        return engineDecrypt(event);
      },
      isCurrent: () => true,
    );
    expect(
      (await recovery.syncOnce(expectedAuthorization: authorized)).kind,
      PersonalHistorySyncOutcomeKind.aborted,
    );
    expect(await h.store.readCheckpoint(h.domain), isNull);
    expect(await h.restoredRows(conversationId), isEmpty);
    expect(h.server.ackedCursors, isEmpty);
  });

  test('Web key package uses an explicit authorization generation', () async {
    final sent = <Map<String, dynamic>>[];
    var responseGeneration = 9;
    final client = PersonalHistoryApiClient(
      webFace: true,
      transport: (method, path, {queryParameters, data}) async {
        expect(method, 'POST');
        expect(path, '/api/v1/web/personal-history/key-package');
        sent.add(Map<String, dynamic>.from(data as Map));
        return PersonalHistoryTransportResult(
          httpStatus: 200,
          body: {
            'code': 0,
            'payload': {'key_version': 1, 'generation': responseGeneration},
          },
        );
      },
    );
    const package = {'key_version': 1, 'wrapped_key': 'encoded-fixture'};

    await client.putKeyPackage(package, generation: 9);
    expect(sent.single, {...package, 'generation': 9});

    responseGeneration = 10;
    await expectLater(
      client.putKeyPackage(package, generation: 9),
      throwsA(
        isA<PersonalHistoryApiException>().having(
          (error) => error.code,
          'code',
          PersonalHistoryErrorCode.generationExpired,
        ),
      ),
    );
    expect(sent.last['generation'], 9);
  });

  test(
    'acknowledgement with a different generation does not sign off sync',
    () async {
      h.server.ackResponseGeneration = 4;
      h.server.events.add(fixtureEvent(1, 'conv-ack-generation', 'm-1'));

      final result = await h.engine.syncOnce();
      expect(result.kind, PersonalHistorySyncOutcomeKind.failed);
      expect(
        result.error,
        isA<PersonalHistoryApiException>().having(
          (error) => error.code,
          'code',
          PersonalHistoryErrorCode.generationExpired,
        ),
      );
      expect(h.server.ackedGenerations, [3]);
    },
  );

  test(
    ':07.2 VFS confirm failure refuses ACK; confirm success then acks once',
    () async {
      h.server.events.addAll([
        fixtureEvent(1, 'conv-a', 'm-1'),
        fixtureEvent(2, 'conv-a', 'm-2'),
        fixtureEvent(3, 'conv-a', 'm-3'),
        fixtureEvent(4, 'conv-a', 'm-4'),
      ]);
      // 阶段一：持久确认失败（VFS 故障注入）→ 无 ACK、无「半确认」。
      var confirmFailures = 1;
      final failingEngine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(transport: h.server.call),
        store: h.store,
        domain: h.domain,
        decrypt: engineDecrypt,
        isCurrent: () => true,
        durableConfirm: () async {
          if (confirmFailures > 0) {
            confirmFailures--;
            throw const BrowserSqliteStoragePoisoned();
          }
          await browserSqliteStorageBridge.durableAccountBarrier(
            h.db,
            databaseName: h.databaseName,
          );
        },
      );
      final failed = await failingEngine.syncOnce();
      expect(failed.kind, PersonalHistorySyncOutcomeKind.durabilityFailed);
      expect(h.server.ackedCursors, isEmpty, reason: 'VFS 确认失败必须拒绝 ack-cursor');
      expect(h.server.calls.where((c) => c.contains('ack-cursor')), isEmpty);

      // 阶段二：真实桥接 barrier 通过 → ACK 恰一次，游标=检查点。
      // 说明：确认失败后 SQL 状态可能已前跳（模拟故障不回滚内存态）——
      // 若 VFS 真失败（桥接 poison），重载后回到旧游标幂等重放，两条路径
      // 都收敛到同一检查点（seq 主键去重保证恰一次业务效果）。
      final outcome = await h.engine.syncOnce();
      expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(h.server.ackedCursors, [4]);
      expect(h.server.ackedGenerations, [3]);
      final checkpoint = await h.store.readCheckpoint(h.domain);
      expect(checkpoint, (generation: 3, cursor: 4));
      final convARows = await h.restoredRows('conv-a');
      expect(convARows.map((r) => r['msg_id']), ['m-1', 'm-2', 'm-3', 'm-4']);
    },
  );

  test(
    'upload reports a partial result when a batch leaves ciphertext',
    () async {
      for (var id = 1; id <= 33; id++) {
        await h.store.enqueueUpload(
          domain: h.domain,
          generation: 3,
          conversationId: 'conv-batch-limit',
          msgId: 'batch-$id',
          actionVersion: 0,
          convSeq: id,
          ciphertext: 'Y2lwaGVydGV4dA==',
          envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
          clientTs: 1700000000000 + id,
        );
      }
      final first = await h.engine.flushUploads(generation: 3);
      expect(first.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(first.uploaded, 32);
      expect(
        (await h.store.pendingUploads(h.domain, 3)).single['msg_id'],
        'batch-33',
      );

      final second = await h.engine.flushUploads(generation: 3);
      expect(second.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(second.uploaded, 1);
      expect(h.server.uploadedKeys, hasLength(33));
      expect(await h.store.pendingUploads(h.domain, 3), isEmpty);
    },
  );

  test(
    'upload queue: idempotent enqueue, transient retry, generation fence',
    () async {
      // 幂等键去重：同键两次入队只保留一行。
      await h.store.enqueueUpload(
        domain: h.domain,
        generation: 3,
        conversationId: 'conv-up',
        msgId: 'up-1',
        actionVersion: 0,
        convSeq: 1,
        ciphertext: 'Y2lwaGVydGV4dA==',
        envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
        clientTs: 1700000000000,
      );
      await h.store.enqueueUpload(
        domain: h.domain,
        generation: 3,
        conversationId: 'conv-up',
        msgId: 'up-1',
        actionVersion: 0,
        convSeq: 1,
        ciphertext: 'Y2lwaGVydGV4dA==',
        envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
        clientTs: 1700000000000,
      );
      await h.store.enqueueUpload(
        domain: h.domain,
        generation: 3,
        conversationId: 'conv-up',
        msgId: 'up-2',
        actionVersion: 0,
        convSeq: 2,
        ciphertext: 'Y2lwaGVydGV4dA==',
        envelopeMeta: const {'alg': 'aes-256-gcm', 'key_version': 1},
        clientTs: 1700000000001,
      );
      var pending = await h.store.pendingUploads(h.domain, 3);
      expect(pending, hasLength(2));

      // transient_failure：up-1 成功移除；up-2 保留待重试。
      final uploadClient = UploadFixtureServerDelegate(h.server);
      final flushEngine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(transport: uploadClient.call),
        store: h.store,
        domain: h.domain,
        decrypt: engineDecrypt,
        isCurrent: () => true,
      );
      final flushed = await flushEngine.flushUploads(generation: 3);
      expect(flushed.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(flushed.uploaded, 1);
      expect(h.server.uploadedBodies.single['generation'], 3);
      pending = await h.store.pendingUploads(h.domain, 3);
      expect(pending.map((r) => r['msg_id']), ['up-2']);
      expect(pending.single['attempts'], 1);

      // 代次变更（g4）：旧代次行不再重试（账号/撤销后中止旧任务）。
      expect(await h.store.pendingUploads(h.domain, 4), isEmpty);

      // 账号切换中途：isCurrent=false 中止冲刷且不误删队列。
      final abortEngine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(transport: h.server.call),
        store: h.store,
        domain: h.domain,
        decrypt: engineDecrypt,
        isCurrent: () => false,
      );
      final aborted = await abortEngine.flushUploads(generation: 3);
      expect(aborted.kind, PersonalHistorySyncOutcomeKind.aborted);
      expect(await h.store.pendingUploads(h.domain, 3), isNotEmpty);
    },
  );
}
