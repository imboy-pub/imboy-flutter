import 'package:imboy/service/protocol/imboy_frame.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/c2g_rejection_hold.dart';
import 'package:imboy/service/c2g_send_gate.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _CapturingSink implements WebSocketSink {
  final List<dynamic> sent = [];

  void Function()? onAdd;

  @override
  void add(dynamic data) {
    sent.add(data);
    onAdd?.call();
  }

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
  final _CapturingSink _sink = _CapturingSink();

  @override
  WebSocketSink get sink => _sink;

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

class _EmptyRetryTransaction extends _EmptyRetryDatabase
    implements Transaction {}

class _EmptyRetryDatabase implements Database {
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => action(_EmptyRetryTransaction());
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async => 1;
  @override
  bool get isOpen => true;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => [];

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
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FencedDatabase extends _EmptyRetryDatabase {
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => action(_FencedTransaction());
}

class _FencedTransaction extends _EmptyRetryTransaction {
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
    if (table == 'attachment_upload_task' && whereArgs?.first == 'blocked-id') {
      return [
        {
          'id': 'upload',
          'stage': 'confirmed',
          'business_intent': jsonEncode({'state': 'commit_unknown'}),
        },
      ];
    }
    return [];
  }
}

class _FailC2gLookupDatabase extends _EmptyRetryDatabase {
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => action(_FailC2gLookupTransaction());

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql.contains('FROM msg_c2g')) {
      throw StateError('synthetic database failure');
    }
    return [];
  }
}

class _FailC2gLookupTransaction extends _EmptyRetryTransaction {
  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final encode = base64Url.encode;
    final secure = <String, String?>{
      'secure_token':
          '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
          '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
          '${encode(utf8.encode('synthetic-signature'))}',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final key = (call.arguments as Map)['key'] as String?;
          if (call.method == 'write') {
            if (key == 'secure_token') {
              throw PlatformException(code: 'synthetic-login-stop');
            }
            secure[key!] = call.arguments['value'] as String?;
          }
          if (call.method == 'read') return secure[key];
          return null;
        });
    UserRepoLocal.to.clearAuthTransitionFailureForTest();
    WebSocketService.resetForTest();
    SqliteService.setDbForTest(_EmptyRetryDatabase());
  });
  tearDown(() {
    SqliteService.setDbForTest(null);
    WebSocketService.to.dispose();
    WebSocketService.resetForTest();
    PersistentMessageQueue.to.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });
  for (final stale in [false, true]) {
    test('edit lookup session changed=$stale', () async {
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      final mode = EncryptionModeService.current;
      final initialized = EncryptionModeService.isInitialized;
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      final entered = Completer<void>();
      final release = Completer<MessageModel?>();
      MessageActions.messageLoaderForTest = (type, id) {
        entered.complete();
        return release.future;
      };
      final requests = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen((event) {
            requests.add(event);
            svc.handleSendRequestForTest(event);
          });
      try {
        final pending = MessageActions.instance.sendEditMessage(
          '1001',
          'C2C',
          'synthetic-edit',
        );
        await entered.future;
        if (stale) {
          await expectLater(
            UserRepoLocal.to.loginAfter('synthetic-session', {
              'uid': '101',
              'token': 'synthetic-token',
              'refreshtoken': 'synthetic-refresh',
            }),
            throwsA(isA<PlatformException>()),
          );
        }
        release.complete(
          MessageModel(
            '1001',
            autoId: 0,
            conversationUk3: 'C2C_100_200',
            type: 'C2C',
            fromId: 100,
            toId: 200,
            msgType: 'text',
            payload: {'text': 'synthetic'},
            status: IMBoyMessageStatus.sent,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            isAuthor: 1,
          ),
        );
        expect(await pending, !stale);
        await pumpEventQueue();
        expect(requests, stale ? isEmpty : hasLength(1));
        expect(fake._sink.sent, stale ? isEmpty : hasLength(1));
        if (!stale) {
          final sent = jsonDecode(requests.single.message) as Map;
          expect(sent['from'], '100');
          expect(sent['to'], '200');
          expect((sent['payload'] as Map)['content'], 'synthetic-edit');
        }
      } finally {
        await subscription.cancel();
        MessageActions.messageLoaderForTest = null;
        await MessageRetry.instance.debugWaitForIdle();
        MessageRetry.instance.dispose();
        SqliteService.setDbForTest(null);
        EncryptionModeService.debugSet(mode: mode, initialized: initialized);
      }
    });
  }
  for (final (framing, stale, stage) in [
    (FramingMode.v2, false, 'connected'),
    (FramingMode.v2, true, 'connected'),
    (FramingMode.none, true, 'connected'),
    (FramingMode.v2, false, 'disconnected'),
    (FramingMode.v2, false, 'rejected'),
  ]) {
    test(
      'revoke lookup framing=$framing session changed=$stale stage=$stage',
      () async {
        final svc = WebSocketService.to;
        final fake = _FakeChannel();
        svc.channelForTest = fake;
        svc.statusForTest = stage == 'disconnected'
            ? SocketStatus.disconnected
            : SocketStatus.connected;
        if (stage == 'rejected') {
          fake._sink.onAdd = () =>
              throw StateError('Synthetic recall sink rejection');
        }
        svc.framingForTest = framing;
        final entered = Completer<void>();
        final release = Completer<MessageModel?>();
        MessageActions.messageLoaderForTest = (type, id) {
          expect(type, 'C2C');
          expect(id, '1001');
          entered.complete();
          return release.future;
        };
        SqliteService.setDbForTest(_EmptyRetryDatabase());
        final requests = <WebSocketMessageSendRequestEvent>[];
        final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
            .listen((event) {
              requests.add(event);
              svc.handleSendRequestForTest(event);
            });
        try {
          final pending = MessageActions.instance.sendRevokeMessage(
            '1001',
            'C2C',
          );
          await entered.future;
          if (stale) {
            await expectLater(
              UserRepoLocal.to.loginAfter('synthetic-session', {
                'uid': '101',
                'token': 'synthetic-token',
                'refreshtoken': 'synthetic-refresh',
              }),
              throwsA(isA<PlatformException>()),
            );
          }
          release.complete(
            MessageModel(
              '1001',
              autoId: 0,
              conversationUk3: 'C2C_100_200',
              type: 'C2C',
              fromId: 100,
              toId: 200,
              msgType: 'text',
              payload: {'text': 'synthetic'},
              status: IMBoyMessageStatus.sent,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              isAuthor: 1,
            ),
          );
          expect(await pending, !stale);
          await pumpEventQueue();
          expect(requests, stale ? isEmpty : hasLength(1));
          expect(
            fake._sink.sent,
            stale || stage == 'disconnected' ? isEmpty : hasLength(1),
          );
        } finally {
          await subscription.cancel();
          MessageActions.messageLoaderForTest = null;
          await MessageRetry.instance.debugWaitForIdle();
          MessageRetry.instance.dispose();
          SqliteService.setDbForTest(null);
        }
      },
    );
  }
  test('C2G held after outbox begin cannot reach the socket', () async {
    ffi.sqfliteFfiInit();
    final db = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    await db.execute(
      'CREATE TABLE msg_c2g (auto_id INTEGER PRIMARY KEY, id TEXT, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER, conversation_uk3 TEXT)',
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
    );
    await db.execute(
      'CREATE TABLE message_send_attempt (user_id TEXT, anchor TEXT, token TEXT, PRIMARY KEY (user_id, anchor, token))',
    );
    await db.insert('msg_c2g', {
      'auto_id': 1,
      'id': 'held-id',
      'type': 'C2G',
      'from_id': '100',
      'to_id': '202',
      'is_author': 1,
      'status': 10,
      'conversation_uk3': 'C2G_100_202',
    });
    await db.insert('message_send_attempt', {
      'user_id': '100',
      'anchor': 'held-id',
      'token': 'earlier-attempt',
    });
    await db.insert('attachment_upload_task', {
      'id': 'upload',
      'user_id': '100',
      'anchor_msg_id': 'held-id',
      'stage': 'confirmed',
      'business_intent': jsonEncode({
        'state': 'dispatch_reserved_v2',
        'marker': 'preserve',
      }),
    });
    SqliteService.setDbForTest(db);
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    svc.afterOutboxBeginForTest = () async {
      expect(
        await C2gSendGate.run(
          '100',
          'held-id',
          () => C2gRejectionHold.persist(
            db: db,
            messageId: 'held-id',
            ownerUid: '100',
            expectedAutoId: 1,
            expectedPeerId: '202',
            isCurrent: () => true,
          ),
        ),
        isTrue,
      );
    };
    try {
      expect(
        await svc.sendMessage(
          jsonEncode({'id': 'held-id', 'type': 'C2G', 'to': '202'}),
          'held-id',
          dispatchClaimed: true,
        ),
        isFalse,
      );
      expect(fake._sink.sent, isEmpty);
      expect((await db.query('msg_c2g')).single['status'], 42);
      expect(await db.query('message_send_attempt'), hasLength(1));
      final intent = jsonDecode(
        (await db.query('attachment_upload_task')).single['business_intent']
            as String,
      );
      expect(intent['state'], 'dispatch_reserved_v2');
      expect(intent['marker'], 'preserve');
    } finally {
      svc.afterOutboxBeginForTest = null;
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      await db.close();
    }
  });

  test('offline queue cannot send a held C2G message', () async {
    ffi.sqfliteFfiInit();
    final db = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    await db.execute(
      'CREATE TABLE msg_c2g (id TEXT, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER)',
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
    );
    await db.insert('msg_c2g', {
      'id': 'held-queue',
      'type': 'C2G',
      'from_id': '100',
      'to_id': '202',
      'is_author': 1,
      'status': 42,
    });
    SqliteService.setDbForTest(db);
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    final queue = PersistentMessageQueue.to;
    queue.enqueue(
      'held-queue',
      jsonEncode({'id': 'held-queue', 'type': 'C2G', 'to': '202'}),
      ownerUid: '100',
      sessionGeneration: UserRepoLocal.to.sessionGeneration,
    );
    try {
      await svc.flushMessageQueueForTest();
      expect(fake._sink.sent, isEmpty);
      expect(queue.messages, hasLength(1));
      expect((await db.query('msg_c2g')).single['status'], 42);
    } finally {
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      await db.close();
    }
  });

  test('queue identity conflict preserves the unsent entry', () async {
    ffi.sqfliteFfiInit();
    final db = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    await db.execute(
      'CREATE TABLE msg_c2g (id TEXT, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER)',
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
    );
    await db.insert('msg_c2g', {
      'id': 'conflict-id',
      'type': 'C2G',
      'from_id': '100',
      'to_id': '202',
      'is_author': 1,
      'status': 42,
    });
    SqliteService.setDbForTest(db);
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    final queue = PersistentMessageQueue.to;
    queue.enqueue(
      'conflict-id',
      jsonEncode({'id': 'conflict-id', 'type': 'C2G', 'to': '999'}),
      ownerUid: '100',
      sessionGeneration: UserRepoLocal.to.sessionGeneration,
    );
    try {
      await svc.flushMessageQueueForTest();
      expect(fake._sink.sent, isEmpty);
      expect(queue.messages, hasLength(1));
      expect((await db.query('msg_c2g')).single['status'], 42);
    } finally {
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      await db.close();
    }
  });

  test('C2G status lookup failure cannot reach the socket', () async {
    SqliteService.setDbForTest(_FailC2gLookupDatabase());
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    expect(
      await svc.sendMessage(
        jsonEncode({'id': 'lookup-failure', 'type': 'C2G', 'to': '202'}),
        'lookup-failure',
        dispatchClaimed: true,
      ),
      isFalse,
    );
    expect(fake._sink.sent, isEmpty);
    await MessageRetry.instance.debugWaitForIdle();
  });

  test('C2G gate compares large peer IDs exactly', () async {
    ffi.sqfliteFfiInit();
    final db = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    await db.execute(
      'CREATE TABLE msg_c2g (id TEXT, type TEXT, from_id INTEGER, to_id INTEGER, is_author INTEGER, status INTEGER)',
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
    );
    await db.insert('msg_c2g', {
      'id': 'large-peer',
      'type': 'C2G',
      'from_id': '100',
      'to_id': '9007199254740993',
      'is_author': 1,
      'status': 10,
    });
    SqliteService.setDbForTest(db);
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    try {
      for (final peer in ['9007199254740992', '9007199254740993']) {
        expect(
          await svc.sendMessage(
            jsonEncode({'id': 'large-peer', 'type': 'C2G', 'to': peer}),
            'large-peer',
            dispatchClaimed: true,
          ),
          peer == '9007199254740993',
        );
      }
      expect(fake._sink.sent, hasLength(1));
    } finally {
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      await db.close();
    }
  });

  test('held unknown attachment retains queue and recovery data after inconclusive lookup', () async {
    ffi.sqfliteFfiInit();
    final db = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    await db.execute(
      'CREATE TABLE msg_c2g (id TEXT, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER)',
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
    );
    await db.execute(
      'CREATE TABLE message_send_attempt (user_id TEXT, anchor TEXT, token TEXT, PRIMARY KEY (user_id, anchor, token))',
    );
    await db.insert('msg_c2g', {
      'id': 'unknown-attachment',
      'type': 'C2G',
      'from_id': '100',
      'to_id': '202',
      'is_author': 1,
      'status': 42,
    });
    final intent = jsonEncode({'state': 'commit_unknown', 'marker': 'keep'});
    await db.insert('attachment_upload_task', {
      'id': 'upload',
      'user_id': '100',
      'anchor_msg_id': 'unknown-attachment',
      'stage': 'confirmed',
      'business_intent': intent,
    });
    await db.insert('message_send_attempt', {
      'user_id': '100',
      'anchor': 'unknown-attachment',
      'token': 'earlier-attempt',
    });
    SqliteService.setDbForTest(db);
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    var lookups = 0;
    svc.outboxCommittedForTest = (type, peer, id) async {
      lookups++;
      return false;
    };
    final queue = PersistentMessageQueue.to;
    queue.enqueue(
      'unknown-attachment',
      jsonEncode({'id': 'unknown-attachment', 'type': 'C2G', 'to': '202'}),
      ownerUid: '100',
      sessionGeneration: UserRepoLocal.to.sessionGeneration,
    );
    try {
      await svc.flushMessageQueueForTest();
      expect(fake._sink.sent, isEmpty);
      expect(queue.messages, hasLength(1));
      expect(lookups, 1);
      expect(
        (await db.query('attachment_upload_task')).single['business_intent'],
        intent,
      );
      expect(
        (await db.query('message_send_attempt')).single['token'],
        'earlier-attempt',
      );
      expect((await db.query('msg_c2g')).single['status'], 42);
    } finally {
      svc.outboxCommittedForTest = null;
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      await db.close();
    }
  });

  test(
    'a rejection waits for an already gated send and blocks later sends',
    () async {
      ffi.sqfliteFfiInit();
      final db = await ffi.databaseFactoryFfi.openDatabase(
        ffi.inMemoryDatabasePath,
      );
      await db.execute(
        'CREATE TABLE msg_c2g (auto_id INTEGER PRIMARY KEY, id TEXT, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER, conversation_uk3 TEXT)',
      );
      await db.execute(
        'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
      );
      await db.insert('msg_c2g', {
        'auto_id': 1,
        'id': 'gate-first',
        'type': 'C2G',
        'from_id': '100',
        'to_id': '202',
        'is_author': 1,
        'status': 10,
        'conversation_uk3': 'C2G_100_202',
      });
      SqliteService.setDbForTest(db);
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      final entered = Completer<void>();
      final release = Completer<void>();
      svc.beforeC2gGateCheckForTest = () async {
        entered.complete();
        await release.future;
      };
      final raw = jsonEncode({'id': 'gate-first', 'type': 'C2G', 'to': '202'});
      try {
        final sending = svc.sendMessage(
          raw,
          'gate-first',
          dispatchClaimed: true,
        );
        await entered.future.timeout(const Duration(seconds: 3));
        var holdFinished = false;
        final hold = C2gSendGate.run('100', 'gate-first', () async {
          final result = await C2gRejectionHold.persist(
            db: db,
            messageId: 'gate-first',
            ownerUid: '100',
            expectedAutoId: 1,
            expectedPeerId: '202',
            isCurrent: () => true,
          );
          holdFinished = true;
          return result;
        });
        await pumpEventQueue();
        expect(holdFinished, isFalse);
        release.complete();
        expect(await sending, isTrue);
        expect(await hold, isTrue);
        expect(fake._sink.sent, hasLength(1));
        svc.beforeC2gGateCheckForTest = null;
        // A late valid ACK may promote the held row before a queued retry runs.
        await db.update(
          'msg_c2g',
          {'status': 11},
          where: 'id = ?',
          whereArgs: ['gate-first'],
        );
        expect(
          await svc.sendMessage(raw, 'gate-first', dispatchClaimed: true),
          isFalse,
        );
        expect(fake._sink.sent, hasLength(1));
        expect((await db.query('msg_c2g')).single['status'], 11);
      } finally {
        if (!release.isCompleted) release.complete();
        svc.beforeC2gGateCheckForTest = null;
        SqliteService.setDbForTest(_EmptyRetryDatabase());
        await db.close();
      }
    },
  );

  for (final framing in [FramingMode.none, FramingMode.v2]) {
    for (final stale in [false, true]) {
      test('pending ACK retry framing=$framing stale=$stale', () async {
        final svc = WebSocketService.to;
        final fake = _FakeChannel();
        svc.channelForTest = fake;
        svc.statusForTest = SocketStatus.connected;
        svc.framingForTest = framing;
        final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
            .listen(svc.handleSendRequestForTest);
        final manager = AckManager.to;
        try {
          manager.sendAck('C2C', '1001', overrideDeviceId: 'synthetic-device');
          await pumpEventQueue();
          expect(fake._sink.sent, hasLength(1));
          final generation = UserRepoLocal.to.sessionGeneration;
          if (stale) {
            await expectLater(
              UserRepoLocal.to.loginAfter('synthetic-session', {
                'uid': '101',
                'token': 'synthetic-token',
                'refreshtoken': 'synthetic-refresh',
              }),
              throwsA(isA<PlatformException>()),
            );
            expect(UserRepoLocal.to.sessionGeneration, generation + 1);
          }
          await Future<void>.delayed(const Duration(milliseconds: 3100));
          await pumpEventQueue();
          expect(fake._sink.sent, hasLength(stale ? 1 : 2));
          expect(manager.pendingCount, stale ? 0 : 1);
        } finally {
          await subscription.cancel();
          manager.dispose();
        }
      });
    }
  }
  test(
    'same ID ACK keeps timer in session and replaces it across sessions',
    () async {
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(svc.handleSendRequestForTest);
      final manager = AckManager.to;
      try {
        void send() => manager.sendAck(
          'C2C',
          '1001',
          overrideDeviceId: 'synthetic-device',
        );
        send();
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        send();
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        await pumpEventQueue();
        expect(fake._sink.sent, hasLength(3));
        await expectLater(
          UserRepoLocal.to.loginAfter('synthetic-session', {
            'uid': '101',
            'token': 'synthetic-token',
            'refreshtoken': 'synthetic-refresh',
          }),
          throwsA(isA<PlatformException>()),
        );
        send();
        await pumpEventQueue();
        expect(fake._sink.sent, hasLength(4));
        await Future<void>.delayed(const Duration(milliseconds: 3100));
        await pumpEventQueue();
        expect(fake._sink.sent, hasLength(5));
        await Future<void>.delayed(const Duration(milliseconds: 2100));
        await pumpEventQueue();
        expect(fake._sink.sent, hasLength(5));
        expect(manager.pendingCount, 1);
      } finally {
        await subscription.cancel();
        manager.dispose();
      }
    },
  );
  for (final stale in [false, true]) {
    test('send event consumption session changed=$stale', () async {
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      final event = WebSocketMessageSendRequestEvent(
        message: '{"type":"C2C","from":"100","to":"200","payload":"synthetic"}',
        messageId: 'synthetic-event',
      );
      if (stale) {
        final repo = UserRepoLocal.to;
        final generation = repo.sessionGeneration;
        await expectLater(
          repo.loginAfter('synthetic-session', {
            'uid': '101',
            'token': 'synthetic-token',
            'refreshtoken': 'synthetic-refresh',
          }),
          throwsA(isA<PlatformException>()),
        );
        expect(repo.sessionGeneration, generation + 1);
        expect(repo.currentUid, '100');
      }
      svc.handleSendRequestForTest(event);
      await pumpEventQueue();
      expect(fake._sink.sent, stale ? isEmpty : hasLength(1));
    });
  }
  for (final stage in ['normal', 'other-owner', 'old-generation', 'unowned']) {
    test('offline queue $stage', () async {
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      final generation = UserRepoLocal.to.sessionGeneration;
      PersistentMessageQueue.to.enqueue(
        'offline-$stage',
        'synthetic-offline',
        ownerUid: stage == 'unowned'
            ? ''
            : stage == 'other-owner'
            ? '101'
            : '100',
        sessionGeneration: stage == 'old-generation'
            ? generation - 1
            : generation,
      );
      await svc.flushMessageQueueForTest();
      expect(fake._sink.sent, stage == 'normal' ? hasLength(1) : isEmpty);
      expect(
        PersistentMessageQueue.to.messages,
        stage == 'normal' ? isEmpty : hasLength(1),
      );
    });
  }
  test('发送许可后通道变化，未调用 sink 时恢复预留状态', () async {
    ffi.sqfliteFfiInit();
    final db = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, last_error TEXT, business_intent TEXT)',
    );
    await db.insert('attachment_upload_task', {
      'id': 'upload',
      'user_id': '100',
      'anchor_msg_id': 'channel-race',
      'stage': 'confirmed',
      'business_intent': jsonEncode({'state': 'dispatch_reserved_v2'}),
    });
    SqliteService.setDbForTest(db);
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    svc.afterOutboxBeginForTest = () async {
      svc.channelForTest = null;
    };
    expect(
      await svc.sendMessage(
        jsonEncode({'id': 'channel-race', 'type': 'C2C'}),
        'channel-race',
        dispatchClaimed: true,
      ),
      isFalse,
    );
    expect(fake._sink.sent, isEmpty);
    final row = (await db.query('attachment_upload_task')).single;
    expect(
      jsonDecode(row['business_intent'] as String)['state'],
      'dispatch_reserved_v2',
    );
    expect(await db.query('message_send_attempt'), isEmpty);
    svc.afterOutboxBeginForTest = null;
    svc.channelForTest = fake;
    fake._sink.onAdd = () => throw StateError('sink failure after invocation');
    expect(
      await svc.sendMessage(
        jsonEncode({'id': 'channel-race', 'type': 'C2C'}),
        'channel-race',
        dispatchClaimed: true,
      ),
      isFalse,
    );
    expect(
      jsonDecode(
        (await db.query('attachment_upload_task')).single['business_intent']
            as String,
      )['state'],
      'commit_unknown',
    );
    expect(await db.query('message_send_attempt'), hasLength(1));
    await db.close();
    SqliteService.setDbForTest(_EmptyRetryDatabase());
  });

  test('未知提交附件留队时不阻塞后续离线消息', () async {
    SqliteService.setDbForTest(_FencedDatabase());
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    final generation = UserRepoLocal.to.sessionGeneration;
    PersistentMessageQueue.to.enqueue(
      'blocked',
      jsonEncode({'id': 'blocked-id'}),
      ownerUid: '100',
      sessionGeneration: generation,
    );
    PersistentMessageQueue.to.enqueue(
      'ordinary',
      'synthetic-ordinary',
      ownerUid: '100',
      sessionGeneration: generation,
    );
    await svc.flushMessageQueueForTest();
    expect(fake._sink.sent, hasLength(1));
    expect(PersistentMessageQueue.to.messages.map((m) => m.id), ['blocked']);
  });

  for (final stage in ['restore-normal', 'restore-other', 'restore-legacy']) {
    test('offline persistence $stage', () async {
      final raw = {
        'id': stage,
        'data': 'synthetic-restored',
        'priority': 0,
        'createdAt': DateTime.now().toIso8601String(),
        if (stage != 'restore-legacy')
          'ownerUid': stage == 'restore-normal' ? '100' : '101',
      };
      final prefs = await SharedPreferences.getInstance();
      await PersistentMessageQueue.to.flushPersistence();
      await prefs.setStringList('ws_message_queue', [jsonEncode(raw)]);
      await PersistentMessageQueue.to.init();
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      await svc.flushMessageQueueForTest();
      expect(
        fake._sink.sent,
        stage == 'restore-normal' ? hasLength(1) : isEmpty,
      );
      expect(
        PersistentMessageQueue.to.messages,
        stage == 'restore-normal' ? isEmpty : hasLength(1),
      );
    });
  }
  for (final priority in [0, 1]) {
    test(
      'failed flush preserves original when sink fills queue priority=$priority',
      () async {
        final svc = WebSocketService.to;
        final fake = _FakeChannel();
        svc.channelForTest = fake;
        svc.statusForTest = SocketStatus.connected;
        final queue = PersistentMessageQueue.to;
        final generation = UserRepoLocal.to.sessionGeneration;
        queue.enqueue(
          'original',
          'synthetic-original',
          ownerUid: '100',
          sessionGeneration: generation,
        );
        fake._sink.onAdd = () {
          for (var i = 0; i < 200; i++) {
            queue.enqueue(
              'competing-$i',
              'synthetic',
              priority: priority,
              ownerUid: 'other',
              sessionGeneration: generation,
            );
          }
          throw StateError('Synthetic sink rejection');
        };
        await svc.flushMessageQueueForTest();
        expect(queue.messages, hasLength(200));
        final original = queue.messages
            .where((entry) => entry.id == 'original')
            .single;
        expect(original.data, 'synthetic-original');
        expect(original.ownerUid, '100');
        expect(original.sessionGeneration, generation);
        expect(
          queue.peekByPriority(eligible: (entry) => entry.id == 'original'),
          same(original),
        );
        fake._sink.onAdd = null;
        svc.channelForTest = fake;
        svc.statusForTest = SocketStatus.connected;
        await svc.flushMessageQueueForTest();
        expect(
          queue.messages.where((entry) => entry.id == 'original'),
          isEmpty,
        );
        expect(queue.messages, hasLength(199));
      },
    );
  }
  test('in-flight priority update cannot duplicate accepted message', () async {
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    final queue = PersistentMessageQueue.to;
    queue.enqueue(
      'original',
      'synthetic-original',
      ownerUid: '100',
      sessionGeneration: UserRepoLocal.to.sessionGeneration,
    );
    fake._sink.onAdd = () => queue.updatePriority('original', 2);
    await svc.flushMessageQueueForTest();
    expect(fake._sink.sent, hasLength(1));
    expect(queue.messages, isEmpty);
  });
  test('flush stops after first frame changes session generation', () async {
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    for (final id in ['first', 'second']) {
      PersistentMessageQueue.to.enqueue(
        id,
        'synthetic-$id',
        ownerUid: '100',
        sessionGeneration: UserRepoLocal.to.sessionGeneration,
      );
    }
    Future<void>? change;
    fake._sink.onAdd = () {
      fake._sink.onAdd = null;
      change = expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
    };
    await svc.flushMessageQueueForTest();
    await change;
    expect(fake._sink.sent, hasLength(1));
    expect(PersistentMessageQueue.to.messages.single.id, 'second');
  });
  test('retained stale ID does not block fresh session enqueue', () async {
    final svc = WebSocketService.to;
    final fake = _FakeChannel();
    svc.channelForTest = fake;
    svc.statusForTest = SocketStatus.connected;
    final generation = UserRepoLocal.to.sessionGeneration;
    final queue = PersistentMessageQueue.to;
    queue.enqueue(
      'same-id',
      'synthetic-same',
      ownerUid: '100',
      sessionGeneration: generation - 1,
    );
    queue.enqueue(
      'same-id',
      'synthetic-same',
      ownerUid: '100',
      sessionGeneration: generation,
    );
    queue.enqueue(
      'same-id',
      'synthetic-same',
      ownerUid: '100',
      sessionGeneration: generation,
    );
    expect(queue.messages, hasLength(2));
    await svc.flushMessageQueueForTest();
    expect(fake._sink.sent, hasLength(1));
    expect(queue.messages.single.sessionGeneration, generation - 1);
  });
  test('priority updates require unambiguous account/session scope', () {
    final generation = UserRepoLocal.to.sessionGeneration;
    final queue = PersistentMessageQueue.to;
    for (final gen in [generation - 1, generation]) {
      queue.enqueue(
        'priority-id',
        'synthetic',
        ownerUid: '100',
        sessionGeneration: gen,
      );
    }
    queue.updatePriority('priority-id', 2);
    expect(queue.messages.every((entry) => entry.priority == 0), isTrue);
    queue.updatePriority(
      'priority-id',
      2,
      ownerUid: '100',
      sessionGeneration: generation,
    );
    expect(
      queue.messages
          .singleWhere((entry) => entry.sessionGeneration == generation)
          .priority,
      2,
    );
    expect(
      queue.messages
          .singleWhere((entry) => entry.sessionGeneration != generation)
          .priority,
      0,
    );
  });
  for (final conflict in [false, true]) {
    test('restore same owner ID conflicting=$conflict', () async {
      final prefs = await SharedPreferences.getInstance();
      final rows = ['old', conflict ? 'new' : 'old']
          .map(
            (data) => jsonEncode({
              'id': 'restore-conflict',
              'ownerUid': '100',
              'priority': 0,
              'data': data,
              'createdAt': DateTime.now().toIso8601String(),
            }),
          )
          .toList();
      await PersistentMessageQueue.to.flushPersistence();
      await prefs.setStringList('ws_message_queue', rows);
      await PersistentMessageQueue.to.init();
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      await svc.flushMessageQueueForTest();
      expect(fake._sink.sent, conflict ? isEmpty : hasLength(1));
      if (conflict) expect(PersistentMessageQueue.to.messages, hasLength(2));
    });
  }
  test(
    'conflict remains quarantined after expiry leaves one restored row',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final rows = ['old', 'new']
          .map(
            (data) => jsonEncode({
              'id': 'durable-conflict',
              'ownerUid': '100',
              'priority': 0,
              'data': data,
              'createdAt':
                  (data == 'old'
                          ? DateTime.now().subtract(const Duration(hours: 25))
                          : DateTime.now())
                      .toIso8601String(),
            }),
          )
          .toList();
      await PersistentMessageQueue.to.flushPersistence();
      await prefs.setStringList('ws_message_queue', rows);
      final queue = PersistentMessageQueue.to;
      await queue.init();
      queue.cleanupExpired();
      await pumpEventQueue();
      final survivor = prefs.getStringList('ws_message_queue')!;
      expect(survivor, hasLength(1));
      queue.clear();
      await PersistentMessageQueue.to.flushPersistence();
      await prefs.setStringList('ws_message_queue', survivor);
      await queue.init();
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      await svc.flushMessageQueueForTest();
      expect(fake._sink.sent, isEmpty);
      expect(queue.messages, hasLength(1));
    },
  );
  for (final stage in ['repeat-normal', 'repeat-conflict', 'merge-conflict']) {
    test('queue initialization $stage', () async {
      final queue = PersistentMessageQueue.to;
      if (stage == 'merge-conflict') {
        queue.enqueue(
          'init-id',
          'old',
          ownerUid: '100',
          sessionGeneration: UserRepoLocal.to.sessionGeneration,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final rows = (stage == 'repeat-normal' ? ['old'] : ['old', 'new'])
          .map(
            (data) => jsonEncode({
              'id': 'init-id',
              'ownerUid': '100',
              'data': data,
              'priority': 0,
              'createdAt': DateTime.now().toIso8601String(),
            }),
          )
          .toList();
      await PersistentMessageQueue.to.flushPersistence();
      await prefs.setStringList('ws_message_queue', rows);
      await queue.init();
      await queue.init();
      expect(queue.messages, hasLength(stage == 'repeat-normal' ? 1 : 2));
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      await svc.flushMessageQueueForTest();
      expect(
        fake._sink.sent,
        stage == 'repeat-normal' ? hasLength(1) : isEmpty,
      );
    });
  }
  for (final stage in [
    'same-priority',
    'lower-priority',
    'evicted-reenqueue',
  ]) {
    test('bounded queue $stage', () {
      final queue = PersistentMessageQueue.to;
      final priority = stage == 'lower-priority' ? 2 : 0;
      for (var i = 0; i < 200; i++) {
        queue.enqueue('capacity-$i', 'synthetic-$i', priority: priority);
      }
      if (stage == 'evicted-reenqueue') {
        queue.enqueue('high', 'synthetic-high', priority: 1);
        expect(queue.dequeueByPriority()!.id, 'high');
        queue.enqueue('capacity-0', 'synthetic-0');
        expect(queue.messages.any((entry) => entry.id == 'capacity-0'), isTrue);
      } else {
        queue.enqueue('overflow', 'synthetic-overflow');
        expect(queue.messages.any((entry) => entry.id == 'overflow'), isFalse);
      }
      expect(queue.messages, hasLength(200));
    });
  }
  for (final framing in [FramingMode.none, FramingMode.v2]) {
    test(
      'local_sender_metadata_stripped_all_actual_ws_exits_$framing',
      () async {
        final svc = WebSocketService.to;
        final channel = _FakeChannel();
        svc.channelForTest = channel;
        svc.statusForTest = SocketStatus.connected;
        svc.framingForTest = framing;
        final raw = jsonEncode({
          'id': 'owned-wire-id',
          'type': 'C2G',
          'from': '100',
          'to': '202',
          'msg_type': 'file',
          'payload': '',
          'e2ee': {
            'protocol': 'megolm',
            MessageModel.localSenderDidKey: 'local-device',
          },
        });
        expect(await svc.sendMessage(raw, 'owned-wire-id'), isTrue);
        // Synchronous direct sending cannot consult the durable C2G hold.
        expect(svc.sendDirect(raw), isFalse);
        PersistentMessageQueue.to.enqueue(
          'owned-queue-id',
          raw,
          ownerUid: '100',
          sessionGeneration: UserRepoLocal.to.sessionGeneration,
        );
        await svc.flushMessageQueueForTest();
        expect(channel._sink.sent, hasLength(2));
        for (final bytes in channel._sink.sent) {
          final wire = bytes is String
              ? bytes
              : utf8.decode(
                  ImboyFrame.tryDecode(bytes as Uint8List)!.frame.payload,
                );
          expect(wire, isNot(contains(MessageModel.localSenderDidKey)));
          expect((jsonDecode(wire) as Map)['e2ee']['protocol'], 'megolm');
        }
      },
    );
  }
  test('direct send permits only explicit complete control frames', () {
    final svc = WebSocketService.to;
    final channel = _FakeChannel();
    svc.channelForTest = channel;
    svc.statusForTest = SocketStatus.connected;
    expect(svc.sendDirect('CLIENT_ACK,C2G,synthetic-id,device'), isTrue);
    expect(svc.sendDirect(ImboyFrame.heartbeatPing(1)), isTrue);
    expect(svc.sendDirect(ImboyFrame.ack(9)), isTrue);
    expect(
      svc.sendDirect(
        jsonEncode({
          'id': 'ack-id',
          'type': 'C2G',
          'action': 'message_edit_ack',
          'payload': {'original_msg_id': 'original-id'},
        }),
      ),
      isTrue,
    );
    final business = ImboyFrame.encode(
      type: FrameType.msgC2G,
      flags: 0,
      payload: Uint8List.fromList(utf8.encode('{"type":"C2G"}')),
    );
    expect(svc.sendDirect(business), isFalse);
    expect(svc.sendDirect(Uint8List.fromList([1, 2, 3])), isFalse);
    expect(svc.sendDirect('{"type":"C2G"}'), isFalse);
    expect(svc.sendDirect('CLIENT_ACK,C2G,id'), isFalse);
    expect(
      svc.sendDirect(Uint8List.fromList([...ImboyFrame.ack(9), ...business])),
      isFalse,
    );
    expect(channel._sink.sent, hasLength(4));
  });
}
