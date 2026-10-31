import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// Pause only the delivery of a completed list query: SQLite has already
/// materialized its snapshot and released the read, so inbound writes can run.
class _PausedConversationListDatabase implements Database {
  _PausedConversationListDatabase(this.inner);

  final Database inner;
  final captured = Completer<List<Map<String, Object?>>>();
  final release = Completer<void>();
  bool pauseNextList = false;
  bool pauseSecondList = false;
  final secondCaptured = Completer<List<Map<String, Object?>>>();
  final releaseSecond = Completer<void>();
  bool pauseNextRecount = false;
  final recountCaptured = Completer<ConversationModel>();
  final releaseRecount = Completer<void>();

  @override
  bool get isOpen => inner.isOpen;

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
    final rows = await inner.query(
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
    if (table == ConversationRepo.tableName &&
        where?.contains('is_show = ?') == true &&
        limit == 200) {
      if (pauseNextList) {
        pauseNextList = false;
        captured.complete(rows);
        await release.future;
      } else if (pauseSecondList) {
        pauseSecondList = false;
        secondCaptured.complete(rows);
        await releaseSecond.future;
      }
    }
    return rows;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) async {
    final result = await inner.transaction(action, exclusive: exclusive);
    if (pauseNextRecount && result is ConversationModel) {
      pauseNextRecount = false;
      recountCaptured.complete(result);
      // Release SQLite's transaction before pausing its snapshot delivery.
      await releaseRecount.future;
    }
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      inner.rawUpdate(sql, arguments);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      inner.execute(sql, arguments);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _currentUid = '995011';
const _peerUid = '995012';
const _uk3 = 'C2C_995011_995012';
const _messageId = 'j16-first-message';

Map<String, dynamic> _inboundMessage() => {
  'id': _messageId,
  'type': 'C2C',
  'from': _peerUid,
  'to': _currentUid,
  'msg_type': 'text',
  'payload': <String, dynamic>{'text': 'first inbound message'},
  'created_at': 1750000000000,
};

Future<void> _expectVisiblePersistence(Database db) async {
  final conversations = await db.query('conversation');
  expect(conversations, hasLength(1));
  final row = conversations.single;
  expect(row['is_show'], 1);
  expect(row['is_muted'], 1);
  expect(row['last_msg_id'], _messageId);
  expect(row['last_time'], 1750000000000);
  expect(row['unread_num'], 1);
  final messages = await db.query('msg_c2c');
  expect(messages, hasLength(1));
  expect(messages.single['id'], _messageId);
  final visible = await ConversationRepo().list();
  expect(visible, hasLength(1));
  expect(visible.single.uk3, _uk3);
  expect(visible.single.isMuted, 1);
}

void _expectProviderRow(ProviderContainer container) {
  final state = container.read(conversationProvider);
  expect(state.conversations, hasLength(1));
  expect(state.conversations.single.uk3, _uk3);
  expect(state.conversations.single.lastMsgId, _messageId);
  expect(state.conversations.single.isMuted, 1);
  expect(state.conversationRemind[_uk3], 1);
  expect(state.chatMsgRemindCounter, 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late _PausedConversationListDatabase pausedDb;
  late ProviderContainer container;
  late MessageRepo offlineRepo;
  late Future<void> rowPublished;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: _currentUid});
    await StorageService.init();
    db = await openFixtureDatabaseAtVersion(version: 32);
    pausedDb = _PausedConversationListDatabase(db);
    SqliteService.setDbForTest(pausedDb);
    await db.insert('contact', {
      'user_id': int.parse(_currentUid),
      'peer_id': int.parse(_peerUid),
      'nickname': 'First message peer',
    });
    container = ProviderContainer();
    final published = Completer<void>();
    final subscription = container.listen(conversationProvider, (_, state) {
      if (state.conversationMap[_uk3]?.lastMsgId == _messageId &&
          !published.isCompleted) {
        published.complete();
      }
    });
    addTearDown(subscription.close);
    rowPublished = published.future;
    MessageService.setProviderContainer(container);
    offlineRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    MessageRepo.setCurrentActiveConversationUk3(null);
    await ConversationRepo().setMutedForPeer('C2C', _peerUid, true);
    final placeholder = (await db.query('conversation')).single;
    expect(placeholder['is_muted'], 1);
    expect(placeholder['is_show'], 0);
    expect(placeholder['last_time'], 0);
    expect(placeholder['last_msg_id'], '');
    expect(await db.query('msg_c2c'), isEmpty);
    expect(await ConversationRepo().list(), isEmpty);
  });

  tearDown(() async {
    if (!pausedDb.release.isCompleted) pausedDb.release.complete();
    if (!pausedDb.releaseSecond.isCompleted) pausedDb.releaseSecond.complete();
    if (!pausedDb.releaseRecount.isCompleted) {
      pausedDb.releaseRecount.complete();
    }
    await offlineRepo.waitForFtsReindexForTest();
    container.dispose();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  tearDownAll(() => MessageService.to.dispose());

  test('J16.a online first message restores muted hidden placeholder', () async {
    expect(
      await MessageService.to.persistInboundMessage(_inboundMessage()),
      isTrue,
    );
    // Completes only after the production 100ms batching timer publishes a row.
    await rowPublished.timeout(const Duration(seconds: 5));
    await _expectVisiblePersistence(db);
    _expectProviderRow(container);
  });

  test(
    'J16.a offline first message restores muted hidden placeholder',
    () async {
      final wire = _inboundMessage()..remove('id');
      wire['msg_id'] = _messageId;
      expect(await offlineRepo.batchInsertOfflineMessages([wire]), [
        _messageId,
      ]);
      await rowPublished.timeout(const Duration(seconds: 5));
      await _expectVisiblePersistence(db);
      _expectProviderRow(container);
    },
  );

  test(
    'removed conversation is not restored by a delayed visible list',
    () async {
      expect(
        await MessageService.to.persistInboundMessage(_inboundMessage()),
        isTrue,
      );
      await rowPublished.timeout(const Duration(seconds: 5));
      _expectProviderRow(container);
      final notifier = container.read(conversationProvider.notifier);
      pausedDb.pauseNextList = true;
      final oldList = notifier.conversationsList();
      try {
        final captured = await pausedDb.captured.future.timeout(
          const Duration(seconds: 5),
        );
        expect(captured, hasLength(1));
        expect(captured.single['is_show'], 1);
        expect(
          await ConversationRepo().hideForAccount(
            account: _currentUid,
            kind: 'C2C',
            peer: _peerUid,
          ),
          isTrue,
        );
        notifier.removeConversationFromMap(_uk3);
        expect(container.read(conversationProvider).conversationMap, isEmpty);

        pausedDb.release.complete();
        expect(await oldList, isEmpty);
        final state = container.read(conversationProvider);
        expect(state.conversationMap, isEmpty);
        expect(state.conversationRemind, isNot(contains(_uk3)));
        expect(state.isLoading, isFalse);
      } finally {
        if (!pausedDb.release.isCompleted) pausedDb.release.complete();
        await oldList;
      }
    },
  );

  test('remove cancels a queued replacement before the 100ms batch', () async {
    expect(
      await MessageService.to.persistInboundMessage(_inboundMessage()),
      isTrue,
    );
    await rowPublished.timeout(const Duration(seconds: 5));
    _expectProviderRow(container);
    final notifier = container.read(conversationProvider.notifier);
    final conversation = container
        .read(conversationProvider)
        .conversationMap[_uk3]!;
    notifier.replaceConversation(conversation);
    notifier.removeConversationFromMap(_uk3);
    expect(container.read(conversationProvider).conversationMap, isEmpty);

    // Observe beyond the real production batching timer, not just removal.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final state = container.read(conversationProvider);
    expect(state.conversationMap, isEmpty);
    expect(state.conversationRemind, isNot(contains(_uk3)));
  });

  test('older list cannot overwrite a newer completed list', () async {
    expect(
      await MessageService.to.persistInboundMessage(_inboundMessage()),
      isTrue,
    );
    await rowPublished.timeout(const Duration(seconds: 5));
    _expectProviderRow(container);
    final notifier = container.read(conversationProvider.notifier);
    pausedDb.pauseNextList = true;
    final oldList = notifier.conversationsList();
    try {
      expect(
        await pausedDb.captured.future.timeout(const Duration(seconds: 5)),
        hasLength(1),
      );
      // Change SQLite only: no provider mutation/revision can mask the
      // independent list-request generation guard under test.
      expect(
        await db.update(
          'conversation',
          {'is_show': 0},
          where: 'user_id = ? AND type = ? AND peer_id = ?',
          whereArgs: [_currentUid, 'C2C', _peerUid],
        ),
        1,
      );
      expect(await notifier.conversationsList(), isEmpty);
      expect(container.read(conversationProvider).conversationMap, isEmpty);

      pausedDb.release.complete();
      expect(await oldList, hasLength(1));
      final state = container.read(conversationProvider);
      expect(state.conversationMap, isEmpty);
      expect(state.isLoading, isFalse);
    } finally {
      if (!pausedDb.release.isCompleted) pausedDb.release.complete();
      await oldList;
    }
  });

  test(
    'inbound during historical list load preserves unrelated rows',
    () async {
      final original = (await db.query('conversation')).single;
      await db.update('conversation', {'is_show': 1, 'title': 'History A'});
      await db.insert('conversation', {
        ...original,
        'id': (original['id'] as int) + 1,
        'peer_id': 995013,
        'title': 'History B',
        'is_show': 1,
      });
      final notifier = container.read(conversationProvider.notifier);
      expect(container.read(conversationProvider).conversationMap, isEmpty);
      pausedDb.pauseNextList = true;
      final oldList = notifier.conversationsList();
      try {
        expect(
          await pausedDb.captured.future.timeout(const Duration(seconds: 5)),
          hasLength(2),
        );
        expect(
          await MessageService.to.persistInboundMessage(_inboundMessage()),
          isTrue,
        );
        await rowPublished.timeout(const Duration(seconds: 5));
        pausedDb.release.complete();
        expect(await oldList, hasLength(2));
        final state = container.read(conversationProvider);
        expect(
          state.conversationMap.keys,
          containsAll([_uk3, 'C2C_995011_995013']),
        );
        expect(state.conversationMap, hasLength(2));
        expect(state.conversationMap[_uk3]?.lastMsgId, _messageId);
        expect(state.conversationRemind[_uk3], 1);
        expect(await ConversationRepo().list(), hasLength(2));
      } finally {
        if (!pausedDb.release.isCompleted) pausedDb.release.complete();
        await oldList;
      }
    },
  );

  test(
    'two conflicting list rounds preserve B and the latest A message',
    () async {
      final original = (await db.query('conversation')).single;
      await db.update('conversation', {'is_show': 1, 'title': 'History A'});
      await db.insert('conversation', {
        ...original,
        'id': (original['id'] as int) + 1,
        'peer_id': 995013,
        'title': 'History B',
        'is_show': 1,
      });
      const secondMessageId = 'j16-second-message';
      const secondMessageTime = 1750000001000;
      final latestPublished = Completer<void>();
      final subscription = container.listen(conversationProvider, (_, state) {
        if (state.conversationMap[_uk3]?.lastMsgId == secondMessageId &&
            !latestPublished.isCompleted) {
          latestPublished.complete();
        }
      });
      addTearDown(subscription.close);
      pausedDb.pauseNextList = true;
      pausedDb.pauseSecondList = true;
      final pending = container
          .read(conversationProvider.notifier)
          .conversationsList();
      try {
        final firstSnapshot = await pausedDb.captured.future.timeout(
          const Duration(seconds: 5),
        );
        expect(firstSnapshot, hasLength(2));
        expect(firstSnapshot.every((row) => row['last_msg_id'] == ''), isTrue);
        expect(
          await MessageService.to.persistInboundMessage(_inboundMessage()),
          isTrue,
        );
        await rowPublished.timeout(const Duration(seconds: 5));
        pausedDb.release.complete();

        final secondSnapshot = await pausedDb.secondCaptured.future.timeout(
          const Duration(seconds: 5),
        );
        expect(secondSnapshot, hasLength(2));
        expect(
          secondSnapshot.singleWhere(
            (row) => row['peer_id'].toString() == _peerUid,
          )['last_msg_id'],
          _messageId,
        );
        final secondMessage = _inboundMessage()
          ..['id'] = secondMessageId
          ..['created_at'] = secondMessageTime
          ..['payload'] = <String, dynamic>{'text': 'second inbound message'};
        expect(
          await MessageService.to.persistInboundMessage(secondMessage),
          isTrue,
        );
        await latestPublished.future.timeout(const Duration(seconds: 5));
        pausedDb.releaseSecond.complete();
        await pending;

        final state = container.read(conversationProvider);
        expect(state.conversationMap, hasLength(2));
        expect(
          state.conversationMap.keys,
          containsAll([_uk3, 'C2C_995011_995013']),
        );
        expect(state.conversationMap[_uk3]?.lastMsgId, secondMessageId);
        expect(state.conversationMap[_uk3]?.lastTime, secondMessageTime);
        expect(state.conversationRemind[_uk3], 2);
        final persisted = await ConversationRepo().list();
        expect(persisted, hasLength(2));
        expect(
          persisted.singleWhere((row) => row.uk3 == _uk3).lastMsgId,
          secondMessageId,
        );
        expect(persisted.singleWhere((row) => row.uk3 == _uk3).unreadNum, 2);
      } finally {
        if (!pausedDb.release.isCompleted) pausedDb.release.complete();
        if (!pausedDb.releaseSecond.isCompleted) {
          pausedDb.releaseSecond.complete();
        }
        await pending;
      }
    },
  );

  for (final duringList in [true, false]) {
    test(
      'hide during ${duringList ? 'list' : 'direct'} recount stays hidden',
      () async {
        expect(
          await MessageService.to.persistInboundMessage(_inboundMessage()),
          isTrue,
        );
        await rowPublished.timeout(const Duration(seconds: 5));
        final notifier = container.read(conversationProvider.notifier);
        final conversation = container
            .read(conversationProvider)
            .conversationMap[_uk3]!;
        pausedDb.pauseNextRecount = true;
        final Future<dynamic> pending = duringList
            ? notifier.conversationsList()
            : notifier.recalculateConversationRemind(conversation);
        try {
          final captured = await pausedDb.recountCaptured.future.timeout(
            const Duration(seconds: 5),
          );
          expect(captured.isShow, 1);
          expect(captured.unreadNum, 1);
          expect(
            await ConversationRepo().hideForAccount(
              account: _currentUid,
              kind: 'C2C',
              peer: _peerUid,
            ),
            isTrue,
          );
          notifier.removeConversationFromMap(_uk3);
          pausedDb.releaseRecount.complete();
          await pending;
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(container.read(conversationProvider).conversationMap, isEmpty);
          expect(
            container.read(conversationProvider).conversationRemind,
            isNot(contains(_uk3)),
          );
          expect(await ConversationRepo().list(), isEmpty);

          // Even a fresh recount of the persisted hidden row cannot publish it.
          await notifier.recalculateConversationRemind(conversation);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(container.read(conversationProvider).conversationMap, isEmpty);
          expect(
            container.read(conversationProvider).conversationRemind,
            isNot(contains(_uk3)),
          );
        } finally {
          if (!pausedDb.releaseRecount.isCompleted) {
            pausedDb.releaseRecount.complete();
          }
          await pending;
        }
      },
    );
  }

  test('J16.a delayed empty list must not erase committed first message', () async {
    final notifier = container.read(conversationProvider.notifier);
    pausedDb.pauseNextList = true;
    final oldList = notifier.conversationsList();
    try {
      // This is the real repo.list SELECT result, captured before inbound.
      expect(
        await pausedDb.captured.future.timeout(const Duration(seconds: 5)),
        isEmpty,
      );
      expect(
        await MessageService.to.persistInboundMessage(_inboundMessage()),
        isTrue,
      );
      await rowPublished.timeout(const Duration(seconds: 5));
      await _expectVisiblePersistence(db);
      _expectProviderRow(container);

      // Release only after the new row is visibly published: no sleep-based
      // race and no manual call that bypasses production snapshot publication.
      pausedDb.release.complete();
      expect(await oldList, hasLength(1));
      await _expectVisiblePersistence(db);
      _expectProviderRow(container);
    } finally {
      if (!pausedDb.release.isCompleted) pausedDb.release.complete();
      await oldList;
    }
  });
}
