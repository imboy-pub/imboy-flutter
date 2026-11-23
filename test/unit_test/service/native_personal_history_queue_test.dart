import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/web_personal_history_upload_refs.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _domain = 'shared-domain';
const _conversation = 'c2c:1:2';
const _generation = 1;
final _ownerA = List.filled(64, 'a').join();
final _ownerB = List.filled(64, 'b').join();

Future<Database> _open() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  addTearDown(db.close);
  return db;
}

Future<void> _enqueue(PersonalHistoryLocalStore store, String id, int time) =>
    store.enqueueUpload(
      domain: _domain,
      generation: _generation,
      conversationId: _conversation,
      msgId: id,
      actionVersion: 0,
      convSeq: 10,
      ciphertext: 'contract-fixture',
      envelopeMeta: const {},
      clientTs: time,
    );

Future<void> _project(
  PersonalHistoryLocalStore store, {
  required String text,
  required int sequence,
  bool deleted = false,
}) async {
  await store.applyEvents(
    domain: _domain,
    generation: _generation,
    events: [
      PersonalHistoryLocalEvent(
        seq: sequence,
        conversationId: _conversation,
        msgId: 'same-message',
        actionVersion: 0,
        deleted: deleted,
        plaintext: deleted ? null : {'text': text},
      ),
    ],
    proposedCursor: sequence,
    applyEvent: (txn, item, localDomain, generation) async {
      await txn.insert('personal_history_restored_row', {
        'domain': localDomain,
        'generation': generation,
        'conversation_id': item.conversationId,
        'msg_id': item.msgId,
        'action_version': item.actionVersion,
        'row': jsonEncode(item.plaintext),
        'merged_at': sequence,
      });
    },
  );
}

Future<List<Map<String, Object?>>> _rows(PersonalHistoryLocalStore store) =>
    store.readRestoredRows(
      domain: _domain,
      generation: _generation,
      conversationId: _conversation,
    );

void main() {
  test('shared native file keeps endpoint queues, projections and tombstones apart', () async {
    final db = await _open();
    final a = PersonalHistoryLocalStore(
      () async => db,
      nativeOwnerDigest: _ownerA,
    );
    final b = PersonalHistoryLocalStore(
      () async => db,
      nativeOwnerDigest: _ownerB,
    );
    final legacy = PersonalHistoryLocalStore(() async => db);
    await _enqueue(a, 'same-message', 1);
    await _enqueue(b, 'same-message', 1);
    await _enqueue(legacy, 'old-unowned', 0);
    final aKey =
        (await a.pendingUploads(_domain, _generation)).single['idempotency_key']
            as String;
    final bKey =
        (await b.pendingUploads(_domain, _generation)).single['idempotency_key']
            as String;
    const oldKey = '$_domain|$_generation|$_conversation|old-unowned';
    expect(aKey, startsWith('native:$_ownerA:'));
    expect(bKey, startsWith('native:$_ownerB:'));
    for (final unknown in [bKey, oldKey]) {
      await a.markUploadAttempted(unknown);
      await a.removeUpload(unknown);
    }
    expect(
      (await b.pendingUploads(_domain, _generation)).single['attempts'],
      0,
    );
    expect(
      (await db.query(
        PersonalHistoryLocalStore.uploadQueueTable,
        where: 'idempotency_key = ?',
        whereArgs: [oldKey],
      )).single['attempts'],
      0,
    );

    await _project(a, text: 'A', sequence: 10);
    await _project(b, text: 'B', sequence: 10);
    await _project(legacy, text: 'unowned', sequence: 11);
    await _project(a, text: '', sequence: 12, deleted: true);
    expect((await a.readCheckpoint(_domain))?.cursor, 12);
    expect((await b.readCheckpoint(_domain))?.cursor, 10);
    expect((await legacy.readCheckpoint(_domain))?.cursor, 11);
    expect(await _rows(a), isEmpty);
    expect(jsonDecode((await _rows(b)).single['row'] as String), {'text': 'B'});
    expect(jsonDecode((await _rows(legacy)).single['row'] as String), {
      'text': 'unowned',
    });
    expect(
      await a.isTombstoned(_conversation, 'same-message', domain: _domain),
      isTrue,
    );
    expect(
      await b.isTombstoned(_conversation, 'same-message', domain: _domain),
      isFalse,
    );
  });

  test(
    'a failed first batch leaves ciphertext queued and lets the tail advance',
    () async {
      final db = await _open();
      final store = PersonalHistoryLocalStore(
        () async => db,
        nativeOwnerDigest: _ownerA,
      );
      for (var i = 1; i <= 33; i++) {
        await _enqueue(store, 'm$i', i);
      }
      final requests = <String>[];
      final engine = PersonalHistorySyncEngine(
        client: PersonalHistoryApiClient(
          transport: (method, path, {queryParameters, data}) async {
            expect(method, 'POST');
            expect(path, '/api/v1/personal-history/upload');
            final id = (data as Map)['msg_id'] as String;
            requests.add(id);
            return id == 'm33'
                ? const PersonalHistoryTransportResult(
                    httpStatus: 200,
                    body: {
                      'code': 0,
                      'payload': {'accepted': true},
                    },
                  )
                : const PersonalHistoryTransportResult(
                    httpStatus: 503,
                    body: {
                      'code': 1,
                      'payload': {'error': 'transient_failure'},
                    },
                  );
          },
        ),
        store: store,
        domain: _domain,
        decrypt: (_) async => null,
        isCurrent: () => true,
      );
      final attempted = <String>{};
      final first = await engine.flushUploads(
        generation: _generation,
        attemptedThisRun: attempted,
      );
      expect(first.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(first.uploaded, 0);
      expect(attempted, hasLength(32));
      expect(
        (await store.pendingUploads(
          _domain,
          _generation,
          limit: 1,
        )).single['msg_id'],
        'm33',
      );

      final second = await engine.flushUploads(
        generation: _generation,
        attemptedThisRun: attempted,
      );
      expect(second.uploaded, 1);
      expect(second.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(requests.last, 'm33');
      final third = await engine.flushUploads(
        generation: _generation,
        attemptedThisRun: attempted,
      );
      expect(third.uploaded, 0);
      expect(third.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(requests.toSet(), hasLength(33));
      expect(requests, hasLength(33));
      expect(await store.pendingUploads(_domain, _generation), hasLength(32));
    },
  );

  test(
    'deferred and removed source refs do not strand the next batch',
    () async {
      final db = await _open();
      final refs = WebPersonalHistoryUploadRefs(db, _ownerA, () {});
      final other = WebPersonalHistoryUploadRefs(db, _ownerB, () {});
      for (final scope in [refs, other]) {
        await scope.observe(
          enabled: true,
          domain: _domain,
          generation: _generation,
        );
      }
      Future<void> enqueue(String owner, int sequence) async {
        await db.transaction((tx) async {
          await WebPersonalHistoryUploadRefs.enqueue(tx, owner, (
            messageId: 'm$sequence',
            sequence: sequence,
            outbound: false,
          ), () {});
        });
      }

      await enqueue(_ownerB, 33);
      for (var i = 1; i <= 33; i++) {
        await enqueue(_ownerA, i);
      }
      final scanned = <String>{};
      final first = await refs.pending(
        _domain,
        _generation,
        excluding: scanned,
      );
      expect(first, hasLength(32));
      for (final ref in first) {
        scanned.add(ref.messageId);
        if (ref.sequence == 1) {
          await refs.remove(_domain, _generation, ref.messageId);
        } else {
          await refs.defer(_domain, _generation, ref.messageId);
        }
      }
      final tail = await refs.pending(_domain, _generation, excluding: scanned);
      expect(tail.single.messageId, 'm33');
      scanned.add(tail.single.messageId);
      await refs.defer(_domain, _generation, tail.single.messageId);
      expect(
        await refs.pending(_domain, _generation, excluding: scanned),
        isEmpty,
      );
      expect(await refs.pending(_domain, _generation), hasLength(32));
      expect(
        (await other.pending(_domain, _generation)).single.messageId,
        'm33',
      );
    },
  );
}
