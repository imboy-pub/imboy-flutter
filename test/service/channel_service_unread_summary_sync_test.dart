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
      'does NOT zero local unreads when API channels field is missing/null',
      () async {
        // 回归用例：API 载荷若丢失 `channels` 字段（上游异常或版本错配），
        // 旧逻辑会视所有本地订阅「权威未读=0」并清零，导致用户看到未读无故消失。
        // 正确行为：将此视为不可信载荷，不写盘、不发 channel 级事件，
        // 但上报 summary 同步失败供观测。
        final repo = _FakeChannelRepo([
          ChannelSubscriptionModel(
            channelId: 1001,
            subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
            unreadCount: 7,
          ),
        ]);
        final api = _FakeChannelApi(
          summary: const <String, dynamic>{'total_unread': 0},
        );
        final service = ChannelService.forTest(api: api, repo: repo);

        final unreadEvents = <ChannelUnreadCountUpdatedEvent>[];
        final syncEvents = <ChannelUnreadSummarySyncEvent>[];
        final unreadSub =
            AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(
          unreadEvents.add,
        );
        final syncSub = AppEventBus.on<ChannelUnreadSummarySyncEvent>().listen(
          syncEvents.add,
        );

        await service.syncUnreadSummary(trigger: 'manual');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await unreadSub.cancel();
        await syncSub.cancel();

        expect(repo.updatedUnreadByChannel, isEmpty,
            reason: 'channels 缺失时不得清零本地未读');
        expect(
          unreadEvents.any((e) => e.channelId == '1001'),
          isFalse,
          reason: 'channels 缺失时不得发 channel 级未读事件',
        );
        expect(syncEvents.length, 1);
        expect(syncEvents.single.success, isFalse,
            reason: 'channels 缺失应上报同步失败供观测');
      },
    );

    test(
      'does NOT zero local unreads when API channels field is wrong type',
      () async {
        // 载荷异常：channels 非 List（例如服务端误回 Map 或字符串）。
        final repo = _FakeChannelRepo([
          ChannelSubscriptionModel(
            channelId: 1001,
            subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
            unreadCount: 3,
          ),
        ]);
        final api = _FakeChannelApi(
          summary: const <String, dynamic>{
            'total_unread': 0,
            'channels': 'not_a_list',
          },
        );
        final service = ChannelService.forTest(api: api, repo: repo);

        final syncEvents = <ChannelUnreadSummarySyncEvent>[];
        final syncSub = AppEventBus.on<ChannelUnreadSummarySyncEvent>().listen(
          syncEvents.add,
        );

        await service.syncUnreadSummary(trigger: 'manual');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await syncSub.cancel();

        expect(repo.updatedUnreadByChannel, isEmpty);
        expect(syncEvents.single.success, isFalse);
      },
    );

    test(
      'empty channels list DOES zero local unreads (authoritative empty)',
      () async {
        // 对照：`channels: []` 是权威语义上的「无未读」，必须清零。
        // 这条用例保护前两个修复不过度宽松。
        final repo = _FakeChannelRepo([
          ChannelSubscriptionModel(
            channelId: 1001,
            subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
            unreadCount: 7,
          ),
        ]);
        final api = _FakeChannelApi(
          summary: const <String, dynamic>{
            'total_unread': 0,
            'channels': <Map<String, dynamic>>[],
          },
        );
        final service = ChannelService.forTest(api: api, repo: repo);

        final syncEvents = <ChannelUnreadSummarySyncEvent>[];
        final syncSub = AppEventBus.on<ChannelUnreadSummarySyncEvent>().listen(
          syncEvents.add,
        );

        await service.syncUnreadSummary(trigger: 'manual');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await syncSub.cancel();

        expect(repo.updatedUnreadByChannel, {'1001': 0},
            reason: 'channels:[] 是权威空集，应清零');
        expect(syncEvents.single.success, isTrue);
      },
    );

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
