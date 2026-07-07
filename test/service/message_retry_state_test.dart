// 出站消息确认状态机（机制B=MessageRetry 升级为唯一状态机）迁移测试
//
// 持久状态 = DB status（真值），易失驻留 = _retryQueue[msgId:Xid]。
// 超时/退避/上限单一来源 RetryPolicy；单一清除入口
// RemoveFromRetryQueueRequestedEvent。
//
// 覆盖验收④的全部迁移：
//   sending → 确认信号 → 出队（不再重投）
//   sending → 间隔到期重投 → retryCount 递增 → 上限 → error 出队（放弃）
//   已 sent/终态 → 幂等（不重投、不覆盖状态）
//   间隔未到 → 不重投；重复入队 → 不重置 count
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// msg_c2c 最小 DDL：列集合 = MessageRepo.defaultColumns。
/// id 用 INTEGER 列以复现生产的 type affinity 行为
/// （Xid base32hex 字符串按 TEXT 落库，见 message_model.dart:193 注释）。
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

/// toTypeMessage 的作者信息查询依赖 contact 表（空表即可，查不到走默认）。
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

Future<MessageModel> _insertMsg(String id, {required int status}) async {
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  return repo.insert(
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
    ),
  );
}

Future<int?> _statusOf(String id) async {
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  return (await repo.find(id))?.status;
}

/// 把队列中该消息的 lastRetryTime 拨回过去，使当前 retryCount 档位的
/// 退避间隔视为已到期（间隔真值源 = RetryPolicy）。
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
    // 生产的 sqflite_sqlcipher 在宿主机无插件实现，注入 ffi 内存库。
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    await db.execute(_contactDdl);
    // 播种联系人：toTypeMessage 的作者查询本地命中，避免走 HTTP 拉取
    // （测试环境该请求失败会级联登出/关库，污染后续用例）。
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
    // 实例创建触发 unawaited(_scanAndRetryFailedMessages())；
    // 等它在空表上跑完，避免与各 test 的插行/重投并发交错。
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

  group('出站确认状态机（机制B 唯一化）', () {
    test('sending → 确认信号(Remove事件) → 出队且不再重投', () async {
      const id = 'sm00000000000000t001';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      retry.addToRetryQueue(id, 'C2C');
      expect(retry.getRetryInfo(id), isNotNull);

      // 单一清除入口：SERVER_ACK / action-ACK 都汇聚到该事件
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: id,
          messageType: 'C2C',
          reason: 'server_ack',
        ),
      );
      await pumpEventQueue();
      expect(retry.getRetryInfo(id), isNull);

      // 已出队：即便间隔到期扫描，也不再重投
      await retry.retryFailedMessages();
      expect(sendRequests.where((e) => e.messageId == id), isEmpty);
    });

    test('sending → 间隔到期 → 重投且 retryCount 递增；间隔未到不重投', () async {
      const id = 'sm00000000000000t002';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      retry.addToRetryQueue(id, 'C2C');

      // 间隔未到：不重投
      await retry.retryFailedMessages();
      expect(sendRequests.where((e) => e.messageId == id), isEmpty);

      // 间隔到期：重投一次，count 0→1
      _makeDue(retry, id);
      await retry.retryFailedMessages();
      expect(sendRequests.where((e) => e.messageId == id).length, 1);
      expect(retry.getRetryInfo(id)!.retryCount, 1);
      // 重投路径将 DB 置回 sending（CAS）
      expect(await _statusOf(id), IMBoyMessageStatus.sending);
    });

    test('重投达上限 → error 出队（放弃），不再重投', () async {
      const id = 'sm00000000000000t003';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      retry.addToRetryQueue(id, 'C2C');

      for (var i = 0; i < RetryPolicy.maxRetryAttempts; i++) {
        _makeDue(retry, id);
        await retry.retryFailedMessages();
      }
      expect(
        sendRequests.where((e) => e.messageId == id).length,
        RetryPolicy.maxRetryAttempts,
      );

      // 第 5 次扫描：达上限 → 标 error 并出队
      _makeDue(retry, id);
      await retry.retryFailedMessages();
      expect(retry.getRetryInfo(id), isNull);
      expect(await _statusOf(id), IMBoyMessageStatus.error);

      // 放弃后不再产生任何重投
      await retry.retryFailedMessages();
      expect(
        sendRequests.where((e) => e.messageId == id).length,
        RetryPolicy.maxRetryAttempts,
      );
    });

    test('幂等：已 sent 的消息即便在队/被扫描，也不重投且状态不回退', () async {
      const id = 'sm00000000000000t004';
      await _insertMsg(id, status: IMBoyMessageStatus.sent);
      retry.addToRetryQueue(id, 'C2C');
      await pumpEventQueue(); // 等 _markPendingRetryStatus 异步守卫跑完

      // 终态守卫：不被回退成 pendingRetry
      expect(await _statusOf(id), IMBoyMessageStatus.sent);

      _makeDue(retry, id);
      await retry.retryFailedMessages();
      expect(retry.getRetryInfo(id), isNull); // 扫描发现已成功 → 出队
      expect(sendRequests.where((e) => e.messageId == id), isEmpty);
      expect(await _statusOf(id), IMBoyMessageStatus.sent);
    });

    test('重复入队幂等：不重置 retryCount', () async {
      const id = 'sm00000000000000t005';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      retry.addToRetryQueue(id, 'C2C');
      _makeDue(retry, id);
      await retry.retryFailedMessages();
      expect(retry.getRetryInfo(id)!.retryCount, 1);

      retry.addToRetryQueue(id, 'C2C'); // 重复入队
      expect(retry.getRetryInfo(id)!.retryCount, 1); // count 保留
    });

    test('error → 手动重试 → 重新进入 sending 并入队等待确认', () async {
      const id = 'sm00000000000000t006';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      final ok = await retry.retryMessage(id, 'C2C');
      expect(ok, isTrue);
      // 提交后为 loading 族中间态：sending（已提交）或 pendingRetry
      //（addToRetryQueue 的异步守卫随后标记，两者都表示等待确认）
      expect(
        await _statusOf(id),
        isIn([IMBoyMessageStatus.sending, IMBoyMessageStatus.pendingRetry]),
      );
      expect(retry.getRetryInfo(id), isNotNull);
      expect(sendRequests.where((e) => e.messageId == id).length, 1);
    });

    test('手动重试幂等：已 sent 的消息拒绝重试', () async {
      const id = 'sm00000000000000t007';
      await _insertMsg(id, status: IMBoyMessageStatus.sent);

      final ok = await retry.retryMessage(id, 'C2C');
      expect(ok, isFalse);
      expect(sendRequests.where((e) => e.messageId == id), isEmpty);
      expect(await _statusOf(id), IMBoyMessageStatus.sent);
    });
  });
}
