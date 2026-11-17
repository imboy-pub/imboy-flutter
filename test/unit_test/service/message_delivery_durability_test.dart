import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _ConversationNotifier extends ConversationNotifier {
  bool failSnapshot = false;

  @override
  ConversationState build() => super.build().copyWith(isLoading: false);

  @override
  void applyConversationSnapshot(ConversationModel conversation) {
    if (failSnapshot) throw StateError('synthetic post-commit UI failure');
    super.applyConversationSnapshot(conversation);
  }
}

/// Pause the completed, empty preflight lookup while a competing delivery
/// commits through the same real SQLite database.
class _PausedInboundLookupDatabase implements Database {
  _PausedInboundLookupDatabase(this.inner, this.messageId);
  final Database inner;
  final String messageId;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool paused = false;

  @override
  bool get isOpen => inner.isOpen;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) => inner.transaction(action, exclusive: exclusive);

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
    if (!paused &&
        table == MessageRepo.c2cTable &&
        whereArgs?.contains(messageId) == true) {
      paused = true;
      entered.complete();
      await release.future;
    }
    return rows;
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database database;
  late ProviderContainer container;
  late ProviderSubscription<ConversationState> listener;
  late _ConversationNotifier notifier;
  late MessageService service;
  late String originalDeviceId;
  final repos = <MessageRepo>[];

  MessageRepo repoFor(String type) {
    final repo = MessageRepo(tableName: MessageRepo.getTableName(type));
    repos.add(repo);
    return repo;
  }

  ConversationModel conversation(String type) => ConversationModel(
    id: 0,
    peerId: type == 'C2G' ? '300' : '200',
    avatar: '',
    title: 'Synthetic peer',
    subtitle: 'synthetic',
    type: type,
    msgType: 'text',
    lastMsgId: '',
    lastTime: 1700000000000,
    unreadNum: 0,
  );

  Future<MessageModel> insert(
    MessageRepo repo,
    String id, {
    String type = 'C2C',
    bool outgoing = false,
    int status = IMBoyMessageStatus.delivered,
    String text = 'synthetic',
  }) => repo.insert(
    MessageModel(
      id,
      autoId: 0,
      type: type,
      fromId: outgoing ? '100' : '200',
      toId: type == 'C2G'
          ? '300'
          : outgoing
          ? '200'
          : '100',
      payload: {'text': text},
      createdAt: 1700000000000,
      isAuthor: outgoing ? 1 : 0,
      conversationUk3: conversation(type).uk3,
      status: status,
      msgType: 'text',
    ),
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    originalDeviceId = init.deviceId;
    init.deviceId = 'synthetic-durability-device';
  });

  setUp(() async {
    UserRepoLocal.to.clearAuthTransitionFailureForTest();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    await StorageService.setMap(Keys.currentUser, {
      'uid': '100',
      'nickname': 'Synthetic self',
    });
    database = await openFixtureDatabaseAtVersion(
      version: kInventoryCurrentDbVersion,
    );
    SqliteService.setDbForTest(database);
    notifier = _ConversationNotifier();
    container = ProviderContainer(
      overrides: [conversationProvider.overrideWith(() => notifier)],
    );
    listener = container.listen(conversationProvider, (_, _) {});
    MessageService.setProviderContainer(container);
    service = MessageService.to;
    await ContactRepo().insert(
      ContactModel(peerId: '200', nickname: 'Synthetic peer'),
    );
    await MessageRetry.instance.debugWaitForIdle();
  });

  tearDown(() async {
    for (final repo in repos) {
      await repo.waitForFtsReindexForTest();
    }
    repos.clear();
    AckManager.to.dispose();
    listener.close();
    container.dispose();
    SqliteService.setDbForTest(null);
    await database.close();
  });

  tearDownAll(() {
    service.dispose();
    MessageRetry.instance.dispose();
    init.deviceId = originalDeviceId;
  });

  for (final type in ['C2C', 'C2G']) {
    for (final hasConversation in [false, true]) {
      test('$type delete persists without a page; conversation=$hasConversation', () async {
        final repo = repoFor(type);
        final id = 'delete-$type-$hasConversation';
        if (hasConversation) {
          final head = conversation(type)
            ..lastMsgId = id
            ..subtitle = 'deleteduniqueword'
            ..payload = {
              'text': 'deleteduniqueword',
              'last_read_auto_id': 7,
              'burn_enabled': true,
              'burn_after_ms': 30000,
              'member_generation_id': 'synthetic-generation',
              'authoritative': {
                'is_pinned': true,
                'last_msg': {'text': 'deleteduniqueword'},
              },
            };
          await ConversationRepo().insert(head);
        }
        await insert(repo, id, type: type, text: 'deleteduniqueword');
        await insert(
          repo,
          '$id-sibling',
          type: type,
          text: 'retaineduniqueword',
        );
        await repo.waitForFtsReindexForTest();
        final events = <ChatExtendEvent>[];
        final subscription = AppEventBus.on<ChatExtendEvent>().listen(
          events.add,
        );
        addTearDown(subscription.cancel);
        final frame = <String, dynamic>{
          'id': 'control-$id',
          'type': 'S2C',
          'action': type == 'C2C' ? 'c2c_del_everyone' : 'c2g_del_everyone',
          'from': 200,
          'to': 100,
          'payload': {'old_msg_id': id, if (type == 'C2G') 'to': 300},
        };
        await MessageS2CService.switchS2C(frame, propagateErrors: true);
        await pumpEventQueue();
        expect(await MessageRepo(tableName: repo.tableName).find(id), isNull);
        expect(await repo.find('$id-sibling'), isNotNull);
        expect(
          await database.rawQuery(
            'SELECT rowid FROM ${repo.tableName}_fts WHERE ${repo.tableName}_fts MATCH ?',
            ['deleteduniqueword'],
          ),
          isEmpty,
        );
        expect(
          await database.rawQuery(
            'SELECT rowid FROM ${repo.tableName}_fts WHERE ${repo.tableName}_fts MATCH ?',
            ['retaineduniqueword'],
          ),
          hasLength(1),
        );
        expect(
          events.where((event) => event.type == 'delete_msg'),
          hasLength(hasConversation ? 1 : 0),
        );
        if (hasConversation) {
          expect(events.single.payload['message_id'], id);
          final head = await ConversationRepo().findByPeerId(
            type,
            type == 'C2G' ? '300' : '200',
          );
          expect(head!.lastMsgId, '$id-sibling');
          expect(head.subtitle, 'retaineduniqueword');
          expect(head.payload.toString(), isNot(contains('deleteduniqueword')));
          expect(head.payload!['last_read_auto_id'], 7);
          expect(head.payload!['burn_enabled'], isTrue);
          expect(head.payload!['burn_after_ms'], 30000);
          expect(head.payload!['member_generation_id'], 'synthetic-generation');
          expect((head.payload!['authoritative'] as Map)['is_pinned'], isTrue);
        }
        // A fresh control ID replays the deletion through persistence again.
        await MessageS2CService.switchS2C({
          ...frame,
          'id': 'control-$id-replay',
        }, propagateErrors: true);
      });
    }
  }

  test(
    'delete failure rolls back and emits no successful deletion or ACK',
    () async {
      final repo = repoFor('C2C');
      const id = 'failed-delete';
      await insert(repo, id, text: 'rollbackword');
      await repo.waitForFtsReindexForTest();
      await database.execute(
        "CREATE TRIGGER reject_delete BEFORE DELETE ON msg_c2c BEGIN SELECT RAISE(ABORT, 'synthetic-delete-failure'); END",
      );
      final events = <ChatExtendEvent>[];
      final acks = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<ChatExtendEvent>().listen(events.add);
      final ackSubscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(acks.add);
      addTearDown(subscription.cancel);
      addTearDown(ackSubscription.cancel);
      await expectLater(
        MessageS2CService.switchS2C({
          'id': 'control-failed-delete',
          'type': 'S2C',
          'action': 'c2c_del_everyone',
          'from': '200',
          'to': '100',
          'payload': {'old_msg_id': id},
        }, propagateErrors: true),
        throwsA(isA<DatabaseException>()),
      );
      await pumpEventQueue();
      expect(await repo.find(id), isNotNull);
      expect(
        await database.rawQuery(
          'SELECT rowid FROM msg_c2c_fts WHERE msg_c2c_fts MATCH ?',
          ['rollbackword'],
        ),
        hasLength(1),
      );
      expect(events, isEmpty);
      expect(acks, isEmpty);
    },
  );

  for (final action in ['not_a_friend', 'in_denylist']) {
    test(
      '$action marks the original outgoing row failed before retry removal',
      () async {
        final repo = repoFor('C2C');
        final id = 'rejected-$action';
        final conv = conversation('C2C')..lastMsgId = id;
        await ConversationRepo().insert(conv);
        await insert(
          repo,
          id,
          outgoing: true,
          status: IMBoyMessageStatus.sending,
        );
        final removals = <RemoveFromRetryQueueRequestedEvent>[];
        final subscription =
            AppEventBus.on<RemoveFromRetryQueueRequestedEvent>().listen(
              removals.add,
            );
        addTearDown(subscription.cancel);
        await MessageS2CService.switchS2C({
          'id': id,
          'type': 'S2C',
          'action': action,
          'from': 200,
          'to': 100,
          'payload': <String, dynamic>{},
        }, propagateErrors: true);
        await pumpEventQueue();
        expect((await repo.find(id))!.status, IMBoyMessageStatus.error);
        expect(
          (await ConversationRepo().findByPeerId('C2C', '200'))!.lastMsgStatus,
          IMBoyMessageStatus.error,
        );
        expect(
          await repo.pageRetryCandidates(
            statuses: [
              IMBoyMessageStatus.sending,
              IMBoyMessageStatus.pendingRetry,
            ],
            limit: 100,
          ),
          isEmpty,
        );
        expect(removals.single.messageType, 'C2C');
        expect(removals.single.reason, action);
      },
    );
  }

  test(
    'post-commit presentation failure retains the row and sends transport ACK',
    () async {
      const id = 'committed-ui-failure';
      notifier.failSnapshot = true;
      final dataEvents = <DataWrapperEvent<dynamic>>[];
      final acks = <WebSocketMessageSendRequestEvent>[];
      final dataSubscription = AppEventBus.on<DataWrapperEvent<dynamic>>()
          .listen(dataEvents.add);
      final ackSubscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(acks.add);
      addTearDown(dataSubscription.cancel);
      addTearDown(ackSubscription.cancel);
      final frame = <String, dynamic>{
        'id': id,
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'created_at': 1700000000000,
        'msg_type': 'text',
        'payload': {'text': 'synthetic committed message'},
      };
      await service.processMessage('C2C', Map.of(frame));
      await pumpEventQueue();
      expect(await repoFor('C2C').find(id), isNotNull);
      expect(acks.where((event) => event.messageId == id), hasLength(1));
      expect(
        dataEvents.where(
          (event) =>
              event.data is Map &&
              [
                'delete_message',
                'rollback_conversation',
              ].contains((event.data as Map)['action']),
        ),
        isEmpty,
      );
      await service.processMessage('C2C', Map.of(frame));
      expect(
        await database.query('msg_c2c', where: 'id = ?', whereArgs: [id]),
        hasLength(1),
      );
    },
  );

  test('uncommitted insert failure sends no transport ACK', () async {
    const id = 'uncommitted-message';
    await database.execute(
      "CREATE TRIGGER reject_insert BEFORE INSERT ON msg_c2c BEGIN SELECT RAISE(ABORT, 'synthetic-write-failure'); END",
    );
    final acks = <WebSocketMessageSendRequestEvent>[];
    final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen(acks.add);
    addTearDown(subscription.cancel);
    await service.processMessage('C2C', {
      'id': id,
      'type': 'C2C',
      'from': '100',
      'to': '200',
      'created_at': 1700000000000,
      'msg_type': 'text',
      'payload': {'text': 'synthetic failed message'},
    });
    await pumpEventQueue();
    expect(await repoFor('C2C').find(id), isNull);
    expect(acks, isEmpty);
  });

  test(
    'concurrent redelivery preserves committed state and conversation head',
    () async {
      const id = 'synthetic-inbound-race';
      final paused = _PausedInboundLookupDatabase(database, id);
      SqliteService.setDbForTest(paused);
      final acks = <WebSocketMessageSendRequestEvent>[];
      final subscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
          .listen(acks.add);
      addTearDown(subscription.cancel);
      final receiving = service.processMessage('C2C', {
        'id': id,
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'created_at': 1700000000000,
        'msg_type': 'text',
        'payload': {'text': 'synthetic replay text'},
      });
      await paused.entered.future;
      try {
        final repo = repoFor('C2C');
        await insert(
          repo,
          id,
          outgoing: true,
          status: IMBoyMessageStatus.seen,
          text: 'synthetic locally edited text',
        );
        await database.update(
          repo.tableName,
          {'conv_seq': 17, 'accepted_at': 1700000000010},
          where: 'id = ?',
          whereArgs: [id],
        );
        await ConversationRepo().insert(
          conversation('C2C').copyWith(
            lastMsgId: id,
            lastMsgStatus: IMBoyMessageStatus.seen,
            subtitle: 'synthetic locally edited text',
            unreadNum: 4,
            payload: {'text': 'synthetic locally edited text'},
          ),
        );
      } finally {
        paused.release.complete();
      }
      await receiving;
      await pumpEventQueue();
      final rows = await database.query('msg_c2c');
      expect(rows, hasLength(1));
      expect(rows.single['status'], IMBoyMessageStatus.seen);
      expect(rows.single['payload'], contains('synthetic locally edited text'));
      expect(rows.single['conv_seq'], 17);
      expect(rows.single['accepted_at'], 1700000000010);
      final head = await ConversationRepo().findByPeerId('C2C', '200');
      expect(head!.subtitle, 'synthetic locally edited text');
      expect(head.lastMsgStatus, IMBoyMessageStatus.seen);
      expect(head.unreadNum, 4);
      expect(acks.where((event) => event.messageId == id), hasLength(1));
    },
  );

  test('read batch persists every status and emits every UI model', () async {
    final repo = repoFor('C2C');
    const ids = ['receipt-first', 'receipt-second', 'receipt-third'];
    final conv = conversation('C2C')..lastMsgId = ids.last;
    await ConversationRepo().insert(conv);
    for (final id in ids) {
      await insert(repo, id, outgoing: true);
    }
    final events = <DataWrapperEvent<dynamic>>[];
    final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
      events.add,
    );
    addTearDown(subscription.cancel);
    expect(
      await MessageActions.instance.handleActionMessage('message_read', {
        'type': 'C2C',
        'from': '200',
        'payload': {
          'msg_ids': [...ids, ids.first],
        },
      }),
      isTrue,
    );
    await pumpEventQueue();
    expect(
      (await repo.findByIds(ids)).map((message) => message.status),
      everyElement(IMBoyMessageStatus.seen),
    );
    final updates =
        events.where((event) => event.dataType == 'List<Message>').single.data
            as List<Message>;
    expect(updates.map((message) => message.id), unorderedEquals(ids));
    expect(
      updates.map((message) => message.status),
      everyElement(MessageStatus.seen),
    );
    expect(
      (await ConversationRepo().findByPeerId('C2C', '200'))!.lastMsgStatus,
      IMBoyMessageStatus.seen,
    );
  });

  test(
    'deleted and revoked read targets do not block healthy receipts',
    () async {
      final repo = repoFor('C2C');
      await insert(repo, 'receipt-before-missing', outgoing: true);
      await insert(
        repo,
        'receipt-revoked',
        outgoing: true,
        status: IMBoyMessageStatus.myRevoked,
      );
      expect(
        await MessageActions.instance.handleActionMessage('message_read', {
          'type': 'C2C',
          'from': '200',
          'payload': {
            'msg_ids': [
              'receipt-before-missing',
              'missing-target',
              'receipt-revoked',
            ],
          },
        }),
        isTrue,
      );
      expect(
        (await repo.find('receipt-before-missing'))!.status,
        IMBoyMessageStatus.seen,
      );
      expect(
        (await repo.find('receipt-revoked'))!.status,
        IMBoyMessageStatus.myRevoked,
      );
    },
  );
}
