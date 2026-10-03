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

  @override
  void add(dynamic data) => sent.add(data);

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
}
