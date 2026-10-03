import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _Notifier extends ConversationNotifier {
  int calls = 0;
  @override
  ConversationState build() => ConversationState(isLoading: false);
  @override
  Future<void> updateConversationByMsgId(
    String id,
    Map<String, dynamic> data,
  ) async {
    calls++;
  }
}

class _Database implements Database {
  int updates = 0;
  int queries = 0;
  final entered = Completer<void>();
  final release = Completer<int>();
  @override
  bool get isOpen => true;
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    updates++;
    entered.complete();
    return release.future;
  }

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
  }) async {
    if (where?.contains('status') == true) return [];
    queries++;
    if (table == 'contact') {
      return [ContactModel(peerId: 200, nickname: 'Synthetic').toJson()];
    }
    return [
      MessageModel(
        'synthetic-status-event',
        autoId: 1,
        type: 'C2C',
        status: IMBoyMessageStatus.seen,
        fromId: 200,
        toId: 100,
        payload: {'text': 'synthetic'},
        isAuthor: 0,
        conversationUk3: 'C2C_100_200',
        msgType: 'text',
      ).toJson(),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final notifier = _Notifier();
  final container = ProviderContainer(
    overrides: [conversationProvider.overrideWith(() => notifier)],
  );
  final listener = container.listen(conversationProvider, (_, _) {});
  late MessageService service;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    SqliteService.setDbForTest(_Database());
    MessageService.setProviderContainer(container);
    service = MessageService.instance;
    await pumpEventQueue();
    await MessageRetry.instance.debugWaitForIdle();
  });
  tearDownAll(() {
    service.dispose();
    MessageRetry.instance.dispose();
    SqliteService.setDbForTest(null);
    listener.close();
    container.dispose();
  });
  for (final phase in ['current', 'before_delivery', 'database_wait']) {
    test('status event session phase=$phase', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final database = _Database();
      SqliteService.setDbForTest(database);
      notifier.calls = 0;
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
      Future<void> change() => expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      try {
        final event = MessageStatusUpdateRequestedEvent(
          messageId: 'synthetic-status-event',
          messageType: 'C2C',
          newStatus: IMBoyMessageStatus.seen,
          ownerUid: UserRepoLocal.to.currentUid,
          sessionGeneration: UserRepoLocal.to.sessionGeneration,
        );
        if (phase == 'before_delivery') await change();
        AppEventBus.fire(event);
        if (phase == 'before_delivery') {
          await pumpEventQueue();
          if (database.entered.isCompleted) database.release.complete(1);
        } else {
          await database.entered.future;
          if (phase == 'database_wait') await change();
          database.release.complete(1);
        }
        await pumpEventQueue();
        expect(database.updates, phase == 'before_delivery' ? 0 : 1);
        expect(notifier.calls, phase == 'current' ? 1 : 0);
        expect(events.length, phase == 'current' ? 1 : 0);
        if (phase == 'current') {
          expect(
            (events.single.data as List).single.id,
            'synthetic-status-event',
          );
          expect(
            (events.single.data as List).single.metadata['status'],
            IMBoyMessageStatus.seen,
          );
        } else {
          expect(database.queries, 0);
        }
      } finally {
        await subscription.cancel();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, null);
      }
    });
  }
}
