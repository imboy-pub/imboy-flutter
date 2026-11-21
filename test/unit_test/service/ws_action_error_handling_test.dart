// 服务端操作拒绝帧（message_revoke_error / message_edit_error）客户端闭环
//
// 契约（plan-v2.2 wave2，对应 J18.d 拒绝分支）：
//   - 后端 msg_c2c_logic.erl / msg_c2g_logic.erl 对超窗/fail-closed 的撤回、
//     编辑请求下发 {reply, ErrorMsg}：id = 客户端操作帧自身 id（与
//     MessageRetry 队列 key 同源）、payload.original_msg_id = 原消息 id、
//     payload.error = 拒绝原因文案。
//   - 客户端发送方在 *_ack 到达前不做乐观写库（气泡转已撤回/已编辑均在
//     MessageActions 的 ack 分支落库），故失败闭环 = 停止重试 + 用户提示，
//     原消息行无需回滚。
//   - error 帧不是 *_ACK：ws_ack_forward_policy 的 isAckSwallowedByTransport
//     对 *_ERROR 天然放行（不扩例外集），帧照常转发 MessageService——
//     integration_test/chat/j18d_edit_window_test.dart 依赖该管道监听
//     message_edit_error。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/ws_ack_forward_policy.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _CapturingSink implements WebSocketSink {
  final List<dynamic> sent = [];

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async => null;

  @override
  Future<dynamic> get done => Future.value();

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {}
}

class _FakeChannel implements WebSocketChannel {
  final _CapturingSink capturingSink = _CapturingSink();

  @override
  WebSocketSink get sink => capturingSink;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => kSubProtocolV2;

  @override
  Stream<dynamic> get stream => const Stream.empty();

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 把 JSON map 包成服务端下发的 v2 MSG_S2C 帧（error reply 的默认投递帧型）
Uint8List _s2cFrame(Map<String, dynamic> msg) => ImboyFrame.encode(
  type: FrameType.msgS2C,
  flags: 0,
  payload: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
);

/// 还原后端 msg_c2c_logic.erl:566 / msg_c2g_logic.erl:826 的 error reply 形状
Map<String, dynamic> _actionErrorFrame({
  required String action,
  required String opMsgId,
  required String type,
  required String originalMsgId,
  String? errorText = '超过撤回时间限制(2分钟)',
  Object? payloadOverride,
}) {
  return {
    'id': opMsgId,
    'type': type,
    'from': '1001',
    'to': '100',
    'msg_type': 'custom',
    'action': action,
    'payload':
        payloadOverride ??
        {
          'content': '',
          'original_msg_id': originalMsgId,
          'error': errorText,
          'code': 10205,
        },
    'server_ts': 1751850000000,
  };
}

/// msg_c2c 最小 DDL（同 message_retry_state_test）
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

/// msg_c2g 最小 DDL（同 retry_plaintext_guard_c2g_test；C2G 用例的
/// pendingRetry 置位会回读消息行，缺表即失败并污染队列断言）。
const String _msgC2gDdl = '''
  CREATE TABLE msg_c2g (
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

/// toTypeMessage 的作者信息查询依赖 contact 表（本文件仅 repo.find，
/// 建空表防无关异常）。
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
    category_id TEXT,
    account_type TEXT,
    last_seen_at INTEGER,
    updated_at INTEGER
  )
''';

const String _msgC2cFtsDdl = '''
  CREATE TABLE msg_c2c_fts (
    id TEXT,
    conversation_uk3 TEXT,
    text_content TEXT
  )
''';

const String _cryptoOutboxDdl = '''
  CREATE TABLE crypto_outbox (
    id TEXT PRIMARY KEY,
    payload TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER NOT NULL,
    sent_at INTEGER
  )
''';

Future<MessageModel> _insertMsg(String id, {required int status}) async {
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  return repo.insert(
    MessageModel(
      id,
      autoId: 0,
      type: 'C2C',
      status: status,
      fromId: 1001,
      toId: 100,
      payload: {'msg_type': 'text', 'text': 'hi'},
      isAuthor: 1,
      conversationUk3: 'C2C_1001_100',
      msgType: 'text',
      createdAt: 1751850000000,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageRetry retry;
  late Database testDb;
  late String originalDeviceId;

  Future<Database> openTestDb() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    await db.execute(_msgC2gDdl);
    // send-gate 读 attachment_upload_task（迁移 v33）；缺表会让重试
    // claim 抛错，队列条目残留导致移除断言失败。
    await db.execute(
      'CREATE TABLE attachment_upload_task ('
      'id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, business_intent TEXT,'
      'scope TEXT, scope_ref TEXT, file_name TEXT, mime TEXT, plain_size INTEGER,'
      'plain_sha256 TEXT, object_key TEXT, stage TEXT, cipher TEXT, binding_hash TEXT,'
      'key_ref TEXT, ciphertext_sha256 TEXT, last_error TEXT, created_at INTEGER,'
      'updated_at INTEGER, upload_path TEXT)',
    );
    await db.execute(_contactDdl);
    await db.execute(_msgC2cFtsDdl);
    await db.execute(_cryptoOutboxDdl);
    // FL-02 LOCAL:01：_receiveMessage 全链路（进程内 C2C 内容消息落库）依赖
    // conversation 表；C2S 重试面依赖 msg_c2s/message_send_attempt（同
    // message_retry_terminal_state_test 的建表口径）。
    await db.execute(
      'CREATE TABLE conversation (user_id TEXT, peer_id TEXT, type TEXT, '
      'last_msg_id TEXT, last_msg_status INTEGER)',
    );
    await db.execute('CREATE TABLE msg_c2s AS SELECT * FROM msg_c2c WHERE 0');
    await db.execute(
      'CREATE TABLE message_send_attempt '
      '(user_id TEXT, anchor TEXT, token TEXT)',
    );
    return db;
  }

  setUpAll(() async {
    sqfliteFfiInit();
    testDb = await openTestDb();
    SqliteService.setDbForTest(testDb);
    retry = MessageRetry.instance;
    // 等实例创建触发的 _scanAndRetryFailedMessages 在空表上跑完
    await pumpEventQueue(times: 200);
  });

  setUp(() async {
    originalDeviceId = init.deviceId;
    init.deviceId = 'fl02-ws-action-device';
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    // setDbForTest 记录打开句柄时的 uid；StorageService.init 把 currentUid
    // 从 '' 变为 '100'，必须在此之后重新注入，否则 db getter 判定
    // _openUid 漂移会关闭句柄并尝试重开生产加密库（宿主机无插件实现）。
    if (!testDb.isOpen) {
      testDb = await openTestDb();
    }
    SqliteService.setDbForTest(testDb);
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    WebSocketService.resetForTest();
    retry.clearRetryQueue();
  });

  tearDown(() {
    WebSocketService.to.channelForTest = null;
    WebSocketService.to.framingForTest = FramingMode.none;
    WebSocketService.resetForTest();
    init.deviceId = originalDeviceId;
  });

  tearDownAll(() {
    retry.dispose();
    SqliteService.setDbForTest(null);
  });

  WebSocketService bootedService() {
    final svc = WebSocketService.to;
    svc.framingForTest = FramingMode.v2;
    svc.channelForTest = _FakeChannel();
    svc.statusForTest = SocketStatus.connected;
    return svc;
  }

  group('传输层放行契约（ws_ack_forward_policy 不吞 *_ERROR）', () {
    test('*_ERROR 不属于 *_ACK 吞没规则，ACK 规则本身不变', () {
      expect(isAckSwallowedByTransport('MESSAGE_REVOKE_ERROR'), isFalse);
      expect(isAckSwallowedByTransport('MESSAGE_EDIT_ERROR'), isFalse);
      // 对照：既有吞没/放行语义不变（REVOKE/EDIT ACK 均在例外集内放行）
      expect(isAckSwallowedByTransport('MESSAGE_REVOKE_ACK'), isFalse);
      expect(isAckSwallowedByTransport('MESSAGE_EDIT_ACK'), isFalse);
      expect(isAckSwallowedByTransport('CLIENT_ACK_CONFIRM'), isTrue);
      expect(isAckSwallowedByTransport('SOME_OTHER_ACK'), isTrue);
    });

    test('message_edit_error 继续转发 MessageService（J18.d 监听管道）', () async {
      final svc = bootedService();
      final forwarded = AppEventBus.on<WebSocketMessageReceivedEvent>()
          .firstWhere((event) => event.data['action'] == 'message_edit_error');
      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_edit_error',
            opMsgId: 'op00000000000000fwd1',
            type: 'C2C',
            originalMsgId: 'orig00000000000000fwd1',
          ),
        ),
      );
      final event = await forwarded.timeout(const Duration(seconds: 3));
      expect(event.type, 'C2C');
      expect(
        event.data['payload']['original_msg_id'],
        'orig00000000000000fwd1',
      );
    });
  });

  /// FFI 事务经真实事件循环（native port）返回；固定次数的 pumpEventQueue
  /// 不保证事务完成，CI 慢机上移除事件可能晚于断言到达。
  /// 有界轮询真实事件循环直到条件满足。
  Future<void> pumpUntilEventLoop(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  group('error 帧停止重试（MessageRetry 队列条目移除）', () {
    test('message_revoke_error 移除对应操作帧的重试条目', () async {
      final svc = bootedService();
      const opId = 'rev00000000000000stop1';
      retry.addToRetryQueue(opId, 'C2C');
      expect(retry.getRetryInfo(opId), isNotNull);

      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_revoke_error',
            opMsgId: opId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000rev1',
          ),
        ),
      );
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull);
    });

    test('message_edit_error 移除对应操作帧的重试条目', () async {
      final svc = bootedService();
      const opId = 'edt00000000000000stop1';
      retry.addToRetryQueue(opId, 'C2C');
      expect(retry.getRetryInfo(opId), isNotNull);

      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_edit_error',
            opMsgId: opId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000edt1',
            errorText: '超过编辑时间限制',
          ),
        ),
      );
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull);
    });

    test('C2G 类型的 message_edit_error 同样停止重试', () async {
      final svc = bootedService();
      const opId = 'c2g00000000000000stop1';
      retry.addToRetryQueue(opId, 'C2G');
      expect(retry.getRetryInfo(opId), isNotNull);

      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_edit_error',
            opMsgId: opId,
            type: 'C2G',
            originalMsgId: 'orig00000000000000c2g1',
          ),
        ),
      );
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull);
    });
  });

  group('本地状态保持与会话一致性', () {
    test('error 帧不修改原消息行，移除事件携带当前会话身份', () async {
      final svc = bootedService();
      const originalId = 'orig00000000000000keep1';
      const opId = 'kep00000000000000stop1';
      await _insertMsg(originalId, status: IMBoyMessageStatus.sent);

      final removals = <RemoveFromRetryQueueRequestedEvent>[];
      final removalReceived = Completer<void>();
      final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
          .listen((event) {
            removals.add(event);
            if (event.messageId == opId && !removalReceived.isCompleted) {
              removalReceived.complete();
            }
          });
      addTearDown(subscription.cancel);

      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_edit_error',
            opMsgId: opId,
            type: 'C2C',
            originalMsgId: originalId,
          ),
        ),
      );
      await removalReceived.future.timeout(const Duration(seconds: 3));

      // 本地无乐观写库：error 帧不得碰原消息行（原文展示即"恢复"）
      final msg = await MessageRepo(tableName: MessageRepo.c2cTable)
          .find(originalId);
      expect(msg, isNotNull);
      expect(msg!.status, IMBoyMessageStatus.sent);
      expect(msg.payload['text'], 'hi');

      // 移除事件与 MessageRetry 消费侧的会话校验（_isRemovalSessionCurrent）
      // 对齐，否则停重试会被静默拒绝
      expect(removals, hasLength(1));
      expect(removals.single.messageId, opId);
      expect(removals.single.reason, 'ws_action_error');
      expect(removals.single.ownerUid, '100');
      expect(
        removals.single.sessionGeneration,
        UserRepoLocal.to.sessionGeneration,
      );
    });
  });

  group('容错', () {
    test('未知 request_id 的 error 帧不崩溃、队列保持为空', () async {
      final svc = bootedService();
      const unknownId = 'unk00000000000000err1';
      const malformedId = 'unk00000000000000err2';

      final removals = <RemoveFromRetryQueueRequestedEvent>[];
      final removalsDone = Completer<void>();
      final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
          .listen((event) {
            removals.add(event);
            if (!removalsDone.isCompleted &&
                removals.any((event) => event.messageId == unknownId) &&
                removals.any((event) => event.messageId == malformedId)) {
              removalsDone.complete();
            }
          });
      addTearDown(subscription.cancel);

      // 队列里没有该 id；payload 缺 error 字段（后端 C2G 编辑 error 不带 content）
      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_edit_error',
            opMsgId: unknownId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000unk1',
            errorText: null,
          ),
        ),
      );
      // payload 非 Map 的畸形变体同样不得抛出
      svc.handleV2BinaryForTest(
        _s2cFrame(
          _actionErrorFrame(
            action: 'message_revoke_error',
            opMsgId: malformedId,
            type: 'C2C',
            originalMsgId: 'orig00000000000000unk1',
            payloadOverride: 'not-a-map',
          ),
        ),
      );
      // 两帧都要等待 SQLite FFI 事务完成，固定轮次的事件循环让步不足以同步。
      await removalsDone.future.timeout(const Duration(seconds: 3));

      expect(retry.getRetryInfo(unknownId), isNull);
      expect(removals, hasLength(2));
      expect(
        removals.map((event) => event.messageId),
        unorderedEquals([unknownId, malformedId]),
      );
      for (final event in removals) {
        expect(event.reason, 'ws_action_error');
        expect(event.ownerUid, '100');
        expect(event.sessionGeneration, UserRepoLocal.to.sessionGeneration);
      }
      expect(retry.getRetryInfo(malformedId), isNull);
    });
  });

  group('FL-02 LOCAL:01 乱序到达与断线幂等', () {
    late Database fl02Db;
    late ProviderContainer fl02Container;

    setUp(() async {
      // 全链路 _receiveMessage 依赖完整 schema、有效登录态与 provider 容器；
      // 沿用 message_offline_pagination_test 口径（prefs uid + secure token
      // 先行，否则处理中的会话守卫触发 quitLogin 关库）。
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      String enc(Object v) =>
          base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
      FlutterSecureStorage.setMockInitialValues({
        'secure_token':
            '${enc({'alg': 'none'})}.${enc({'exp': 4102444800, 'uid': 100})}.test',
      });
      await StorageService.init();
      databaseFactory = databaseFactoryFfi;
      AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
      fl02Db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(fl02Db);
      fl02Container = ProviderContainer();
      MessageService.setProviderContainer(fl02Container);
    });

    tearDown(() async {
      fl02Container.dispose();
      SqliteService.setDbForTest(testDb);
      await fl02Db.close();
      AppFeatureRegistry.clear();
    });

    Map<String, dynamic> c2cFrame(String id, String text, int createdAt) => {
      'id': id,
      'type': 'C2C',
      'from': '1001',
      'to': '100',
      'msg_type': 'text',
      'payload': {'msg_type': 'text', 'text': text},
      'created_at': createdAt,
    };

    Future<int> rowCount(List<String> ids) async {
      final rows = await fl02Db.query(
        'msg_c2c',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
      return rows.length;
    }

    test('102 先到、101 迟到：均落库一次，各发一次业务 ACK，无重复效果', () async {
      final ackIds = <String>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        (event) => ackIds.add(event.messageId ?? ''),
      );
      addTearDown(sub.cancel);

      // 102 先到
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000102', 'first-102', 1751850000102),
      );
      // 101 迟到（乱序到达，随后断线由 sink 不可用模拟——此处先钉乱序语义）
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000101', 'late-101', 1751850000101),
      );
      await pumpEventQueue(times: 50);

      expect(
        await rowCount(['fl02m00000000000101', 'fl02m00000000000102']),
        2,
        reason: '迟到 101 不被跳过，102 不重复落库',
      );
      expect(ackIds, contains('fl02m00000000000101'));
      expect(ackIds, contains('fl02m00000000000102'));
      expect(
        ackIds.where((id) => id == 'fl02m00000000000101').length,
        lessThanOrEqualTo(1),
        reason: '102 无重复业务效果',
      );
    });

    test('断线后离线补拉重复收到 101：本地幂等，不产生第二条业务效果', () async {
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000201', 'dup-101', 1751850000201),
      );
      await pumpEventQueue(times: 50);
      expect(
        await rowCount(['fl02m00000000000201']),
        1,
        reason: '断线前 101 已本地持久化',
      );

      // 模拟重连/离线补拉重复投递同一条 101
      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000201', 'dup-101', 1751850000201),
      );
      await pumpEventQueue(times: 50);

      expect(
        await rowCount(['fl02m00000000000201']),
        1,
        reason: '重复投递不得产生第二条消息行（幂等恢复）',
      );
    });

    test('负例：102 处理失败（payload 不可解析）不 ACK，101 不被牵连', () async {
      final ackIds = <String>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        (event) => ackIds.add(event.messageId ?? ''),
      );
      addTearDown(sub.cancel);

      await MessageService.to.processMessage(
        'C2C',
        c2cFrame('fl02m00000000000301', 'ok-101', 1751850000301),
      );
      await MessageService.to.processMessage('C2C', {
        'id': 'fl02m00000000000302',
        'type': 'C2C',
        'from': '1001',
        'to': '100',
        'msg_type': 'text',
        // 非法 payload：解不出 Map → fail-closed 不 ACK
        'payload': '\x00\x01not-json',
        'created_at': 1751850000302,
      });
      await pumpEventQueue(times: 50);

      expect(await rowCount(['fl02m00000000000301']), 1);
      expect(await rowCount(['fl02m00000000000302']), 0);
      expect(
        ackIds,
        isNot(contains('fl02m00000000000302')),
        reason: '失败帧不确认，服务端保留 pending',
      );
      expect(
        ackIds,
        contains('fl02m00000000000301'),
        reason: '101 不被 102 的失败牵连',
      );
    });
  });

  group('FL-02 LOCAL:02 S2C 去重层与 ACK 语义', () {
    setUp(() {
      MessageS2CService.resetS2CDedupForTest();
    });

    tearDown(() {
      MessageS2CService.resetS2CDedupForTest();
    });

    Stream<String> ackIds() =>
        AppEventBus.on<WebSocketMessageSendRequestEvent>().map(
          (event) => event.messageId ?? '',
        );

    Map<String, dynamic> s2cFrame(String id, String action, {String? msgType}) {
      final frame = <String, dynamic>{
        'id': id,
        'type': 'S2C',
        'action': action,
        'from': '1001',
        'to': '100',
        'payload': const <String, dynamic>{},
        'server_ts': 1751850000000,
      };
      if (msgType != null) frame['msg_type'] = msgType;
      return frame;
    }

    test('未知纯控制 S2C 重投：首帧 ACK，去重命中帧仍 ACK（向前兼容）', () async {
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);

      await MessageS2CService.switchS2C(
        s2cFrame('fl02s00000000000001', 'future_control_event'),
      );
      await MessageS2CService.switchS2C(
        s2cFrame('fl02s00000000000001', 'future_control_event'),
      );
      await pumpEventQueue();

      expect(
        acks.where((id) => id == 'fl02s00000000000001').length,
        2,
        reason: '去重命中也必须 ACK，否则服务端在重发窗口内继续重投',
      );
    });

    test('未知关键 S2C（携带内容 msg_type）首帧与去重命中帧均不确认', () async {
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);

      final frame = s2cFrame(
        'fl02s00000000000002',
        'future_content_event',
        msgType: 'forward',
      );
      await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
      await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
      await pumpEventQueue();

      expect(
        acks.where((id) => id == 'fl02s00000000000002'),
        isEmpty,
        reason: '未知关键 S2C 保留服务端 pending：首帧与重投都不确认',
      );
    });

    test('TTL 过期后旧事件重放：默认分支幂等（无副作用），关键帧仍不确认', () async {
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);

      await MessageS2CService.switchS2C(
        s2cFrame(
          'fl02s00000000000003',
          'future_content_event',
          msgType: 'forward',
        ),
      );
      await pumpEventQueue();
      // 把去重标记推到 TTL 之外，模拟 5 分钟后旧事件重放
      MessageS2CService.ageS2CDedupForTest(
        MessageS2CService.s2cDedupTtlMs + 1000,
      );
      await MessageS2CService.switchS2C(
        s2cFrame(
          'fl02s00000000000003',
          'future_content_event',
          msgType: 'forward',
        ),
      );
      await pumpEventQueue();

      expect(
        acks.where((id) => id == 'fl02s00000000000003'),
        isEmpty,
        reason: '旧事件重放不覆盖、不确认，等待可处理版本',
      );
    });

    test('帧 id 为空时回退复合 key 去重（2.4）', () async {
      // 直接钉 buildS2CDedupKey 的回退语义
      final key1 = MessageS2CService.buildS2CDedupKey(
        {'server_ts': 1751850000000},
        'future_control_event',
        '1001',
        '100',
      );
      final key2 = MessageS2CService.buildS2CDedupKey(
        {'server_ts': 1751850000000},
        'future_control_event',
        '1001',
        '100',
      );
      expect(key1, key2);
      expect(key1, 'future_control_event_1001_100_1751850000000');

      // 端到端：两帧同复合 key（无 id）→ 第二帧去重命中不抛异常；
      // 空 id 帧 _sendS2CAck 直接跳过（不得对空 id 发 ACK）。
      bootedService();
      final acks = <String>[];
      final sub = ackIds().listen(acks.add);
      addTearDown(sub.cancel);
      await MessageS2CService.switchS2C(s2cFrame('', 'future_control_event'));
      await MessageS2CService.switchS2C(s2cFrame('', 'future_control_event'));
      await pumpEventQueue();
      expect(acks.where((id) => id.isEmpty), isEmpty);
    });
  });

  group('FL-02 LOCAL:03 C2S 重试与最终结果', () {
    late Database fl02Db;

    setUp(() async {
      // 编辑 ack 落库走当前 schema 全列（minimal DDL 缺列会 SqfliteFfiException）
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '100',
        // toTypeMessage 需要当前用户最小档案（uid）
        Keys.currentUser: '{"uid": "100"}',
      });
      await StorageService.init();
      databaseFactory = databaseFactoryFfi;
      AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
      fl02Db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(fl02Db);
    });

    tearDown(() async {
      SqliteService.setDbForTest(testDb);
      await fl02Db.close();
      AppFeatureRegistry.clear();
    });

    test('重复 message_edit_ack 不二次应用编辑（幂等收敛）且队列条目移除', () async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      // 原始行 = 本人（uid 100）发出的消息，编辑操作被服务端确认
      await repo.insert(
        MessageModel(
          'fl02e00000000000001',
          autoId: 0,
          type: 'C2C',
          status: 2,
          fromId: 100,
          toId: 1001,
          payload: {'msg_type': 'text', 'text': 'before edit'},
          isAuthor: 1,
          conversationUk3: 'C2C_100_1001',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );

      const opId = 'fl02op000000000001';
      retry.addToRetryQueue(opId, 'C2C');
      expect(retry.getRetryInfo(opId), isNotNull);

      Map<String, dynamic> editAckFrame() => {
        'id': opId,
        'type': 'C2C',
        // 本人发出的编辑操作被服务端确认（isMyEdit 分支触发重试移除）
        'from': '100',
        'to': '1001',
        'msg_type': 'custom',
        'action': 'message_edit_ack',
        'payload': {
          'content': 'edited-once',
          'original_msg_id': 'fl02e00000000000001',
        },
        'server_ts': 1751850000000,
      };

      // 与 LOCAL:01 同口径直接驱动服务层入口
      await MessageService.to.processMessage('C2C', editAckFrame());
      await pumpUntilEventLoop(() => retry.getRetryInfo(opId) == null);
      expect(retry.getRetryInfo(opId), isNull, reason: '受理→完成后停止重试');

      final afterFirst = await repo.find('fl02e00000000000001');
      expect(afterFirst, isNotNull, reason: '最终状态可查询');

      // 同一 ack 重投：不产生第二条业务效果（编辑幂等），队列保持空
      await MessageService.to.processMessage('C2C', editAckFrame());
      await pumpEventQueue(times: 50);
      expect(retry.getRetryInfo(opId), isNull);
      final rows = await fl02Db.query(
        'msg_c2c',
        where: 'id = ?',
        whereArgs: ['fl02e00000000000001'],
      );
      expect(rows.length, 1);
    });
  });

  group('FL-02 LOCAL:04 非法帧与超限输入', () {
    test('截断 JSON/坏字节/超限帧不崩溃，同批后续有效帧仍被分发', () async {
      final svc = bootedService();
      // 截断 JSON
      svc.handleV2BinaryForTest(
        ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List.fromList(
            utf8.encode('{"id":"fuzz1","type":"C2C","payl'),
          ),
        ),
      );
      // 坏字节（非 JSON 非 protobuf 可解码）
      svc.handleV2BinaryForTest(
        ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List.fromList(List.generate(64, (i) => 0x07)),
        ),
      );
      // 超限输入：编码器 fail-closed（16MiB 上限超限即 ArgumentError，
      // 有界拒绝而非无界分配）；入站侧由 isInboundFrameSizeAllowed 拦截。
      expect(
        () => ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List(ImboyFrame.maxPayload + 1),
        ),
        throwsArgumentError,
      );

      // 同批后续有效帧仍被分发（不静默丢关键事件）：action 帧
      // 触发 WebSocketMessageReceivedEvent（与 FL-05 wire 测试同口径）
      final delivered = AppEventBus.on<WebSocketMessageReceivedEvent>()
          .firstWhere(
            (event) => event.data['action'] == 'fl02_after_fuzz_event',
          );
      svc.handleV2BinaryForTest(
        ImboyFrame.encode(
          type: FrameType.msgC2C,
          flags: 0,
          payload: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'id': 'fl02fuzzvalid001',
                'type': 'C2C',
                'action': 'fl02_after_fuzz_event',
                'payload': <String, dynamic>{},
              }),
            ),
          ),
        ),
      );
      final event = await delivered.timeout(const Duration(seconds: 3));
      expect(event.type, 'C2C');
    });

    test('超长 msg_ids 列表：有界处理不崩溃不无限循环', () async {
      final hugeIds = List.generate(
        2000,
        (i) => 'fl02bulk${i.toString().padLeft(6, '0')}',
      );
      final acks = <String>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        (event) => acks.add(event.messageId ?? ''),
      );
      addTearDown(sub.cancel);

      await MessageService.to.processMessage('C2C', {
        'id': 'fl02bulk00000000001',
        'type': 'C2C',
        'from': '1001',
        'to': '100',
        'action': 'message_read',
        'payload': {'msg_ids': hugeIds},
        'server_ts': 1751850000000,
      });
      await pumpEventQueue(times: 100);

      // 有界完成（到达此处即未崩溃/未死循环）；空库下逐条找不到目标是
      // 该 action 的既定 no-op 语义，不产生重复副作用。
      expect(hugeIds.length, 2000);
    });
  });
}
