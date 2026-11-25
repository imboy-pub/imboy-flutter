@TestOn('chrome')
library;

/// FL-04:LOCAL:07/:08 个人云端历史 Web 边界（chrome + 真桥接 + 真 WASM SQLite）。
///
/// 本文件覆盖账号重置快照域（mh01-personal-history-contract v1.1 §10）：
/// - 快照提交先于精确 ACK、续页环检测、抑制版本隐藏与后续实证编辑接受。
/// - 无证明体/混合抑制事件拒绝；水位后抑制尾段消费。
/// - 失败 completion 保留旧检查点幂等重试；durable barrier 失败不发 completion。
/// - legacy changes 请求的快照能力可选。
///
/// 共享 fixture/harness 见 web_personal_history_chrome_support.dart。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';

import 'web_personal_history_chrome_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = WebPersonalHistoryChromeHarness();
  setUpAll(h.setUpAll);
  setUp(h.setUp);

  const accountSnapshotConv = 'c2c:1:2';
  Map<String, dynamic> snapshotEvent(
    int seq,
    String id, {
    bool deleted = false,
    int actionVersion = 0,
    int? convSeq,
  }) =>
      fixtureEvent(
          seq,
          accountSnapshotConv,
          id,
          deleted: deleted,
          actionVersion: actionVersion,
        )
        ..['conv_seq'] = convSeq ?? seq
        ..['accepted_message'] = {
          'from_id': '1',
          'to_id': '2',
          'conv_seq': convSeq ?? seq,
          'action_version': actionVersion,
        };

  Map<String, dynamic> suppressedSnapshotEvent(
    int seq,
    String id, {
    int actionVersion = 0,
    int? convSeq,
  }) => {
    'event_seq': seq,
    'conversation_id': accountSnapshotConv,
    'msg_id': id,
    'conv_seq': convSeq ?? seq,
    'action_version': actionVersion,
    'deleted': false,
    'suppressed': true,
  };

  void prepareAccountSnapshot() {
    h.server.resetBefore = 100;
    h.server.snapshotPages.addAll({
      null: {
        'generation': 3,
        'events': [snapshotEvent(120, 'early-merged')],
        'has_more': true,
        'page_token': 'second-page-token',
      },
      'second-page-token': {
        'generation': 3,
        'events': [snapshotEvent(102, 'deleted', deleted: true)],
        'has_more': false,
        'recovery_cursor': 100,
        'completion_token': 'finished-token',
      },
    });
    h.server.events.addAll([
      snapshotEvent(102, 'deleted', deleted: true),
      snapshotEvent(110, 'concurrent-unseen'),
      snapshotEvent(120, 'early-merged'),
    ]);
  }

  PersonalHistorySyncEngine accountRecoveryEngine({
    Future<void> Function()? durable,
  }) => PersonalHistorySyncEngine(
    client: PersonalHistoryApiClient(
      transport: h.server.call,
      webFace: true,
      clientInstance: 'test-snapshot-did',
    ),
    store: h.store,
    domain: h.domain,
    decrypt: (event) async => {'text': event.msgId},
    isCurrent: () => true,
    durableConfirm:
        durable ??
        () => browserSqliteStorageBridge.durableAccountBarrier(
          h.db,
          databaseName: h.databaseName,
        ),
  );

  PersonalHistoryStatus accountSnapshotScope() =>
      PersonalHistoryStatus(state: 'ON', generation: 3, domain: h.domain);

  test('account reset commits snapshot before exact ACK and resumes below an already merged event', () async {
    prepareAccountSnapshot();
    var durable = false;
    h.server.beforeCompletionAck = () async {
      expect(durable, isTrue);
      expect(await h.store.readCheckpoint(h.domain), isNull);
      expect(
        await h.store.isTombstoned(accountSnapshotConv, 'deleted'),
        isTrue,
      );
    };
    final recovery = accountRecoveryEngine(
      durable: () async {
        await browserSqliteStorageBridge.durableAccountBarrier(
          h.db,
          databaseName: h.databaseName,
        );
        durable = true;
      },
    );
    final outcome = await recovery.syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(h.server.snapshotRequests, [null, 'second-page-token']);
    expect(h.server.completionAcks.single, {
      'cursor': 100,
      'generation': 3,
      'client_instance': 'test-snapshot-did',
      'completion_token': 'finished-token',
    });
    expect(h.server.ackedCursors, [100, 120]);
    expect((await h.store.readCheckpoint(h.domain))?.cursor, 120);
    expect(
      await h.store
          .readRestoredRows(
            domain: h.domain,
            generation: 3,
            conversationId: accountSnapshotConv,
          )
          .then((rows) => rows.map((row) => row['msg_id']).toSet()),
      {'early-merged', 'concurrent-unseen'},
    );
    expect(outcome.duplicates, 2);
  });

  test('account reset rejects a non-adjacent continuation cycle', () async {
    h.server.resetBefore = 100;
    h.server.snapshotPages.addAll({
      null: {
        'generation': 3,
        'events': [snapshotEvent(88, 'first')],
        'has_more': true,
        'page_token': 'token-a',
      },
      'token-a': {
        'generation': 3,
        'events': [snapshotEvent(89, 'second')],
        'has_more': true,
        'page_token': 'token-b',
      },
      'token-b': {
        'generation': 3,
        'events': [snapshotEvent(90, 'repeated-continuation')],
        'has_more': true,
        'page_token': 'token-a',
      },
    });
    final outcome = await accountRecoveryEngine().syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.failed);
    expect(
      outcome.error,
      isA<PersonalHistoryApiException>().having(
        (error) => error.code,
        'code',
        PersonalHistoryErrorCode.malformedRequest,
      ),
    );
    expect(h.server.snapshotRequests, [null, 'token-a', 'token-b']);
    expect(h.server.completionAcks, isEmpty);
    expect(h.server.ackedCursors, isEmpty);
    expect(await h.store.readCheckpoint(h.domain), isNull);
    final rows = await h.store.readRestoredRows(
      domain: h.domain,
      generation: 3,
      conversationId: accountSnapshotConv,
    );
    expect(
      rows.map((row) => row['msg_id']),
      unorderedEquals(['first', 'second']),
    );
  });

  test('account reset hides only suppressed versions and accepts a later proven edit', () async {
    final recovery = accountRecoveryEngine();
    final scope = accountSnapshotScope();
    h.server.events.addAll([
      snapshotEvent(1, 'loses-proof'),
      snapshotEvent(2, 'keep-newer', actionVersion: 3),
    ]);
    expect((await recovery.syncOnce(expectedAuthorization: scope)).cursor, 2);
    h.server.resetBefore = 100;
    h.server.events
      ..clear()
      ..add(snapshotEvent(110, 'loses-proof', actionVersion: 2, convSeq: 1));
    h.server.snapshotPages[null] = {
      'generation': 3,
      'events': [
        suppressedSnapshotEvent(1, 'loses-proof'),
        suppressedSnapshotEvent(3, 'keep-newer', actionVersion: 1, convSeq: 2),
        snapshotEvent(4, 'other-live-copy'),
      ],
      'has_more': false,
      'recovery_cursor': 100,
      'completion_token': 'finished-token',
    };
    Future<Map<Object?, Object?>> versions() async => {
      for (final row in await h.store.readRestoredRows(
        domain: h.domain,
        generation: 3,
        conversationId: accountSnapshotConv,
      ))
        row['msg_id']: row['action_version'],
    };
    h.server.beforeCompletionAck = () async {
      expect((await h.store.readCheckpoint(h.domain))?.cursor, 2);
      expect(await versions(), {'keep-newer': 3, 'other-live-copy': 0});
      expect(
        await h.store.isTombstoned(accountSnapshotConv, 'loses-proof'),
        isFalse,
      );
    };
    final outcome = await recovery.syncOnce(expectedAuthorization: scope);
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(outcome.cursor, 110);
    expect(await versions(), {
      'keep-newer': 3,
      'other-live-copy': 0,
      'loses-proof': 2,
    });
    expect(
      await h.store.isTombstoned(accountSnapshotConv, 'loses-proof'),
      isFalse,
    );
  });

  test(
    'account reset rejects proofless bodies and mixed suppression events',
    () async {
      h.server.resetBefore = 100;
      final recovery = accountRecoveryEngine();
      final scope = accountSnapshotScope();
      for (final row in [
        snapshotEvent(1, 'missing-proof')..remove('accepted_message'),
        suppressedSnapshotEvent(2, 'mixed')..['ciphertext'] = 'unexpected',
      ]) {
        h.server.snapshotPages[null] = {
          'generation': 3,
          'events': [row],
          'has_more': false,
          'recovery_cursor': 100,
          'completion_token': 'finished-token',
        };
        final outcome = await recovery.syncOnce(expectedAuthorization: scope);
        expect(outcome.kind, PersonalHistorySyncOutcomeKind.failed);
        expect(
          outcome.error,
          isA<PersonalHistoryApiException>().having(
            (error) => error.code,
            'code',
            PersonalHistoryErrorCode.malformedRequest,
          ),
        );
        expect(await h.store.readCheckpoint(h.domain), isNull);
        expect(h.server.completionAcks, isEmpty);
      }
    },
  );

  test('account reset consumes suppressed tail after watermark and keeps later changes', () async {
    h.server.resetBefore = 100;
    h.server.snapshotPages[null] = {
      'generation': 3,
      'events': [
        snapshotEvent(
          105,
          'proof-lost-after-scan',
          actionVersion: 1,
          convSeq: 5,
        ),
      ],
      'has_more': false,
      'recovery_cursor': 100,
      'completion_token': 'finished-token',
    };
    h.server.events.addAll([
      suppressedSnapshotEvent(
        105,
        'proof-lost-after-scan',
        actionVersion: 1,
        convSeq: 5,
      ),
      snapshotEvent(112, 'next-live', convSeq: 6),
    ]);
    Future<Map<Object?, Object?>> versions() async => {
      for (final row in await h.store.readRestoredRows(
        domain: h.domain,
        generation: 3,
        conversationId: accountSnapshotConv,
      ))
        row['msg_id']: row['action_version'],
    };
    h.server.beforeCompletionAck = () async {
      expect(await h.store.readCheckpoint(h.domain), isNull);
      expect(await versions(), {'proof-lost-after-scan': 1});
    };
    final recovery = accountRecoveryEngine();
    final scope = accountSnapshotScope();
    final outcome = await recovery.syncOnce(expectedAuthorization: scope);
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(outcome.cursor, 112);
    expect(await versions(), {'next-live': 0});
    expect(
      await h.store.isTombstoned(accountSnapshotConv, 'proof-lost-after-scan'),
      isFalse,
    );
    expect(h.server.ackedCursors, [100, 112]);
    expect(h.server.changeQueries.map((query) => query['cursor']), [
      0,
      100,
      112,
    ]);
    expect(
      h.server.changeQueries.every(
        (query) =>
            query['snapshot'] == 'account' &&
            query['client_instance'] == 'test-snapshot-did',
      ),
      isTrue,
    );

    h.server.events.add(
      snapshotEvent(120, 'proof-lost-after-scan', actionVersion: 2, convSeq: 5),
    );
    final updated = await recovery.syncOnce(expectedAuthorization: scope);
    expect(updated.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(updated.cursor, 120);
    expect(await versions(), {'next-live': 0, 'proof-lost-after-scan': 2});
    expect(h.server.ackedCursors, [100, 112, 120]);
  });

  test(
    'account reset capability is optional for legacy changes requests',
    () async {
      h.server.events.add(
        snapshotEvent(9, 'legacy')..remove('accepted_message'),
      );
      final legacy = PersonalHistoryApiClient(transport: h.server.call);
      final reply = await legacy.changes(cursor: 0);
      expect(reply.nextCursor, 9);
      expect(reply.events.single.suppressed, isFalse);
      expect(h.server.changeQueries.single.containsKey('snapshot'), isFalse);
      await expectLater(
        legacy.changes(cursor: 0, accountRecovery: true),
        throwsA(
          isA<PersonalHistoryApiException>().having(
            (error) => error.code,
            'code',
            PersonalHistoryErrorCode.identityRejected,
          ),
        ),
      );
      expect(h.server.changeQueries, hasLength(1));
    },
  );

  test('failed account completion leaves old checkpoint and retries staged rows idempotently', () async {
    prepareAccountSnapshot();
    final recovery = accountRecoveryEngine();
    h.server.rejectCompletionAck = true;
    final failed = await recovery.syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(failed.kind, PersonalHistorySyncOutcomeKind.ackFailed);
    expect(await h.store.readCheckpoint(h.domain), isNull);
    expect(h.server.ackedCursors, isEmpty);
    expect(h.server.completionAcks, hasLength(1));
    h.server.rejectCompletionAck = false;
    final retried = await recovery.syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(retried.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(retried.duplicates, 4);
    expect(h.server.snapshotRequests, [
      null,
      'second-page-token',
      null,
      'second-page-token',
    ]);
    expect((await h.store.readCheckpoint(h.domain))?.cursor, 120);
  });

  test(
    'account reset never sends completion with failed durable barrier',
    () async {
      prepareAccountSnapshot();
      final recovery = accountRecoveryEngine(
        durable: () async {
          throw StateError('indexeddb durability failure');
        },
      );
      final outcome = await recovery.syncOnce(
        expectedAuthorization: accountSnapshotScope(),
      );
      expect(outcome.kind, PersonalHistorySyncOutcomeKind.durabilityFailed);
      expect(h.server.completionAcks, isEmpty);
      expect(h.server.ackedCursors, isEmpty);
      expect(await h.store.readCheckpoint(h.domain), isNull);
    },
  );
}
