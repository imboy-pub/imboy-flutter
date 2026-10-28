import 'dart:async';

import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/component/http/http_exceptions.dart' as http;

ChannelMessageModel _buildMessage({required int id, bool pinned = false}) {
  return ChannelMessageModel(
    id: id,
    channelId: 1001,
    content: 'hello',
    msgType: 'channel_text',
    createdAt: DateTime.now(),
    isPinned: pinned,
  );
}

void main() {
  test('自定义地址缓存写入等待期间删除不会恢复页面', () async {
    final api = _AliasApi();
    final service = _BlockingAliasService();
    final container = ProviderContainer(
      overrides: [
        channelApiProvider.overrideWithValue(api),
        channelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final load = container
        .read(channelDetailProvider.notifier)
        .loadChannel('alpha');
    await _flushCursorFutures();
    api.responses['alpha']!.complete(_cursorChannel(41));
    await service.started.future;
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '41',
        action: 'channel_deleted',
        payload: const {},
      ),
    );
    await _flushCursorFutures();
    service.release.complete();
    await load;
    expect(container.read(channelDetailProvider).channel, isNull);
    expect(container.read(channelDetailProvider).messages, isEmpty);
    expect(container.read(channelDetailProvider).error, isNotNull);
  });

  test('自定义地址解析期间收到数值 ID 删除后不缓存旧结果', () async {
    final api = _AliasApi();
    final service = _AliasService();
    final container = ProviderContainer(
      overrides: [
        channelApiProvider.overrideWithValue(api),
        channelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final load = container
        .read(channelDetailProvider.notifier)
        .loadChannel('alpha');
    await _flushCursorFutures();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '41',
        action: 'channel_deleted',
        payload: const {},
      ),
    );
    await _flushCursorFutures();
    api.responses['alpha']!.complete(_cursorChannel(41));
    await load;
    expect(container.read(channelDetailProvider).channel, isNull);
    expect(container.read(channelDetailProvider).error, isNotNull);
    expect(service.saved, isEmpty);
  });

  test('删除事件使在途详情和消息响应失效', () async {
    final api = _DeferredCursorApi();
    final service = _DeferredChannelService();
    final container = ProviderContainer(
      overrides: [
        channelApiProvider.overrideWithValue(api),
        channelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    service.cache['41']!.complete(_cursorChannel(41));
    final load = container
        .read(channelDetailProvider.notifier)
        .loadChannel('41');
    final request = await _cursorRequest(api, 0, channelId: '41', cursor: null);
    request.result.complete(_cursorPage(41, [1], next: null));
    await _flushCursorFutures();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '41',
        action: 'channel_deleted',
        payload: const {},
      ),
    );
    await _flushCursorFutures();
    service.details['41']!.complete(_cursorChannel(41));
    await load;
    final state = container.read(channelDetailProvider);
    expect(state.channel, isNull);
    expect(state.messages, isEmpty);
    expect(state.error, isNotNull);
  });

  test('初始缓存尚未返回时删除事件也使请求失效', () async {
    final service = _DeferredChannelService();
    final container = ProviderContainer(
      overrides: [channelServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final load = container
        .read(channelDetailProvider.notifier)
        .loadChannel('41');
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '41',
        action: 'channel_deleted',
        payload: const {},
      ),
    );
    await _flushCursorFutures();
    service.cache['41']!.complete(_cursorChannel(41));
    await load;
    expect(container.read(channelDetailProvider).channel, isNull);
    expect(container.read(channelDetailProvider).error, isNotNull);
    expect(service.detailRequests, isEmpty);
  });

  for (final code in [1, 403, 503]) {
    test('自定义地址错误 $code 展示失败态', () async {
      final api = _AliasApi();
      final service = _AliasService();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final load = container
          .read(channelDetailProvider.notifier)
          .loadChannel('alpha');
      await _flushCursorFutures();
      api.responses['alpha']!.completeError(
        http.BadRequestException(code: code, message: 'failure'),
      );
      await load;
      final state = container.read(channelDetailProvider);
      expect(state.channel, isNull);
      expect(state.error, isNotNull);
      expect(service.saved, isEmpty);
    });
  }

  test('自定义地址旧响应不能覆盖新频道或写入缓存', () async {
    final api = _AliasApi();
    final service = _AliasService();
    final container = ProviderContainer(
      overrides: [
        channelApiProvider.overrideWithValue(api),
        channelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final notifier = container.read(channelDetailProvider.notifier);
    final first = notifier.loadChannel('alpha');
    await _flushCursorFutures();
    final second = notifier.loadChannel('beta');
    await _flushCursorFutures();
    api.responses['beta']!.complete(_cursorChannel(42));
    await second;
    api.responses['alpha']!.complete(_cursorChannel(41));
    await first;
    expect(container.read(channelDetailProvider).channel?.id, '42');
    expect(service.saved.map((channel) => channel.id), ['42']);
  });

  for (final code in [-1, 1, 403, 404, 503]) {
    test('个人频道刷新状态 $code 区分失效与暂不可用', () async {
      final api = _DeferredCursorApi();
      final service = _DeferredChannelService();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      service.cache['41']!.complete(_cursorChannel(41));
      final load = container
          .read(channelDetailProvider.notifier)
          .loadChannel('41');
      final request = await _cursorRequest(
        api,
        0,
        channelId: '41',
        cursor: null,
      );
      request.result.complete(_cursorPage(41, [1], next: null));
      await _flushCursorFutures();
      service.details['41']!.completeError(
        code == -1
            ? http.NetworkException(message: 'offline')
            : http.BadRequestException(code: code, message: 'unavailable'),
      );
      await load;
      final state = container.read(channelDetailProvider);
      if (code == 503 || code == -1) {
        expect(state.channel?.id, '41');
        expect(state.messages, hasLength(1));
      } else {
        expect(state.channel, isNull);
        expect(state.messages, isEmpty);
        expect(state.error, isNotNull);
      }
    });
  }

  test('同频道刷新读取失败后旧发布结果不能覆盖错误态', () async {
    final service = _DeferredPublishService();
    final container = ProviderContainer(
      overrides: [channelServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final notifier = container.read(channelDetailProvider.notifier);
    notifier.debugSetChannelId('41');
    notifier.state = ChannelDetailState(
      channel: ChannelModel(
        id: 41,
        scope: 'personal',
        name: 'A',
        creatorId: 1,
        userRole: ChannelUserRole.creator,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final publish = notifier.publishMessage(
      content: 'old',
      msgType: 'channel_text',
    );
    final load = notifier.loadChannel('41');
    service.cache['41']!.completeError(StateError('database unavailable'));
    await load;
    service.publish.complete(_buildMessage(id: 1));
    expect(await publish, isFalse);
    expect(container.read(channelDetailProvider).messages, isEmpty);
    expect(container.read(channelDetailProvider).error, isNotNull);
  });

  test('详情本地读取失败时退出加载并显示错误', () async {
    final service = _DeferredChannelService();
    final container = ProviderContainer(
      overrides: [channelServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final loading = container
        .read(channelDetailProvider.notifier)
        .loadChannel('41');
    service.cache['41']!.completeError(StateError('database unavailable'));
    await loading;
    final state = container.read(channelDetailProvider);
    expect(state.isLoading, isFalse);
    expect(state.channel, isNull);
    expect(state.error, isNotNull);
  });

  test('工作区频道刷新开始时不保留旧受保护内容', () async {
    final service = _DeferredChannelService();
    final container = ProviderContainer(
      overrides: [channelServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final notifier = container.read(channelDetailProvider.notifier);
    notifier.debugSetChannelId('41');
    notifier.state = ChannelDetailState(
      channel: ChannelModel(
        id: 41,
        scope: 'workspace',
        name: 'private',
        creatorId: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      messages: [_buildMessage(id: 1)],
    );
    final load = notifier.loadChannel('41');
    expect(container.read(channelDetailProvider).channel, isNull);
    expect(container.read(channelDetailProvider).messages, isEmpty);
    service.cache['41']!.complete(
      ChannelModel(
        id: 41,
        scope: 'workspace',
        name: 'private',
        creatorId: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await _flushCursorFutures();
    service.details['41']!.complete(null);
    await load;
  });

  for (final scope in [null, 'workspace']) {
    test('来源为 $scope 的缓存未经校验不展示', () async {
      final api = _DeferredCursorApi();
      final service = _DeferredChannelService();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      service.cache['41']!.complete(
        ChannelModel(
          id: 41,
          scope: scope,
          workspaceId: scope == 'workspace' ? '1' : null,
          name: 'private',
          creatorId: 1,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final loading = container
          .read(channelDetailProvider.notifier)
          .loadChannel('41');
      await _flushCursorFutures();
      expect(service.detailRequests, ['41']);
      expect(container.read(channelDetailProvider).channel, isNull);
      expect(container.read(channelDetailProvider).messages, isEmpty);
      expect(api.requests, isEmpty);
      service.details['41']!.complete(null);
      await loading;
      expect(container.read(channelDetailProvider).channel, isNull);
      expect(container.read(channelDetailProvider).error, isNotNull);
    });
  }

  test('自定义频道地址匹配已解析的频道后可发布', () async {
    final service = _DeferredPublishService();
    final container = ProviderContainer(
      overrides: [channelServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final notifier = container.read(channelDetailProvider.notifier);
    notifier.debugSetChannelId('41');
    notifier.state = ChannelDetailState(
      channel: ChannelModel(
        id: 41,
        customId: 'news',
        name: 'A',
        creatorId: 1,
        userRole: ChannelUserRole.creator,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final result = notifier.publishMessage(
      content: 'post',
      msgType: 'channel_text',
      expectedChannelId: 'news',
    );
    service.publish.complete(_buildMessage(id: 10));
    expect(await result, isTrue);
  });

  test('切换频道立即清除旧内容，旧发布结果不写入新页面', () async {
    final api = _DeferredCursorApi();
    final service = _DeferredPublishService();
    final container = ProviderContainer(
      overrides: [
        channelApiProvider.overrideWithValue(api),
        channelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final notifier = container.read(channelDetailProvider.notifier);
    notifier.debugSetChannelId('41');
    notifier.state = ChannelDetailState(
      channel: ChannelModel(
        id: 41,
        name: 'A',
        creatorId: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        userRole: ChannelUserRole.creator,
      ),
      messages: [_buildMessage(id: 1)],
    );
    final publish = notifier.publishMessage(
      content: 'old',
      msgType: 'channel_text',
    );
    final loadB = notifier.loadChannel('42');
    expect(container.read(channelDetailProvider).channel, isNull);
    expect(container.read(channelDetailProvider).messages, isEmpty);
    service.publish.complete(_buildMessage(id: 2));
    expect(await publish, isFalse);
    service.cache['42']!.complete(_cursorChannel(42));
    final cached = await _cursorRequest(api, 0, channelId: '42', cursor: null);
    cached.result.complete(_cursorPage(42, [3], next: null));
    await _flushCursorFutures();
    service.details['42']!.complete(_cursorChannel(42));
    final refreshed = await _cursorRequest(
      api,
      1,
      channelId: '42',
      cursor: null,
    );
    refreshed.result.complete(_cursorPage(42, [3], next: null));
    await loadB;
    expect(container.read(channelDetailProvider).channel?.id, '42');
    expect(
      container
          .read(channelDetailProvider)
          .messages
          .map((m) => int.parse(m.id)),
      [3],
    );
  });

  test(
    'TZ05 old more lock neither blocks B page2 nor unlocks B in-flight more',
    () async {
      final api = _DeferredCursorApi();
      final service = _DeferredChannelService();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final notifier = container.read(channelDetailProvider.notifier);
      notifier.debugSetChannelId('41');
      final firstA = notifier.loadMessages('41');
      api.requests[0].result.complete(_cursorPage(41, [1], next: 'A-next'));
      await firstA;
      final oldMore = notifier.loadMoreMessages();
      final oldARequest = await _cursorRequest(
        api,
        1,
        channelId: '41',
        cursor: 'A-next',
      );
      service.cache['42']!.complete(_cursorChannel(42));
      final loadB = notifier.loadChannel('42');
      final cachedB = await _cursorRequest(
        api,
        2,
        channelId: '42',
        cursor: null,
      );
      cachedB.result.complete(
        _cursorPage(42, List.generate(20, (i) => 25 - i), next: 'B-next'),
      );
      await _flushCursorFutures();
      expect(service.detailRequests, ['42']);
      service.details['42']!.complete(_cursorChannel(42));
      final refreshedB = await _cursorRequest(
        api,
        3,
        channelId: '42',
        cursor: null,
      );
      refreshedB.result.complete(
        _cursorPage(42, List.generate(20, (i) => 25 - i), next: 'B-next'),
      );
      await loadB;
      final moreB = notifier.loadMoreMessages();
      final bPage2 = await _cursorRequest(
        api,
        4,
        channelId: '42',
        cursor: 'B-next',
      );
      expect(
        oldARequest.result.isCompleted,
        isFalse,
        reason:
            'B page2 must start while A still owns its old in-flight request',
      );
      oldARequest.result.complete(_cursorPage(41, [0], next: null));
      await oldMore; // old finally must leave B page2's lock owned by B
      expect(bPage2.result.isCompleted, isFalse);
      await notifier.loadMoreMessages();
      expect(
        api.requests.length,
        5,
        reason: 'old finally must not release B active lock',
      );
      bPage2.result.complete(_cursorPage(42, [5, 4, 3, 2, 1], next: null));
      await moreB;
      final ids = container
          .read(channelDetailProvider)
          .messages
          .map((m) => int.parse(m.id))
          .toList();
      expect(ids, List.generate(25, (i) => 25 - i));
      expect(ids.toSet().length, 25);
    },
  );

  test(
    'TZ05 refresh generation can page while older more remains pending',
    () async {
      final api = _DeferredCursorApi();
      final container = ProviderContainer(
        overrides: [channelApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final notifier = container.read(channelDetailProvider.notifier);
      notifier.debugSetChannelId('42');
      final first = notifier.loadMessages('42');
      api.requests[0].result.complete(_cursorPage(42, [2], next: 'old-next'));
      await first;
      final oldMore = notifier.loadMoreMessages();
      final refresh = notifier.loadMessages('42');
      api.requests[2].result.complete(_cursorPage(42, [4], next: 'fresh-next'));
      await refresh;
      final freshMore = notifier.loadMoreMessages();
      expect(api.requests.length, 4);
      expect(api.requests[3].cursor, 'fresh-next');
      api.requests[1].result.complete(_cursorPage(42, [1], next: null));
      await oldMore;
      await notifier.loadMoreMessages();
      expect(api.requests.length, 4);
      api.requests[3].result.complete(_cursorPage(42, [3], next: null));
      await freshMore;
      expect(
        container
            .read(channelDetailProvider)
            .messages
            .map((m) => int.parse(m.id)),
        [4, 3],
      );
    },
  );

  for (final lateStage in ['cache', 'details', 'message']) {
    test(
      'TZ05 stale A $lateStage cannot overwrite B or restart A messages',
      () async {
        final api = _DeferredCursorApi();
        final service = _DeferredChannelService();
        final container = ProviderContainer(
          overrides: [
            channelApiProvider.overrideWithValue(api),
            channelServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        _watchCursorProvider(container);
        final notifier = container.read(channelDetailProvider.notifier);
        if (lateStage != 'cache') {
          service.cache['41']!.complete(_cursorChannel(41));
        }
        final a = notifier.loadChannel('41');
        _DeferredCursorRequest? aRequest;
        if (lateStage != 'cache') {
          aRequest = await _cursorRequest(
            api,
            0,
            channelId: '41',
            cursor: null,
          );
        }
        if (lateStage == 'details') {
          aRequest!.result.complete(_cursorPage(41, [1], next: null));
          await _flushCursorFutures();
          expect(service.detailRequests, ['41']);
        }
        service.cache['42']!.complete(_cursorChannel(42));
        final b = notifier.loadChannel('42');
        final firstBIndex = lateStage == 'cache' ? 0 : 1;
        final cachedB = await _cursorRequest(
          api,
          firstBIndex,
          channelId: '42',
          cursor: null,
        );
        cachedB.result.complete(
          _cursorPage(42, List.generate(20, (i) => 25 - i), next: 'B-next'),
        );
        await _flushCursorFutures();
        expect(
          service.detailRequests,
          lateStage == 'details' ? ['41', '42'] : ['42'],
        );
        service.details['42']!.complete(_cursorChannel(42));
        final refreshedB = await _cursorRequest(
          api,
          firstBIndex + 1,
          channelId: '42',
          cursor: null,
        );
        refreshedB.result.complete(
          _cursorPage(42, List.generate(20, (i) => 25 - i), next: 'B-next'),
        );
        await b;
        final requestCount = api.requests.length;
        if (lateStage == 'cache') {
          service.cache['41']!.complete(_cursorChannel(41));
        } else if (lateStage == 'details') {
          service.details['41']!.complete(_cursorChannel(41));
        } else {
          aRequest!.result.complete(_cursorPage(41, [1], next: 'A-next'));
        }
        await a;
        expect(api.requests.length, requestCount);
        expect(container.read(channelDetailProvider).channel?.id, '42');
        expect(
          service.detailRequests.where((id) => id == '41').length,
          lateStage == 'details' ? 1 : 0,
        );
        final more = notifier.loadMoreMessages();
        final bPage2 = await _cursorRequest(
          api,
          firstBIndex + 2,
          channelId: '42',
          cursor: 'B-next',
        );
        bPage2.result.complete(_cursorPage(42, [5, 4, 3, 2, 1], next: null));
        await more;
        final ids = container
            .read(channelDetailProvider)
            .messages
            .map((m) => int.parse(m.id))
            .toList();
        expect(ids, List.generate(25, (i) => 25 - i));
        expect(ids.toSet().length, 25);
        expect(container.read(channelDetailProvider).hasMore, isFalse);
      },
    );
  }

  test('TZ05 concurrent refresh drops older first-page and late load-more responses', () async {
    final api = _DeferredCursorApi();
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    _watchCursorProvider(container);
    final notifier = container.read(channelDetailProvider.notifier);
    notifier.debugSetChannelId('42');
    final oldRefresh = notifier.loadMessages('42');
    final newRefresh = notifier.loadMessages('42');
    api.requests[1].result.complete(
      _cursorPage(42, [25, 24], next: 'new-next'),
    );
    await newRefresh;
    api.requests[0].result.complete(_cursorPage(42, [99], next: 'old-next'));
    await oldRefresh;
    final more = notifier.loadMoreMessages();
    final refresh = notifier.loadMessages('42');
    expect(api.requests.last.cursor, isNull);
    api.requests.last.result.complete(_cursorPage(42, [100], next: null));
    await refresh;
    api.requests[2].result.complete(_cursorPage(42, [23], next: null));
    await more;
    expect(
      container
          .read(channelDetailProvider)
          .messages
          .map((m) => int.parse(m.id)),
      [100],
    );
    expect(container.read(channelDetailProvider).hasMore, isFalse);
  });

  test(
    'TZ05 provider uses opaque cursor, terminal null and refresh reset',
    () async {
      final api = _CursorChannelApi();
      final container = ProviderContainer(
        overrides: [channelApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final notifier = container.read(channelDetailProvider.notifier);
      notifier.debugSetChannelId('42');
      await notifier.loadMessages('42');
      await notifier.loadMoreMessages();
      expect(api.requests.map((r) => r.cursor), [null, 'opaque-boundary']);
      expect(
        container
            .read(channelDetailProvider)
            .messages
            .map((m) => int.parse(m.id)),
        List.generate(25, (i) => 25 - i),
      );
      expect(container.read(channelDetailProvider).hasMore, isFalse);
      await notifier.loadMoreMessages();
      expect(api.requests.length, 2);
      await notifier.loadMessages('42');
      expect(api.requests.last.cursor, isNull);
      notifier.debugSetChannelId('43');
      await notifier.loadMessages('43');
      expect(api.requests.last, (channel: '43', cursor: null));
      expect(container.read(channelDetailProvider).messages.length, 20);
    },
  );

  group('ChannelDetailNotifier local updates', () {
    late ProviderContainer container;
    late ChannelDetailNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(channelDetailProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('updateMessagePinned pins only the targeted message (off→on)', () {
      // 旧用例两条消息都 pinned=true 收尾，无法区分「只动目标」与
      // 「全部标记置顶」两种实现 —— 断言在 bug 版本上也会通过。
      // 此处让 messageB 保持 pinned=false 作为控制组，强制验证隔离性。
      final messageA = _buildMessage(id: 1, pinned: false);
      final messageB = _buildMessage(id: 2, pinned: false);
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.updateMessagePinned('1', true);

      final state = container.read(channelDetailProvider);
      expect(
        state.messages.firstWhere((msg) => msg.id == '1').isPinned,
        isTrue,
        reason: '目标消息必须被置顶',
      );
      expect(
        state.messages.firstWhere((msg) => msg.id == '2').isPinned,
        isFalse,
        reason: '非目标消息不得被改动（隔离性）',
      );
    });

    test('updateMessagePinned unpins only the targeted message (on→off)', () {
      // 对称方向：确认取消置顶不会误伤其他已置顶消息。
      final messageA = _buildMessage(id: 1, pinned: true);
      final messageB = _buildMessage(id: 2, pinned: true);
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.updateMessagePinned('1', false);

      final state = container.read(channelDetailProvider);
      expect(
        state.messages.firstWhere((msg) => msg.id == '1').isPinned,
        isFalse,
      );
      expect(
        state.messages.firstWhere((msg) => msg.id == '2').isPinned,
        isTrue,
        reason: '取消置顶只能影响目标消息',
      );
    });

    test('updateMessagePinned is a no-op when messageId is not found', () {
      final messageA = _buildMessage(id: 1, pinned: false);
      notifier.state = notifier.state.copyWith(messages: [messageA]);

      notifier.updateMessagePinned('9999', true);

      final state = container.read(channelDetailProvider);
      expect(
        state.messages.single.isPinned,
        isFalse,
        reason: '不存在的 id 不得误改现有消息',
      );
    });

    test(
      'updateMessageReaction syncs like count and my reaction only on target',
      () {
        final messageA = _buildMessage(id: 1)
            .copyWith(reactionSummary: {ChannelReactionType.like: 2});
        final messageB = _buildMessage(id: 2)
            .copyWith(reactionSummary: {ChannelReactionType.like: 7});
        notifier.state = notifier.state.copyWith(
          messages: [messageA, messageB],
        );

        notifier.updateMessageReaction('1', true, 3);

        final state = container.read(channelDetailProvider);
        final updatedA = state.messages.firstWhere((msg) => msg.id == '1');
        final unchangedB = state.messages.firstWhere((msg) => msg.id == '2');
        expect(updatedA.reactionSummary?[ChannelReactionType.like], 3);
        expect(updatedA.myReactions, contains(ChannelReactionType.like));
        expect(unchangedB.reactionSummary?[ChannelReactionType.like], 7);
        expect(unchangedB.myReactions, isEmpty);
      },
    );

    test(
      'updateMessageReaction removes like from target without affecting others',
      () {
        final messageA = _buildMessage(id: 1).copyWith(
          reactionSummary: {ChannelReactionType.like: 3},
          myReactions: [ChannelReactionType.like],
        );
        final messageB = _buildMessage(id: 2).copyWith(
          reactionSummary: {ChannelReactionType.like: 4},
          myReactions: [ChannelReactionType.like],
        );
        notifier.state = notifier.state.copyWith(
          messages: [messageA, messageB],
        );

        notifier.updateMessageReaction('1', false, 2);

        final state = container.read(channelDetailProvider);
        final updatedA = state.messages.firstWhere((msg) => msg.id == '1');
        final unchangedB = state.messages.firstWhere((msg) => msg.id == '2');
        expect(updatedA.reactionSummary?[ChannelReactionType.like], 2);
        expect(updatedA.myReactions, isNot(contains(ChannelReactionType.like)));
        expect(unchangedB.reactionSummary?[ChannelReactionType.like], 4);
        expect(unchangedB.myReactions, contains(ChannelReactionType.like));
      },
    );

    test('removeMessageLocally drops the targeted message only', () {
      final messageA = _buildMessage(id: 1);
      final messageB = _buildMessage(id: 2);
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.removeMessageLocally('1');

      final state = container.read(channelDetailProvider);
      expect(state.messages.length, 1);
      expect(state.messages.single.id, '2');
    });

    test('handleMessageDeletedEvent removes matching channel message', () {
      final message = _buildMessage(id: 1);
      notifier.state = notifier.state.copyWith(messages: [message]);
      notifier.debugSetChannelId('1001');

      notifier.handleMessageDeletedEvent(
        const ChannelMessageDeletedEvent(
          channelId: '1001',
          messageId: '1',
          reason: 'deleted',
        ),
      );

      final state = container.read(channelDetailProvider);
      expect(state.messages, isEmpty);
    });

    test('handleMessageDeletedEvent ignores other channels', () {
      final message = _buildMessage(id: 1);
      notifier.state = notifier.state.copyWith(messages: [message]);
      notifier.debugSetChannelId('1001');

      notifier.handleMessageDeletedEvent(
        const ChannelMessageDeletedEvent(
          channelId: '9999',
          messageId: '1',
          reason: 'deleted',
        ),
      );

      final state = container.read(channelDetailProvider);
      expect(state.messages.length, 1);
    });
  });

  group('ChannelDetailNotifier publish permission guard', () {
    late ProviderContainer container;
    late ChannelDetailNotifier notifier;

    ChannelModel buildChannel(ChannelUserRole role) {
      return ChannelModel(
        id: 1001,
        name: 'Test',
        creatorId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userRole: role,
      );
    }

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(channelDetailProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('publishMessage returns false when user role is subscriber', () async {
      notifier.debugSetChannelId('1001');
      notifier.state = notifier.state.copyWith(
        channel: buildChannel(ChannelUserRole.subscriber),
      );

      final result = await notifier.publishMessage(
        content: 'hi',
        msgType: 'channel_text',
      );

      expect(result, isFalse);
      // State must not flip to isPublishing; no network call should be attempted.
      expect(container.read(channelDetailProvider).isPublishing, isFalse);
      expect(container.read(channelDetailProvider).messages, isEmpty);
    });

    test('页面目标与共享频道不一致时不发布', () async {
      notifier.debugSetChannelId('1002');
      notifier.state = notifier.state.copyWith(
        channel: buildChannel(ChannelUserRole.creator),
      );
      final result = await notifier.publishMessage(
        content: 'draft',
        msgType: 'channel_text',
        expectedChannelId: '1001',
      );
      expect(result, isFalse);
      expect(container.read(channelDetailProvider).isPublishing, isFalse);
    });

    test('publishMessage returns false when user role is none', () async {
      notifier.debugSetChannelId('1001');
      notifier.state = notifier.state.copyWith(
        channel: buildChannel(ChannelUserRole.none),
      );

      final result = await notifier.publishMessage(
        content: 'hi',
        msgType: 'channel_text',
      );

      expect(result, isFalse);
      expect(container.read(channelDetailProvider).isPublishing, isFalse);
    });

    test('publishMessage short-circuits before toggling isPublishing '
        'for non-publishing roles', () async {
      notifier.debugSetChannelId('1001');
      notifier.state = notifier.state.copyWith(
        channel: buildChannel(ChannelUserRole.subscriber),
      );

      // If the guard is missing, the notifier would set isPublishing=true,
      // attempt a network call, and then reset it. We assert the state
      // never transitions through isPublishing=true.
      bool sawPublishing = false;
      final sub = container.listen<ChannelDetailState>(channelDetailProvider, (
        _,
        next,
      ) {
        if (next.isPublishing) sawPublishing = true;
      });
      addTearDown(sub.close);

      await notifier.publishMessage(content: 'hi', msgType: 'channel_text');

      expect(
        sawPublishing,
        isFalse,
        reason: 'Guard must reject before mutating isPublishing',
      );
    });
  });

  group('叠页目标快照（J07 页面归属隔离）', () {
    test('切换目标前保存快照，返回原目标立即恢复内容', () async {
      final service = _SnapshotSwitchService();
      final api = _SnapshotSwitchApi();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final notifier = container.read(channelDetailProvider.notifier);

      // 1. 加载 A（personal）：state 达成 A 内容。
      await notifier.loadChannel('11');
      expect(container.read(channelDetailProvider).channel?.id, '11');

      // 2. 切到 B：切换瞬间同步保存 A 快照，state 离开 A（B 不存在，
      //    flush 后会推进到 error 态，故归属断言必须在同步段完成）。
      final loadB = notifier.loadChannel('22');
      expect(
        notifier.debugSnapshotFor('11')?.channel?.id,
        '11',
        reason: '切换目标前必须保存 A 的完整状态',
      );
      // B 无快照 → 恢复加载态而非 A 的内容。
      expect(container.read(channelDetailProvider).channel, isNull);
      expect(container.read(channelDetailProvider).isLoading, isTrue);
      await loadB;
      await _flushCursorFutures();

      // 3. 返回 A：恢复快照同步生效（首个 await 之前 state 即为 A 内容）。
      final loadA = notifier.loadChannel('11');
      expect(
        container.read(channelDetailProvider).channel?.id,
        '11',
        reason: '返回原目标必须立即恢复快照，不能闪清空/B 内容',
      );
      expect(container.read(channelDetailProvider).isLoading, isFalse);
      await loadA;
      expect(container.read(channelDetailProvider).channel?.id, '11');
    });

    test('workspace 目标不落快照（受保护内容不做离线恢复）', () async {
      final service = _SnapshotSwitchService();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(_SnapshotSwitchApi()),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final notifier = container.read(channelDetailProvider.notifier);

      await notifier.loadChannel('33');
      expect(container.read(channelDetailProvider).channel?.id, '33');
      final loadB = notifier.loadChannel('22');
      await _flushCursorFutures();
      expect(
        notifier.debugSnapshotFor('33'),
        isNull,
        reason: 'workspace scope 按 C3 不允许快照恢复',
      );
      await loadB;
      await _flushCursorFutures();
    });

    test('频道删除事件使对应快照失效', () async {
      final service = _SnapshotSwitchService();
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(_SnapshotSwitchApi()),
          channelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      _watchCursorProvider(container);
      final notifier = container.read(channelDetailProvider.notifier);

      await notifier.loadChannel('11');
      notifier.debugSeedSnapshot('11', container.read(channelDetailProvider));
      expect(notifier.debugSnapshotFor('11')?.channel?.id, '11');

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '11',
          action: 'channel_deleted',
          payload: const {},
        ),
      );
      await _flushCursorFutures();
      expect(
        notifier.debugSnapshotFor('11'),
        isNull,
        reason: '删除事件后快照不得再恢复已删频道',
      );
    });
  });
}

class _CursorChannelApi extends ChannelApi {
  final requests = <({String channel, String? cursor})>[];
  @override
  Future<ChannelPageResult<ChannelMessageModel>> getMessagesPage({
    required String channelId,
    String? cursor,
    int limit = 20,
  }) async {
    requests.add((channel: channelId, cursor: cursor));
    final first = cursor == null;
    final count = first ? 20 : 5;
    return ChannelPageResult(
      list: List.generate(
        count,
        (i) => _buildMessage(id: first ? 25 - i : 5 - i),
      ),
      nextCursor: first ? 'opaque-boundary' : null,
      hasMore: first,
    );
  }
}

Future<void> _flushCursorFutures() => Future<void>.delayed(Duration.zero);

ChannelModel _cursorChannel(int id) => ChannelModel(
  id: id,
  scope: 'personal',
  name: 'fixture',
  creatorId: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
ChannelPageResult<ChannelMessageModel> _cursorPage(
  int channelId,
  List<int> ids, {
  required String? next,
}) => ChannelPageResult(
  list: ids
      .map(
        (id) => ChannelMessageModel(
          id: id,
          channelId: channelId,
          content: 'fixture',
          msgType: 'channel_text',
          createdAt: DateTime.utc(2026),
        ),
      )
      .toList(),
  nextCursor: next,
  hasMore: next != null,
);

class _DeferredCursorRequest {
  _DeferredCursorRequest(this.channelId, this.cursor);
  final String channelId;
  final String? cursor;
  final result = Completer<ChannelPageResult<ChannelMessageModel>>();
}

class _DeferredCursorApi extends ChannelApi {
  final requests = <_DeferredCursorRequest>[];
  @override
  Future<ChannelPageResult<ChannelMessageModel>> getMessagesPage({
    required String channelId,
    String? cursor,
    int limit = 20,
  }) {
    final request = _DeferredCursorRequest(channelId, cursor);
    requests.add(request);
    return request.result.future;
  }
}

class _DeferredChannelService extends Fake implements ChannelService {
  final cache = {
    for (final id in ['41', '42']) id: Completer<ChannelModel?>(),
  };
  final details = {
    for (final id in ['41', '42']) id: Completer<ChannelModel?>(),
  };
  final detailRequests = <String>[];
  @override
  Future<ChannelModel?> getChannel(String id, {bool Function()? isCurrent}) =>
      cache[id]!.future;
  @override
  Future<ChannelModel?> refreshChannel(
    String id, {
    bool Function()? isCurrent,
  }) {
    detailRequests.add(id);
    return details[id]!.future;
  }

  @override
  Future<ChannelModel?> refreshChannelChecked(
    String id, {
    bool Function()? isCurrent,
  }) => refreshChannel(id, isCurrent: isCurrent);

  @override
  Future<void> cacheChannelSnapshot(
    ChannelModel channel, {
    bool Function()? isCurrent,
  }) async {}
}

class _AliasApi extends ChannelApi {
  final responses = {
    for (final id in ['alpha', 'beta']) id: Completer<ChannelModel>(),
  };
  @override
  Future<ChannelModel> getChannelByCustomIdChecked(String id) =>
      responses[id]!.future;
  @override
  Future<ChannelPageResult<ChannelMessageModel>> getMessagesPage({
    required String channelId,
    String? cursor,
    int limit = 20,
  }) async =>
      const ChannelPageResult(list: [], nextCursor: null, hasMore: false);
}

/// 叠页快照用：11=personal、33=workspace、22=不存在的目标。
class _SnapshotSwitchApi extends ChannelApi {
  @override
  Future<ChannelModel> getChannelByCustomIdChecked(String id) async =>
      throw http.BadServiceException(message: 'not found');
  @override
  Future<ChannelPageResult<ChannelMessageModel>> getMessagesPage({
    required String channelId,
    String? cursor,
    int limit = 20,
  }) async =>
      const ChannelPageResult(list: [], nextCursor: null, hasMore: false);
}

class _SnapshotSwitchService extends Fake implements ChannelService {
  @override
  Future<ChannelModel?> getChannel(
    String id, {
    bool Function()? isCurrent,
  }) async => switch (id) {
    '11' => _snapshotChannel(11, 'personal'),
    '33' => _snapshotChannel(33, 'workspace'),
    _ => null,
  };

  @override
  Future<ChannelModel?> refreshChannel(
    String id, {
    bool Function()? isCurrent,
  }) async => switch (id) {
    '11' => _snapshotChannel(11, 'personal'),
    '33' => _snapshotChannel(33, 'workspace'),
    _ => null,
  };

  @override
  Future<ChannelModel?> refreshChannelChecked(
    String id, {
    bool Function()? isCurrent,
  }) async => switch (id) {
    '11' => _snapshotChannel(11, 'personal'),
    _ => null,
  };

  @override
  Future<void> cacheChannelSnapshot(
    ChannelModel channel, {
    bool Function()? isCurrent,
  }) async {}
}

ChannelModel _snapshotChannel(int id, String scope) => ChannelModel(
  id: id,
  scope: scope,
  name: 'snapshot-$id',
  creatorId: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _AliasService extends Fake implements ChannelService {
  final saved = <ChannelModel>[];
  @override
  Future<ChannelModel?> getChannel(
    String id, {
    bool Function()? isCurrent,
  }) async => null;
  @override
  Future<ChannelModel?> refreshChannel(
    String id, {
    bool Function()? isCurrent,
  }) async => null;
  @override
  Future<void> cacheChannelSnapshot(
    ChannelModel channel, {
    bool Function()? isCurrent,
  }) async => saved.add(channel);
}

class _BlockingAliasService extends _AliasService {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> cacheChannelSnapshot(
    ChannelModel channel, {
    bool Function()? isCurrent,
  }) async {
    started.complete();
    await release.future;
  }
}

class _DeferredPublishService extends _DeferredChannelService {
  final publish = Completer<ChannelMessageModel?>();
  @override
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
    String? requestId,
  }) => publish.future;
}

// Match a mounted Consumer's watch: autoDispose must not invalidate this notifier
// while deliberately delayed requests span event turns. Close before container.
void _watchCursorProvider(ProviderContainer container) {
  final subscription = container.listen(channelDetailProvider, (_, _) {});
  addTearDown(subscription.close);
}

Future<_DeferredCursorRequest> _cursorRequest(
  _DeferredCursorApi api,
  int index, {
  required String channelId,
  required String? cursor,
}) async {
  await _flushCursorFutures();
  expect(
    api.requests,
    hasLength(index + 1),
    reason: 'expected next cursor request phase',
  );
  final request = api.requests[index];
  expect(request.channelId, channelId);
  expect(request.cursor, cursor);
  expect(
    request.result.isCompleted,
    isFalse,
    reason: 'each phase completes its own future once',
  );
  return request;
}
