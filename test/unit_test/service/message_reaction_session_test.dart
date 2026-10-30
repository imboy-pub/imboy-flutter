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
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart';

class _ReactionDatabase implements Database {
  _ReactionDatabase(
    this.phase, {
    this.fromId = 200,
    this.toId = 100,
    this.type = 'C2C',
  });
  final String phase;
  final int fromId;
  final int toId;
  final String type;
  Map<String, dynamic> payload = {'text': 'synthetic'};
  final entered = Completer<void>();
  final release = Completer<void>();
  int updates = 0;
  int conversationUpdates = 0;
  bool paused = false;
  int transactions = 0;
  int status = IMBoyMessageStatus.delivered;
  @override
  bool get isOpen => true;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    transactions++;
    if (transactions == 1 && phase == 'concurrent_revoke') {
      status = IMBoyMessageStatus.peerRevoked;
    } else if (transactions == 1 && phase == 'concurrent_reaction') {
      payload = {
        'text': 'synthetic',
        'reactions': {
          '👍': ['300'],
        },
      };
    }
    return action(_ReactionTransaction(this));
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
    if (table == 'conversation' && phase == 'conversation') {
      entered.complete();
      await release.future;
      return [
        {
          'id': 1,
          'user_id': 100,
          'peer_id': '200',
          'type': 'C2C',
          'last_msg_id': 'synthetic-reaction',
          'msg_type': 'text',
        },
      ];
    }
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
        type: type,
        status: status,
        fromId: fromId,
        toId: toId,
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
    if (table == 'conversation') {
      conversationUpdates++;
      return 1;
    }
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

class _ReactionTransaction implements Transaction {
  _ReactionTransaction(this.db);
  final _ReactionDatabase db;

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
  }) => db.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => db.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PausedEditDatabase implements Database {
  _PausedEditDatabase(
    this.inner, {
    this.beforeTransaction,
    this.pauseWrite = true,
  });
  final Database inner;
  final Future<void> Function()? beforeTransaction;
  final bool pauseWrite;
  int transactions = 0;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  bool get isOpen => inner.isOpen;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    transactions++;
    if (transactions == 1) await beforeTransaction?.call();
    return inner.transaction(
      (txn) => action(
        pauseWrite ? _PausedEditTransaction(txn, entered, release) : txn,
      ),
      exclusive: exclusive,
    );
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
  }) {
    if (table == 'contact') {
      return Future.value([
        ContactModel(peerId: 200, nickname: 'Synthetic').toJson(),
      ]);
    }
    if (table == 'conversation') return Future.value([]);
    return inner.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PausedEditTransaction implements Transaction {
  _PausedEditTransaction(this.inner, this.entered, this.release);
  final Transaction inner;
  final Completer<void> entered;
  final Completer<void> release;

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
  }) => inner.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final rows = await inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    entered.complete();
    await release.future;
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final failConversation in [false, true]) {
    test('peer revoke commits atomically, conversation failure=$failConversation', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      ffi.sqfliteFfiInit();
      final inner = await ffi.databaseFactoryFfi.openDatabase(
        ffi.inMemoryDatabasePath,
      );
      final row = MessageModel(
        'synthetic-reaction',
        autoId: 1,
        type: 'C2C',
        status: IMBoyMessageStatus.delivered,
        fromId: 200,
        toId: 100,
        payload: {'text': 'synthetic'},
        isAuthor: 0,
        conversationUk3: 'synthetic-reaction',
        msgType: 'text',
      ).toJson();
      await inner.execute(
        'CREATE TABLE msg_c2c (${{...row.keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
      );
      await inner.execute('CREATE TABLE msg_c2g AS SELECT * FROM msg_c2c');
      await inner.execute('CREATE TABLE msg_c2s AS SELECT * FROM msg_c2c');
      await inner.execute(
        'CREATE TABLE conversation (id INTEGER, user_id TEXT, peer_id TEXT, '
        'avatar, title, subtitle, region, sign, last_time, last_msg_id, '
        'last_msg_status, unread_num, mention_unread, is_muted, payload, '
        'type, msg_type, is_show)',
      );
      await inner.insert('msg_c2c', row);
      await inner.insert('conversation', {
        'id': 1,
        'user_id': '100',
        'peer_id': '200',
        'type': 'C2C',
        'last_msg_id': 'synthetic-reaction',
        'last_msg_status': IMBoyMessageStatus.delivered,
        'payload': jsonEncode({'text': 'synthetic'}),
      });
      if (failConversation) {
        await inner.execute(
          "CREATE TRIGGER fail_conversation_update BEFORE UPDATE ON conversation "
          "BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
        );
      }
      SqliteService.setDbForTest(_PausedEditDatabase(inner, pauseWrite: false));
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      final sent = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(sent.add);
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageRevoke,
          {
            'id': 'synthetic-revoke',
            'type': 'C2C',
            'from': '200',
            'to': '100',
            'payload': {'original_msg_id': 'synthetic-reaction'},
          },
        );
        await pumpEventQueue();
        final stored = (await inner.query('msg_c2c')).single;
        expect(handled, !failConversation);
        expect(
          stored['status'],
          failConversation
              ? IMBoyMessageStatus.delivered
              : IMBoyMessageStatus.peerRevoked,
        );
        expect(jsonDecode(stored['payload']! as String)['text'], 'synthetic');
        final conversation = (await inner.query('conversation')).single;
        expect(
          conversation['last_msg_status'],
          failConversation
              ? IMBoyMessageStatus.delivered
              : IMBoyMessageStatus.peerRevoked,
        );
        expect(
          jsonDecode(conversation['payload']! as String)['text'],
          'synthetic',
        );
        expect(sent, hasLength(failConversation ? 0 : 1));
        if (!failConversation) {
          expect(sent.single.messageId, 'synthetic-revoke');
        }
      } finally {
        await subscription.cancel();
        SqliteService.setDbForTest(null);
        await inner.close();
      }
    });
  }

  for (final frame in [
    {'from': '999', 'to': '100'},
    {'from': '200', 'to': '999'},
  ]) {
    test('revoke request rejects mismatched parties $frame', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase('normal');
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      final sent = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(sent.add);
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageRevoke,
          {
            'id': 'synthetic-revoke',
            'type': 'C2C',
            ...frame,
            'payload': {'original_msg_id': 'synthetic-reaction'},
          },
        );
        await pumpEventQueue();
        expect(handled, isFalse);
        expect(db.updates, 0);
        expect(sent, isEmpty);
      } finally {
        await subscription.cancel();
        SqliteService.setDbForTest(null);
      }
    });
  }

  test('revoke request rejects session change during lookup', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final db = _ReactionDatabase('lookup');
    SqliteService.setDbForTest(db);
    final service = MessageService.instance;
    await pumpEventQueue();
    service.cancelAllSubscriptions();
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'write' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            throw PlatformException(code: 'synthetic-login-stop');
          }
          return null;
        });
    final sent = <WebSocketMessageSendRequestEvent>[];
    final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(sent.add);
    try {
      final pending = MessageActions.instance.handleActionMessage(
        C2SAction.messageRevoke,
        {
          'id': 'synthetic-revoke',
          'type': 'C2C',
          'from': '200',
          'to': '100',
          'payload': {'original_msg_id': 'synthetic-reaction'},
        },
      );
      await db.entered.future;
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      db.release.complete();
      expect(await pending, isFalse);
      await pumpEventQueue();
      expect(db.updates, 0);
      expect(db.conversationUpdates, 0);
      expect(sent, isEmpty);
    } finally {
      await subscription.cancel();
      SqliteService.setDbForTest(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
    }
  });

  test('revoke ACK rejects session change during lookup', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final db = _ReactionDatabase('lookup', fromId: 100, toId: 200);
    SqliteService.setDbForTest(db);
    final service = MessageService.instance;
    await pumpEventQueue();
    service.cancelAllSubscriptions();
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'write' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            throw PlatformException(code: 'synthetic-login-stop');
          }
          return null;
        });
    final removed = <RemoveFromRetryQueueRequestedEvent>[];
    final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
        .listen(removed.add);
    try {
      final pending = MessageActions.instance.handleActionMessage(
        C2SAction.messageRevokeAck,
        {
          'id': 'synthetic-revoke',
          'type': 'C2C',
          'from': '100',
          'to': '200',
          'payload': {'original_msg_id': 'synthetic-reaction'},
        },
      );
      await db.entered.future;
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      db.release.complete();
      expect(await pending, isFalse);
      await pumpEventQueue();
      expect(db.updates, 0);
      expect(removed, isEmpty);
    } finally {
      await subscription.cancel();
      SqliteService.setDbForTest(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
    }
  });

  for (final frame in [
    {'from': '999', 'to': '200'},
    {'from': '100', 'to': '999'},
  ]) {
    test('revoke ACK rejects mismatched parties $frame', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase('normal', fromId: 100, toId: 200);
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      final removed = <RemoveFromRetryQueueRequestedEvent>[];
      final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
          .listen(removed.add);
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageRevokeAck,
          {
            'id': 'synthetic-revoke',
            'type': 'C2C',
            ...frame,
            'payload': {'original_msg_id': 'synthetic-reaction'},
          },
        );
        await pumpEventQueue();
        expect(handled, isFalse);
        expect(db.updates, 0);
        expect(removed, isEmpty);
      } finally {
        await subscription.cancel();
        SqliteService.setDbForTest(null);
      }
    });
  }
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  tearDownAll(() async {
    MessageService.instance.dispose();
    await MessageRetry.instance.debugWaitForIdle();
    MessageRetry.instance.dispose();
  });
  for (final phase in ['concurrent_revoke', 'concurrent_reaction', 'peer']) {
    test(
      'edit ACK clears retry only after successful update: $phase',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        await StorageService.setMap(Keys.currentUser, {'uid': '100'});
        final db = phase == 'peer'
            ? _ReactionDatabase(phase)
            : _ReactionDatabase(phase, fromId: 100, toId: 200);
        SqliteService.setDbForTest(db);
        final service = MessageService.instance;
        await pumpEventQueue();
        service.cancelAllSubscriptions();
        final removed = <RemoveFromRetryQueueRequestedEvent>[];
        final subscription =
            AppEventBus.on<RemoveFromRetryQueueRequestedEvent>().listen(
              removed.add,
            );
        try {
          final handled = await MessageActions.instance.handleActionMessage(
            C2SAction.messageEditAck,
            {
              'id': 'synthetic-edit-ack',
              'type': 'C2C',
              'from': phase == 'peer' ? '200' : '100',
              'to': phase == 'peer' ? '100' : '200',
              'payload': {
                'original_msg_id': 'synthetic-reaction',
                'content': 'synthetic edited text',
              },
            },
          );
          await pumpEventQueue();
          expect(handled, phase != 'concurrent_revoke');
          expect(removed.length, phase == 'concurrent_reaction' ? 1 : 0);
          if (removed.isNotEmpty) {
            expect(removed.single.messageId, 'synthetic-edit-ack');
          }
        } finally {
          await subscription.cancel();
          SqliteService.setDbForTest(null);
        }
      },
    );
  }
  for (final frame in [
    {'from': '200', 'to': '100'},
    {'from': '100', 'to': '300'},
  ]) {
    test('own edit ACK rejects mismatched frame $frame', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase('none', fromId: 100, toId: 200);
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEditAck,
          {
            'id': 'synthetic-edit-ack',
            'type': 'C2C',
            ...frame,
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        expect(handled, isFalse);
        expect(db.updates, 0);
        expect(db.payload['text'], 'synthetic');
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  for (final frame in [
    {'from': '300', 'to': '100'},
    {'from': '200', 'to': '300'},
  ]) {
    test('edit ACK rejects mismatched peer frame $frame', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase('none');
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEditAck,
          {
            'id': 'synthetic-edit-ack',
            'type': 'C2C',
            ...frame,
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        expect(handled, isFalse);
        expect(db.updates, 0);
        expect(db.payload['text'], 'synthetic');
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  for (final frame in [
    {'from': '100', 'to': '500'},
    {'from': '200', 'to': '500'},
    {'from': '100', 'to': '501'},
  ]) {
    test('own group edit ACK checks author and group $frame', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      await StorageService.setMap(Keys.currentUser, {'uid': '100'});
      final db = _ReactionDatabase('none', fromId: 100, toId: 500, type: 'C2G');
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEditAck,
          {
            'id': 'synthetic-edit-ack',
            'type': 'C2G',
            ...frame,
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        final valid = frame['from'] == '100' && frame['to'] == '500';
        expect(handled, valid);
        expect(db.updates, valid ? 1 : 0);
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  for (final frame in [
    {'from': '200', 'to': '500'},
    {'from': '300', 'to': '500'},
    {'from': '200', 'to': '501'},
  ]) {
    test('group edit ACK checks author and group $frame', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase('none', toId: 500, type: 'C2G');
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEditAck,
          {
            'id': 'synthetic-edit-ack',
            'type': 'C2G',
            ...frame,
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        final valid = frame['from'] == '200' && frame['to'] == '500';
        expect(handled, valid);
        expect(db.updates, valid ? 1 : 0);
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  for (final scenario in [
    ('C2C', 100, '200', '100', true),
    ('C2C', 100, '200', '300', false),
    ('C2C', 300, '200', '300', false),
    ('C2C', 100, '300', '100', false),
    ('C2G', 500, '200', '500', true),
    ('C2G', 500, '200', '501', false),
    ('C2G', 500, '300', '500', false),
  ]) {
    test('edit request checks author and target $scenario', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final (type, originalTo, from, to, valid) = scenario;
      final db = _ReactionDatabase('none', toId: originalTo, type: type);
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEdit,
          {
            'id': 'synthetic-edit',
            'type': type,
            'from': from,
            'to': to,
            'e2ee': {'edit_of': 'synthetic-reaction'},
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        expect(handled, valid);
        expect(db.updates, valid ? 1 : 0);
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  for (final target in ['synthetic-reaction', 'other-message', '']) {
    test('encrypted edit routing target=$target', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase('none');
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEdit,
          {
            'id': 'synthetic-edit',
            'type': 'C2C',
            'from': '200',
            'to': '100',
            'e2ee': {'edit_of': target},
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        expect(handled, target == 'synthetic-reaction');
        expect(db.updates, target == 'synthetic-reaction' ? 1 : 0);
        if (target == 'synthetic-reaction') {
          expect(db.payload['text'], 'synthetic edited text');
        }
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  test('encrypted edit from another author is rejected', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final db = _ReactionDatabase('none');
    SqliteService.setDbForTest(db);
    final service = MessageService.instance;
    await pumpEventQueue();
    service.cancelAllSubscriptions();
    try {
      final handled = await MessageActions.instance.handleActionMessage(
        C2SAction.messageEdit,
        {
          'id': 'synthetic-edit',
          'type': 'C2C',
          'from': '300',
          'to': '100',
          'e2ee': {'edit_of': 'synthetic-reaction'},
          'payload': {
            'original_msg_id': 'synthetic-reaction',
            'content': 'synthetic edited text',
          },
        },
      );
      expect(handled, isFalse);
      expect(db.updates, 0);
      expect(db.payload['text'], 'synthetic');
    } finally {
      SqliteService.setDbForTest(null);
    }
  });
  for (final phase in ['concurrent_revoke', 'concurrent_reaction']) {
    test('edit preserves $phase', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final db = _ReactionDatabase(phase);
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEdit,
          {
            'id': 'synthetic-edit',
            'type': 'C2C',
            'from': '200',
            'to': '100',
            'e2ee': {'edit_of': 'synthetic-reaction'},
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        expect(handled, phase == 'concurrent_reaction');
        expect(db.updates, phase == 'concurrent_reaction' ? 1 : 0);
        if (phase == 'concurrent_reaction') {
          expect(db.payload['text'], 'synthetic edited text');
          expect(db.payload['reactions'], {
            '👍': ['300'],
          });
          expect(db.status, IMBoyMessageStatus.delivered);
        } else {
          expect(db.payload['text'], 'synthetic');
          expect(db.status, IMBoyMessageStatus.peerRevoked);
        }
      } finally {
        SqliteService.setDbForTest(null);
      }
    });
  }
  for (final change in [
    'reaction',
    'revoke',
    'author',
    'recipient',
    'newer',
    'conversation_failure',
  ]) {
    test('SQLite edit handles concurrent $change', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      ffi.sqfliteFfiInit();
      final inner = await ffi.databaseFactoryFfi.openDatabase(
        ffi.inMemoryDatabasePath,
      );
      final row = MessageModel(
        'synthetic-reaction',
        autoId: 1,
        type: 'C2C',
        status: IMBoyMessageStatus.delivered,
        fromId: 200,
        toId: 100,
        payload: {'text': 'synthetic'},
        isAuthor: 0,
        conversationUk3: 'synthetic-reaction',
        msgType: 'text',
      ).toJson();
      await inner.execute(
        'CREATE TABLE msg_c2c (${{...row.keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
      );
      await inner.execute(
        'CREATE TABLE conversation (id INTEGER, user_id TEXT, peer_id TEXT, '
        'avatar, title, subtitle, region, sign, last_time, last_msg_id, '
        'last_msg_status, unread_num, mention_unread, is_muted, payload, '
        'type, msg_type, is_show)',
      );
      await inner.insert('msg_c2c', row);
      if (change == 'newer' || change == 'conversation_failure') {
        await inner.insert('conversation', {
          'id': 1,
          'user_id': '100',
          'peer_id': '200',
          'type': 'C2C',
          'last_msg_id': 'synthetic-reaction',
          'subtitle': 'original',
          'msg_type': 'text',
        });
      }
      if (change == 'conversation_failure') {
        await inner.execute(
          "CREATE TRIGGER fail_edit_conversation BEFORE UPDATE ON conversation "
          "BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
        );
      }
      final db = _PausedEditDatabase(
        inner,
        pauseWrite: false,
        beforeTransaction: () async {
          if (change == 'newer') {
            await inner.update('conversation', {
              'last_msg_id': 'new-message',
              'subtitle': 'new message',
            });
          }
          await inner.update('msg_c2c', {
            if (change == 'revoke') 'status': IMBoyMessageStatus.peerRevoked,
            if (change == 'author') 'from_id': 300,
            if (change == 'recipient') 'to_id': 300,
            'payload': jsonEncode({
              'text': 'synthetic',
              if (change == 'reaction')
                'reactions': {
                  '👍': ['300'],
                },
            }),
          });
        },
      );
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageEdit,
          {
            'id': 'synthetic-edit',
            'type': 'C2C',
            'from': '200',
            'to': '100',
            'e2ee': {'edit_of': 'synthetic-reaction'},
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        expect(handled, change == 'reaction' || change == 'newer');
        final stored = (await inner.query('msg_c2c')).single;
        final payload = jsonDecode(stored['payload']! as String);
        expect(
          stored['status'],
          change == 'revoke'
              ? IMBoyMessageStatus.peerRevoked
              : IMBoyMessageStatus.delivered,
        );
        expect(
          payload['text'],
          change == 'reaction' || change == 'newer'
              ? 'synthetic edited text'
              : 'synthetic',
        );
        if (change == 'newer') {
          final conversation = (await inner.query('conversation')).single;
          expect(conversation['last_msg_id'], 'new-message');
          expect(conversation['subtitle'], 'new message');
        }
        if (change == 'conversation_failure') {
          final conversation = (await inner.query('conversation')).single;
          expect(conversation['last_msg_id'], 'synthetic-reaction');
          expect(conversation['subtitle'], 'original');
        }
        if (change == 'reaction') {
          expect(payload['reactions'], {
            '👍': ['300'],
          });
        }
      } finally {
        SqliteService.setDbForTest(null);
        await inner.close();
      }
    });
  }
  for (final field in ['from_id', 'to_id']) {
    test('revoke ACK rejects concurrent $field change in SQLite', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      ffi.sqfliteFfiInit();
      final inner = await ffi.databaseFactoryFfi.openDatabase(
        ffi.inMemoryDatabasePath,
      );
      final row = MessageModel(
        'synthetic-reaction',
        autoId: 1,
        type: 'C2C',
        status: IMBoyMessageStatus.delivered,
        fromId: 100,
        toId: 200,
        payload: {'text': 'synthetic'},
        isAuthor: 1,
        conversationUk3: 'synthetic-reaction',
        msgType: 'text',
      ).toJson();
      await inner.execute(
        'CREATE TABLE msg_c2c (${{...row.keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
      );
      await inner.insert('msg_c2c', row);
      final db = _PausedEditDatabase(
        inner,
        pauseWrite: false,
        beforeTransaction: () async => inner.update('msg_c2c', {field: 999}),
      );
      SqliteService.setDbForTest(db);
      final service = MessageService.instance;
      await pumpEventQueue();
      service.cancelAllSubscriptions();
      try {
        final handled = await MessageActions.instance.handleActionMessage(
          C2SAction.messageRevokeAck,
          {
            'id': 'synthetic-revoke',
            'type': 'C2C',
            'from': '100',
            'to': '200',
            'payload': {'original_msg_id': 'synthetic-reaction'},
          },
        );
        expect(handled, isFalse);
        final stored = (await inner.query('msg_c2c')).single;
        expect(stored[field], 999);
        expect(stored['status'], IMBoyMessageStatus.delivered);
        expect(jsonDecode(stored['payload']! as String)['text'], 'synthetic');
      } finally {
        SqliteService.setDbForTest(null);
        await inner.close();
      }
    });
  }
  test('revoke ACK session change during write rolls back SQLite', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    ffi.sqfliteFfiInit();
    final inner = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    final row = MessageModel(
      'synthetic-reaction',
      autoId: 1,
      type: 'C2C',
      status: IMBoyMessageStatus.delivered,
      fromId: 100,
      toId: 200,
      payload: {'text': 'synthetic'},
      isAuthor: 1,
      conversationUk3: 'synthetic-reaction',
      msgType: 'text',
    ).toJson();
    await inner.execute(
      'CREATE TABLE msg_c2c (${{...row.keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
    );
    await inner.insert('msg_c2c', row);
    final db = _PausedEditDatabase(inner);
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
    final removed = <RemoveFromRetryQueueRequestedEvent>[];
    final subscription = AppEventBus.on<RemoveFromRetryQueueRequestedEvent>()
        .listen(removed.add);
    try {
      final pending = MessageActions.instance.handleActionMessage(
        C2SAction.messageRevokeAck,
        {
          'id': 'synthetic-revoke',
          'type': 'C2C',
          'from': '100',
          'to': '200',
          'payload': {'original_msg_id': 'synthetic-reaction'},
        },
      );
      await db.entered.future;
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      db.release.complete();
      expect(await pending, isFalse);
      await pumpEventQueue();
      final stored = (await inner.query('msg_c2c')).single;
      expect(stored['status'], IMBoyMessageStatus.delivered);
      expect(jsonDecode(stored['payload']! as String)['text'], 'synthetic');
      expect(removed, isEmpty);
    } finally {
      await subscription.cancel();
      SqliteService.setDbForTest(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
      await inner.close();
    }
  });
  test('edit session change during write rolls back SQLite', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    ffi.sqfliteFfiInit();
    final inner = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    final row = MessageModel(
      'synthetic-reaction',
      autoId: 1,
      type: 'C2C',
      status: IMBoyMessageStatus.delivered,
      fromId: 200,
      toId: 100,
      payload: {'text': 'synthetic'},
      isAuthor: 0,
      conversationUk3: 'synthetic-reaction',
      msgType: 'text',
    ).toJson();
    await inner.execute(
      'CREATE TABLE msg_c2c (${{...row.keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
    );
    await inner.insert('msg_c2c', row);
    final db = _PausedEditDatabase(inner);
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
    try {
      final pending = MessageActions.instance.handleActionMessage(
        C2SAction.messageEdit,
        {
          'id': 'synthetic-edit',
          'type': 'C2C',
          'from': '200',
          'to': '100',
          'e2ee': {'edit_of': 'synthetic-reaction'},
          'payload': {
            'original_msg_id': 'synthetic-reaction',
            'content': 'synthetic edited text',
          },
        },
      );
      await db.entered.future;
      await expectLater(
        UserRepoLocal.to.loginAfter('synthetic-session', {
          'uid': '101',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        }),
        throwsA(isA<PlatformException>()),
      );
      db.release.complete();
      expect(await pending, isFalse);
      final stored = (await inner.query('msg_c2c')).single;
      expect(jsonDecode(stored['payload']! as String)['text'], 'synthetic');
    } finally {
      SqliteService.setDbForTest(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
      await inner.close();
    }
  });
  for (final phase in ['lookup', 'update', 'conversation']) {
    test('edit $phase session changed', () async {
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
          C2SAction.messageEdit,
          {
            'id': 'synthetic-edit',
            'type': 'C2C',
            'from': '200',
            'to': '100',
            'e2ee': {'edit_of': 'synthetic-reaction'},
            'payload': {
              'original_msg_id': 'synthetic-reaction',
              'content': 'synthetic edited text',
            },
          },
        );
        await db.entered.future;
        await expectLater(
          UserRepoLocal.to.loginAfter('synthetic-session', {
            'uid': '101',
            'token': 'synthetic-token',
            'refreshtoken': 'synthetic-refresh',
          }),
          throwsA(isA<PlatformException>()),
        );
        db.release.complete();
        expect(await pending, isFalse);
        await pumpEventQueue();
        expect(db.updates, phase == 'lookup' ? 0 : 1);
        expect(db.conversationUpdates, 0);
        expect(events.where((e) => e.dataType == 'List<Message>').length, 0);
      } finally {
        await subscription.cancel();
        SqliteService.setDbForTest(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, null);
      }
    });
  }
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
