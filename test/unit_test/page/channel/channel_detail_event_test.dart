import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_publish_bar.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/events/channel_events.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/model/channel_model.dart';

class _TestChannelDetailNotifier extends ChannelDetailNotifier {
  final ChannelModel channel;
  final List<ChannelMessageModel> initialMessages;

  _TestChannelDetailNotifier(this.channel, this.initialMessages);

  @override
  Future<void> loadChannel(String channelId) async {
    state = state.copyWith(
      channel: channel,
      messages: initialMessages,
      hasMore: false,
      isLoading: false,
    );
    debugSetChannelId(channel.id.toString());
  }

  @override
  Future<void> loadMessages(
    String channelId, {
    int? cursor,
    int limit = 20,
  }) async {}
}

class _ChangingDetailNotifier extends ChannelDetailNotifier {
  final calls = <String>[];
  String? target;
  @override
  String? get requestedChannelId => target;
  @override
  Future<void> loadChannel(String channelId) async {
    calls.add(channelId);
    target = channelId;
    state = ChannelDetailState(
      channel: ChannelModel(
        id: int.parse(channelId),
        name: 'channel-$channelId',
        creatorId: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      hasMore: false,
    );
  }
}

class _PendingSubscriptionNotifier extends ChannelListNotifier {
  final pending = Completer<ChannelSubscribeOutcome>();
  @override
  ChannelListState build() => const ChannelListState();
  @override
  Future<ChannelSubscribeOutcome> subscribeChannel(String channelId) =>
      pending.future;
}

class _PendingDetailNotifier extends _ChangingDetailNotifier {
  final pending = Completer<void>();
  @override
  Future<void> loadChannel(String channelId) async {
    if (channelId != '42') return super.loadChannel(channelId);
    calls.add(channelId);
    target = channelId;
    state = const ChannelDetailState(isLoading: true);
    await pending.future;
  }
}

ChannelMessageModel _buildMessage(int id) {
  return ChannelMessageModel(
    id: id,
    channelId: 1001,
    content: 'Test message',
    msgType: 'channel_text',
    createdAt: DateTime.now(),
  );
}

ChannelModel _buildChannel() {
  return ChannelModel(
    id: 1001,
    name: 'My Channel',
    creatorId: 1002,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    userRole: ChannelUserRole.admin,
    isSubscribed: true,
  );
}

/// J10.a 用：受保护（workspace）频道 + 可发布角色，供写入口断言。
ChannelModel _protectedChannel() => ChannelModel(
  id: 41,
  scope: 'workspace',
  workspaceId: '1',
  name: 'private-ws',
  creatorId: 1,
  userRole: ChannelUserRole.creator,
  isSubscribed: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

ChannelPageResult<ChannelMessageModel> _emptyMessagePage() =>
    const ChannelPageResult(list: [], nextCursor: null, hasMore: false);

/// J10.a 用：消息请求逐段延迟，可在撤权事件后精确续放。
class _StagedMessagesApi extends ChannelApi {
  final requests = <Completer<ChannelPageResult<ChannelMessageModel>>>[];
  @override
  Future<ChannelPageResult<ChannelMessageModel>> getMessagesPage({
    required String channelId,
    String? cursor,
    int limit = 20,
  }) {
    final reply = Completer<ChannelPageResult<ChannelMessageModel>>();
    requests.add(reply);
    return reply.future;
  }
}

/// J10.a 用：详情缓存/刷新逐段延迟，支持撤权后补放旧响应。
class _StagedDetailService extends Fake implements ChannelService {
  final cache = <Completer<ChannelModel?>>[];
  final details = <Completer<ChannelModel?>>[];

  Completer<ChannelModel?> _issue(List<Completer<ChannelModel?>> queue) {
    final reply = Completer<ChannelModel?>();
    queue.add(reply);
    return reply;
  }

  @override
  Future<ChannelModel?> getChannel(String id, {bool Function()? isCurrent}) =>
      _issue(cache).future;

  @override
  Future<ChannelModel?> refreshChannel(
    String id, {
    bool Function()? isCurrent,
  }) => _issue(details).future;

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

  @override
  bool hasPendingSubscription(String channelId) => false;

  @override
  Future<ChannelSubscriptionModel?> getSubscription(String channelId) async =>
      null;
}

void main() {
  testWidgets('订阅 A 延迟完成后不能把复用的 B 页面切回 A', (tester) async {
    final detail = _ChangingDetailNotifier();
    final list = _PendingSubscriptionNotifier();
    Widget app(String channelId) => TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(() => detail),
          channelListProvider.overrideWith(() => list),
        ],
        child: MaterialApp(
          home: ChannelDetailPage(channelId: channelId, autoLoadStats: false),
        ),
      ),
    );
    await tester.pumpWidget(app('41'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.channel.subscribe).first);
    await tester.pump();
    await tester.pumpWidget(app('42'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(detail.calls, ['41', '42']);
    list.pending.complete(ChannelSubscribeOutcome.completed);
    await tester.pumpAndSettle();
    expect(detail.calls, ['41', '42']);
    expect(find.text('channel-42'), findsWidgets);
  });

  testWidgets('订阅 A 延迟完成后 A 到 B 再回 A 不触发旧刷新', (tester) async {
    final detail = _ChangingDetailNotifier();
    final list = _PendingSubscriptionNotifier();
    Widget app(String id) => TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(() => detail),
          channelListProvider.overrideWith(() => list),
        ],
        child: MaterialApp(
          home: ChannelDetailPage(channelId: id, autoLoadStats: false),
        ),
      ),
    );
    await tester.pumpWidget(app('41'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.channel.subscribe).first);
    await tester.pump();
    await tester.pumpWidget(app('42'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(app('41'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(detail.calls, ['41', '42', '41']);
    list.pending.complete(ChannelSubscribeOutcome.completed);
    await tester.pumpAndSettle();
    expect(detail.calls, ['41', '42', '41']);
  });

  testWidgets('频道 B 仍在加载时返回 A 会恢复 A', (tester) async {
    final notifier = _PendingDetailNotifier();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelDetailProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            navigatorKey: navigator,
            home: const ChannelDetailPage(
              channelId: '41',
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ChannelDetailPage(channelId: '42', autoLoadStats: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(notifier.calls, ['41', '42']);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(notifier.calls, ['41', '42', '41']);
    expect(find.text('channel-41'), findsWidgets);
    notifier.pending.complete();
    await tester.pump();
  });

  testWidgets('返回上一频道时恢复其详情而不持续加载', (tester) async {
    final notifier = _ChangingDetailNotifier();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelDetailProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            navigatorKey: navigator,
            home: const ChannelDetailPage(
              channelId: '41',
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('channel-41'), findsWidgets);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ChannelDetailPage(channelId: '42', autoLoadStats: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('channel-42'), findsWidgets);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('channel-41'), findsWidgets);
    expect(notifier.calls, ['41', '42', '41']);
  });

  testWidgets('同一详情 widget 更换频道时重新加载目标', (tester) async {
    final notifier = _ChangingDetailNotifier();
    var id = '41';
    late StateSetter change;
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelDetailProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return ChannelDetailPage(channelId: id, autoLoadStats: false);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifier.calls, ['41']);
    expect(find.text('channel-41'), findsWidgets);
    change(() => id = '42');
    await tester.pumpAndSettle();
    expect(notifier.calls, ['41', '42']);
    expect(find.text('channel-42'), findsWidgets);
    expect(find.text('channel-41'), findsNothing);
  });

  testWidgets('ChannelDetailPage removes message after deleted event', (
    tester,
  ) async {
    final channel = _buildChannel();
    final providerOverride = channelDetailProvider.overrideWith(
      () => _TestChannelDetailNotifier(channel, [_buildMessage(1)]),
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [providerOverride],
          child: MaterialApp(
            home: ChannelDetailPage(
              channelId: channel.id.toString(),
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsOneWidget);

    AppEventBus.fire(
      const ChannelMessageDeletedEvent(
        channelId: '1001',
        messageId: '1',
        reason: 'deleted',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsNothing);
  });

  testWidgets('ChannelDetailPage updates message after edited event', (
    tester,
  ) async {
    // 回归：channel_message_edited 此前无消费者（ACK 后静默丢弃），
    // 频道消息编辑不实时生效，直到手动重拉
    final channel = _buildChannel();
    final providerOverride = channelDetailProvider.overrideWith(
      () => _TestChannelDetailNotifier(channel, [_buildMessage(1)]),
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [providerOverride],
          child: MaterialApp(
            home: ChannelDetailPage(
              channelId: channel.id.toString(),
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsOneWidget);

    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '1001',
        action: 'channel_message_edited',
        payload: const {
          'channel_id': '1001',
          'message_id': '1',
          'content': 'Edited message',
          'edited_at': '2026-08-20T20:00:00.000000+08:00',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsNothing);
    expect(find.text('Edited message'), findsOneWidget);
  });

  testWidgets('J10.a 前台保护页：权威撤权后旧响应完成不恢复内容与写入口', (tester) async {
    final service = _StagedDetailService();
    final api = _StagedMessagesApi();
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            channelServiceProvider.overrideWithValue(service),
            channelApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            home: const ChannelDetailPage(
              channelId: '41',
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChannelDetailPage)),
    );

    // 初始授权加载：受保护频道经权威校验后呈现，写入口（发布条）在位。
    service.cache.removeAt(0).complete(_protectedChannel());
    await tester.pump();
    service.details.removeAt(0).complete(_protectedChannel());
    await tester.pump();
    expect(api.requests, hasLength(1));
    api.requests.single.complete(_emptyMessagePage());
    await tester.pumpAndSettle();
    expect(find.text('private-ws'), findsWidgets);
    expect(find.byType(ChannelPublishBar), findsOneWidget);

    // 同资源刷新在途（旧代次请求，尚未完成）。
    final staleRefresh = container
        .read(channelDetailProvider.notifier)
        .loadChannel('41');
    await tester.pump();
    expect(service.cache, hasLength(1));
    service.cache.removeAt(0).complete(_protectedChannel());
    await tester.pump();
    expect(service.details, hasLength(1));

    // 权威撤权事件先于旧响应完成到达：撤内容和写入口。
    AppEventBus.fire(
      const ChannelStateChangedEvent(
        channelId: '41',
        action: 'channel_deleted',
        payload: {},
      ),
    );
    await tester.pump();
    final revoked = container.read(channelDetailProvider);
    expect(revoked.channel, isNull);
    expect(revoked.messages, isEmpty);
    expect(revoked.error, isNotNull);
    expect(find.byType(ChannelPublishBar), findsNothing);
    expect(find.text('private-ws'), findsNothing);

    // 旧代次响应此刻完成：不得恢复内容与写入口。
    service.details.removeAt(0).complete(_protectedChannel());
    await staleRefresh;
    await tester.pumpAndSettle();
    final restored = container.read(channelDetailProvider);
    expect(restored.channel, isNull);
    expect(restored.messages, isEmpty);
    expect(restored.error, isNotNull);
    expect(find.byType(ChannelPublishBar), findsNothing);
    expect(find.text('private-ws'), findsNothing);
  });
}
