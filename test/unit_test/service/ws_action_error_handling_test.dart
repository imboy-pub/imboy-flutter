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
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
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
}
