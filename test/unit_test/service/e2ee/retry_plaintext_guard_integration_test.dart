// E2EE-062 第九刀：**重发路径明文闸门的接线实证**。
//
// == 为什么需要这个文件 ==
//
// 第八刀（`evidence/E2EE-062-retry-plaintext-guard.md`）实现了
// `shouldBlockPlaintextRetry` 并把它接进 `MessageRetry._retryMessage`，
// 但当时只有纯函数被实证，「MessageRetry 真的会调它、且在发送之前」是
// **文件级阅读结论**——被明确记为该刀最大的验收缺口（evidence §5.1）。
//
// 本文件用真 SQLite（ffi 内存库）+ 真事件总线驱动 `retryFailedMessages()`，
// 断言的是**有没有 `WebSocketMessageSendRequestEvent` 出网**，
// 不是内部函数的返回值。
//
// == 守护 ==
//
// 1. 【对照组】明文行 + 部署本就明文 → **必须重投**。
//    对照组红 = harness 根本没驱动起重投，此时任何"没出网"的绿都无意义；
// 2. 明文行 + 部署要求加密 → **不得出网**（第八刀修的那条路）；
// 3. 【正向可用性】已加密行 + 部署要求加密 → **必须重投**。
//    一个「一律不发」的实现在"不泄漏明文"上恒满分，被这条否掉；
// 4. 策略未就绪（未知）→ 明文行**不得出网**（未知即拦，不 fail-open）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 与 `message_retry_state_test.dart` 同一份最小 DDL（列集合 = MessageRepo.defaultColumns）。
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

Future<void> _insertMsg(
  String id, {
  required int status,
  Map<String, dynamic>? e2ee,
}) async {
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  await repo.insert(
    MessageModel(
      id,
      autoId: 0,
      type: 'C2C',
      status: status,
      fromId: 1001,
      toId: 2002,
      payload: {'msg_type': 'text', 'text': 'hi'},
      isAuthor: 1,
      conversationUk3: 'C2C_1001_2002',
      msgType: 'text',
      createdAt: 1751850000000,
      e2ee: e2ee,
    ),
  );
}

/// 把队列中该消息的退避间隔拨到已到期（真值源 = RetryPolicy）。
void _makeDue(MessageRetry retry, String id) {
  final info = retry.getRetryInfo(id);
  if (info == null) return;
  info.lastRetryTime -=
      RetryPolicy.messageSendIntervalAt(info.retryCount) + 1000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageRetry retry;
  final List<WebSocketMessageSendRequestEvent> sendRequests = [];

  setUpAll(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    await db.execute(_contactDdl);
    for (final peerId in [1001, 2002]) {
      await db.insert('contact', {
        'user_id': '',
        'peer_id': peerId,
        'nickname': 'peer$peerId',
        'avatar': '',
        'account': 'acc$peerId',
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
    }
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

  /// 走完整重发路径一次：入队 → 拨到到期 → 驱动扫描。
  Future<void> driveRetry(String id) async {
    retry.addToRetryQueue(id, 'C2C');
    _makeDue(retry, id);
    await retry.retryFailedMessages();
    await pumpEventQueue();
  }

  Iterable<WebSocketMessageSendRequestEvent> sentOf(String id) =>
      sendRequests.where((e) => e.messageId == id);

  Future<int?> statusOf(String id) async =>
      (await MessageRepo(tableName: MessageRepo.c2cTable).find(id))?.status;

  group('重发路径明文闸门（真 SQLite + 真事件总线）', () {
    test('对照组：部署本就明文 → 明文行必须照常重投', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      const id = 'gd0000000000000pt01';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(
        sentOf(id).length,
        1,
        reason:
            '对照组红 = harness 没驱动起重投，'
            '此时任何"没出网"的绿都毫无意义',
      );
    });

    test('部署要求加密 + 明文行 → 不得出网', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );
      const id = 'gd0000000000000pt02';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(
        sentOf(id),
        isEmpty,
        reason:
            'OTK 耗尽/429 导致加密失败的行就是这个形状；'
            '按库中原样重发 = 明文出网，绕开发送侧 fail-closed',
      );
    });

    test('正向可用性：部署要求加密 + 已加密行 → 必须照常重投', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );
      const id = 'gd0000000000000pt03';
      await _insertMsg(
        id,
        status: IMBoyMessageStatus.error,
        e2ee: <String, dynamic>{
          'meta_version': 3,
          'protocol': 'olm',
          'version': 1,
          'fan_out': 'per_device',
        },
      );

      await driveRetry(id);

      expect(
        sentOf(id).length,
        1,
        reason:
            '一律不发会让所有重发失效、消息永久卡住，'
            '却在"不泄漏明文"指标上恒得满分',
      );
    });

    // ===== 闸门与 CAS 的先后顺序（E2EE-062 残留 1）=====
    //
    // 闸门若排在 CAS 之后，被拦下的行每个扫描周期都会被写库翻成 `sending`：
    // 用户永远看到「发送中」而不是「失败」，DB 写入无上限，且因为随后即出队，
    // retryCount 被丢弃，**永远到不了放弃上限**。
    // 拦下 = 这一轮什么都不该发生，包括不该动库。

    test('对照组：允许重投的行，状态必须被 CAS 翻成 sending', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      const id = 'gd0000000000000pt05';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(sentOf(id).length, 1);
      expect(
        await statusOf(id),
        IMBoyMessageStatus.sending,
        reason:
            '对照组红 = CAS 根本没生效，'
            '此时"被拦下时状态不变"的绿也说明不了任何事',
      );
    });

    test('被拦下时不得改动 DB 状态（闸门必须排在 CAS 之前）', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );
      const id = 'gd0000000000000pt06';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(sentOf(id), isEmpty);
      expect(
        await statusOf(id),
        IMBoyMessageStatus.error,
        reason:
            '闸门排在 CAS 之后会把 error 翻成 sending：'
            '用户永远看到「发送中」，且永远到不了放弃上限',
      );
    });

    test('策略未就绪（未知）+ 明文行 → 不得出网（未知即拦）', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
      const id = 'gd0000000000000pt04';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(sentOf(id), isEmpty, reason: '策略取不到时不得 fail-open；发送路径对同一异常也是拒发');
    });
  });
}
