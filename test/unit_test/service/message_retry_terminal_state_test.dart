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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Hold a real SQLite result after its snapshot is read. A rejection can then
/// commit before the retry consumes that stale row; every write still uses SQL.
class _PausedRetryDatabase implements Database {
  _PausedRetryDatabase(
    this.inner,
    this.messageId, {
    this.pauseScan = false,
    this.pauseLookup = 0,
  });

  final Database inner;
  final String messageId;
  final bool pauseScan;
  final int pauseLookup;
  final entered = Completer<void>();
  final release = Completer<void>();
  final casResults = <int>[];
  List<Map<String, Object?>> snapshot = [];
  int lookups = 0;

  @override
  bool get isOpen => inner.isOpen;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) => inner.transaction(action, exclusive: exclusive);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await inner.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    if (table == MessageRepo.c2cTable && !entered.isCompleted) {
      final isLookup = where == 'id = ?' && whereArgs?.single == messageId;
      if (isLookup) lookups++;
      if ((pauseScan && (where?.startsWith('status IN (') ?? false)) ||
          (isLookup && lookups == pauseLookup)) {
        snapshot = rows;
        entered.complete();
        await release.future;
      }
    }
    return rows;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final rows = await inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    if (table == MessageRepo.c2cTable &&
        values['status'] == IMBoyMessageStatus.sending &&
        (where?.contains('status IN') ?? false)) {
      casResults.add(rows);
    }
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      inner.rawUpdate(sql, arguments);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  await repo.waitForFtsReindexForTest();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageRetry retry;
  late Database database;
  late StreamSubscription<WebSocketMessageSendRequestEvent> sendSubscription;
  final sendRequests = <WebSocketMessageSendRequestEvent>[];

  Future<int?> statusOf(String id) async =>
      (await MessageRepo(tableName: MessageRepo.c2cTable).find(id))?.status;

  void makeDue(String id) {
    final info = retry.getRetryInfo(id)!;
    info.lastRetryTime -=
        RetryPolicy.messageSendIntervalAt(info.retryCount) + 1000;
  }

  Future<void> enqueueAutomatic(String id) async {
    retry.addToRetryQueue(id, 'C2C');
    // Wait for the actual sending -> pendingRetry write before arming a
    // later-read barrier; queue bookkeeping cannot steal that barrier.
    await Future.doWhile(() async {
      if (await statusOf(id) == IMBoyMessageStatus.pendingRetry) return false;
      await Future<void>.delayed(Duration.zero);
      return true;
    }).timeout(const Duration(seconds: 5));
    makeDue(id);
  }

  setUpAll(() async {
    // Set the owner before injecting its FFI database and starting retry work.
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    await StorageService.setMap(Keys.currentUser, {
      'id': '1001',
      'nickname': 'peer1001',
      'avatar': '',
    });
    expect(UserRepoLocal.to.currentUid, '1001');
    expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    database = db;
    await db.execute(_msgC2cDdl);
    // MessageRetry 启动扫描会按生产路径读取三类消息表；其余两张表
    // 只需具备相同列集合即可，避免测试把“缺表”误报成状态机故障。
    await db.execute('CREATE TABLE msg_c2g AS SELECT * FROM msg_c2c WHERE 0');
    await db.execute('CREATE TABLE msg_c2s AS SELECT * FROM msg_c2c WHERE 0');
    await db.execute(_contactDdl);
    await db.execute(_msgC2cFtsDdl);
    await db.execute(
      'CREATE TABLE attachment_upload_task ('
      'anchor_msg_id TEXT, user_id TEXT, business_intent TEXT)',
    );
    await db.insert('contact', {
      'user_id': '1001',
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
    await retry.debugWaitForIdle().timeout(const Duration(seconds: 5));
    sendSubscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(sendRequests.add);
  });

  setUp(() async {
    retry.clearRetryQueue();
    sendRequests.clear();
    final db = await SqliteService.to.db;
    await db!.delete('msg_c2c');
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
  });

  tearDownAll(() async {
    retry.dispose();
    await sendSubscription.cancel();
    SqliteService.setDbForTest(null);
  });

  group('拒收与自动重试交错', () {
    test('已落库的拒收不等待出队事件也不得自动发送', () async {
      const id = 'reject-before-retry';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      await enqueueAutomatic(id);

      // This is the production rejection's state after its message write and
      // before its awaited conversation update emits the removal event.
      await database.update(
        'msg_c2c',
        {'status': IMBoyMessageStatus.error},
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(retry.getRetryInfo(id), isNotNull);
      await retry.retryFailedMessages();
      await pumpEventQueue();

      expect(await statusOf(id), IMBoyMessageStatus.error);
      expect(sendRequests, isEmpty);
      expect(retry.getRetryInfo(id), isNull);
      await retry.debugScanFailedMessages();
      expect(retry.getRetryInfo(id), isNull);
    });

    test('发送前快照仍是10时，CAS不得覆盖稍后落库的41', () async {
      const id = 'reject-after-dispatch-read';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      await enqueueAutomatic(id);
      await database.update('msg_c2c', {'status': IMBoyMessageStatus.sending});
      final paused = _PausedRetryDatabase(database, id, pauseLookup: 2);
      SqliteService.setDbForTest(paused);
      final pending = retry.retryFailedMessages();
      try {
        await paused.entered.future.timeout(const Duration(seconds: 5));
        expect(paused.snapshot.single['status'], IMBoyMessageStatus.sending);
        await database.update(
          'msg_c2c',
          {'status': IMBoyMessageStatus.error},
          where: 'id = ?',
          whereArgs: [id],
        );
        paused.release.complete();
        await pending;
        await pumpEventQueue();

        expect(paused.casResults, [0], reason: '真实 SQL 必须拒绝旧快照的状态写入');
        expect(await statusOf(id), IMBoyMessageStatus.error);
        expect(sendRequests, isEmpty);
        expect(retry.getRetryInfo(id), isNull);
      } finally {
        if (!paused.release.isCompleted) paused.release.complete();
        await pending;
        SqliteService.setDbForTest(database);
      }
    });

    test('拒收出队后返回的旧启动扫描快照不得再次发送', () async {
      const id = 'reject-before-scan-result';
      await _insertMsg(id, status: IMBoyMessageStatus.sending);
      final paused = _PausedRetryDatabase(database, id, pauseScan: true);
      SqliteService.setDbForTest(paused);
      final pending = retry.debugScanFailedMessages();
      try {
        await paused.entered.future.timeout(const Duration(seconds: 5));
        expect(paused.snapshot.single['status'], IMBoyMessageStatus.sending);
        await database.update(
          'msg_c2c',
          {'status': IMBoyMessageStatus.error},
          where: 'id = ?',
          whereArgs: [id],
        );
        final removed = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
            .firstWhere((event) => event.messageId == id);
        AppEventBus.fire(
          RemoveFromRetryQueueRequestedEvent(
            messageId: id,
            messageType: 'C2C',
            reason: 'not_a_friend',
          ),
        );
        await removed;
        expect(retry.getRetryInfo(id), isNull);
        paused.release.complete();
        await pending;
        expect(retry.getRetryInfo(id), isNotNull);
        makeDue(id);
        await retry.retryFailedMessages();
        await pumpEventQueue();

        expect(await statusOf(id), IMBoyMessageStatus.error);
        expect(sendRequests, isEmpty);
        expect(retry.getRetryInfo(id), isNull);
        await retry.debugScanFailedMessages();
        expect(retry.getRetryInfo(id), isNull);
      } finally {
        if (!paused.release.isCompleted) paused.release.complete();
        await pending;
        SqliteService.setDbForTest(database);
      }
    });

    test('显式手动重试41后仍能进入正常自动重试', () async {
      const id = 'manual-retry-rejected';
      await _insertMsg(id, status: IMBoyMessageStatus.error);

      expect(await retry.retryMessage(id, 'C2C'), isTrue);
      await pumpEventQueue();
      expect(sendRequests, hasLength(1));
      expect(
        await statusOf(id),
        isIn([IMBoyMessageStatus.sending, IMBoyMessageStatus.pendingRetry]),
      );
      expect(retry.getRetryInfo(id)!.retryCount, 1);
      makeDue(id);
      await retry.retryFailedMessages();
      await pumpEventQueue();

      expect(sendRequests, hasLength(2));
      expect(await statusOf(id), IMBoyMessageStatus.sending);
      expect(retry.getRetryInfo(id)!.retryCount, 2);
    });
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

    test('超过单页 100 条时继续扫描后续页', () async {
      for (var i = 0; i < 101; i++) {
        await _insertMsg(
          'ts${i.toString().padLeft(18, '0')}',
          status: IMBoyMessageStatus.pendingRetry,
        );
      }

      await retry.debugScanFailedMessages();

      expect(retry.retryQueueSize, 101);
      expect(
        retry.getRetryInfo('ts${0.toString().padLeft(18, '0')}'),
        isNotNull,
      );
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

  group('Inbound receipt is not outgoing delivery', () {
    for (final rejectionFirst in [true, false]) {
      test(
        'rejectionFirst=$rejectionFirst cannot promote status to delivered',
        () async {
          final id = 'receipt-order-$rejectionFirst';
          await _insertMsg(id, status: IMBoyMessageStatus.sent);
          retry.addToRetryQueue(id, 'C2C');
          final db = (await SqliteService.to.db)!;

          Future<void> reject() async {
            await db.update(
              'msg_c2c',
              {'status': IMBoyMessageStatus.error},
              where: 'id = ?',
              whereArgs: [id],
            );
          }

          Future<void> drainEvents() async {
            final barrier = AppEventBus.on<WebSocketMessageReceivedEvent>()
                .firstWhere((event) => event.type == 'RECEIPT_ORDER_BARRIER');
            AppEventBus.fire(
              WebSocketMessageReceivedEvent(
                type: 'RECEIPT_ORDER_BARRIER',
                data: const {},
              ),
            );
            await barrier.timeout(const Duration(seconds: 1));
          }

          if (rejectionFirst) await reject();
          final session = UserRepoLocal.to;
          AppEventBus.fire(
            RemoveFromRetryQueueRequestedEvent(
              messageId: id,
              messageType: 'C2C',
              reason: 'client_ack_confirm',
              ownerUid: session.currentUid,
              sessionGeneration: session.sessionGeneration,
            ),
          );
          await drainEvents();
          expect(
            retry.getRetryInfo(id),
            isNotNull,
            reason: 'A receipt must not remove the outgoing retry',
          );
          final repo = MessageRepo(tableName: MessageRepo.c2cTable);
          expect(
            (await repo.find(id))?.status,
            rejectionFirst ? IMBoyMessageStatus.error : IMBoyMessageStatus.sent,
          );
          if (!rejectionFirst) await reject();
          expect((await repo.find(id))?.status, IMBoyMessageStatus.error);

          // The actual business rejection still removes the outgoing retry.
          AppEventBus.fire(
            RemoveFromRetryQueueRequestedEvent(
              messageId: id,
              messageType: 'C2C',
              reason: 'not_a_friend',
              ownerUid: session.currentUid,
              sessionGeneration: session.sessionGeneration,
            ),
          );
          await drainEvents();
          expect(retry.getRetryInfo(id), isNull);
          expect((await repo.find(id))?.status, IMBoyMessageStatus.error);
        },
      );
    }
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
