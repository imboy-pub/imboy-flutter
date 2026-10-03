import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
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

/// 最小 fake channel：暴露 sink，其它成员抛出
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

class _EmptyRetryDatabase implements Database {
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

    WebSocketService.resetForTest();
  });
  tearDown(() {
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
          expect(await pending, !stale && stage == 'connected');
          await pumpEventQueue();
          expect(requests, isEmpty);
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
}
