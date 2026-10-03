import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
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
      await prefs.setStringList('ws_message_queue', rows);
      final queue = PersistentMessageQueue.to;
      await queue.init();
      queue.cleanupExpired();
      await pumpEventQueue();
      final survivor = prefs.getStringList('ws_message_queue')!;
      expect(survivor, hasLength(1));
      queue.clear();
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
}
