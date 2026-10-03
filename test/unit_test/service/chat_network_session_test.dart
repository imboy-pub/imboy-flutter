import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Sink implements WebSocketSink {
  final sent = <dynamic>[];
  @override
  void add(dynamic data) => sent.add(data);
  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel implements WebSocketChannel {
  final output = _Sink();
  @override
  WebSocketSink get sink => output;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyDatabase implements Database {
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
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  for (final stale in [false, true]) {
    test('group policy wait session changed=$stale', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final entered = Completer<void>();
      final release = Completer<String?>();
      final encode = base64Url.encode;
      final token =
          '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
          '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
          '${encode(utf8.encode('synthetic-signature'))}';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (call) async {
            final key = (call.arguments as Map)['key'];
            if (call.method == 'read' && key == 'group_e2ee_mode_200') {
              entered.complete();
              return release.future;
            }
            if (call.method == 'read' && key == 'secure_token') return token;
            if (call.method == 'write' && key == 'secure_token') {
              throw PlatformException(code: 'synthetic-login-stop');
            }
            return null;
          });
      final mode = EncryptionModeService.current;
      final initialized = EncryptionModeService.isInitialized;
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      SqliteService.setDbForTest(_EmptyDatabase());
      WebSocketService.resetForTest();
      final svc = WebSocketService.to;
      final channel = _Channel();
      svc.channelForTest = channel;
      svc.statusForTest = SocketStatus.connected;
      final requests = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen((event) {
            requests.add(event);
            svc.handleSendRequestForTest(event);
          });
      try {
        final pending = const ChatNetworkService().sendMessage({
          'id': 'synthetic-policy-wait',
          'type': 'C2G',
          'from': '100',
          'to': '200',
          'msg_type': 'text',
          'action': '',
          'payload': {'text': 'synthetic-content'},
        });
        await entered.future;
        if (stale) {
          final generation = UserRepoLocal.to.sessionGeneration;
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
        release.complete(null);
        expect(await pending, !stale);
        await pumpEventQueue();
        expect(requests, stale ? isEmpty : hasLength(1));
        expect(channel.output.sent, stale ? isEmpty : hasLength(1));
        expect(MessageRetry.instance.retryQueueSize, stale ? 0 : 1);
      } finally {
        if (!release.isCompleted) release.complete(null);
        await subscription.cancel();
        await MessageRetry.instance.debugWaitForIdle();
        MessageRetry.instance.dispose();
        SqliteService.setDbForTest(null);
        svc.dispose();
        WebSocketService.resetForTest();
        PersistentMessageQueue.to.dispose();
        EncryptionModeService.debugSet(mode: mode, initialized: initialized);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, null);
      }
    });
  }
}
