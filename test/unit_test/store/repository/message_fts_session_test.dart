import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';

class _FtsDatabase implements Database {
  _FtsDatabase(this.phase);
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
  final statements = <String>[];
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    statements.add(sql);
    if ((phase == 'delete' || phase == 'retry') &&
        statements.length == 1 &&
        sql.startsWith('DELETE')) {
      entered.complete();
      await release.future;
      if (phase == 'retry') throw StateError('database is locked');
    }
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  for (final type in ['C2C', 'C2G']) {
    for (final phase in ['lookup', 'delete', 'retry']) {
      for (final stale in [false, true]) {
        test('FTS $type $phase session changed=$stale', () async {
          SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
          await StorageService.init();
          final db = _FtsDatabase(phase);
          SqliteService.setDbForTest(db);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'write' &&
                    (call.arguments as Map)['key'] == 'secure_token') {
                  throw PlatformException(code: 'synthetic-login-stop');
                }
                return null;
              });
          try {
            final repo = MessageRepo(
              tableName: type == 'C2C'
                  ? MessageRepo.c2cTable
                  : MessageRepo.c2gTable,
            );
            final pending = phase == 'lookup'
                ? repo.update({
                    'id': 'synthetic-reaction',
                    'payload': {'text': 'new'},
                  })
                : MessageFtsRepo().indexMessage(
                    type: type,
                    id: 'synthetic-reaction',
                    conversationUk3: 'synthetic',
                    textContent: 'new',
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
            await pending;
            await repo.waitForFtsReindexForTest();
            expect(
              db.statements.length,
              stale ? (phase == 'lookup' ? 0 : 1) : (phase == 'retry' ? 3 : 2),
            );
            if (!stale) expect(db.statements.last, startsWith('INSERT'));
          } finally {
            SqliteService.setDbForTest(null);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null);
          }
        });
      }
    }
  }
}
