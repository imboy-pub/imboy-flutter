import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/channel/channel_snapshot_sync.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_message_outbox_repo.dart';
import 'package:imboy/store/repository/channel_publish_outbox_repo.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

ChannelModel _channel(int id) => ChannelModel(
  id: id,
  name: 'channel-$id',
  creatorId: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _Api extends ChannelApi {
  _Api(this.result);
  final Future<Map<String, dynamic>> result;
  @override
  Future<Map<String, dynamic>> getUnreadSummary() => result;
}

class _PublishApi extends ChannelApi {
  _PublishApi(this.response);
  final Future<ChannelMessageModel?> response;
  @override
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
    String? requestId,
  }) => response;
}

class _FailPublishApi extends ChannelApi {
  @override
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async => [];
  @override
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
    String? requestId,
  }) async => throw StateError('network');
}

class _DeferredMessagesApi extends ChannelApi {
  final started = Completer<void>();
  final response = Completer<List<ChannelMessageModel>>();
  @override
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) {
    started.complete();
    return response.future;
  }
}

class _DeferredSubscriptionWriteApi extends ChannelApi {
  final started = Completer<void>();
  final response = Completer<bool>();
  @override
  Future<bool> subscribe(String channelId) {
    started.complete();
    return response.future;
  }

  @override
  Future<bool> unsubscribe(String channelId) {
    started.complete();
    return response.future;
  }

  @override
  Future<ChannelModel?> getChannel(String channelId) async =>
      _channel(10).copyWith(isSubscribed: true);
}

class _ReconcileSubscribeApi extends ChannelApi {
  int writes = 0;
  bool accept = true;
  bool readable = false;
  @override
  Future<bool> subscribe(String channelId) async {
    writes++;
    return accept;
  }

  @override
  Future<ChannelModel?> getChannel(String channelId) async =>
      readable ? _channel(10).copyWith(isSubscribed: true) : null;
}

class _DeferredChannelApi extends ChannelApi {
  final started = Completer<void>();
  final response = Completer<ChannelModel?>();
  @override
  Future<ChannelModel?> getChannel(String channelId) {
    started.complete();
    return response.future;
  }
}

class _MessagesApi extends ChannelApi {
  _MessagesApi(this.messages);
  final List<ChannelMessageModel> messages;
  @override
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async => messages;
}

class _FailingMessageOutbox extends ChannelMessageOutboxRepo {
  @override
  Future<void> enqueue(
    ChannelMessageModel message, {
    String? error,
    Transaction? txn,
  }) async => throw StateError('outbox failed');
}

class _InvalidatingRepo extends ChannelRepo {
  _InvalidatingRepo(this.invalidate);
  final void Function() invalidate;
  @override
  Future<void> saveChannel(ChannelModel channel, {Transaction? txn}) async {
    await super.saveChannel(channel, txn: txn);
    invalidate();
  }
}

class _InvalidatingMuteRepo extends ChannelRepo {
  _InvalidatingMuteRepo(this.invalidate);
  final Future<void> Function() invalidate;

  @override
  Future<int> setMuted(String channelId, bool muted, {Transaction? txn}) async {
    final rows = await super.setMuted(channelId, muted, txn: txn);
    await invalidate();
    return rows;
  }
}

class _DeferredSubscriptionsApi extends ChannelApi {
  final started = Completer<void>();
  final response = Completer<List<ChannelModel>>();

  @override
  Future<List<ChannelModel>> getSubscribedChannels({
    String? cursor,
    int limit = 50,
  }) {
    started.complete();
    return response.future;
  }
}

class _FailingMessageRepo extends ChannelMessageRepo {
  @override
  Future<void> saveMessage(
    ChannelMessageModel message, {
    Transaction? txn,
  }) async {
    throw StateError('cache write failed');
  }
}

class _InvalidatingMessageRepo extends ChannelMessageRepo {
  _InvalidatingMessageRepo(this.invalidate);
  final void Function() invalidate;
  @override
  Future<void> saveMessage(
    ChannelMessageModel message, {
    Transaction? txn,
  }) async {
    await super.saveMessage(message, txn: txn);
    invalidate();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '1001');
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
  });
  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  test('并发订阅只发送一次，确认前不允许相反写入', () async {
    final api = _DeferredSubscriptionWriteApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final a = service.subscribeChannelResult('10');
    final b = service.subscribeChannelResult('10');
    await api.started.future;
    expect(await service.unsubscribeChannel('10'), isFalse);
    api.response.complete(true);
    expect(await a, ChannelSubscribeOutcome.completed);
    expect(await b, ChannelSubscribeOutcome.completed);
  });

  test('退订在途时不发送反向订阅写请求', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final api = _DeferredSubscriptionWriteApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final pending = service.unsubscribeChannel('10');
    await api.started.future;
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.stale,
    );
    api.response.complete(true);
    expect(await pending, isTrue);
    expect(await db.query(ChannelRepo.subscriptionTableName), isEmpty);
  });

  test('待对账状态按账号隔离', () async {
    final api = _ReconcileSubscribeApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.pending,
    );
    await StorageService.to.setString(Keys.currentUid, '1002');
    expect(service.hasPendingSubscription('10'), isFalse);
    await StorageService.to.setString(Keys.currentUid, '1001');
    expect(service.hasPendingSubscription('10'), isTrue);
  });

  test('服务端已订阅但回读失败，重试只对账并恢复', () async {
    final api = _ReconcileSubscribeApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.pending,
    );
    expect(service.hasPendingSubscription('10'), isTrue);
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.pending,
    );
    expect(api.writes, 1);
    api.readable = true;
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.completed,
    );
    expect(api.writes, 1);
    expect(service.hasPendingSubscription('10'), isFalse);
    expect(await db.query(ChannelRepo.subscriptionTableName), hasLength(1));
  });

  test('普通订阅失败不建立待核对锁，后续允许重试', () async {
    final api = _ReconcileSubscribeApi()..accept = false;
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.failed,
    );
    expect(service.hasPendingSubscription('10'), isFalse);
    api.accept = true;
    expect(
      await service.subscribeChannelResult('10'),
      ChannelSubscribeOutcome.pending,
    );
    expect(api.writes, 2);
  });

  test('订阅写请求等待中切号不会写入当前数据库', () async {
    final api = _DeferredSubscriptionWriteApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final pending = service.subscribeChannel('10');
    await api.started.future;
    await StorageService.to.setString(Keys.currentUid, '1002');
    api.response.complete(true);
    expect(await pending, isFalse);
    expect(await db.query(ChannelRepo.tableName), isEmpty);
    expect(await db.query(ChannelRepo.subscriptionTableName), isEmpty);
  });

  test('退订写请求等待中切号不会删除当前数据库订阅', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final api = _DeferredSubscriptionWriteApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final pending = service.unsubscribeChannel('10');
    await api.started.future;
    await StorageService.to.setString(Keys.currentUid, '1002');
    api.response.complete(true);
    expect(await pending, isFalse);
    expect(await db.query(ChannelRepo.subscriptionTableName), hasLength(1));
  });

  test('订阅事务中会话失效时回滚频道和订阅', () async {
    var current = true;
    final api = _DeferredSubscriptionWriteApi();
    final service = ChannelService.forTest(
      api: api,
      repo: _InvalidatingRepo(() => current = false),
      bindPublishDatabase: true,
      sessionValidForTest: () => current,
    );
    final pending = service.subscribeChannel('10');
    await api.started.future;
    api.response.complete(true);
    expect(await pending, isFalse);
    expect(await db.query(ChannelRepo.tableName), isEmpty);
    expect(await db.query(ChannelRepo.subscriptionTableName), isEmpty);
  });

  test('订阅对账事务中会话失效时回滚频道与订阅', () async {
    var current = true;
    final service = ChannelService.forTest(
      api: _Api(Future.value({})),
      repo: _InvalidatingRepo(() => current = false),
      bindPublishDatabase: true,
      sessionValidForTest: () => current,
    );
    expect(
      await service.syncSubscribedChannels(fromList: [_channel(10)]),
      isEmpty,
    );
    expect(await db.query(ChannelRepo.tableName), isEmpty);
    expect(await db.query(ChannelRepo.subscriptionTableName), isEmpty);
  });

  test('订阅接口等待时切账号不写入旧账号数据', () async {
    final api = _DeferredSubscriptionsApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final pending = service.syncSubscribedChannels();
    await api.started.future;
    await StorageService.to.setString(Keys.currentUid, '1002');
    api.response.complete([_channel(10)]);
    expect(await pending, isEmpty);
    expect(await db.query(ChannelRepo.tableName), isEmpty);
    expect(await db.query(ChannelRepo.subscriptionTableName), isEmpty);
  });

  test('静音写入期间切账号回滚并返回失败', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final service = ChannelService.forTest(
      api: _Api(Future.value({})),
      repo: _InvalidatingMuteRepo(
        () => StorageService.to.setString(Keys.currentUid, '1002'),
      ),
      bindPublishDatabase: true,
    );
    final events = <ChannelStateChangedEvent>[];
    final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
    addTearDown(sub.cancel);
    expect(await service.setMuted('10', true), isFalse);
    await Future<void>.delayed(Duration.zero);
    final row = (await db.query(ChannelRepo.subscriptionTableName)).single;
    expect(row[ChannelRepo.isMuted], 0);
    expect(events, isEmpty);
  });

  test('静音成功后仅发送对应频道状态事件', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final service = ChannelService.forTest(
      api: _Api(Future.value({})),
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final events = <ChannelStateChangedEvent>[];
    final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
    addTearDown(sub.cancel);
    expect(await service.setMuted('10', true), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(
      (await db.query(ChannelRepo.subscriptionTableName))
          .single[ChannelRepo.isMuted],
      1,
    );
    expect(events, hasLength(1));
    expect(events.single.channelId, '10');
    expect(events.single.action, 'channel_muted_changed');
    expect(events.single.payload['is_muted'], isTrue);
  });

  test('订阅对账保留既有通知配置及阅读状态', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    await db.update(ChannelRepo.subscriptionTableName, {
      ChannelRepo.isMuted: 1,
      ChannelRepo.isPinned: 1,
      ChannelRepo.notificationsEnabled: 0,
      ChannelRepo.unreadCount: 7,
      ChannelRepo.lastMessageId: 42,
    });
    final before = (await db.query(ChannelRepo.subscriptionTableName)).single;
    final service = ChannelService.forTest(
      api: _Api(Future.value({})),
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    expect(
      await service.syncSubscribedChannels(fromList: [_channel(10)]),
      hasLength(1),
    );
    expect((await db.query(ChannelRepo.subscriptionTableName)).single, before);
  });

  test('列表代次在事务中失效时回滚频道和订阅', () async {
    var current = true;
    final result = await syncChannelSnapshot(
      repo: _InvalidatingRepo(() => current = false),
      channels: [_channel(10)],
      isCurrent: () => current,
    );
    expect(result, isFalse);
    expect(await db.query(ChannelRepo.tableName), isEmpty);
    expect(await db.query(ChannelRepo.subscriptionTableName), isEmpty);
  });

  for (final localFirst in [true, false]) {
    test('详情读取 localFirst=$localFirst 在网络等待时失效不缓存', () async {
      var current = true;
      final api = _DeferredChannelApi();
      final service = ChannelService.forTest(
        api: api,
        repo: ChannelRepo(),
        bindPublishDatabase: true,
        sessionValidForTest: () => current,
      );
      final pending = localFirst
          ? service.getChannel('10')
          : service.refreshChannel('10');
      await api.started.future;
      current = false;
      api.response.complete(_channel(10));
      expect(await pending, isNull);
      expect(await db.query(ChannelRepo.tableName), isEmpty);
    });
  }

  test('频道快照写入时会话失效回滚', () async {
    var current = true;
    final service = ChannelService.forTest(
      api: _Api(Future.value({})),
      repo: _InvalidatingRepo(() => current = false),
      bindPublishDatabase: true,
      sessionValidForTest: () => current,
    );
    await service.cacheChannelSnapshot(_channel(10));
    expect(await db.query(ChannelRepo.tableName), isEmpty);
  });

  test('频道快照写入时请求代次失效回滚', () async {
    var current = true;
    final service = ChannelService.forTest(
      api: _Api(Future.value({})),
      repo: _InvalidatingRepo(() => current = false),
      bindPublishDatabase: true,
    );
    await service.cacheChannelSnapshot(_channel(10), isCurrent: () => current);
    expect(await db.query(ChannelRepo.tableName), isEmpty);
  });

  test('频道刷新等待时请求代次失效不写缓存', () async {
    var current = true;
    final api = _DeferredChannelApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    final pending = service.refreshChannel('10', isCurrent: () => current);
    await api.started.future;
    current = false;
    api.response.complete(_channel(10));
    expect(await pending, isNull);
    expect(await db.query(ChannelRepo.tableName), isEmpty);
  });

  test('绑定频道读取优先使用已缓存内容', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final api = _DeferredChannelApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      bindPublishDatabase: true,
    );
    expect((await service.getChannel('10'))?.id, 10);
    expect(api.started.isCompleted, isFalse);
  });

  test('发布和消息 outbox 可在同一事务中回滚', () async {
    final publish = ChannelPublishOutboxRepo();
    final messages = ChannelMessageOutboxRepo();
    final message = ChannelMessageModel(
      id: 100,
      channelId: 10,
      content: 'pending',
      msgType: 'channel_text',
      createdAt: DateTime.utc(2026),
    );
    await expectLater(
      db.transaction((txn) async {
        await publish.enqueue(
          requestId: 'r1',
          channelId: '10',
          content: 'pending',
          msgType: 'channel_text',
          txn: txn,
        );
        await messages.enqueue(message, txn: txn);
        throw StateError('stale session');
      }),
      throwsStateError,
    );
    expect(await db.query(ChannelPublishOutboxRepo.tableName), isEmpty);
    expect(await db.query(ChannelMessageOutboxRepo.tableName), isEmpty);
    await db.transaction((txn) async {
      await publish.enqueue(
        requestId: 'r1',
        channelId: '10',
        content: 'pending',
        msgType: 'channel_text',
        txn: txn,
      );
      await messages.enqueue(message, txn: txn);
    });
    await expectLater(
      db.transaction((txn) async {
        expect(await publish.pending(txn: txn), hasLength(1));
        expect(await messages.pending(txn: txn), hasLength(1));
        await publish.markRetry('r1', 'failure', txn: txn);
        await messages.markRetry(100, 'failure', txn: txn);
        await publish.remove('r1', txn: txn);
        await messages.remove(100, txn: txn);
        throw StateError('stale session');
      }),
      throwsStateError,
    );
    expect(
      (await db.query(ChannelPublishOutboxRepo.tableName)).single['attempts'],
      0,
    );
    expect(
      (await db.query(ChannelMessageOutboxRepo.tableName)).single['attempts'],
      0,
    );
  });

  test('发布成功使用绑定数据库事务保存消息并清理请求', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final pending = ChannelPublishOutboxRepo();
    await pending.enqueue(
      requestId: 'r1',
      channelId: '10',
      content: 'hello',
      msgType: 'channel_text',
    );
    final service = ChannelService.forTest(
      api: _PublishApi(
        Future.value(
          ChannelMessageModel(
            id: 101,
            channelId: 10,
            content: 'hello',
            msgType: 'channel_text',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      repo: ChannelRepo(),
      publishOutboxRepo: pending,
      outboxRepo: ChannelMessageOutboxRepo(),
      bindPublishDatabase: true,
    );
    final result = await service.publishMessage(
      channelId: '10',
      content: 'hello',
      msgType: 'channel_text',
      requestId: 'r1',
    );
    expect(result?.id, 101);
    expect(await db.query('channel_message'), hasLength(1));
    expect(await db.query(ChannelPublishOutboxRepo.tableName), isEmpty);
  });

  test('服务端成功但缓存失败时原子保留消息重试', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final pending = ChannelPublishOutboxRepo();
    await pending.enqueue(
      requestId: 'r2',
      channelId: '10',
      content: 'hello',
      msgType: 'channel_text',
    );
    final service = ChannelService.forTest(
      api: _PublishApi(
        Future.value(
          ChannelMessageModel(
            id: 102,
            channelId: 10,
            content: 'hello',
            msgType: 'channel_text',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      repo: ChannelRepo(),
      messageRepo: _FailingMessageRepo(),
      publishOutboxRepo: pending,
      outboxRepo: ChannelMessageOutboxRepo(),
      bindPublishDatabase: true,
    );
    expect(
      (await service.publishMessage(
        channelId: '10',
        content: 'hello',
        msgType: 'channel_text',
        requestId: 'r2',
      ))?.id,
      102,
    );
    expect(await db.query('channel_message'), isEmpty);
    expect(await db.query(ChannelMessageOutboxRepo.tableName), hasLength(1));
    expect(await db.query(ChannelPublishOutboxRepo.tableName), isEmpty);
  });

  test('网络失败时发布请求写入绑定数据库 outbox', () async {
    final service = ChannelService.forTest(
      api: _FailPublishApi(),
      repo: ChannelRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      bindPublishDatabase: true,
    );
    expect(
      await service.publishMessage(
        channelId: '10',
        content: 'hello',
        msgType: 'channel_text',
        requestId: 'r3',
      ),
      isNull,
    );
    final rows = await db.query(ChannelPublishOutboxRepo.tableName);
    expect(rows.single['request_id'], 'r3');
  });

  test('事务中会话失效会回滚消息和发布请求删除', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final pending = ChannelPublishOutboxRepo();
    await pending.enqueue(
      requestId: 'r4',
      channelId: '10',
      content: 'hello',
      msgType: 'channel_text',
    );
    var current = true;
    final service = ChannelService.forTest(
      api: _PublishApi(
        Future.value(
          ChannelMessageModel(
            id: 103,
            channelId: 10,
            content: 'hello',
            msgType: 'channel_text',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      repo: ChannelRepo(),
      messageRepo: _InvalidatingMessageRepo(() => current = false),
      publishOutboxRepo: pending,
      outboxRepo: ChannelMessageOutboxRepo(),
      bindPublishDatabase: true,
      sessionValidForTest: () => current,
    );
    expect(
      await service.publishMessage(
        channelId: '10',
        content: 'hello',
        msgType: 'channel_text',
        requestId: 'r4',
      ),
      isNull,
    );
    expect(await db.query('channel_message'), isEmpty);
    expect(
      (await db.query(ChannelPublishOutboxRepo.tableName)).single['request_id'],
      'r4',
    );
    expect(await db.query(ChannelMessageOutboxRepo.tableName), isEmpty);
  });

  test('发布 outbox 重放成功使用原请求并写入绑定数据库', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final pending = ChannelPublishOutboxRepo();
    await pending.enqueue(
      requestId: 'r5',
      channelId: '10',
      content: 'hello',
      msgType: 'channel_text',
    );
    final service = ChannelService.forTest(
      api: _PublishApi(
        Future.value(
          ChannelMessageModel(
            id: 105,
            channelId: 10,
            content: 'hello',
            msgType: 'channel_text',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      repo: ChannelRepo(),
      publishOutboxRepo: pending,
      outboxRepo: ChannelMessageOutboxRepo(),
      bindPublishDatabase: true,
    );
    expect((await service.getMessages(channelId: '10')).single.id, 105);
    expect(await db.query(ChannelPublishOutboxRepo.tableName), isEmpty);
  });

  test('发布 outbox 重放失败保留请求并增加重试次数', () async {
    final pending = ChannelPublishOutboxRepo();
    await pending.enqueue(
      requestId: 'r6',
      channelId: '10',
      content: 'hello',
      msgType: 'channel_text',
    );
    final service = ChannelService.forTest(
      api: _FailPublishApi(),
      repo: ChannelRepo(),
      publishOutboxRepo: pending,
      outboxRepo: ChannelMessageOutboxRepo(),
      bindPublishDatabase: true,
    );
    await service.getMessages(channelId: '10');
    final row = (await db.query(ChannelPublishOutboxRepo.tableName)).single;
    expect(row['request_id'], 'r6');
    expect(row['attempts'], 1);
  });

  test('消息 outbox 重放在绑定事务中保存并删除队列项', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final outbox = ChannelMessageOutboxRepo();
    await outbox.enqueue(
      ChannelMessageModel(
        id: 106,
        channelId: 10,
        content: 'pending',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    final service = ChannelService.forTest(
      api: _FailPublishApi(),
      repo: ChannelRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      outboxRepo: outbox,
      bindPublishDatabase: true,
    );
    expect((await service.getMessages(channelId: '10')).single.id, 106);
    expect(await db.query(ChannelMessageOutboxRepo.tableName), isEmpty);
  });

  test('消息 outbox 重放失败保留数据并增加重试次数', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final outbox = ChannelMessageOutboxRepo();
    await outbox.enqueue(
      ChannelMessageModel(
        id: 107,
        channelId: 10,
        content: 'pending',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    final service = ChannelService.forTest(
      api: _FailPublishApi(),
      repo: ChannelRepo(),
      messageRepo: _FailingMessageRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      outboxRepo: outbox,
      bindPublishDatabase: true,
    );
    await service.getMessages(channelId: '10');
    final row = (await db.query(ChannelMessageOutboxRepo.tableName)).single;
    expect(row['message_id'], 107);
    expect(row['attempts'], 1);
  });

  test('消息 outbox 重放事务内会话失效时保留原队列', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final outbox = ChannelMessageOutboxRepo();
    await outbox.enqueue(
      ChannelMessageModel(
        id: 108,
        channelId: 10,
        content: 'pending',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    var current = true;
    final service = ChannelService.forTest(
      api: _FailPublishApi(),
      repo: ChannelRepo(),
      messageRepo: _InvalidatingMessageRepo(() => current = false),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      outboxRepo: outbox,
      bindPublishDatabase: true,
      sessionValidForTest: () => current,
    );
    await service.getMessages(channelId: '10');
    expect(await db.query('channel_message'), isEmpty);
    final row = (await db.query(ChannelMessageOutboxRepo.tableName)).single;
    expect(row['message_id'], 108);
    expect(row['attempts'], 0);
  });

  test('网络消息回退等待期间会话失效不写缓存或返回旧消息', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    var current = true;
    final api = _DeferredMessagesApi();
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      outboxRepo: ChannelMessageOutboxRepo(),
      bindPublishDatabase: true,
      sessionValidForTest: () => current,
    );
    final pending = service.getMessages(channelId: '10');
    await api.started.future;
    current = false;
    api.response.complete([
      ChannelMessageModel(
        id: 109,
        channelId: 10,
        content: 'old',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    ]);
    expect(await pending, isEmpty);
    expect(await db.query('channel_message'), isEmpty);
    expect(await db.query(ChannelMessageOutboxRepo.tableName), isEmpty);
  });

  test('网络成功但缓存和队列均失败时保留网络消息', () async {
    await syncChannelSnapshot(
      repo: ChannelRepo(),
      channels: [_channel(10)],
      isCurrent: () => true,
    );
    final message = ChannelMessageModel(
      id: 110,
      channelId: 10,
      content: 'network',
      msgType: 'channel_text',
      createdAt: DateTime.utc(2026),
    );
    final service = ChannelService.forTest(
      api: _MessagesApi([message]),
      repo: ChannelRepo(),
      messageRepo: _FailingMessageRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      outboxRepo: _FailingMessageOutbox(),
      bindPublishDatabase: true,
    );
    expect((await service.syncMessages(channelId: '10')).single.id, 110);
    expect(await db.query('channel_message'), isEmpty);
  });

  test('未读汇总缺席项保留原值并报告待核对，显式零可清零', () async {
    expect(
      await syncChannelSnapshot(
        repo: ChannelRepo(),
        channels: [_channel(10)],
        isCurrent: () => true,
      ),
      isTrue,
    );
    await db.update(ChannelRepo.subscriptionTableName, {
      ChannelRepo.unreadCount: 5,
    });
    expect(
      await syncChannelUnreadSnapshot(
        api: _Api(Future.value({'channels': <Map<String, dynamic>>[]})),
        isCurrent: () => true,
      ),
      isFalse,
    );
    var rows = await db.query(ChannelRepo.subscriptionTableName);
    expect(rows.single[ChannelRepo.unreadCount], 5);
    expect(
      await syncChannelUnreadSnapshot(
        api: _Api(
          Future.value({
            'channels': [
              {'channel_id': 10, 'unread_count': 0},
            ],
          }),
        ),
        isCurrent: () => true,
      ),
      isTrue,
    );
    rows = await db.query(ChannelRepo.subscriptionTableName);
    expect(rows.single[ChannelRepo.unreadCount], 0);
  });

  test('未读请求期间会话失效时不写旧响应', () async {
    expect(
      await syncChannelSnapshot(
        repo: ChannelRepo(),
        channels: [_channel(10)],
        isCurrent: () => true,
      ),
      isTrue,
    );
    await db.update(ChannelRepo.subscriptionTableName, {
      ChannelRepo.unreadCount: 5,
    });
    var current = true;
    final response = Completer<Map<String, dynamic>>();
    final pending = syncChannelUnreadSnapshot(
      api: _Api(response.future),
      isCurrent: () => current,
    );
    current = false;
    response.complete({
      'channels': [
        {'channel_id': 10, 'unread_count': 0},
      ],
    });
    expect(await pending, isFalse);
    final rows = await db.query(ChannelRepo.subscriptionTableName);
    expect(rows.single[ChannelRepo.unreadCount], 5);
  });

  test('未读汇总中无效条目使整批回滚，不把无效值当零', () async {
    expect(
      await syncChannelSnapshot(
        repo: ChannelRepo(),
        channels: [_channel(10)],
        isCurrent: () => true,
      ),
      isTrue,
    );
    await db.update(ChannelRepo.subscriptionTableName, {
      ChannelRepo.unreadCount: 5,
    });
    final ok = await syncChannelUnreadSnapshot(
      api: _Api(
        Future.value({
          'channels': [
            {'channel_id': 10, 'unread_count': 0},
            {'channel_id': 11, 'unread_count': null},
          ],
        }),
      ),
      isCurrent: () => true,
    );
    expect(ok, isFalse);
    final rows = await db.query(ChannelRepo.subscriptionTableName);
    expect(rows.single[ChannelRepo.unreadCount], 5);
  });
}
