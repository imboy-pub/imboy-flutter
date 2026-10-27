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
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/websocket_message_queue.dart';

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

  const ids = [
    '00123',
    '123',
    'opaque-alpha',
    'opaque-beta',
    '184467440737095516160001',
    '550e8400-e29b-41d4-a716-446655440000',
    'd1s0sm3j1dds73b7acog',
  ];
  String wire(dynamic frame) => frame is String
      ? frame
      : utf8.decode(ImboyFrame.tryDecode(frame as Uint8List)!.frame.payload);

  for (final framing in [FramingMode.none, FramingMode.v2]) {
    test(
      'ACK initial/direct/retry retain every string with framing=$framing',
      () async {
        final svc = WebSocketService.to;
        final fake = _FakeChannel();
        svc.channelForTest = fake;
        svc.statusForTest = SocketStatus.connected;
        svc.framingForTest = framing;
        final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
            .listen(svc.handleSendRequestForTest);
        final manager = AckManager.to;
        try {
          for (final id in ids) {
            manager.sendAck('C2C', id, overrideDeviceId: 'synthetic-device');
            manager.sendAckDirect(
              'C2C',
              id,
              overrideDeviceId: 'synthetic-device',
            );
          }
          await pumpEventQueue();
          expect(fake._sink.sent, hasLength(ids.length * 2));
          await Future<void>.delayed(const Duration(milliseconds: 3100));
          await pumpEventQueue();
          expect(fake._sink.sent, hasLength(ids.length * 3));
          final payloads = fake._sink.sent.map(wire).toList();
          for (final id in ids) {
            expect(
              payloads.where(
                (payload) => payload == 'CLIENT_ACK,C2C,$id,synthetic-device',
              ),
              hasLength(3),
            );
          }
        } finally {
          await subscription.cancel();
          manager.dispose();
        }
      },
    );

    test('revoke retains original string with framing=$framing', () async {
      final svc = WebSocketService.to;
      final fake = _FakeChannel();
      svc.channelForTest = fake;
      svc.statusForTest = SocketStatus.connected;
      svc.framingForTest = framing;
      SqliteService.setDbForTest(_EmptyRetryDatabase());
      MessageActions.messageLoaderForTest = (type, id) async => MessageModel(
        id,
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
      );
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(svc.handleSendRequestForTest);
      try {
        for (final id in ids) {
          expect(
            await MessageActions.instance.sendRevokeMessage(id, 'C2C'),
            isTrue,
          );
        }
        await pumpEventQueue();
        expect(fake._sink.sent, hasLength(ids.length));
        final originals = fake._sink.sent
            .map(
              (frame) =>
                  (jsonDecode(wire(frame))
                      as Map)['payload']['original_msg_id'],
            )
            .toList();
        expect(originals, ids);
      } finally {
        await subscription.cancel();
        MessageActions.messageLoaderForTest = null;
        await MessageRetry.instance.debugWaitForIdle();
        MessageRetry.instance.dispose();
        SqliteService.setDbForTest(null);
      }
    });
  }
}
