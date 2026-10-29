/// ChannelListNotifier 对 ChannelStateChangedEvent 的响应契约：
/// - channel_unsubscribed / channel_deleted：本地过滤对应频道（不触发网络）
/// - channel_subscribed：触发权威拉取（这里不落测网络副作用，仅验证事件不把本地误删）
///
/// 这些行为保证多端一致性：设备 A 退订/被删后，设备 B 收到 S2C 推送时
/// 本端列表会立即对齐，不依赖用户手动下拉。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_publish_outbox_repo.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_message_outbox_repo.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../secure_storage_test_pin.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _MockChannelApi extends Mock implements ChannelApi {}

class _MockPublishOutbox extends Mock implements ChannelPublishOutboxRepo {}

class _MockChannelRepo extends Mock implements ChannelRepo {}

class _MockMessageRepo extends Mock implements ChannelMessageRepo {}

class _MockMessageOutbox extends Mock implements ChannelMessageOutboxRepo {}

class _IsolatedPathProvider extends PathProviderPlatform {
  _IsolatedPathProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
}

ChannelModel _channel(int id, String name) => ChannelModel(
  id: id,
  name: name,
  creatorId: 1,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
);

void main() {
  setUpAll(pinInertSecureStorage);
  group('ChannelListNotifier auto-sync via ChannelStateChangedEvent', () {
    late ProviderContainer container;
    late ChannelListNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      // Riverpod 3 auto-dispose：不 listen 则 `container.read(provider)` 会
      // 在无订阅者时重建 state，导致外部通过 `notifier.state = ...` 写入的
      // 瞬态状态被清空。测试阶段主动订阅保活。
      container.listen(channelListProvider, (_, _) {});
      notifier = container.read(channelListProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('channel_unsubscribed filters the channel out locally', () async {
      notifier.state = notifier.state.copyWith(
        channels: [
          _channel(1001, 'A'),
          _channel(1002, 'B'),
          _channel(1003, 'C'),
        ],
      );

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '1002',
          action: 'channel_unsubscribed',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1001', '1003']);
    });

    test('channel_deleted filters the channel out locally', () async {
      notifier.state = notifier.state.copyWith(
        channels: [_channel(1001, 'A'), _channel(1002, 'B')],
      );

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '1001',
          action: 'channel_deleted',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1002']);
    });

    test('unknown action does not mutate state', () async {
      final before = [_channel(1001, 'A')];
      notifier.state = notifier.state.copyWith(channels: before);

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '9999',
          action: 'something_unrelated',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1001']);
    });

    test('channel_unsubscribed for an id not in the list is a no-op', () async {
      final before = [_channel(1001, 'A'), _channel(1002, 'B')];
      notifier.state = notifier.state.copyWith(channels: before);

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '9999',
          action: 'channel_unsubscribed',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1001', '1002']);
    });
  });

  test('并发订阅列表刷新复用同一个 in-flight 请求', () async {
    final api = _MockChannelApi();
    final gate = Completer<ChannelPageResult<ChannelModel>>();
    when(
      () => api.getSubscribedChannelsPage(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => gate.future);

    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    final first = notifier.loadSubscribedChannels();
    final second = notifier.loadSubscribedChannels();
    expect(identical(first, second), isTrue);
    verify(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .called(1);

    gate.complete(
      const ChannelPageResult<ChannelModel>(
        list: [],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await Future.wait([first, second]);
  });

  test('订阅与管理请求反序返回时各自保留列表', () async {
    final api = _MockChannelApi();
    final subscribed = Completer<ChannelPageResult<ChannelModel>>();
    final managed = Completer<List<ChannelModel>>();
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => subscribed.future);
    when(() => api.getManagedChannels()).thenAnswer((_) => managed.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final subLoad = notifier.loadSubscribedChannels();
    final managedLoad = notifier.loadManagedChannels();
    managed.complete([_channel(20, 'managed')]);
    await managedLoad;
    subscribed.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'subscribed')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await subLoad;
    final result = container.read(channelListProvider);
    expect(result.channels.map((c) => c.id), ['10']);
    expect(result.managed.channels.map((c) => c.id), ['20']);
  });

  test('退订事件后迟到的旧订阅响应不能恢复频道', () async {
    final api = _MockChannelApi();
    final first = Completer<ChannelPageResult<ChannelModel>>();
    final second = Completer<ChannelPageResult<ChannelModel>>();
    var calls = 0;
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final load = notifier.loadSubscribedChannels();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '10',
        action: 'channel_unsubscribed',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    first.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'old')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await load;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(channelListProvider).channels, isEmpty);
    expect(calls, 2);
    second.complete(
      const ChannelPageResult<ChannelModel>(
        list: [],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(channelListProvider).channels, isEmpty);
  });

  test('切换账号后，旧账号迟到响应不能覆盖新账号列表', () async {
    final oldAccount = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, 'account-a');
    addTearDown(
      () async => StorageService.to.setString(Keys.currentUid, oldAccount),
    );
    final api = _MockChannelApi();
    final first = Completer<ChannelPageResult<ChannelModel>>();
    final second = Completer<ChannelPageResult<ChannelModel>>();
    var calls = 0;
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final oldLoad = notifier.loadSubscribedChannels();
    await StorageService.to.setString(Keys.currentUid, 'account-b');
    final newLoad = notifier.loadSubscribedChannels();
    second.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(20, 'new account')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await newLoad;
    first.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'old account')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await oldLoad;
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '20',
    ]);
  });

  test('管理列表首屏请求期间收到删除事件会重拉剩余列表', () async {
    final api = _MockChannelApi();
    final old = Completer<List<ChannelModel>>();
    final fresh = Completer<List<ChannelModel>>();
    var calls = 0;
    when(() => api.getManagedChannels())
        .thenAnswer((_) => ++calls == 1 ? old.future : fresh.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final load = container
        .read(channelListProvider.notifier)
        .loadManagedChannels();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '10',
        action: 'channel_deleted',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    old.complete([_channel(10, 'deleted'), _channel(20, 'remaining')]);
    await load;
    expect(calls, 2);
    fresh.complete([_channel(20, 'remaining')]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      container.read(channelListProvider).managed.channels.map((c) => c.id),
      ['20'],
    );
  });

  test('认证退出意图立即清空列表并阻止旧请求回写', () async {
    final isolated = await Directory.systemTemp.createTemp(
      'channel_auth_test_',
    );
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _IsolatedPathProvider(isolated.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPaths;
      if (await isolated.exists()) await isolated.delete(recursive: true);
    });
    final oldAccount = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, 'session-user');
    addTearDown(
      () async => StorageService.to.setString(Keys.currentUid, oldAccount),
    );
    final api = _MockChannelApi();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final oldDb = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(oldDb);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      if (oldDb.isOpen) await oldDb.close();
    });
    final networkStarted = Completer<void>();
    final networkGate = Completer<List<ChannelMessageModel>>();
    when(() => api.getMessages(channelId: '10', cursor: null, limit: 20))
        .thenAnswer((_) {
          networkStarted.complete();
          return networkGate.future;
        });
    final boundService = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      outboxRepo: ChannelMessageOutboxRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      bindPublishDatabase: true,
    );
    final networkLoad = boundService.getMessages(channelId: '10');
    await networkStarted.future;
    final gate = Completer<ChannelPageResult<ChannelModel>>();
    final messageGate = Completer<ChannelPageResult<ChannelMessageModel>>();
    final publishGate = Completer<ChannelMessageModel?>();
    final publishOutbox = _MockPublishOutbox();
    final channelGate = Completer<ChannelModel?>();
    final cacheRepo = _MockChannelRepo();
    final messageRepo = _MockMessageRepo();
    final messageOutbox = _MockMessageOutbox();
    final secondOutbox = _MockPublishOutbox();
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => gate.future);
    when(() => api.getMessagesPage(channelId: '10', cursor: null, limit: 20))
        .thenAnswer((_) => messageGate.future);
    when(
      () => api.publishMessage(
        channelId: '10',
        content: 'draft',
        msgType: 'channel_text',
        payload: null,
        requestId: 'request-a',
      ),
    ).thenAnswer((_) => publishGate.future);
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      publishOutboxRepo: publishOutbox,
    );
    final publishing = service.publishMessage(
      channelId: '10',
      content: 'draft',
      msgType: 'channel_text',
      requestId: 'request-a',
    );
    when(
      () => api.publishMessage(
        channelId: '10',
        content: 'other',
        msgType: 'channel_text',
        payload: null,
        requestId: 'request-b',
      ),
    ).thenAnswer(
      (_) async => ChannelMessageModel(
        id: 98,
        channelId: 10,
        content: 'other',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    when(() => secondOutbox.remove('request-b')).thenAnswer((_) async {});
    when(() => cacheRepo.getChannel('10'))
        .thenAnswer((_) => channelGate.future);
    final secondService = ChannelService.forTest(
      api: api,
      repo: cacheRepo,
      messageRepo: messageRepo,
      outboxRepo: messageOutbox,
      publishOutboxRepo: secondOutbox,
    );
    final caching = secondService.publishMessage(
      channelId: '10',
      content: 'other',
      msgType: 'channel_text',
      requestId: 'request-b',
    );
    await Future<void>.delayed(Duration.zero);
    verify(() => cacheRepo.getChannel('10')).called(1);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    container.listen(channelDetailProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final detail = container.read(channelDetailProvider.notifier);
    detail.debugSetChannelId('10');
    detail.state = ChannelDetailState(channel: _channel(10, 'private'));
    final messageLoad = detail.loadMessages('10');
    notifier.state = ChannelListState(channels: [_channel(10, 'sensitive')]);
    final load = notifier.loadSubscribedChannels();
    final logout = UserRepoLocal.to.quitLogin();
    addTearDown(() async => logout);
    channelGate.complete(_channel(10, 'old account'));
    expect(await caching, isNull);
    verifyZeroInteractions(messageRepo);
    verifyZeroInteractions(messageOutbox);
    publishGate.complete(
      ChannelMessageModel(
        id: 99,
        channelId: 10,
        content: 'draft',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    expect(await publishing, isNull);
    verifyZeroInteractions(publishOutbox);
    expect(container.read(channelListProvider).channels, isEmpty);
    expect(container.read(channelDetailProvider).channel, isNull);
    messageGate.complete(
      ChannelPageResult<ChannelMessageModel>(
        list: [
          ChannelMessageModel(
            id: 1,
            channelId: 10,
            content: 'private',
            msgType: 'channel_text',
            createdAt: DateTime.utc(2026),
          ),
        ],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await messageLoad;
    expect(container.read(channelDetailProvider).messages, isEmpty);
    gate.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'stale')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await load;
    expect(container.read(channelListProvider).channels, isEmpty);
    await logout;
    await StorageService.to.setString(Keys.currentUid, 'session-user-b');
    final newDb = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(newDb);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      if (newDb.isOpen) await newDb.close();
    });
    networkGate.complete([
      ChannelMessageModel(
        id: 200,
        channelId: 10,
        content: 'old account',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    ]);
    expect(await networkLoad, isEmpty);
    expect(await newDb.query('channel_message'), isEmpty);
    expect(await newDb.query(ChannelMessageOutboxRepo.tableName), isEmpty);
  });
}
