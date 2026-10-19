import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

ConversationModel _row({int peerId = 200}) => ConversationModel(
  id: 1,
  peerId: peerId,
  avatar: '',
  title: 'Synthetic',
  subtitle: 'Synthetic',
  type: 'C2C',
  msgType: 'text',
  unreadNum: 0,
  lastMsgId: 'cb8b2hc0p9qkx2n8m300',
  lastMsgStatus: IMBoyMessageStatus.seen,
);

class _Database implements Database {
  final entered = Completer<void>();
  final release = Completer<int>();
  int queries = 0;
  List<Object?>? updateArgs;
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
    updateArgs = whereArgs;
    entered.complete();
    return release.future;
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
    queries++;
    return [_row().toJson()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  for (final phase in ['database', 'batch_timer', 'batch_mixed']) {
    for (final stale in [false, true]) {
      if (phase == 'batch_mixed' && !stale) continue;
      test('conversation status phase=$phase changed=$stale', () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        final database = _Database();
        SqliteService.setDbForTest(database);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, (call) async {
              if (call.method == 'write' &&
                  (call.arguments as Map)['key'] == 'secure_token') {
                throw PlatformException(code: 'synthetic-login-stop');
              }
              return null;
            });
        final container = ProviderContainer();
        final listener = container.listen(conversationProvider, (_, _) {});
        final notifier = container.read(conversationProvider.notifier);
        final events = <DataWrapperEvent<dynamic>>[];
        final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
          events.add,
        );
        try {
          Future<void>? pending;
          if (phase == 'database') {
            pending = notifier.updateConversationByMsgId('300', {
              ConversationRepo.lastMsgStatus: IMBoyMessageStatus.seen,
            });
            await database.entered.future;
          } else {
            notifier.replaceConversation(_row());
          }
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
          if (phase == 'batch_mixed') {
            notifier.replaceConversation(_row(peerId: 201));
          }
          if (phase == 'database') {
            database.release.complete(1);
            await pending;
            expect(database.updateArgs, ['100', '300']);
            expect(database.queries, stale ? 0 : 1);
          }
          // Real 100ms production batching timer; no simulated device clock.
          await Future<void>.delayed(const Duration(milliseconds: 150));
          final rows = container
              .read(conversationProvider)
              .conversationMap
              .values;
          expect(rows.length, stale && phase != 'batch_mixed' ? 0 : 1);
          if (rows.isNotEmpty) {
            expect(rows.single.lastMsgStatus, IMBoyMessageStatus.seen);
          }
          if (phase == 'batch_mixed') {
            expect(rows.single.peerId, 201);
          }
          expect(events.length, phase == 'database' && !stale ? 1 : 0);
        } finally {
          await subscription.cancel();
          listener.close();
          container.dispose();
          SqliteService.setDbForTest(null);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureChannel, null);
        }
      });
    }
  }
}
