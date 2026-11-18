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

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';
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
  late ProviderContainer container;

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
    await db.execute(_msgC2cDdl.replaceFirst('msg_c2c', 'msg_c2g'));
    await db.execute('CREATE TABLE msg_c2s AS SELECT * FROM msg_c2c WHERE 0');
    await db.execute(_contactDdl);
    await db.execute(_msgC2cFtsDdl);
    await db.execute(_msgC2cFtsDdl.replaceFirst('msg_c2c_fts', 'msg_c2g_fts'));
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT, anchor_msg_id TEXT, user_id TEXT, business_intent TEXT)',
    );
    await db.execute(
      'CREATE TABLE message_send_attempt (user_id TEXT, anchor TEXT, token TEXT)',
    );
    await db.execute(
      'CREATE TABLE conversation (user_id TEXT, peer_id TEXT, type TEXT, '
      'last_msg_id TEXT, last_msg_status INTEGER)',
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
    container = ProviderContainer();
    MessageService.setProviderContainer(container);
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
    container.dispose();
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
    test('同账号新登录代次不接收旧 ACK 界面事件', () async {
      const id = 'c2g-ack-same-user-new-generation';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.sending,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      final db = (await SqliteService.to.db)!;
      await db.insert('message_send_attempt', {
        'user_id': '1001',
        'anchor': id,
        'token': 'attempt',
      });
      const secureChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(secureChannel, (call) async {
        if (call.method == 'write') {
          throw PlatformException(code: 'synthetic_failure');
        }
        return null;
      });
      final entered = Completer<void>(), release = Completer<void>();
      MessageService.to.beforeAckUiPublishForTest = () async {
        entered.complete();
        await release.future;
      };
      final observed = <MessageStatus?>[];
      final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
        event,
      ) {
        if (event.data is List) {
          for (final item in event.data as List) {
            if (item is Message && item.id == id) observed.add(item.status);
          }
        }
      });
      try {
        final ack = MessageService.to.processMessage('C2G_SERVER_ACK', {
          'id': id,
          'type': 'C2G_SERVER_ACK',
        });
        await entered.future.timeout(const Duration(seconds: 3));
        final priorGeneration = UserRepoLocal.to.sessionGeneration;
        await expectLater(
          UserRepoLocal.to.loginAfterQr(
            uid: '1001',
            token: 'synthetic-token-with-required-length',
          ),
          throwsA(anything),
        );
        expect(UserRepoLocal.to.currentUid, '1001');
        expect(
          UserRepoLocal.to.sessionGeneration,
          greaterThan(priorGeneration),
        );
        UserRepoLocal.to.clearAuthTransitionFailureForTest();
        expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
        release.complete();
        await ack;
        await pumpEventQueue();
        expect(observed, isEmpty);
      } finally {
        if (!release.isCompleted) release.complete();
        MessageService.to.beforeAckUiPublishForTest = null;
        UserRepoLocal.to.clearAuthTransitionFailureForTest();
        messenger.setMockMethodCallHandler(secureChannel, null);
        await subscription.cancel();
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'message_send_attempt',
          where: 'anchor = ?',
          whereArgs: [id],
        );
      }
    });
    for (final ack in [false, true]) {
      test('自动重试界面发布与${ack ? 'ACK' : '拒绝'}串行', () async {
        final id = 'c2g-auto-ui-race-$ack';
        final repo = MessageRepo(tableName: MessageRepo.c2gTable);
        await repo.insert(
          MessageModel(
            id,
            autoId: 0,
            type: 'C2G',
            status: IMBoyMessageStatus.pendingRetry,
            fromId: 1001,
            toId: 2002,
            payload: {'text': 'preserve'},
            e2ee: {'protocol': 'megolm'},
            isAuthor: 1,
            conversationUk3: 'C2G_1001_2002',
            msgType: 'text',
            createdAt: 1751850000000,
          ),
        );
        final db = (await SqliteService.to.db)!;
        await db.insert('message_send_attempt', {
          'user_id': '1001',
          'anchor': id,
          'token': 'attempt',
        });
        retry.addToRetryQueue(id, 'C2G');
        retry.getRetryInfo(id)!.lastRetryTime = -100000;
        final entered = Completer<void>(), release = Completer<void>();
        retry.beforeRetryUiPublishForTest = () async {
          entered.complete();
          await release.future;
        };
        final observed = <MessageStatus?>[];
        final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
          (event) {
            if (event.data is List) {
              for (final item in event.data as List) {
                if (item is Message && item.id == id) observed.add(item.status);
              }
            }
          },
        );
        try {
          final sending = retry.retryFailedMessages();
          await entered.future.timeout(const Duration(seconds: 3));
          final eventType = ack ? 'C2G_SERVER_ACK' : 'C2G_ERROR';
          final server = MessageService.to.processMessage(eventType, {
            'id': id,
            'type': eventType,
            if (!ack) 'code': 403,
          });
          await pumpEventQueue();
          release.complete();
          await sending;
          await server;
          await pumpEventQueue();
          expect(
            (await repo.find(id))?.status,
            ack ? IMBoyMessageStatus.sent : IMBoyMessageStatus.outcomeUnknown,
          );
          expect(observed, isNotEmpty);
          expect(observed.last, ack ? MessageStatus.sent : MessageStatus.error);
        } finally {
          if (!release.isCompleted) release.complete();
          retry.beforeRetryUiPublishForTest = null;
          await subscription.cancel();
          await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
          await db.delete(
            'message_send_attempt',
            where: 'anchor = ?',
            whereArgs: [id],
          );
          retry.clearRetryQueue();
        }
      });
    }
    test('ACK 转换后切换账号不向新会话发布或更新摘要', () async {
      const id = 'c2g-ack-owner-switch-race';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.sending,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      final db = (await SqliteService.to.db)!;
      await db.insert('message_send_attempt', {
        'user_id': '1001',
        'anchor': id,
        'token': 'attempt',
      });
      await db.insert('conversation', {
        'user_id': '9999',
        'peer_id': '2002',
        'type': 'C2G',
        'last_msg_id': id,
        'last_msg_status': IMBoyMessageStatus.outcomeUnknown,
      });
      final entered = Completer<void>(), release = Completer<void>();
      MessageService.to.beforeAckUiPublishForTest = () async {
        entered.complete();
        await release.future;
      };
      final observed = <MessageStatus?>[];
      final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
        event,
      ) {
        if (event.data is List) {
          for (final item in event.data as List) {
            if (item is Message && item.id == id) observed.add(item.status);
          }
        }
      });
      try {
        final ack = MessageService.to.processMessage('C2G_SERVER_ACK', {
          'id': id,
          'type': 'C2G_SERVER_ACK',
        });
        await entered.future.timeout(const Duration(seconds: 3));
        await StorageService.to.setString(Keys.currentUid, '9999');
        release.complete();
        await ack;
        await pumpEventQueue();
        expect(observed, isEmpty);
        expect(
          (await db.query(
            'conversation',
            where: 'user_id = ?',
            whereArgs: ['9999'],
          )).single['last_msg_status'],
          IMBoyMessageStatus.outcomeUnknown,
        );
      } finally {
        if (!release.isCompleted) release.complete();
        MessageService.to.beforeAckUiPublishForTest = null;
        await StorageService.to.setString(Keys.currentUid, '1001');
        await subscription.cancel();
        await db.delete(
          'conversation',
          where: 'user_id = ?',
          whereArgs: ['9999'],
        );
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'message_send_attempt',
          where: 'anchor = ?',
          whereArgs: [id],
        );
      }
    });

    test('手动重试界面发布与拒绝通知串行，不回退发送中', () async {
      const id = 'c2g-retry-ui-rejection-race';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.error,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          e2ee: {'protocol': 'megolm'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      final db = (await SqliteService.to.db)!;
      await db.insert('message_send_attempt', {
        'user_id': '1001',
        'anchor': id,
        'token': 'attempt',
      });
      final entered = Completer<void>(), release = Completer<void>();
      retry.beforeRetryUiPublishForTest = () async {
        entered.complete();
        await release.future;
      };
      final observed = <MessageStatus?>[];
      final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
        event,
      ) {
        final data = event.data;
        if (data is List) {
          for (final item in data) {
            if (item is Message && item.id == id) observed.add(item.status);
          }
        }
      });
      try {
        final sending = retry.retryMessage(id, 'C2G');
        await entered.future.timeout(const Duration(seconds: 3));
        final rejection = MessageService.to.processMessage('C2G_ERROR', {
          'id': id,
          'type': 'C2G_ERROR',
          'code': 403,
        });
        await pumpEventQueue();
        release.complete();
        await sending;
        await rejection;
        await pumpEventQueue();
        expect(
          (await repo.find(id))?.status,
          IMBoyMessageStatus.outcomeUnknown,
        );
        expect(observed, isNotEmpty);
        expect(observed.last, MessageStatus.error);
      } finally {
        if (!release.isCompleted) release.complete();
        retry.beforeRetryUiPublishForTest = null;
        await subscription.cancel();
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'message_send_attempt',
          where: 'anchor = ?',
          whereArgs: [id],
        );
      }
    });
    test('拒绝和迟到确认并发时界面不得倒退', () async {
      const id = 'c2g-rejection-ack-race';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.sending,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      final db = (await SqliteService.to.db)!;
      await db.insert('message_send_attempt', {
        'user_id': '1001',
        'anchor': id,
        'token': 'attempt',
      });
      addTearDown(() async {
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'message_send_attempt',
          where: 'anchor = ?',
          whereArgs: [id],
        );
      });
      final observed = <MessageStatus?>[];
      final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
        event,
      ) {
        final data = event.data;
        if (data is List) {
          for (final item in data) {
            if (item is Message && item.id == id) observed.add(item.status);
          }
        }
      });
      addTearDown(subscription.cancel);

      await Future.wait([
        MessageService.to.processMessage('C2G_ERROR', {
          'id': id,
          'type': 'C2G_ERROR',
          'code': 403,
        }),
        MessageService.to.processMessage('C2G_SERVER_ACK', {
          'id': id,
          'type': 'C2G_SERVER_ACK',
        }),
      ]);
      await pumpEventQueue();

      expect((await repo.find(id))?.status, IMBoyMessageStatus.sent);
      expect(observed, isNotEmpty);
      expect(observed.last, MessageStatus.sent);
    });

    test('拒绝帧分发将当前群消息置为待确认并停止重试', () async {
      const id = 'c2g-server-rejection';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.sending,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'keep original'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      final db = (await SqliteService.to.db)!;
      await db.insert('message_send_attempt', {
        'user_id': '1001',
        'anchor': id,
        'token': 'attempt',
      });
      addTearDown(() async {
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'message_send_attempt',
          where: 'anchor = ?',
          whereArgs: [id],
        );
      });
      retry.addToRetryQueue(id, 'C2G');
      await pumpEventQueue();

      final before = (await repo.find(id))!.status;
      await MessageService.to.processMessage('C2G_ERROR', {
        'id': id,
        'type': 'C2G_ERROR',
        'code': 429,
      });
      await MessageService.to.processMessage('C2G_ERROR', {
        'id': id,
        'type': 'C2G_ERROR',
        'code': 403,
      }, ownerUid: 'another-account');
      expect((await repo.find(id))?.status, before);
      expect(retry.getRetryInfo(id), isNotNull);

      await MessageService.to.processMessage('C2G_ERROR', {
        'id': id,
        'type': 'C2G_ERROR',
        'code': 403,
        'error': 'Not a group member',
      });
      await pumpEventQueue();

      expect((await repo.find(id))?.status, IMBoyMessageStatus.outcomeUnknown);
      expect(retry.getRetryInfo(id), isNull);
    });

    test('历史空状态群消息仍可手动重试', () async {
      const id = 'c2g-null-status-retry';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.error,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          e2ee: {'protocol': 'megolm'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      final db = (await SqliteService.to.db)!;
      await db.update(
        'msg_c2g',
        {'status': null},
        where: 'id = ?',
        whereArgs: [id],
      );
      addTearDown(() => db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]));
      var sends = 0;
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen((event) {
            if (event.messageId == id) sends++;
          });
      addTearDown(subscription.cancel);

      expect(await retry.retryMessage(id, 'C2G'), isTrue);
      await pumpEventQueue();
      expect(sends, 1);
      expect((await repo.find(id))?.status, IMBoyMessageStatus.pendingRetry);
    });

    test('群消息结果待确认时不得自动或手动重发', () async {
      const id = 'c2g-unknown-retry';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: 42,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          e2ee: {'protocol': 'megolm'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      addTearDown(() async {
        final db = (await SqliteService.to.db)!;
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
      });
      var sends = 0;
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen((_) => sends++);
      addTearDown(subscription.cancel);

      await retry.debugScanFailedMessages();
      expect(retry.getRetryInfo(id), isNull);
      expect(await retry.retryMessage(id, 'C2G'), isFalse);
      expect((await repo.find(id))?.status, 42);
      expect(sends, 0);
    });

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
    test('群消息待确认不能被旧的重试上限任务覆盖', () async {
      const id = 'c2g-unknown-exhaustion';
      final repo = MessageRepo(tableName: MessageRepo.c2gTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2G',
          status: IMBoyMessageStatus.outcomeUnknown,
          fromId: 1001,
          toId: 2002,
          payload: {'text': 'preserve'},
          isAuthor: 1,
          conversationUk3: 'C2G_1001_2002',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
      addTearDown(() async {
        final db = (await SqliteService.to.db)!;
        await db.delete('msg_c2g', where: 'id = ?', whereArgs: [id]);
      });
      retry.addToRetryQueue(id, 'C2G');
      retry.getRetryInfo(id)!.retryCount = RetryPolicy.maxRetryAttempts;

      await retry.retryFailedMessages();

      expect((await repo.find(id))?.status, IMBoyMessageStatus.outcomeUnknown);
      expect(retry.getRetryInfo(id), isNull);
    });

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
