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
import 'package:imboy/service/web_personal_history_upload_refs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart' as common;

import '../env_test_pin.dart';

/// 合同级 fixture 服务端：按冻结合同出页/受理 ACK/幂等上传。
/// （PersonalHistoryTransport 是 typedef；本类的 call 即该签名实现。）
class _FixtureServer {
  _FixtureServer({
    required this.generation,
    required this.events,
    required this.domain,
  });

  int generation;
  final String domain;
  final List<Map<String, dynamic>> events;

  final calls = <String>[];
  final ackedCursors = <int>[];
  final ackedGenerations = <int>[];
  final changeInstances = <Object?>[];
  final changeQueries = <Map<String, dynamic>>[];
  final ackInstances = <Object?>[];
  final uploadedKeys = <String>[];
  final uploadedBodies = <Map<String, dynamic>>[];
  final issuedByScope = <(int, Object?), int>{};
  int? changesGeneration;
  int? ackResponseGeneration;
  bool offline = false;
  bool resetHint = false;
  int? resetBefore;
  final snapshotPages = <String?, Map<String, dynamic>>{};
  final snapshotRequests = <String?>[];
  final completionAcks = <Map<String, dynamic>>[];
  Future<void> Function()? beforeCompletionAck;
  bool rejectCompletionAck = false;

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
          'domain': domain,
          'upload_cursor': 0,
        }),
        headers: {'cache-control': 'no-store'},
      );
    }
    if (path.endsWith('/changes')) {
      changeInstances.add(queryParameters?['client_instance']);
      changeQueries.add(Map<String, dynamic>.from(queryParameters ?? const {}));
      final cursor = (queryParameters?['cursor'] as int? ?? 0);
      if (cursor < (resetBefore ?? 0)) {
        return PersonalHistoryTransportResult(
          httpStatus: 200,
          body: _ok({
            'generation': generation,
            'events': <Object?>[],
            'reset_hint': true,
          }),
        );
      }
      final pending =
          events.where((event) => (event['event_seq'] as int) > cursor).toList()
            ..sort(
              (a, b) =>
                  (a['event_seq'] as int).compareTo(b['event_seq'] as int),
            );
      final page = pending.take(3).toList();
      final nextCursor = page.isEmpty ? null : page.last['event_seq'] as int;
      final scope = (generation, queryParameters?['client_instance']);
      if (nextCursor != null && nextCursor > (issuedByScope[scope] ?? 0)) {
        issuedByScope[scope] = nextCursor;
      }
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok({
          'generation': changesGeneration ?? generation,
          'events': page,
          'next_cursor': nextCursor,
          'reset_hint': resetHint,
        }),
      );
    }
    if (path.endsWith('/page') && queryParameters?['snapshot'] == 'account') {
      expect(queryParameters?['client_instance'], 'test-snapshot-did');
      final token = queryParameters?['page_token'] as String?;
      snapshotRequests.add(token);
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok(snapshotPages[token]!),
      );
    }
    if (path.endsWith('/ack-cursor')) {
      final body = data as Map;
      ackInstances.add(body['client_instance']);
      final cursor = body['cursor'] as int;
      final requestedGeneration = body['generation'];
      if (requestedGeneration != generation) {
        return PersonalHistoryTransportResult(
          httpStatus: 410,
          body: _error('generation_expired'),
        );
      }
      if (body['completion_token'] != null) {
        final completion = Map<String, dynamic>.from(body);
        completionAcks.add(completion);
        await beforeCompletionAck?.call();
        final last = snapshotPages.values.last;
        if (rejectCompletionAck ||
            cursor != last['recovery_cursor'] ||
            body['completion_token'] != last['completion_token']) {
          return PersonalHistoryTransportResult(
            httpStatus: 503,
            body: _error('transient_failure'),
          );
        }
        issuedByScope[(generation, body['client_instance'])] = cursor;
      }
      if (cursor >
          (issuedByScope[(generation, body['client_instance'])] ?? 0)) {
        return PersonalHistoryTransportResult(
          httpStatus: 409,
          body: _error('malformed_request'),
        );
      }
      ackedCursors.add(cursor);
      ackedGenerations.add(requestedGeneration as int);
      return PersonalHistoryTransportResult(
        httpStatus: 200,
        body: _ok({
          'accepted': true,
          'advanced_to': cursor,
          'generation': ackResponseGeneration ?? generation,
        }),
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
  'event_seq': seq,
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
    server = _FixtureServer(generation: 3, events: [], domain: domain);
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

  test(
    'locked references share the accepted row transaction and retry',
    () async {
      final scope = owner.preferenceKey(domain);
      final refs = WebPersonalHistoryUploadRefs(db, scope, () {});
      const first = (messageId: 'c2c-retry', sequence: null, outbound: true);
      const second = (messageId: 'c2c-locked', sequence: 7, outbound: false);
      expect(
        await refs.observe(enabled: false, domain: domain, generation: 0),
        isFalse,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(db, scope, first, () {}),
        isFalse,
      );
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name LIKE 'web_personal_history_upload_%'",
        ),
        isEmpty,
      );

      expect(
        await refs.observe(enabled: true, domain: domain, generation: 3),
        isTrue,
      );
      await expectLater(
        db.transaction((txn) async {
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
      expect(await refs.pending(domain, 3), isEmpty);

      await db.transaction((txn) async {
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
        db,
        databaseName: databaseName,
      );
      final reopened = WebPersonalHistoryUploadRefs(db, scope, () {});
      expect(await reopened.pending(domain, 3), [first, second]);
      await reopened.defer(domain, 3, first.messageId);
      expect(await reopened.pending(domain, 3), [second, first]);
      await reopened.remove(domain, 3, second.messageId);
      expect(await reopened.pending(domain, 3), [first]);
    },
  );

  test(
    'authoritative generation rotation isolates local upload references',
    () async {
      final scope = owner.preferenceKey(domain);
      final refs = WebPersonalHistoryUploadRefs(db, scope, () {});
      final other = WebPersonalHistoryUploadRefs(db, 'other-$scope', () {});
      const ref = (messageId: 'c2c-accepted', sequence: 3, outbound: true);
      expect(
        await refs.observe(enabled: true, domain: domain, generation: 3),
        isTrue,
      );
      expect(
        await other.observe(enabled: true, domain: domain, generation: 3),
        isTrue,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(db, scope, ref, () {}),
        isTrue,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(
          db,
          'other-$scope',
          ref,
          () {},
        ),
        isTrue,
      );
      expect(
        await refs.observe(enabled: false, domain: domain, generation: 4),
        isTrue,
      );
      expect(
        await refs.observe(enabled: true, domain: domain, generation: 3),
        isFalse,
      );
      expect(
        await refs.observe(enabled: true, domain: domain, generation: 4),
        isFalse,
      );
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(db, scope, ref, () {}),
        isFalse,
      );
      expect(await refs.pending(domain, 3), isEmpty);
      expect(await other.pending(domain, 3), [ref]);

      expect(
        await refs.observe(enabled: true, domain: domain, generation: 5),
        isTrue,
      );
      expect(await refs.pending(domain, 5), isEmpty);
      expect(
        await WebPersonalHistoryUploadRefs.enqueue(db, scope, ref, () {}),
        isTrue,
      );
      expect(await refs.pending(domain, 5), [ref]);
      await refs.remove(domain, 3, ref.messageId);
      expect(await refs.pending(domain, 5), [ref]);
    },
  );

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
    'changes page from a different generation is neither merged nor acked',
    () async {
      const conversationId = 'conv-generation-changed';
      server.changesGeneration = 4;
      server.events.add(_event(1, conversationId, 'm-1'));

      expect(
        (await engine.syncOnce()).kind,
        PersonalHistorySyncOutcomeKind.aborted,
      );
      expect(await store.readCheckpoint(domain), isNull);
      expect(await restoredRows(conversationId), isEmpty);
      expect(server.ackedCursors, isEmpty);
    },
  );

  test(
    'recovery refuses a different authorization domain before changes',
    () async {
      final outcome = await engine.syncOnce(
        expectedAuthorization: const PersonalHistoryStatus(
          state: 'ON',
          generation: 3,
          domain: 'different-deployment',
        ),
      );

      expect(outcome.kind, PersonalHistorySyncOutcomeKind.aborted);
      expect(await store.readCheckpoint(domain), isNull);
      expect(server.changeInstances, isEmpty);
      expect(server.ackInstances, isEmpty);
    },
  );

  test('recovery uses the same device instance for changes and ack', () async {
    final client = PersonalHistoryApiClient(
      transport: server.call,
      clientInstance: 'new-browser-device',
    );
    final status = await client.status();
    // 账号恢复模式（设备实例 + 期望授权）下服务端按账号快照形状下发事件，
    // 必带 accepted_message；旧形状会被客户端判为 malformedRequest。
    server.events.add(
      _event(1, 'conv-device-cursor', 'm-1')
        ..['accepted_message'] = {
          'from_id': '1',
          'to_id': '2',
          'conv_seq': 1,
          'action_version': 0,
        },
    );
    final outcome = await PersonalHistorySyncEngine(
      client: client,
      store: store,
      domain: domain,
      decrypt: engineDecrypt,
      isCurrent: () => true,
      durableConfirm: () => browserSqliteStorageBridge.durableAccountBarrier(
        db,
        databaseName: databaseName,
      ),
    ).syncOnce(expectedAuthorization: status);

    expect(status.domain, domain);
    expect(
      outcome.kind,
      PersonalHistorySyncOutcomeKind.synced,
      reason: 'outcome.error=${outcome.error}',
    );
    expect(server.changeInstances, everyElement('new-browser-device'));
    expect(server.changeInstances, isNotEmpty);
    expect(server.ackInstances, ['new-browser-device']);
    expect(server.ackedGenerations, [3]);
  });

  test(
    'fresh authorization advances generation and rejects late rollback',
    () async {
      final client = PersonalHistoryApiClient(transport: server.call);
      final previous = await client.status();
      server.events.add(_event(4, 'conv-before-reopen', 'm-before'));
      expect(
        (await engine.syncOnce(expectedAuthorization: previous)).kind,
        PersonalHistorySyncOutcomeKind.synced,
      );
      expect(await store.readCheckpoint(domain), (generation: 3, cursor: 4));

      server.generation = 4;
      server.events
        ..clear()
        ..add(_event(10005, 'conv-after-reopen', 'm-after'));
      final reopened = await client.status();
      expect(
        (await engine.syncOnce(expectedAuthorization: reopened)).kind,
        PersonalHistorySyncOutcomeKind.synced,
      );
      expect(await store.readCheckpoint(domain), (
        generation: 4,
        cursor: 10005,
      ));
      expect(await restoredRows('conv-before-reopen'), hasLength(1));
      expect(await restoredRows('conv-after-reopen'), hasLength(1));

      server.generation = 3;
      expect(
        (await engine.syncOnce(expectedAuthorization: previous)).kind,
        PersonalHistorySyncOutcomeKind.aborted,
      );
      expect(await store.readCheckpoint(domain), (
        generation: 4,
        cursor: 10005,
      ));
      expect(server.ackedGenerations, [3, 4]);
    },
  );

  test('revoked authorization after decrypt prevents merge and ack', () async {
    final client = PersonalHistoryApiClient(transport: server.call);
    final authorized = await client.status();
    const conversationId = 'conv-revoke-after-decrypt';
    server.events.add(_event(1, conversationId, 'm-revoked'));
    final recovery = PersonalHistorySyncEngine(
      client: client,
      store: store,
      domain: domain,
      decrypt: (event) async {
        server.generation = 4;
        return engineDecrypt(event);
      },
      isCurrent: () => true,
    );
    expect(
      (await recovery.syncOnce(expectedAuthorization: authorized)).kind,
      PersonalHistorySyncOutcomeKind.aborted,
    );
    expect(await store.readCheckpoint(domain), isNull);
    expect(await restoredRows(conversationId), isEmpty);
    expect(server.ackedCursors, isEmpty);
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
    'restored copy uses the newest scoped row with accepted facts',
    () async {
      const conv = 'conv-restored-copy';
      final current = _event(2, conv, 'edited', actionVersion: 1)
        ..['accepted_message'] = {
          'from_id': '9007199254740993',
          'to_id': '9007199254740995',
          'conv_seq': 2,
          'action_version': 1,
        };
      server.events.addAll([
        _event(1, conv, 'edited'),
        current,
        _event(3, conv, 'removed'),
        _event(4, conv, 'removed', deleted: true, actionVersion: 1),
        _event(5, 'other-conversation', 'unrelated'),
      ]);
      final client = PersonalHistoryApiClient(transport: server.call);
      final page = await client.changes(cursor: 0);
      expect(page.events[1].acceptedMessage, (
        fromId: '9007199254740993',
        toId: '9007199254740995',
        sequence: 2,
        actionVersion: 1,
      ));
      expect(
        (await engine.syncOnce()).kind,
        PersonalHistorySyncOutcomeKind.synced,
      );
      final rows = await store.readRestoredRows(
        domain: domain,
        generation: 3,
        conversationId: conv,
      );
      expect(rows.single['msg_id'], 'edited');
      expect(rows.single['action_version'], 1);
      final requested = await store.readRestoredRowsForPage(
        domain: domain,
        generation: 3,
        conversationId: conv,
        messageIds: ['edited', 'removed', 'unrelated'],
      );
      expect(requested.single['msg_id'], 'edited');
      expect(requested.single['action_version'], 1);
      expect(
        await store.readRestoredRowsForPage(
          domain: domain,
          generation: 3,
          conversationId: conv,
          messageIds: ['removed', 'unrelated'],
        ),
        isEmpty,
      );
      expect(
        await store.readRestoredRows(
          domain: domain,
          generation: 4,
          conversationId: conv,
        ),
        isEmpty,
      );
    },
  );

  test('snapshot page selects older durable rows by requested IDs', () async {
    const conv = 'conv-paginated-restored-copy';
    server.events.addAll([
      for (var seq = 1; seq <= 51; seq++) _event(seq, conv, 'message-$seq'),
    ]);
    expect(
      (await engine.syncOnce()).kind,
      PersonalHistorySyncOutcomeKind.synced,
    );
    final olderPage = await store.readRestoredRowsForPage(
      domain: domain,
      generation: 3,
      conversationId: conv,
      messageIds: ['message-1'],
    );
    expect(olderPage.single['msg_id'], 'message-1');
    final before = olderPage.single['row'] as String;
    final stamped = await store.stampRestoredRowsForPage(
      domain: domain,
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
      (await store.readRestoredRowsForPage(
        domain: domain,
        generation: 3,
        conversationId: conv,
        messageIds: ['message-1'],
      )).single['row'],
      '{"_personal_history_verified_conv_seq":1}',
    );
    final checkpoint = await store.readCheckpoint(domain);
    expect(checkpoint?.cursor, 51);
    expect(server.ackedCursors, [51]);
  });

  test('reset hint asks for rescan without acknowledging a cursor', () async {
    server.resetHint = true;

    expect(
      (await engine.syncOnce()).kind,
      PersonalHistorySyncOutcomeKind.rescanRequired,
    );
    expect(await store.readCheckpoint(domain), isNull);
    expect(server.ackedCursors, isEmpty);
  });

  const accountSnapshotConv = 'c2c:1:2';
  Map<String, dynamic> snapshotEvent(
    int seq,
    String id, {
    bool deleted = false,
    int actionVersion = 0,
    int? convSeq,
  }) =>
      _event(
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
    server.resetBefore = 100;
    server.snapshotPages.addAll({
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
    server.events.addAll([
      snapshotEvent(102, 'deleted', deleted: true),
      snapshotEvent(110, 'concurrent-unseen'),
      snapshotEvent(120, 'early-merged'),
    ]);
  }

  PersonalHistorySyncEngine accountRecoveryEngine({
    Future<void> Function()? durable,
  }) => PersonalHistorySyncEngine(
    client: PersonalHistoryApiClient(
      transport: server.call,
      webFace: true,
      clientInstance: 'test-snapshot-did',
    ),
    store: store,
    domain: domain,
    decrypt: (event) async => {'text': event.msgId},
    isCurrent: () => true,
    durableConfirm:
        durable ??
        () => browserSqliteStorageBridge.durableAccountBarrier(
          db,
          databaseName: databaseName,
        ),
  );

  PersonalHistoryStatus accountSnapshotScope() =>
      PersonalHistoryStatus(state: 'ON', generation: 3, domain: domain);

  test('account reset commits snapshot before exact ACK and resumes below an already merged event', () async {
    prepareAccountSnapshot();
    var durable = false;
    server.beforeCompletionAck = () async {
      expect(durable, isTrue);
      expect(await store.readCheckpoint(domain), isNull);
      expect(await store.isTombstoned(accountSnapshotConv, 'deleted'), isTrue);
    };
    final recovery = accountRecoveryEngine(
      durable: () async {
        await browserSqliteStorageBridge.durableAccountBarrier(
          db,
          databaseName: databaseName,
        );
        durable = true;
      },
    );
    final outcome = await recovery.syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(server.snapshotRequests, [null, 'second-page-token']);
    expect(server.completionAcks.single, {
      'cursor': 100,
      'generation': 3,
      'client_instance': 'test-snapshot-did',
      'completion_token': 'finished-token',
    });
    expect(server.ackedCursors, [100, 120]);
    expect((await store.readCheckpoint(domain))?.cursor, 120);
    expect(
      await store
          .readRestoredRows(
            domain: domain,
            generation: 3,
            conversationId: accountSnapshotConv,
          )
          .then((rows) => rows.map((row) => row['msg_id']).toSet()),
      {'early-merged', 'concurrent-unseen'},
    );
    expect(outcome.duplicates, 2);
  });

  test('account reset rejects a non-adjacent continuation cycle', () async {
    server.resetBefore = 100;
    server.snapshotPages.addAll({
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
    expect(server.snapshotRequests, [null, 'token-a', 'token-b']);
    expect(server.completionAcks, isEmpty);
    expect(server.ackedCursors, isEmpty);
    expect(await store.readCheckpoint(domain), isNull);
    final rows = await store.readRestoredRows(
      domain: domain,
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
    server.events.addAll([
      snapshotEvent(1, 'loses-proof'),
      snapshotEvent(2, 'keep-newer', actionVersion: 3),
    ]);
    expect((await recovery.syncOnce(expectedAuthorization: scope)).cursor, 2);
    server.resetBefore = 100;
    server.events
      ..clear()
      ..add(snapshotEvent(110, 'loses-proof', actionVersion: 2, convSeq: 1));
    server.snapshotPages[null] = {
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
      for (final row in await store.readRestoredRows(
        domain: domain,
        generation: 3,
        conversationId: accountSnapshotConv,
      ))
        row['msg_id']: row['action_version'],
    };
    server.beforeCompletionAck = () async {
      expect((await store.readCheckpoint(domain))?.cursor, 2);
      expect(await versions(), {'keep-newer': 3, 'other-live-copy': 0});
      expect(
        await store.isTombstoned(accountSnapshotConv, 'loses-proof'),
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
      await store.isTombstoned(accountSnapshotConv, 'loses-proof'),
      isFalse,
    );
  });

  test(
    'account reset rejects proofless bodies and mixed suppression events',
    () async {
      server.resetBefore = 100;
      final recovery = accountRecoveryEngine();
      final scope = accountSnapshotScope();
      for (final row in [
        snapshotEvent(1, 'missing-proof')..remove('accepted_message'),
        suppressedSnapshotEvent(2, 'mixed')..['ciphertext'] = 'unexpected',
      ]) {
        server.snapshotPages[null] = {
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
        expect(await store.readCheckpoint(domain), isNull);
        expect(server.completionAcks, isEmpty);
      }
    },
  );

  test('account reset consumes suppressed tail after watermark and keeps later changes', () async {
    server.resetBefore = 100;
    server.snapshotPages[null] = {
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
    server.events.addAll([
      suppressedSnapshotEvent(
        105,
        'proof-lost-after-scan',
        actionVersion: 1,
        convSeq: 5,
      ),
      snapshotEvent(112, 'next-live', convSeq: 6),
    ]);
    Future<Map<Object?, Object?>> versions() async => {
      for (final row in await store.readRestoredRows(
        domain: domain,
        generation: 3,
        conversationId: accountSnapshotConv,
      ))
        row['msg_id']: row['action_version'],
    };
    server.beforeCompletionAck = () async {
      expect(await store.readCheckpoint(domain), isNull);
      expect(await versions(), {'proof-lost-after-scan': 1});
    };
    final recovery = accountRecoveryEngine();
    final scope = accountSnapshotScope();
    final outcome = await recovery.syncOnce(expectedAuthorization: scope);
    expect(outcome.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(outcome.cursor, 112);
    expect(await versions(), {'next-live': 0});
    expect(
      await store.isTombstoned(accountSnapshotConv, 'proof-lost-after-scan'),
      isFalse,
    );
    expect(server.ackedCursors, [100, 112]);
    expect(server.changeQueries.map((query) => query['cursor']), [0, 100, 112]);
    expect(
      server.changeQueries.every(
        (query) =>
            query['snapshot'] == 'account' &&
            query['client_instance'] == 'test-snapshot-did',
      ),
      isTrue,
    );

    server.events.add(
      snapshotEvent(120, 'proof-lost-after-scan', actionVersion: 2, convSeq: 5),
    );
    final updated = await recovery.syncOnce(expectedAuthorization: scope);
    expect(updated.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(updated.cursor, 120);
    expect(await versions(), {'next-live': 0, 'proof-lost-after-scan': 2});
    expect(server.ackedCursors, [100, 112, 120]);
  });

  test(
    'account reset capability is optional for legacy changes requests',
    () async {
      server.events.add(snapshotEvent(9, 'legacy')..remove('accepted_message'));
      final legacy = PersonalHistoryApiClient(transport: server.call);
      final reply = await legacy.changes(cursor: 0);
      expect(reply.nextCursor, 9);
      expect(reply.events.single.suppressed, isFalse);
      expect(server.changeQueries.single.containsKey('snapshot'), isFalse);
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
      expect(server.changeQueries, hasLength(1));
    },
  );

  test('failed account completion leaves old checkpoint and retries staged rows idempotently', () async {
    prepareAccountSnapshot();
    final recovery = accountRecoveryEngine();
    server.rejectCompletionAck = true;
    final failed = await recovery.syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(failed.kind, PersonalHistorySyncOutcomeKind.ackFailed);
    expect(await store.readCheckpoint(domain), isNull);
    expect(server.ackedCursors, isEmpty);
    expect(server.completionAcks, hasLength(1));
    server.rejectCompletionAck = false;
    final retried = await recovery.syncOnce(
      expectedAuthorization: accountSnapshotScope(),
    );
    expect(retried.kind, PersonalHistorySyncOutcomeKind.synced);
    expect(retried.duplicates, 4);
    expect(server.snapshotRequests, [
      null,
      'second-page-token',
      null,
      'second-page-token',
    ]);
    expect((await store.readCheckpoint(domain))?.cursor, 120);
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
      expect(server.completionAcks, isEmpty);
      expect(server.ackedCursors, isEmpty);
      expect(await store.readCheckpoint(domain), isNull);
    },
  );

  test(
    'acknowledgement with a different generation does not sign off sync',
    () async {
      server.ackResponseGeneration = 4;
      server.events.add(_event(1, 'conv-ack-generation', 'm-1'));

      final result = await engine.syncOnce();
      expect(result.kind, PersonalHistorySyncOutcomeKind.failed);
      expect(
        result.error,
        isA<PersonalHistoryApiException>().having(
          (error) => error.code,
          'code',
          PersonalHistoryErrorCode.generationExpired,
        ),
      );
      expect(server.ackedGenerations, [3]);
    },
  );

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
      expect(server.ackedGenerations, [3]);
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
    'upload reports a partial result when a batch leaves ciphertext',
    () async {
      for (var id = 1; id <= 33; id++) {
        await store.enqueueUpload(
          domain: domain,
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
      final first = await engine.flushUploads(generation: 3);
      expect(first.kind, PersonalHistorySyncOutcomeKind.uploadPartial);
      expect(first.uploaded, 32);
      expect(
        (await store.pendingUploads(domain, 3)).single['msg_id'],
        'batch-33',
      );

      final second = await engine.flushUploads(generation: 3);
      expect(second.kind, PersonalHistorySyncOutcomeKind.synced);
      expect(second.uploaded, 1);
      expect(server.uploadedKeys, hasLength(33));
      expect(await store.pendingUploads(domain, 3), isEmpty);
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
      expect(server.uploadedBodies.single['generation'], 3);
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
