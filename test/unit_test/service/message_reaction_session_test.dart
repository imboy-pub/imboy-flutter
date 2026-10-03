import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _ReactionDatabase implements Database {
  _ReactionDatabase(this.phase);
  final String phase;
  Map<String, dynamic> payload = {'text': 'synthetic'};
  final entered = Completer<void>();
  final release = Completer<void>();
  int updates = 0;
  bool paused = false;
  @override
  bool get isOpen => true;
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
    if (table == 'contact') {
      return [ContactModel(peerId: 200, nickname: 'Synthetic').toJson()];
    }
    if (!table.startsWith('msg_')) return [];
    if (phase == 'lookup' && !paused) {
      paused = true;
      entered.complete();
      await release.future;
    }
    return [
      MessageModel(
        'synthetic-reaction',
        autoId: 1,
        type: 'C2C',
        status: IMBoyMessageStatus.delivered,
        fromId: 200,
        toId: 100,
        payload: payload,
        isAuthor: 0,
        conversationUk3: 'synthetic-reaction',
        msgType: 'text',
      ).toJson(),
    ];
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
    if (phase == 'update') {
      entered.complete();
      await release.future;
    }
    payload = jsonDecode(values['payload']! as String) as Map<String, dynamic>;
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => [];
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  tearDownAll(() async {
    MessageService.instance.dispose();
    await MessageRetry.instance.debugWaitForIdle();
    MessageRetry.instance.dispose();
  });
  for (final phase in ['lookup', 'update']) {
    for (final stale in [false, true]) {
      test('reaction $phase session changed=$stale', () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        final db = _ReactionDatabase(phase);
        SqliteService.setDbForTest(db);
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
          final pending = MessageActions.instance.handleActionMessage(
            C2SAction.messageReaction,
            {
              'id': 'synthetic-action',
              'type': 'C2C',
              'from': '200',
              'to': '100',
              'payload': {
                'original_msg_id': 'synthetic-reaction',
                'emoji': '👍',
                'op': 'add',
                'user_id': '200',
              },
            },
          );
          await db.entered.future;
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
          db.release.complete();
          expect(await pending, !stale);
          await pumpEventQueue();
          expect(db.updates, stale && phase == 'lookup' ? 0 : 1);
          if (!stale) {
            expect(db.payload['reactions'], {
              '👍': ['200'],
            });
          }
          expect(
            events.where((e) => e.dataType == 'List<Message>').length,
            stale ? 0 : 1,
          );
        } finally {
          await subscription.cancel();
          SqliteService.setDbForTest(null);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureChannel, null);
        }
      });
    }
  }
}
