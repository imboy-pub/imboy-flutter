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
//    本测试驱动真实事件总线断言 crypto_outbox 被置 sent。
//
// 守护（空验证）：对照组必须同时成立——
// - 若重发事件根本没出网（harness 没驱动起来），用例 1 的绿无意义，
//   故用例 1 先断言出网再比内容；
// - 用例 3 证明 outbox 表缺失时移除事件照样生效（卫生动作不阻断 ACK）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
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
    e2ee TEXT
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageRetry retry;
  final sendRequests = <WebSocketMessageSendRequestEvent>[];
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    await db.execute(_contactDdl);
    await db.insert('contact', {
      'user_id': '',
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
    await pumpEventQueue(times: 200);
    AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(sendRequests.add);
  });

  setUp(() {
    retry.clearRetryQueue();
    sendRequests.clear();
  });

  tearDownAll(() {
    retry.dispose();
    SqliteService.setDbForTest(null);
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
    final store = CryptoStore(db);
    await store.ensureSchema();
    await store.insertOutbox(
      id: 'msg-resend-1',
      payload: jsonEncode(_v3Envelope()),
    );
    expect((await store.getOutboxEntry('msg-resend-1'))?['status'], 'pending');

    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: 'msg-resend-1',
        messageType: 'C2C',
        reason: 'SERVER_ACK',
      ),
    );
    await pumpEventQueue();

    final entry = await store.getOutboxEntry('msg-resend-1');
    expect(entry?['status'], 'sent', reason: 'ACK 移除未联动确认 outbox');
  });

  test('outbox 表缺失时移除事件照样生效（卫生动作不阻断 ACK）', () async {
    // 不建 crypto_outbox 表：_confirmOutboxQuietly 应只记日志
    await db.execute('DROP TABLE IF EXISTS crypto_outbox');
    retry.addToRetryQueue('msg-ghost', 'C2C');

    AppEventBus.fire(
      RemoveFromRetryQueueRequestedEvent(
        messageId: 'msg-ghost',
        messageType: 'C2C',
        reason: 'SERVER_ACK',
      ),
    );
    await pumpEventQueue();

    // 移除生效即通过（确认失败不得阻断）；队列中不应再有该 id
    expect(retry.getRetryInfo('msg-ghost'), isNull);
  });
}
