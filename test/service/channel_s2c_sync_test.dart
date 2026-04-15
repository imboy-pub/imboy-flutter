import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';

class _FakeChannelApi extends ChannelApi {
  _FakeChannelApi({this.channelById = const {}});

  final Map<String, ChannelModel> channelById;
  final List<(String, String)> markAsReadCalls = <(String, String)>[];

  @override
  Future<ChannelModel?> getChannel(String channelId) async {
    return channelById[channelId];
  }

  @override
  Future<bool> markAsRead(String channelId, String messageId) async {
    markAsReadCalls.add((channelId, messageId));
    return true;
  }
}

class _FakeChannelRepo extends ChannelRepo {
  final List<ChannelModel> savedChannels = <ChannelModel>[];
  final List<String> deletedChannels = <String>[];
  final List<ChannelSubscriptionModel> savedSubscriptions =
      <ChannelSubscriptionModel>[];
  final Map<String, ChannelSubscriptionModel> subscriptions =
      <String, ChannelSubscriptionModel>{};
  final List<(String, String)> markAsReadCalls = <(String, String)>[];

  @override
  Future<int> markAsRead(String channelId, String messageId) async {
    markAsReadCalls.add((channelId, messageId));
    return 1;
  }

  @override
  Future<void> saveChannel(ChannelModel channel, {dynamic txn}) async {
    savedChannels.add(channel);
  }

  @override
  Future<int> deleteChannel(String channelId) async {
    deletedChannels.add(channelId);
    return 1;
  }

  @override
  Future<ChannelSubscriptionModel?> getSubscription(String channelId) async {
    return subscriptions[channelId];
  }

  @override
  Future<void> saveSubscription(
    ChannelSubscriptionModel subscription, {
    dynamic txn,
  }) async {
    savedSubscriptions.add(subscription);
    subscriptions[subscription.channelId.toString()] = subscription;
  }
}

class _FakeChannelMessageRepo extends ChannelMessageRepo {
  final List<String> deletedMessageIds = <String>[];
  final List<String> deletedChannelMessages = <String>[];
  final Map<String, bool> pinnedByMessageId = <String, bool>{};

  @override
  Future<int> deleteMessage(String messageId) async {
    deletedMessageIds.add(messageId);
    return 1;
  }

  @override
  Future<int> deleteMessagesByChannel(String channelId) async {
    deletedChannelMessages.add(channelId);
    return 1;
  }

  @override
  Future<int> setMessagePinned(String messageId, bool pinned) async {
    pinnedByMessageId[messageId] = pinned;
    return 1;
  }
}

ChannelModel _channel({
  required int id,
  required String name,
  bool isSubscribed = true,
}) {
  return ChannelModel(
    id: id,
    name: name,
    creatorId: 1002,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
    isSubscribed: isSubscribed,
  );
}

Map<String, dynamic> _channelPayload({
  required int id,
  required String name,
}) {
  return _channel(id: id, name: name).toJson();
}

void main() {
  group('ChannelService S2C sync', () {
    test('handleChannelUpdated reads nested payload channel', () async {
      final repo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      await service.handleChannelUpdated({
        'channel_id': 'ch-1',
        'channel': _channelPayload(id: 1001, name: 'Updated Channel'),
      });

      expect(repo.savedChannels, hasLength(1));
      expect(repo.savedChannels.single.id, 1001);
      expect(repo.savedChannels.single.name, 'Updated Channel');
    });

    test(
      'handleChannelMessageDeleted deletes local message and emits event',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub = AppEventBus.on<ChannelMessageDeletedEvent>().listen(
          events.add,
        );

        await service.handleChannelMessageDeleted({
          'channel_id': 'ch-1',
          'message_id': 'msg-1',
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(messageRepo.deletedMessageIds, equals(const ['msg-1']));
        expect(events, hasLength(1));
        expect(events.single.channelId, 'ch-1');
        expect(events.single.messageId, 'msg-1');
        expect(events.single.reason, 'deleted');
      },
    );

    test(
      'handleChannelMessageRevoked removes local message and emits revoked event',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub = AppEventBus.on<ChannelMessageDeletedEvent>().listen(
          events.add,
        );

        await service.handleChannelMessageRevoked({
          'channel_id': 'ch-2',
          'message_id': 'msg-2',
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(messageRepo.deletedMessageIds, equals(const ['msg-2']));
        expect(events, hasLength(1));
        expect(events.single.channelId, 'ch-2');
        expect(events.single.messageId, 'msg-2');
        expect(events.single.reason, 'revoked');
      },
    );

    test(
      'handleChannelMessageRevoked ignores empty channel_id',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub = AppEventBus.on<ChannelMessageDeletedEvent>().listen(
          events.add,
        );

        await service.handleChannelMessageRevoked({
          'channel_id': '',
          'message_id': 'msg-x',
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        // 非法载荷不得触发本地删除或事件广播，避免误删他频道消息。
        expect(messageRepo.deletedMessageIds, isEmpty);
        expect(events, isEmpty);
      },
    );

    test(
      'handleChannelMessageRevoked ignores empty message_id',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub = AppEventBus.on<ChannelMessageDeletedEvent>().listen(
          events.add,
        );

        await service.handleChannelMessageRevoked({
          'channel_id': 'ch-3',
          'message_id': '',
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(messageRepo.deletedMessageIds, isEmpty);
        expect(events, isEmpty);
      },
    );

    test(
      'markAsRead updates local DB and emits unread count cleared event',
      () async {
        final api = _FakeChannelApi();
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: api,
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );
        final unreadEvents = <ChannelUnreadCountUpdatedEvent>[];
        final sub = AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(
          unreadEvents.add,
        );

        final ok = await service.markAsRead('ch-9', 'msg-99');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(ok, isTrue);
        expect(api.markAsReadCalls, equals(const [('ch-9', 'msg-99')]),
            reason: 'API 端必须同步');
        expect(repo.markAsReadCalls, equals(const [('ch-9', 'msg-99')]),
            reason: '本地 DB 必须清 0 保持一致');
        expect(
          unreadEvents.any(
            (e) => e.channelId == 'ch-9' && e.unreadCount == 0,
          ),
          isTrue,
          reason: '必须广播 ChannelUnreadCountUpdatedEvent 触发 UI 徽标刷新',
        );
      },
    );

    test(
      'handleChannelSubscribed emits channel_subscribed event for cross-device sync',
      () async {
        final api = _FakeChannelApi(
          channelById: {
            '2001': _channel(id: 2001, name: 'Remote-Subscribed'),
          },
        );
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: api,
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(
          events.add,
        );

        await service.handleChannelSubscribed({'channel_id': '2001'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(repo.savedChannels, hasLength(1));
        expect(repo.savedSubscriptions, hasLength(1));
        expect(
          events.any(
            (e) =>
                e.channelId == '2001' && e.action == 'channel_subscribed',
          ),
          isTrue,
          reason: '多端同步：必须广播 channel_subscribed 让订阅列表刷新',
        );
      },
    );

    test(
      'handleChannelSubscribed is idempotent - no duplicate event on repeat',
      () async {
        final api = _FakeChannelApi(
          channelById: {
            '2001': _channel(id: 2001, name: 'Remote-Subscribed'),
          },
        );
        final repo = _FakeChannelRepo();
        // 预置已存在的订阅，模拟重复 S2C 推送
        repo.subscriptions['2001'] = ChannelSubscriptionModel(
          channelId: 2001,
          subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        final service = ChannelService.forTest(
          api: api,
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(
          events.add,
        );

        await service.handleChannelSubscribed({'channel_id': '2001'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(
          events.any((e) => e.action == 'channel_subscribed'),
          isFalse,
          reason: '已订阅时必须幂等短路，不再 save 也不再广播',
        );
        expect(repo.savedChannels, isEmpty);
      },
    );

    test(
      'handleChannelUnsubscribed emits channel_unsubscribed event',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelStateChangedEvent>[];
        final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(
          events.add,
        );

        await service.handleChannelUnsubscribed({'channel_id': '2002'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(
          events.any(
            (e) =>
                e.channelId == '2002' && e.action == 'channel_unsubscribed',
          ),
          isTrue,
          reason: '退订后必须广播 channel_unsubscribed 驱动列表移除',
        );
      },
    );

    test(
      'handleChannelDeleted cascades message cleanup',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );

        await service.handleChannelDeleted({'channel_id': 'ch-del'});

        expect(messageRepo.deletedChannelMessages, contains('ch-del'),
            reason: '频道被删后必须清理其本地消息，避免孤儿行累积');
      },
    );

    test(
      'handleChannelUnsubscribed cascades message cleanup',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );

        await service.handleChannelUnsubscribed({'channel_id': 'ch-unsub'});

        expect(messageRepo.deletedChannelMessages, contains('ch-unsub'),
            reason: '取消订阅后不再可访问该频道，消息应一并清理');
      },
    );

    test(
      'handleChannelDeleted skips message cleanup on empty channel_id',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );

        await service.handleChannelDeleted({'channel_id': ''});

        expect(messageRepo.deletedChannelMessages, isEmpty);
      },
    );

    test(
      'handleChannelMessageDeleted ignores empty ids (parity with revoked)',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub = AppEventBus.on<ChannelMessageDeletedEvent>().listen(
          events.add,
        );

        await service.handleChannelMessageDeleted({
          'channel_id': '',
          'message_id': '',
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(messageRepo.deletedMessageIds, isEmpty);
        expect(events, isEmpty);
      },
    );

    test(
      'handleChannelOrderPaid refreshes subscription state and emits channel change',
      () async {
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(
            channelById: {
              '1003': _channel(id: 1003, name: 'Paid Channel'),
            },
          ),
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(
          events.add,
        );

        await service.handleChannelOrderPaid({'channel_id': '1003'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(repo.savedChannels, hasLength(1));
        expect(repo.savedChannels.single.id, 1003);
        expect(repo.savedSubscriptions, hasLength(1));
        expect(repo.savedSubscriptions.single.channelId, 1003);
        expect(
          events.any(
            (event) =>
                event.channelId == '1003' &&
                event.action == 'channel_order_paid',
          ),
          isTrue,
        );
      },
    );
  });
}
