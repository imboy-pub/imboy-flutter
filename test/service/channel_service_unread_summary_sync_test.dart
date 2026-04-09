import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';

class _FakeChannelApi extends ChannelApi {
  _FakeChannelApi({required this.summary, this.shouldThrow = false});

  final Map<String, dynamic> summary;
  final bool shouldThrow;

  @override
  Future<Map<String, dynamic>> getUnreadSummary() async {
    if (shouldThrow) {
      throw StateError('fake unread summary failure');
    }
    return summary;
  }
}

class _FakeChannelRepo extends ChannelRepo {
  _FakeChannelRepo(List<ChannelSubscriptionModel> subscriptions)
    : _subscriptions = subscriptions;

  final List<ChannelSubscriptionModel> _subscriptions;
  final Map<String, int> updatedUnreadByChannel = <String, int>{};

  @override
  Future<List<ChannelSubscriptionModel>> getAllSubscriptions() async {
    return _subscriptions
        .map((item) => item.copyWith())
        .toList(growable: false);
  }

  @override
  Future<int> updateUnreadCount(String channelId, int count) async {
    updatedUnreadByChannel[channelId] = count;
    for (int i = 0; i < _subscriptions.length; i++) {
      if (_subscriptions[i].channelId.toString() == channelId) {
        _subscriptions[i] = _subscriptions[i].copyWith(unreadCount: count);
      }
    }
    return 1;
  }
}

void main() {
  group('ChannelService.syncUnreadSummary', () {
    test('emits unread delta and summary sync event with trigger', () async {
      final repo = _FakeChannelRepo([
        ChannelSubscriptionModel(
          channelId: 1001,
          subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
          unreadCount: 1,
        ),
        ChannelSubscriptionModel(
          channelId: 1002,
          subscribedAt: DateTime.fromMillisecondsSinceEpoch(2),
          unreadCount: 2,
        ),
      ]);
      final api = _FakeChannelApi(
        summary: const <String, dynamic>{
          'total_unread': 6,
          'channels': <Map<String, dynamic>>[
            {'channel_id': '1001', 'unread_count': 1},
            {'channel_id': '1002', 'unread_count': 5},
            {'channel_id': '1003', 'unread_count': 99},
          ],
        },
      );
      final service = ChannelService.forTest(api: api, repo: repo);

      final unreadEvents = <ChannelUnreadCountUpdatedEvent>[];
      final syncEvents = <ChannelUnreadSummarySyncEvent>[];
      final unreadSub = AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(
        unreadEvents.add,
      );
      final syncSub = AppEventBus.on<ChannelUnreadSummarySyncEvent>().listen(
        syncEvents.add,
      );

      final result = await service.syncUnreadSummary(trigger: 'ws_connected');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await unreadSub.cancel();
      await syncSub.cancel();

      expect(result['total_unread'], 6);
      expect(repo.updatedUnreadByChannel, {'1002': 5});
      expect(
        unreadEvents.any((e) => e.channelId == '1002' && e.unreadCount == 5),
        isTrue,
      );
      expect(
        unreadEvents.any(
          (e) => e.channelId == 'unread_summary' && e.unreadCount == 6,
        ),
        isTrue,
      );

      expect(syncEvents.length, 1);
      final syncEvent = syncEvents.single;
      expect(syncEvent.trigger, 'ws_connected');
      expect(syncEvent.source, 'server_unread_summary_pull');
      expect(syncEvent.totalUnread, 6);
      expect(syncEvent.changedSubscriptions, 1);
      expect(syncEvent.success, isTrue);
    });

    test(
      'emits failed summary sync event on unread summary exception',
      () async {
        final repo = _FakeChannelRepo([
          ChannelSubscriptionModel(
            channelId: 1001,
            subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
            unreadCount: 7,
          ),
        ]);
        final api = _FakeChannelApi(
          summary: const <String, dynamic>{},
          shouldThrow: true,
        );
        final service = ChannelService.forTest(api: api, repo: repo);

        final syncEvents = <ChannelUnreadSummarySyncEvent>[];
        final syncSub = AppEventBus.on<ChannelUnreadSummarySyncEvent>().listen(
          syncEvents.add,
        );

        final result = await service.syncUnreadSummary(trigger: 'cache_start');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await syncSub.cancel();

        expect(result, isEmpty);
        expect(repo.updatedUnreadByChannel, isEmpty);

        expect(syncEvents.length, 1);
        final syncEvent = syncEvents.single;
        expect(syncEvent.trigger, 'cache_start');
        expect(syncEvent.source, 'server_unread_summary_pull');
        expect(syncEvent.totalUnread, 0);
        expect(syncEvent.changedSubscriptions, 0);
        expect(syncEvent.success, isFalse);
      },
    );
  });
}
