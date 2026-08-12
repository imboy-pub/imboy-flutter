// 回归：重试状态机不得自噬 —— 终态 `error` 不能被启动扫描重新捞回队列。
//
// 原实现里 `_scanAndRetryFailedMessages` 的状态集是
// `{sending, pendingRetry, error}`，而 `_markMessageAsError` 在 retryCount
// 达上限时正是把行置为 `error` 后出队。于是：
//   重试 4 次 → 置 error → 出队 → 下次扫描捞回 → retryCount 归零（队列在内存里）
//   → 再重试 4 次 → 再置 error → …… 永不停止。
//
// 真机实测：一条服务端恒拒的存量坏消息（msg_type 为空）每 5~10s 被重发一次。
// 「放弃上限」形同虚设，且没有任何清理路径。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

const String _msgC2cFtsDdl = '''
  CREATE TABLE msg_c2c_fts (
    id TEXT,
    conversation_uk3 TEXT,
    text_content TEXT
  )
''';

Future<void> _insertMsg(String id, {required int status}) async {
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
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageRetry retry;

  setUpAll(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    // MessageRetry 启动扫描会按生产路径读取三类消息表；其余两张表
    // 只需具备相同列集合即可，避免测试把“缺表”误报成状态机故障。
    await db.execute('CREATE TABLE msg_c2g AS SELECT * FROM msg_c2c WHERE 0');
    await db.execute('CREATE TABLE msg_c2s AS SELECT * FROM msg_c2c WHERE 0');
    await db.execute(_contactDdl);
    await db.execute(_msgC2cFtsDdl);
    await db.insert('contact', {
      'user_id': '',
      'peer_id': 1001,
      'nickname': 'peer1001',
      'avatar': '',
      'account': 'acc1001',
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
      'account_type': '',
      'updated_at': 1751850000000,
    });
    SqliteService.setDbForTest(db);
    retry = MessageRetry.instance;
    await pumpEventQueue(times: 200);
  });

  setUp(() async {
    retry.clearRetryQueue();
    final db = await SqliteService.to.db;
    await db!.delete('msg_c2c');
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
  });

  tearDownAll(() {
    retry.dispose();
    SqliteService.setDbForTest(null);
  });

  group('启动扫描的状态集', () {
    test('对照组：pendingRetry 的中间态行必须被捞回队列', () async {
      const id = 'ts0000000000000pr01';
      await _insertMsg(id, status: IMBoyMessageStatus.pendingRetry);

      await retry.debugScanFailedMessages();

      expect(
        retry.getRetryInfo(id),
        isNotNull,
        reason: '对照组红 = 扫描根本没跑起来，此时任何"没捞回"的绿都无意义',
      );
    });

    test('sending 的中间态行也必须被捞回（进程被杀留下的）', () async {
      const id = 'ts0000000000000sd01';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);

      await retry.debugScanFailedMessages();

      expect(retry.getRetryInfo(id), isNotNull);
    });

    test('终态 error 不得被捞回 —— 否则放弃上限形同虚设', () async {
      const id = 'ts0000000000000er01';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      await retry.debugScanFailedMessages();

      expect(
        retry.getRetryInfo(id),
        isNull,
        reason: 'error 是本状态机自己的终态，扫描把它捞回来就形成闭环自噬',
      );
    });
  });

  group('达到重试上限后落终态', () {
    test('retryCount 到上限 → 行被置为 error 且出队', () async {
      const id = 'ts0000000000000mx01';
      await _insertMsg(id, status: IMBoyMessageStatus.pendingRetry);

      retry.addToRetryQueue(id, 'C2C');
      final info = retry.getRetryInfo(id)!;
      info.retryCount = RetryPolicy.maxRetryAttempts;
      info.lastRetryTime = 0;

      await retry.retryFailedMessages();
      await pumpEventQueue();

      expect(retry.getRetryInfo(id), isNull, reason: '达上限应出队');
      final msg = await MessageRepo(tableName: MessageRepo.c2cTable).find(id);
      expect(msg?.status, IMBoyMessageStatus.error, reason: '达上限应落 error 终态');

      // 关键：落了终态之后，再扫描一次也不能把它复活
      await retry.debugScanFailedMessages();
      expect(
        retry.getRetryInfo(id),
        isNull,
        reason: '这一条才是「无限重试」的闭环出口：放弃过的消息不再被自动捞起',
      );
    });
  });
}
