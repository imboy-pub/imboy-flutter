// ws_action_error_handling 契约测试共享基建（仅供同目录 *_test.dart 引用）
//
// 服务对象：
//   - ws_action_error_handling_test.dart（error 帧闭环契约）
//   - ws_fl02_local_recovery_test.dart（FL-02 LOCAL:01-04 系列）
//
// 拆分说明（ratchet APP-02）：原 ws_action_error_handling_test.dart 单文件
// 989 行超过 800 行上限，按业务域拆为上述两文件；共享桩/帧构造器/最小 DDL
// 内存库/生命周期样板逐字下沉至此（仅改符号名前缀），用例与 group 结构等价，
// 不改 ratchet baseline/阈值。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsActionCapturingSink implements WebSocketSink {
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

class WsActionFakeChannel implements WebSocketChannel {
  final WsActionCapturingSink capturingSink = WsActionCapturingSink();

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
Uint8List wsS2cFrame(Map<String, dynamic> msg) => ImboyFrame.encode(
  type: FrameType.msgS2C,
  flags: 0,
  payload: Uint8List.fromList(utf8.encode(jsonEncode(msg))),
);

/// 还原后端 msg_c2c_logic.erl:566 / msg_c2g_logic.erl:826 的 error reply 形状
Map<String, dynamic> wsActionErrorFrame({
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

Future<MessageModel> wsInsertMsg(String id, {required int status}) async {
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

Future<Database> wsOpenTestDb() async {
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

/// FFI 事务经真实事件循环（native port）返回；固定次数的 pumpEventQueue
/// 不保证事务完成，CI 慢机上移除事件可能晚于断言到达。
/// 有界轮询真实事件循环直到条件满足。
Future<void> pumpUntilEventLoop(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// error 帧闭环两文件共享的生命周期环境（原 main() 的
/// setUpAll/setUp/tearDown/tearDownAll 样板逐字下沉）。
class WsActionTestEnv {
  late MessageRetry retry;
  late Database testDb;
  late String originalDeviceId;

  Future<void> setUpAll() async {
    sqfliteFfiInit();
    testDb = await wsOpenTestDb();
    SqliteService.setDbForTest(testDb);
    retry = MessageRetry.instance;
    // 等实例创建触发的 _scanAndRetryFailedMessages 在空表上跑完
    await pumpEventQueue(times: 200);
  }

  Future<void> setUp() async {
    originalDeviceId = init.deviceId;
    init.deviceId = 'fl02-ws-action-device';
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    // setDbForTest 记录打开句柄时的 uid；StorageService.init 把 currentUid
    // 从 '' 变为 '100'，必须在此之后重新注入，否则 db getter 判定
    // _openUid 漂移会关闭句柄并尝试重开生产加密库（宿主机无插件实现）。
    if (!testDb.isOpen) {
      testDb = await wsOpenTestDb();
    }
    SqliteService.setDbForTest(testDb);
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    WebSocketService.resetForTest();
    retry.clearRetryQueue();
  }

  void tearDown() {
    WebSocketService.to.channelForTest = null;
    WebSocketService.to.framingForTest = FramingMode.none;
    WebSocketService.resetForTest();
    init.deviceId = originalDeviceId;
  }

  void tearDownAll() {
    retry.dispose();
    SqliteService.setDbForTest(null);
  }

  WebSocketService bootedService() {
    final svc = WebSocketService.to;
    svc.framingForTest = FramingMode.v2;
    svc.channelForTest = WsActionFakeChannel();
    svc.statusForTest = SocketStatus.connected;
    return svc;
  }
}
