import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/channel_events.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';

class _Session extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (
    uid: 'fixture-a',
    generation: 1,
    transitioning: false,
  );
  @override
  bool isCurrent(AuthSessionScope scope) =>
      scope == current && scope.uid.isNotEmpty && !scope.transitioning;
  void rotate(String uid) {
    current = (
      uid: uid,
      generation: current.generation + 1,
      transitioning: false,
    );
    notifyListeners();
  }
}

class _Repo extends Fake implements ChannelRepo {
  List<Map<String, dynamic>> rows = [];
  @override
  Future<List<Map<String, dynamic>>>
  getSubscribedChannelsWithSubscription() async => rows;
}

class _Cache extends Fake implements ChannelService {
  @override
  final _Repo repo;
  _Cache(this.repo);
  List<List<String>> requested = [];
  Future<Map<String, ChannelMessageModel>> Function(List<String>)? load;
  @override
  Future<Map<String, ChannelMessageModel>> getCachedPreviews(
    List<String> ids,
  ) async {
    requested.add(List.of(ids));
    return load?.call(ids) ?? {for (final id in ids) id: _message(id)};
  }
}

ChannelMessageModel _message(String id) => ChannelMessageModel(
  id: '91',
  channelId: id,
  content: 'preview-$id',
  msgType: 'channel_text',
  createdAt: DateTime.utc(2026),
);
Map<String, dynamic> _row(
  int id, {
  String? scope = 'personal',
  String? workspace,
  bool paid = false,
  bool purchased = false,
  bool subscribed = true,
}) => {
  ...ChannelModel(
    id: id,
    scope: scope,
    workspaceId: workspace,
    name: 'fixture-$id',
    creatorId: 1,
    visibility: 0,
    accessType: paid ? 1 : 0,
    joinPolicy: paid ? 3 : 0,
    isSubscribed: subscribed,
    hasPurchased: purchased,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ).toMap(),
  ...ChannelSubscriptionModel(
    channelId: id,
    subscribedAt: DateTime.utc(2026),
    unreadCount: 7,
  ).toMap(),
};
ProviderContainer _container(_Session session, _Cache cache) {
  final container = ProviderContainer(
    overrides: [
      channelServiceProvider.overrideWithValue(cache),
      subscribedChannelStripProvider.overrideWith(
        () => SubscribedChannelStripNotifier(session: session),
      ),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(
    subscribedChannelStripProvider,
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'previews require explicit personal access; all subscription counts remain',
    () async {
      final session = _Session();
      final repo = _Repo()
        ..rows = [
          _row(1),
          _row(2, scope: 'workspace', workspace: '8'),
          _row(3, scope: null),
          _row(4, workspace: '8'),
          _row(5, paid: true),
          _row(6, paid: true, purchased: true),
          _row(7, subscribed: false),
        ];
      final cache = _Cache(repo);
      final container = _container(session, cache);
      final result = await container.read(
        subscribedChannelStripProvider.future,
      );
      expect(cache.requested.single, ['1', '6']);
      expect(result, hasLength(7));
      expect(result.fold<int>(0, (sum, item) => sum + item.unreadCount), 49);
      expect(
        result
            .where((item) => item.lastMessagePreview != null)
            .map((item) => item.channelId)
            .toSet(),
        {'1', '6'},
      );
    },
  );
  test(
    'unread event during preview query beats older subscription snapshot',
    () async {
      final session = _Session();
      final repo = _Repo()..rows = [_row(1)];
      final pending = Completer<Map<String, ChannelMessageModel>>();
      final cache = _Cache(repo)..load = (_) => pending.future;
      final container = _container(session, cache);
      final load = container.read(subscribedChannelStripProvider.future);
      await Future<void>.delayed(Duration.zero);
      AppEventBus.fire(
        const ChannelUnreadCountUpdatedEvent(channelId: '1', unreadCount: 0),
      );
      await Future<void>.delayed(Duration.zero);
      pending.complete({'1': _message('1')});
      expect((await load).single.unreadCount, 0);
    },
  );
  for (final nextUid in ['fixture-a', 'fixture-b']) {
    test(
      'session rotation to $nextUid clears old data and rejects late results',
      () async {
        final session = _Session();
        final repo = _Repo()..rows = [_row(1)];
        final pending = Completer<Map<String, ChannelMessageModel>>();
        final cache = _Cache(repo)
          ..load = (ids) => ids.contains('1')
              ? pending.future
              : Future.value({'2': _message('2')});
        final container = _container(session, cache);
        container.read(subscribedChannelStripProvider.future);
        await Future<void>.delayed(Duration.zero);
        repo.rows = [_row(2)];
        session.rotate(nextUid);
        expect(
          container.read(subscribedChannelStripProvider).value ?? [],
          isEmpty,
        );
        final latest = await container.read(
          subscribedChannelStripProvider.future,
        );
        expect(latest.single.channelId, '2');
        pending.complete({'1': _message('1')});
        await Future<void>.delayed(Duration.zero);
        expect(
          container
              .read(subscribedChannelStripProvider)
              .value!
              .single
              .channelId,
          '2',
        );
      },
    );
  }
  test(
    'preview failure remains visible while subscription counters survive',
    () async {
      final session = _Session();
      final repo = _Repo()..rows = [_row(1)];
      final cache = _Cache(repo)
        ..load = (_) => Future.error(StateError('fixture failure'));
      final container = _container(session, cache);
      final result = await container.read(
        subscribedChannelStripProvider.future,
      );
      expect(result.single.unreadCount, 7);
      expect(result.single.previewLoadFailed, isTrue);
    },
  );
  test(
    'access-change event drops old content before the new snapshot arrives',
    () async {
      final session = _Session();
      final repo = _Repo()..rows = [_row(1)];
      final cache = _Cache(repo);
      final container = _container(session, cache);
      await container.read(subscribedChannelStripProvider.future);
      repo.rows = [_row(1, paid: true)];
      AppEventBus.fire(
        const ChannelStateChangedEvent(
          channelId: '1',
          action: 'channel_updated',
          payload: {},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final updated = await container.read(
        subscribedChannelStripProvider.future,
      );
      expect(updated.single.lastMessagePreview, isNull);
      expect(canShowPersonalInboxChannel(updated.single.channel), isFalse);
    },
  );
}
