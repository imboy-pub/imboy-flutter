import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/contact_model.dart';
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
  int updates = 0;
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    updates++;
    return 0;
  }

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

class _StatusDatabase extends _EmptyDatabase {
  int rowStatus = IMBoyMessageStatus.error;
  final entered = Completer<void>();
  final release = Completer<int>();
  int queries = 0;
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    updates++;
    if (updates == 1) {
      entered.complete();
      return release.future;
    }
    return 0;
  }

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
    if (where?.contains('status') == true) return [];
    queries++;
    if (table == 'contact') {
      return [ContactModel(peerId: 200, nickname: 'Synthetic').toJson()];
    }
    if (!table.startsWith('msg_')) return [];
    return [
      MessageModel(
        'synthetic-status',
        autoId: 1,
        type: 'C2C',
        status: rowStatus,
        fromId: 200,
        toId: 200,
        payload: {'text': 'synthetic'},
        isAuthor: 1,
        conversationUk3: 'synthetic-status',
        msgType: 'text',
      ).toJson(),
    ];
  }
}

class _ReadActionDatabase extends _StatusDatabase {
  _ReadActionDatabase() {
    rowStatus = IMBoyMessageStatus.seen;
  }
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    updates++;
    if (updates == 1) {
      entered.complete();
      return release.future;
    }
    return 1;
  }
}

class _ReceiptConversationNotifier extends ConversationNotifier {
  final updatedIds = <String>[];
  @override
  ConversationState build() => ConversationState(isLoading: false);
  @override
  Future<void> updateConversationByMsgId(
    String id,
    Map<String, dynamic> data,
  ) async {
    updatedIds.add(id);
  }
}

class _ChangeOnSuccessfulEncode {
  _ChangeOnSuccessfulEncode(this.change);
  final void Function() change;
  Object toJson() {
    change();
    return {'text': 'synthetic-content'};
  }
}

class _ChangeOnEncode {
  _ChangeOnEncode(this.change);
  final void Function() change;
  Object toJson() {
    change();
    throw StateError('Synthetic encoding failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final receiptNotifier = _ReceiptConversationNotifier();
  final receiptContainer = ProviderContainer(
    overrides: [conversationProvider.overrideWith(() => receiptNotifier)],
  );
  // The injected global references remain live until this whole file completes.
  final receiptProviderSubscription = receiptContainer.listen(
    conversationProvider,
    (_, _) {},
  );
  tearDownAll(() {
    receiptProviderSubscription.close();
    receiptContainer.dispose();
  });
  for (final action in [C2SAction.messageRead, C2SAction.messageReadAck]) {
    for (final stale in [false, true]) {
      test('read action=$action database session changed=$stale', () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        final database = _ReadActionDatabase();
        SqliteService.setDbForTest(database);
        final notifier = receiptNotifier;
        notifier.updatedIds.clear();
        MessageService.setProviderContainer(receiptContainer);
        final service = MessageService.instance;
        await pumpEventQueue();
        service.cancelAllSubscriptions();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, (call) async {
              if (call.method == 'write' &&
                  (call.arguments as Map)['key'] == 'secure_token') {
                throw PlatformException(code: 'synthetic-login-stop');
              }
              return null;
            });
        final events = <DataWrapperEvent<dynamic>>[];
        final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
          events.add,
        );
        try {
          final pending = MessageActions.instance.handleActionMessage(action, {
            'id': 'synthetic-read-action',
            'type': 'C2C',
            'from': action == C2SAction.messageRead ? '200' : '100',
            'to': '100',
            'payload': {
              'msg_ids': ['synthetic-status'],
            },
          });
          await database.entered.future;
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
          database.release.complete(1);
          expect(await pending, !stale);
          await pumpEventQueue();
          expect(database.updates, 1);
          expect(notifier.updatedIds.length, stale ? 0 : 1);
          expect(database.queries, stale ? 0 : 2);
          expect(events.length, stale ? 0 : 1);
          if (!stale) {
            expect((events.single.data as List).single.id, 'synthetic-status');
            expect(
              (events.single.data as List).single.metadata['status'],
              IMBoyMessageStatus.seen,
            );
          }
        } finally {
          await subscription.cancel();
          SqliteService.setDbForTest(null);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureChannel, null);
        }
      });
    }
  }
  group('read receipt session boundary', () {
    late MessageService service;
    setUpAll(() async {
      service = MessageService.instance;
      await pumpEventQueue();
      // Observe the production receipt event without starting its UI consumer.
      service.cancelAllSubscriptions();
    });
    tearDownAll(() => service.dispose());
    for (final stale in [false, true]) {
      test('database completion changed=$stale', () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        final database = _StatusDatabase();
        SqliteService.setDbForTest(database);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, (call) async {
              if (call.method == 'write' &&
                  (call.arguments as Map)['key'] == 'secure_token') {
                throw PlatformException(code: 'synthetic-login-stop');
              }
              return null;
            });
        final events = <MessageStatusUpdateRequestedEvent>[];
        final subscription = AppEventBus.on<MessageStatusUpdateRequestedEvent>()
            .listen(events.add);
        try {
          final pending = service.processMessage('MSG_READ', {
            'id': 'synthetic-read-receipt',
            'from': '200',
            'to': '100',
          });
          await database.entered.future;
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
          database.release.complete(1);
          await pending;
          await pumpEventQueue();
          expect(database.updates, 1);
          expect(events.length, stale ? 0 : 1);
          if (!stale) {
            expect(events.single.messageId, 'synthetic-read-receipt');
            expect(events.single.newStatus, IMBoyMessageStatus.seen);
            expect(events.single.notifyUI, isTrue);
          }
        } finally {
          await subscription.cancel();
          SqliteService.setDbForTest(null);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureChannel, null);
        }
      });
    }
  });
  for (final stale in [false, true]) {
    test('direct encoding completion session changed=$stale', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      SqliteService.setDbForTest(_EmptyDatabase());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (call) async {
            if (call.method == 'write' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              throw PlatformException(code: 'synthetic-login-stop');
            }
            return null;
          });
      final requests = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(requests.add);
      try {
        await MessageRetry.instance.debugWaitForIdle();
        Future<void>? changed;
        final result = await const ChatNetworkService().sendMessage({
          'id': 'synthetic-direct-encoding',
          'type': 'C2C',
          'from': '100',
          'to': '200',
          'msg_type': 'text',
          'payload': _ChangeOnSuccessfulEncode(() {
            if (stale) {
              changed = expectLater(
                UserRepoLocal.to.loginAfter('synthetic-session', {
                  'uid': '101',
                  'token': 'synthetic-token',
                  'refreshtoken': 'synthetic-refresh',
                }),
                throwsA(isA<PlatformException>()),
              );
            }
          }),
        });
        if (changed != null) await changed;
        await pumpEventQueue();
        expect(result, !stale);
        expect(requests.length, stale ? 0 : 1);
        expect(MessageRetry.instance.retryQueueSize, stale ? 0 : 1);
        if (!stale) {
          final frame = jsonDecode(requests.single.message) as Map;
          expect((frame['payload'] as Map)['text'], 'synthetic-content');
        }
      } finally {
        await subscription.cancel();
        await MessageRetry.instance.debugWaitForIdle();
        MessageRetry.instance.dispose();
        SqliteService.setDbForTest(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, null);
      }
    });
  }
  test('anonymous status update starts no database write', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: ''});
    await StorageService.init();
    final database = _EmptyDatabase();
    SqliteService.setDbForTest(database);
    try {
      await const ChatNetworkService().updateMessageStatus(
        'anonymous-status',
        IMBoyMessageStatus.error,
      );
      expect(database.updates, 0);
    } finally {
      SqliteService.setDbForTest(null);
    }
  });
  for (final firstResult in [0, 1]) {
    for (final stale in [false, true]) {
      test(
        'status update completion firstResult=$firstResult session changed=$stale',
        () async {
          SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
          await StorageService.init();
          final database = _StatusDatabase();
          SqliteService.setDbForTest(database);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureChannel, (call) async {
                if (call.method == 'write' &&
                    (call.arguments as Map)['key'] == 'secure_token') {
                  throw PlatformException(code: 'synthetic-login-stop');
                }
                return null;
              });
          final events = <DataWrapperEvent<dynamic>>[];
          final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>()
              .listen(events.add);
          try {
            final pending = const ChatNetworkService().updateMessageStatus(
              'synthetic-status',
              IMBoyMessageStatus.error,
            );
            await database.entered.future;
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
            database.release.complete(firstResult);
            await pending;
            await pumpEventQueue();
            expect(database.updates, !stale && firstResult == 0 ? 3 : 1);
            expect(database.queries, stale || firstResult == 0 ? 0 : 2);
            final notifications = events.where(
              (e) => e.dataType == 'List<Message>',
            );
            expect(notifications.length, stale || firstResult == 0 ? 0 : 1);
            if (!stale && firstResult > 0) {
              expect(
                (notifications.single.data as List).single.id,
                'synthetic-status',
              );
            }
          } finally {
            await subscription.cancel();
            SqliteService.setDbForTest(null);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(secureChannel, null);
          }
        },
      );
    }
  }
  test('retry rejects expired generation and stale encode failure', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final database = _EmptyDatabase();
    SqliteService.setDbForTest(database);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'write' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            throw PlatformException(code: 'synthetic-login-stop');
          }
          return null;
        });
    final requests = <WebSocketMessageSendRequestEvent>[];
    final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(requests.add);
    try {
      await MessageRetry.instance.debugWaitForIdle();
      final repo = UserRepoLocal.to;
      final generation = repo.sessionGeneration;
      const network = ChatNetworkService();
      expect(
        await network.sendWithRetry('expired', {
          'type': 'C2C',
        }, sessionGeneration: generation - 1),
        isFalse,
      );
      late Future<void> changed;
      final result = await network.sendWithRetry('synthetic-encoding', {
        'type': 'C2C',
        'payload': _ChangeOnEncode(() {
          changed = expectLater(
            repo.loginAfter('synthetic-session', {
              'uid': '101',
              'token': 'synthetic-token',
              'refreshtoken': 'synthetic-refresh',
            }),
            throwsA(isA<PlatformException>()),
          );
        }),
      });
      await changed;
      await pumpEventQueue();
      expect(repo.sessionGeneration, generation + 1);
      expect(result, isFalse);
      expect(requests, isEmpty);
      expect(MessageRetry.instance.retryQueueSize, 0);
      expect(database.updates, 0);
    } finally {
      await subscription.cancel();
      await MessageRetry.instance.debugWaitForIdle();
      MessageRetry.instance.dispose();
      SqliteService.setDbForTest(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
    }
  });
  for (final entry in ['direct', 'stored']) {
    for (final stale in [false, true]) {
      test('group policy wait entry=$entry session changed=$stale', () async {
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
          const network = ChatNetworkService();
          final pending = entry == 'direct'
              ? network.sendMessage({
                  'id': 'synthetic-policy-wait',
                  'type': 'C2G',
                  'from': '100',
                  'to': '200',
                  'msg_type': 'text',
                  'action': '',
                  'payload': {'text': 'synthetic-content'},
                })
              : network.sendWsMsg(
                  MessageModel(
                    'synthetic-policy-wait',
                    autoId: 0,
                    type: 'C2G',
                    fromId: 200,
                    toId: 200,
                    payload: {'text': 'synthetic-content'},
                    msgType: 'text',
                    status: IMBoyMessageStatus.sending,
                    isAuthor: 1,
                    conversationUk3: 'C2G_100_200',
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  ),
                );
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
}
