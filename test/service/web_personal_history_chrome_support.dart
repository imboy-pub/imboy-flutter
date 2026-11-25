// FL-04:LOCAL:07/:08 个人云端历史 Web 边界（chrome）共享 harness。
//
// 拆分自 web_personal_history_chrome_test.dart（file_size_ratchet <800 行约束）：
// fixture 服务端 / 事件构造 / 上行代理 / 引擎解密注入 / 公共 setUp harness
// 下沉至此；用例按业务域分布在 web_personal_history_chrome*_test.dart。
// 本文件不含用例；`@TestOn('chrome')` 由各 test 文件自行声明。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart' as common;

import '../env_test_pin.dart';

/// 合同级 fixture 服务端：按冻结合同出页/受理 ACK/幂等上传。
/// （PersonalHistoryTransport 是 typedef；本类的 call 即该签名实现。）
class FixtureServer {
  FixtureServer({
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

Map<String, dynamic> fixtureEvent(
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

/// 上行 fixture：第一条上传成功、其后 transient_failure（可安全重试）。
class UploadFixtureServerDelegate {
  UploadFixtureServerDelegate(this._inner);
  final FixtureServer _inner;
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

/// 引擎默认解密注入（fixture 恒成功）。
Future<Map<String, dynamic>?> engineDecrypt(PersonalHistoryEvent event) async =>
    {
      'msg_id': event.msgId,
      'conversation_id': event.conversationId,
      'seq': event.seq,
      'text': 'plain-${event.msgId}',
    };

/// chrome 系列共享 harness：uid/owner/db/server/store/engine + restoredRows。
class WebPersonalHistoryChromeHarness {
  String uid = '';
  late AccountLocalTaskOwner owner;
  late common.Database db;
  late FixtureServer server;
  late PersonalHistoryLocalStore store;
  late PersonalHistorySyncEngine engine;
  late String databaseName;
  late String domain;
  int _domainSeq = 0;

  Future<void> setUpAll() async {
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
  }

  Future<void> setUp() async {
    db = (await SqliteService.to.db)!;
    databaseName = SqliteService.databaseNameForUid(uid);
    domain = 'fl04-chrome-test-${_domainSeq++}';
    server = FixtureServer(generation: 3, events: [], domain: domain);
    store = PersonalHistoryLocalStore(() async => db);
    engine = PersonalHistorySyncEngine(
      client: PersonalHistoryApiClient(transport: server.call),
      store: store,
      domain: domain,
      decrypt: engineDecrypt,
      isCurrent: () => true,
      durableConfirm: () async {
        await browserSqliteStorageBridge.durableAccountBarrier(
          db,
          databaseName: databaseName,
        );
      },
    );
  }

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
}
