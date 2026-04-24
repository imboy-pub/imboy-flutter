/// ChannelService 操作契约测试（slice CH-1 ~ CH-17）
///
/// 覆盖以下未测区域：
/// - CH-1: handleChannelMessage（有效消息 + channelId/id=0 守卫）
/// - CH-2: handleChannelInvitationCreated / handleChannelInvitationAccepted
/// - CH-3: createAndPayOrder 失败路径
/// - CH-4: deleteMessage / setMessagePinned
/// - CH-5: subscribeChannel / unsubscribeChannel
/// - CH-6: syncSubscribedChannels（已有订阅 vs 新订阅）
/// - CH-7: syncMessages（消息保存 + 异常降级）
/// - CH-8: publishMessage / getMessages / deleteChannel / markAsRead
/// - CH-9: searchChannels / getChannel（本地优先回退）
/// - CH-10: cleanupOldData（遍历订阅 + 删旧消息）
/// - CH-11: handleChannelMessageRevoked（撤回守卫 + reason=revoked）
/// - CH-12: addReaction / removeReaction（成功/失败/异常三路）
/// - CH-17: acceptInvitation / rejectInvitation / discoverChannels
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

/// ChannelApi fake，可控制各操作的返回值
class _FakeChannelApi extends ChannelApi {
  _FakeChannelApi({
    this.channelById = const {},
    this.subscribeResult = true,
    this.unsubscribeResult = true,
    this.createOrderResult,
    this.payOrderResult = true,
    this.getOrderResult,
    this.deleteMessageResult = true,
    this.setMessagePinnedResult = true,
    this.subscribedChannels = const [],
    this.messages = const [],
    this.publishMessageResult,
    this.markAsReadResult = true,
    this.deleteChannelResult = true,
    this.searchResult = const [],
    this.channelByIdFromApi,
    this.channelStatsResult,
    this.unreadSummaryResult = const {},
    this.myOrdersResult = const [],
    this.myInvitationsResult = const [],
    this.sentInvitationsResult = const [],
  });

  final Map<String, ChannelModel> channelById;
  final bool subscribeResult;
  final bool unsubscribeResult;
  final ChannelOrderModel? Function()? createOrderResult;
  final bool payOrderResult;
  final ChannelOrderModel? Function()? getOrderResult;
  final bool deleteMessageResult;
  final bool setMessagePinnedResult;
  final List<ChannelModel> subscribedChannels;
  final List<ChannelMessageModel> messages;
  final ChannelMessageModel? publishMessageResult;
  final bool markAsReadResult;
  final bool deleteChannelResult;
  final List<ChannelModel> searchResult;
  final ChannelModel? channelByIdFromApi;
  final ChannelStatsModel? channelStatsResult;
  final Map<String, dynamic> unreadSummaryResult;
  final List<ChannelOrderModel> myOrdersResult;
  final List<Map<String, dynamic>> myInvitationsResult;
  final List<Map<String, dynamic>> sentInvitationsResult;
  final List<String> getChannelStatsCalls = <String>[];
  int getUnreadSummaryCalls = 0;
  bool acceptInvitationResult = true;
  bool rejectInvitationResult = true;
  List<ChannelModel> discoverChannelsResult = <ChannelModel>[];
  final List<String> acceptInvitationCalls = <String>[];
  final List<String> rejectInvitationCalls = <String>[];
  int discoverChannelsCalls = 0;

  final List<(String, String, String)> publishMessageCalls = [];
  final List<(String, String)> markAsReadCalls = [];
  final List<String> deleteChannelCalls = [];
  final List<String> searchChannelCalls = [];
  final List<String> getChannelCalls = [];
  final List<(String, String, String)> addReactionCalls = [];
  final List<(String, String, String)> removeReactionCalls = [];
  bool addReactionResult = true;
  bool removeReactionResult = true;

  final List<String> createOrderCalls = <String>[];
  final List<String> payOrderCalls = <String>[];
  final List<String> getOrderCalls = <String>[];
  final List<(String, String)> deleteMessageCalls = <(String, String)>[];
  final List<(String, String, bool)> setMessagePinnedCalls =
      <(String, String, bool)>[];
  final List<String> subscribeCalls = <String>[];
  final List<String> unsubscribeCalls = <String>[];

  @override
  Future<bool> subscribe(String channelId) async {
    subscribeCalls.add(channelId);
    return subscribeResult;
  }

  @override
  Future<bool> unsubscribe(String channelId) async {
    unsubscribeCalls.add(channelId);
    return unsubscribeResult;
  }

  @override
  Future<ChannelOrderModel?> createOrder({required String channelId}) async {
    createOrderCalls.add(channelId);
    return createOrderResult?.call();
  }

  @override
  Future<bool> payOrder({required String orderNo}) async {
    payOrderCalls.add(orderNo);
    return payOrderResult;
  }

  @override
  Future<ChannelOrderModel?> getOrder({required String orderNo}) async {
    getOrderCalls.add(orderNo);
    return getOrderResult?.call();
  }

  @override
  Future<bool> deleteMessage(String channelId, String messageId) async {
    deleteMessageCalls.add((channelId, messageId));
    return deleteMessageResult;
  }

  @override
  Future<bool> setMessagePinned(
    String channelId,
    String messageId,
    bool pinned,
  ) async {
    setMessagePinnedCalls.add((channelId, messageId, pinned));
    return setMessagePinnedResult;
  }

  @override
  Future<List<ChannelModel>> getSubscribedChannels({
    String? cursor,
    int limit = 50,
  }) async {
    return subscribedChannels;
  }

  @override
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    return messages;
  }

  @override
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) async {
    publishMessageCalls.add((channelId, content, msgType));
    return publishMessageResult;
  }

  @override
  Future<bool> markAsRead(String channelId, String messageId) async {
    markAsReadCalls.add((channelId, messageId));
    return markAsReadResult;
  }

  @override
  Future<bool> deleteChannel(String channelId) async {
    deleteChannelCalls.add(channelId);
    return deleteChannelResult;
  }

  @override
  Future<bool> addReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    addReactionCalls.add((channelId, messageId, reactionType));
    return addReactionResult;
  }

  @override
  Future<bool> removeReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    removeReactionCalls.add((channelId, messageId, reactionType));
    return removeReactionResult;
  }

  @override
  Future<List<ChannelModel>> searchChannels(
    String keyword, {
    int limit = 20,
  }) async {
    searchChannelCalls.add(keyword);
    return searchResult;
  }

  @override
  Future<ChannelModel?> getChannel(String channelId) async {
    getChannelCalls.add(channelId);
    // channelById 优先（CH-2/CH-5 使用），回退到 channelByIdFromApi（CH-9 使用）
    if (channelById.containsKey(channelId)) return channelById[channelId];
    return channelByIdFromApi;
  }

  @override
  Future<ChannelStatsModel?> getChannelStats(String channelId) async {
    getChannelStatsCalls.add(channelId);
    return channelStatsResult;
  }

  @override
  Future<Map<String, dynamic>> getUnreadSummary() async {
    getUnreadSummaryCalls++;
    return unreadSummaryResult;
  }

  @override
  Future<List<ChannelOrderModel>> getMyOrders() async => myOrdersResult;

  @override
  Future<List<Map<String, dynamic>>> getMyInvitations() async =>
      myInvitationsResult;

  @override
  Future<List<Map<String, dynamic>>> getSentInvitations() async =>
      sentInvitationsResult;

  @override
  Future<bool> acceptInvitation({required String invitationId}) async {
    acceptInvitationCalls.add(invitationId);
    return acceptInvitationResult;
  }

  @override
  Future<bool> rejectInvitation({required String invitationId}) async {
    rejectInvitationCalls.add(invitationId);
    return rejectInvitationResult;
  }

  @override
  Future<List<ChannelModel>> discoverChannels({
    String? category,
    int limit = 20,
  }) async {
    discoverChannelsCalls++;
    return discoverChannelsResult;
  }
}

/// ChannelRepo fake，追踪 saveChannel / incrementUnreadCount / deleteSubscription
class _FakeChannelRepo extends ChannelRepo {
  final List<ChannelModel> savedChannels = <ChannelModel>[];
  final List<ChannelSubscriptionModel> savedSubscriptions =
      <ChannelSubscriptionModel>[];
  final List<String> incrementedChannels = <String>[];
  final List<String> deletedSubscriptions = <String>[];
  final List<String> deletedChannels = <String>[];
  final List<(String, String)> markAsReadCalls = <(String, String)>[];
  final Map<String, int> unreadCountByChannel = <String, int>{};
  List<Map<String, dynamic>> channelsWithSubscription =
      <Map<String, dynamic>>[];
  final Map<String, ChannelSubscriptionModel> subscriptions =
      <String, ChannelSubscriptionModel>{};

  // 本地频道数据（测试可预先填充）
  List<ChannelModel> localChannels = <ChannelModel>[];
  List<ChannelSubscriptionModel> allSubscriptionsList =
      <ChannelSubscriptionModel>[];

  @override
  Future<void> saveChannel(ChannelModel channel, {dynamic txn}) async {
    savedChannels.add(channel);
  }

  @override
  Future<void> saveSubscription(
    ChannelSubscriptionModel subscription, {
    dynamic txn,
  }) async {
    savedSubscriptions.add(subscription);
  }

  @override
  Future<ChannelSubscriptionModel?> getSubscription(String channelId) async {
    return subscriptions[channelId];
  }

  @override
  Future<int> incrementUnreadCount(String channelId) async {
    incrementedChannels.add(channelId);
    return 1;
  }

  @override
  Future<int> deleteSubscription(String channelId) async {
    deletedSubscriptions.add(channelId);
    return 1;
  }

  @override
  Future<int> deleteChannel(String channelId) async {
    deletedChannels.add(channelId);
    return 1;
  }

  @override
  Future<int> markAsRead(String channelId, String messageId) async {
    markAsReadCalls.add((channelId, messageId));
    return 1;
  }

  @override
  Future<int> updateUnreadCount(String channelId, int count) async {
    unreadCountByChannel[channelId] = count;
    return 1;
  }

  @override
  Future<int> getTotalUnreadCount() async {
    return unreadCountByChannel.values.fold<int>(0, (a, b) => a + b);
  }

  @override
  Future<List<ChannelModel>> searchChannels(
    String keyword, {
    int limit = 50,
  }) async {
    return localChannels
        .where(
          (c) => c.name.toLowerCase().contains(keyword.toLowerCase()),
        )
        .toList();
  }

  @override
  Future<ChannelModel?> getChannel(
    String channelId, {
    dynamic txn,
  }) async {
    try {
      return localChannels.firstWhere(
        (c) => c.id.toString() == channelId,
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<ChannelSubscriptionModel>> getAllSubscriptions() async {
    return allSubscriptionsList;
  }

  @override
  Future<List<Map<String, dynamic>>>
      getSubscribedChannelsWithSubscription() async {
    return channelsWithSubscription;
  }
}

/// ChannelMessageRepo fake，追踪 saveMessage / deleteMessage / setMessagePinned
class _FakeChannelMessageRepo extends ChannelMessageRepo {
  final List<ChannelMessageModel> savedMessages = <ChannelMessageModel>[];
  final List<String> deletedMessageIds = <String>[];
  // alias used in CH-14 tests
  List<String> get deletedMessages => deletedMessageIds;
  final List<String> deletedByChannelCalls = <String>[];
  final Map<String, bool> pinnedByMessageId = <String, bool>{};
  List<ChannelMessageModel> localMessages = <ChannelMessageModel>[];

  @override
  Future<void> saveMessage(
    ChannelMessageModel message, {
    dynamic txn,
  }) async {
    savedMessages.add(message);
  }

  @override
  Future<int> deleteMessage(String messageId) async {
    deletedMessageIds.add(messageId);
    return 1;
  }

  @override
  Future<int> setMessagePinned(String messageId, bool pinned) async {
    pinnedByMessageId[messageId] = pinned;
    return 1;
  }

  @override
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    return localMessages
        .where((m) => m.channelId.toString() == channelId)
        .toList();
  }

  @override
  Future<int> deleteMessagesByChannel(String channelId) async {
    deletedByChannelCalls.add(channelId);
    return 0;
  }

  final List<(String, int)> deleteOldMessagesCalls = <(String, int)>[];

  @override
  Future<int> deleteOldMessages(String channelId, int keepCount) async {
    deleteOldMessagesCalls.add((channelId, keepCount));
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _validMessageData({int channelId = 100, int id = 500}) {
  return {
    'id': id,
    'channel_id': channelId,
    'content': 'hello channel',
    'msg_type': 'channel_text',
    'created_at': 1745000000000,
  };
}

ChannelOrderModel _order(String orderNo) {
  return ChannelOrderModel(
    id: 1,
    channelId: 999,
    userId: 1,
    orderNo: orderNo,
    amount: 9.9,
    currency: 'CNY',
    status: 1,
    paymentMethod: 'wechat',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
}

ChannelModel _channel(int id) {
  return ChannelModel(
    id: id,
    name: 'Channel-$id',
    creatorId: 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── CH-1: handleChannelMessage ──────────────────────────────────────────────
  group('CH-1: handleChannelMessage', () {
    test('有效消息 → 保存消息 + 增量未读 + 广播 ChannelNewMessageEvent', () async {
      final messageRepo = _FakeChannelMessageRepo();
      final channelRepo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: channelRepo,
        messageRepo: messageRepo,
      );
      final events = <ChannelNewMessageEvent>[];
      final sub =
          AppEventBus.on<ChannelNewMessageEvent>().listen(events.add);

      await service.handleChannelMessage(_validMessageData());

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(messageRepo.savedMessages, hasLength(1),
          reason: '有效消息必须写本地');
      expect(messageRepo.savedMessages.single.id, 500);
      expect(channelRepo.incrementedChannels, equals(['100']),
          reason: 'unreadCount 必须 +1');
      expect(
        events.any((e) => e.channelId == '100'),
        isTrue,
        reason: '必须广播 ChannelNewMessageEvent 驱动列表/徽标刷新',
      );
    });

    test('channelId == 0 → 忽略，不写库不广播', () async {
      final messageRepo = _FakeChannelMessageRepo();
      final channelRepo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: channelRepo,
        messageRepo: messageRepo,
      );
      final events = <ChannelNewMessageEvent>[];
      final sub =
          AppEventBus.on<ChannelNewMessageEvent>().listen(events.add);

      await service.handleChannelMessage(
        _validMessageData(channelId: 0, id: 500),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(messageRepo.savedMessages, isEmpty,
          reason: 'channelId=0 是无效载荷，不得写库');
      expect(channelRepo.incrementedChannels, isEmpty);
      expect(events, isEmpty);
    });

    test('message.id == 0 → 忽略，不写库不广播', () async {
      final messageRepo = _FakeChannelMessageRepo();
      final channelRepo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: channelRepo,
        messageRepo: messageRepo,
      );
      final events = <ChannelNewMessageEvent>[];
      final sub =
          AppEventBus.on<ChannelNewMessageEvent>().listen(events.add);

      await service.handleChannelMessage(
        _validMessageData(channelId: 100, id: 0),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(messageRepo.savedMessages, isEmpty,
          reason: 'message.id=0 是无效载荷，不得写库');
      expect(channelRepo.incrementedChannels, isEmpty);
      expect(events, isEmpty);
    });
  });

  // ── CH-2: handleChannelInvitationCreated / handleChannelInvitationAccepted ──
  group('CH-2: handleChannelInvitation*', () {
    test(
      'handleChannelInvitationCreated 广播 channel_invitation_created 事件',
      () async {
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub =
            AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);

        await service.handleChannelInvitationCreated({'channel_id': '2001'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(
          events.any(
            (e) =>
                e.channelId == '2001' &&
                e.action == 'channel_invitation_created',
          ),
          isTrue,
          reason: '收到邀请创建通知必须广播让 UI 感知',
        );
      },
    );

    test(
      'handleChannelInvitationCreated 空 channel_id → 忽略不广播',
      () async {
        final service = ChannelService.forTest(
          api: _FakeChannelApi(),
          repo: _FakeChannelRepo(),
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub =
            AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);

        await service.handleChannelInvitationCreated({'channel_id': ''});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(events, isEmpty);
      },
    );

    test(
      'handleChannelInvitationAccepted 有效 channel → 写库 + 广播 accepted 事件',
      () async {
        final channelRepo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(
            channelById: {'3001': _channel(3001)},
          ),
          repo: channelRepo,
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub =
            AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);

        await service.handleChannelInvitationAccepted({'channel_id': '3001'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(channelRepo.savedChannels, hasLength(1),
            reason: '邀请接受后应写入频道信息');
        expect(channelRepo.savedChannels.single.id, 3001);
        expect(
          events.any(
            (e) =>
                e.channelId == '3001' &&
                e.action == 'channel_invitation_accepted',
          ),
          isTrue,
          reason: '邀请接受后必须广播事件驱动 UI',
        );
      },
    );

    test(
      'handleChannelInvitationAccepted channel.id==0 → 不写库但仍广播事件',
      () async {
        // 与 handleChannelSubscribed 对齐：id=0 无效不写库，
        // 但邀请已接受这一事实仍需广播让 UI 知晓（由用户手动重试详情）。
        final channelRepo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(
            channelById: {'4001': _channel(0)},
          ),
          repo: channelRepo,
          messageRepo: _FakeChannelMessageRepo(),
        );
        final events = <ChannelStateChangedEvent>[];
        final sub =
            AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);

        await service.handleChannelInvitationAccepted({'channel_id': '4001'});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(channelRepo.savedChannels, isEmpty,
            reason: 'channel.id=0 的无效载荷不得写库');
        expect(
          events.any(
            (e) =>
                e.channelId == '4001' &&
                e.action == 'channel_invitation_accepted',
          ),
          isTrue,
          reason: '即使频道信息无效，邀请接受事件仍须广播',
        );
      },
    );
  });

  // ── CH-3: createAndPayOrder ─────────────────────────────────────────────────
  group('CH-3: createAndPayOrder 失败路径', () {
    test('createOrder 返回 null → 立即返回 null，不调 payOrder', () async {
      final api = _FakeChannelApi(createOrderResult: () => null);
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.createAndPayOrder('ch-99');

      expect(result, isNull);
      expect(api.payOrderCalls, isEmpty,
          reason: '创建订单失败后不应调 payOrder');
      expect(api.getOrderCalls, isEmpty);
    });

    test('payOrder 返回 false → 返回 null，不调 getOrder', () async {
      final api = _FakeChannelApi(
        createOrderResult: () => _order('order-001'),
        payOrderResult: false,
      );
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.createAndPayOrder('ch-99');

      expect(result, isNull);
      expect(api.payOrderCalls, equals(['order-001']),
          reason: 'payOrder 必须以 createOrder 返回的 orderNo 调用');
      expect(api.getOrderCalls, isEmpty,
          reason: '支付失败后不应调 getOrder');
    });

    test('全部成功 → 返回 getOrder 的最终订单', () async {
      final finalOrder = _order('order-002');
      final api = _FakeChannelApi(
        createOrderResult: () => _order('order-002'),
        payOrderResult: true,
        getOrderResult: () => finalOrder,
      );
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.createAndPayOrder('ch-99');

      expect(result, isNotNull);
      expect(result!.orderNo, 'order-002');
      expect(api.getOrderCalls, equals(['order-002']));
    });
  });

  // ── CH-4: deleteMessage / setMessagePinned ──────────────────────────────────
  group('CH-4: deleteMessage / setMessagePinned', () {
    test(
      'deleteMessage 成功 → 删本地 + 广播 ChannelMessageDeletedEvent',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(deleteMessageResult: true),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub =
            AppEventBus.on<ChannelMessageDeletedEvent>().listen(events.add);

        final ok = await service.deleteMessage('ch-1', 'msg-1');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(ok, isTrue);
        expect(messageRepo.deletedMessageIds, equals(['msg-1']),
            reason: 'API 成功后必须删本地');
        expect(
          events.any(
            (e) => e.channelId == 'ch-1' && e.messageId == 'msg-1',
          ),
          isTrue,
          reason: '删除成功后必须广播事件驱动 UI 移除气泡',
        );
      },
    );

    test(
      'deleteMessage API 失败 → 返回 false + 不删本地 + 不广播',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(deleteMessageResult: false),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );
        final events = <ChannelMessageDeletedEvent>[];
        final sub =
            AppEventBus.on<ChannelMessageDeletedEvent>().listen(events.add);

        final ok = await service.deleteMessage('ch-1', 'msg-2');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(ok, isFalse);
        expect(messageRepo.deletedMessageIds, isEmpty,
            reason: 'API 失败时不得删本地，防止半一致');
        expect(events, isEmpty);
      },
    );

    test(
      'setMessagePinned 成功 → 更新本地 pinnedByMessageId',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(setMessagePinnedResult: true),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );

        final ok = await service.setMessagePinned('ch-1', 'msg-3', true);

        expect(ok, isTrue);
        expect(messageRepo.pinnedByMessageId, equals({'msg-3': true}),
            reason: 'API 成功后必须更新本地置顶状态');
      },
    );

    test(
      'setMessagePinned API 失败 → 返回 false + 不更新本地',
      () async {
        final messageRepo = _FakeChannelMessageRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(setMessagePinnedResult: false),
          repo: _FakeChannelRepo(),
          messageRepo: messageRepo,
        );

        final ok = await service.setMessagePinned('ch-1', 'msg-4', true);

        expect(ok, isFalse);
        expect(messageRepo.pinnedByMessageId, isEmpty,
            reason: 'API 失败时不得修改本地状态');
      },
    );
  });

  // ── CH-5: subscribeChannel / unsubscribeChannel ─────────────────────────────
  group('CH-5: subscribeChannel / unsubscribeChannel', () {
    test(
      'subscribeChannel 成功 → 写频道 + 写订阅关系 + 返回 true',
      () async {
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(
            subscribeResult: true,
            channelById: {'ch-1': _channel(1001)},
          ),
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );

        final ok = await service.subscribeChannel('ch-1');

        expect(ok, isTrue);
        expect(repo.savedChannels, hasLength(1),
            reason: '订阅后需写入频道信息');
        expect(repo.savedChannels.single.id, 1001);
        expect(repo.savedSubscriptions, hasLength(1),
            reason: '订阅后需写入订阅关系');
      },
    );

    test(
      'subscribeChannel API 失败 → 返回 false，不写本地',
      () async {
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(subscribeResult: false),
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );

        final ok = await service.subscribeChannel('ch-2');

        expect(ok, isFalse);
        expect(repo.savedChannels, isEmpty);
        expect(repo.savedSubscriptions, isEmpty);
      },
    );

    test(
      'subscribeChannel getChannel 返回 null → 返回 false，不写订阅',
      () async {
        final repo = _FakeChannelRepo();
        // subscribeResult=true 但 channelById 为空（getChannel 返回 null）
        final service = ChannelService.forTest(
          api: _FakeChannelApi(subscribeResult: true, channelById: const {}),
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );

        final ok = await service.subscribeChannel('ch-3');

        expect(ok, isFalse,
            reason: '频道信息拉取失败时订阅应回滚，避免空壳订阅');
        expect(repo.savedSubscriptions, isEmpty);
      },
    );

    test(
      'unsubscribeChannel 成功 → 删订阅关系 + 返回 true',
      () async {
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(unsubscribeResult: true),
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );

        final ok = await service.unsubscribeChannel('ch-4');

        expect(ok, isTrue);
        expect(repo.deletedSubscriptions, equals(['ch-4']),
            reason: '退订后必须删除本地订阅关系');
      },
    );

    test(
      'unsubscribeChannel API 失败 → 返回 false + 不删本地',
      () async {
        final repo = _FakeChannelRepo();
        final service = ChannelService.forTest(
          api: _FakeChannelApi(unsubscribeResult: false),
          repo: repo,
          messageRepo: _FakeChannelMessageRepo(),
        );

        final ok = await service.unsubscribeChannel('ch-5');

        expect(ok, isFalse);
        expect(repo.deletedSubscriptions, isEmpty,
            reason: 'API 失败时不得删本地订阅，防止半一致');
      },
    );
  });

  // ─── CH-6  syncSubscribedChannels ──────────────────────────────────────────
  group('CH-6 syncSubscribedChannels', () {
    test('API 返回两个频道 → 两个 saveChannel + 两个 saveSubscription（均为新）',
        () async {
      final ch1 = _channel(1);
      final ch2 = _channel(2);
      final repo = _FakeChannelRepo(); // subscriptions 为空 → 全部视为新订阅
      final service = ChannelService.forTest(
        api: _FakeChannelApi(subscribedChannels: [ch1, ch2]),
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.syncSubscribedChannels();

      expect(result, hasLength(2));
      expect(repo.savedChannels, hasLength(2));
      expect(repo.savedSubscriptions, hasLength(2),
          reason: '两个频道均未存在订阅，各自应创建一条 subscription');
    });

    test('已存在订阅的频道 → saveChannel 但不重复 saveSubscription', () async {
      final ch = _channel(42);
      final repo = _FakeChannelRepo();
      // 预先填充订阅，模拟 "已有订阅"
      repo.subscriptions['42'] = ChannelSubscriptionModel(
        channelId: 42,
        subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final service = ChannelService.forTest(
        api: _FakeChannelApi(subscribedChannels: [ch]),
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      await service.syncSubscribedChannels();

      expect(repo.savedChannels, hasLength(1));
      expect(repo.savedSubscriptions, isEmpty,
          reason: '订阅已存在，不得重复插入');
    });

    test('API 返回空列表 → 返回空 + 不写库', () async {
      final repo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(subscribedChannels: []),
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.syncSubscribedChannels();

      expect(result, isEmpty);
      expect(repo.savedChannels, isEmpty);
    });

    test('API 抛出异常 → 返回空列表，不崩溃', () async {
      final apiThrows = _ThrowingChannelApi();
      final service = ChannelService.forTest(
        api: apiThrows,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.syncSubscribedChannels();

      expect(result, isEmpty);
    });
  });

  // ─── CH-7  syncMessages ───────────────────────────────────────────────────
  group('CH-7 syncMessages', () {
    ChannelMessageModel msg(int id) => ChannelMessageModel(
          id: id,
          channelId: 100,
          content: 'content-$id',
          msgType: 'channel_text',
          createdAt: DateTime.fromMillisecondsSinceEpoch(id * 1000),
        );

    test('API 返回 3 条消息 → saveMessage 被调 3 次 + 返回 3 条', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(messages: [msg(1), msg(2), msg(3)]),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final result = await service.syncMessages(channelId: '100');

      expect(result, hasLength(3));
      expect(msgRepo.savedMessages, hasLength(3));
    });

    test('API 返回空 → 不写库 + 返回空', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(messages: []),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final result = await service.syncMessages(channelId: '100');

      expect(result, isEmpty);
      expect(msgRepo.savedMessages, isEmpty);
    });

    test('API 抛出异常 → 返回空列表，不崩溃', () async {
      final service = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.syncMessages(channelId: '100');

      expect(result, isEmpty);
    });
  });

  // ─── CH-8  publishMessage / getMessages / deleteChannel / markAsRead ────────
  group('CH-8 publishMessage', () {
    ChannelMessageModel msg(int id) => ChannelMessageModel(
          id: id,
          channelId: 100,
          content: 'test',
          msgType: 'channel_text',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        );

    test('API 返回消息 → 保存到本地 + 返回消息', () async {
      final m = msg(99);
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(publishMessageResult: m),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final result = await service.publishMessage(
        channelId: '100',
        content: 'hello',
        msgType: 'channel_text',
      );

      expect(result, isNotNull);
      expect(result!.id, 99);
      expect(msgRepo.savedMessages, hasLength(1));
    });

    test('API 返回 null → 不写本地 + 返回 null', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(publishMessageResult: null),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final result = await service.publishMessage(
        channelId: '100',
        content: 'hello',
        msgType: 'channel_text',
      );

      expect(result, isNull);
      expect(msgRepo.savedMessages, isEmpty);
    });

    test('API 抛异常 → 返回 null，不崩溃', () async {
      final service = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.publishMessage(
        channelId: '100',
        content: 'hello',
        msgType: 'channel_text',
      );

      expect(result, isNull);
    });
  });

  group('CH-8 getMessages (本地优先回退)', () {
    ChannelMessageModel msg(int id, int channelId) => ChannelMessageModel(
          id: id,
          channelId: channelId,
          content: 'c',
          msgType: 'channel_text',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        );

    test('本地有数据 → 直接返回本地，不请求 API', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final localMsg = msg(1, 100);
      msgRepo.localMessages = [localMsg];

      final api = _FakeChannelApi(messages: [msg(2, 100)]); // API 有不同数据
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final result = await service.getMessages(channelId: '100');

      expect(result, hasLength(1));
      expect(result.first.id, 1, reason: '应返回本地数据，不是 API 数据');
    });

    test('本地无数据 → 回退到 API 同步 + 保存本地', () async {
      final msgRepo = _FakeChannelMessageRepo();
      // localMessages 为空（默认）

      final apiMsg = msg(5, 100);
      final api = _FakeChannelApi(messages: [apiMsg]);
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final result = await service.getMessages(channelId: '100');

      expect(result, hasLength(1));
      expect(result.first.id, 5, reason: '本地空时走 API 数据');
      expect(msgRepo.savedMessages, hasLength(1), reason: 'API 数据应落库');
    });
  });

  group('CH-8 deleteChannel', () {
    test('API 成功 → 删除本地 + 返回 true', () async {
      final repo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(deleteChannelResult: true),
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.deleteChannel('ch-99');

      expect(ok, isTrue);
      expect(repo.deletedChannels, contains('ch-99'));
    });

    test('API 失败 → 不删本地 + 返回 false', () async {
      final repo = _FakeChannelRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(deleteChannelResult: false),
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.deleteChannel('ch-99');

      expect(ok, isFalse);
      expect(repo.deletedChannels, isEmpty,
          reason: 'API 失败时不应删本地，防止半一致');
    });
  });

  group('CH-8 markAsRead', () {
    test('成功路径 → API + Repo 均被调用 + 广播 ChannelUnreadCountUpdatedEvent',
        () async {
      final repo = _FakeChannelRepo();
      final api = _FakeChannelApi(markAsReadResult: true);
      final service = ChannelService.forTest(
        api: api,
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final events = <ChannelUnreadCountUpdatedEvent>[];
      final sub =
          AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(events.add);

      final ok = await service.markAsRead('ch-1', 'msg-42');
      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(ok, isTrue);
      expect(api.markAsReadCalls, contains(('ch-1', 'msg-42')));
      expect(repo.markAsReadCalls, contains(('ch-1', 'msg-42')));
      expect(events, hasLength(1));
      expect(events.first.channelId, 'ch-1');
      expect(events.first.unreadCount, 0);
    });

    test('API 抛异常 → 返回 false，不广播事件', () async {
      final service = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final events = <ChannelUnreadCountUpdatedEvent>[];
      final sub =
          AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(events.add);

      final ok = await service.markAsRead('ch-1', 'msg-42');
      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(ok, isFalse);
      expect(events, isEmpty, reason: '失败时不应广播未读事件');
    });
  });

  // ─── CH-9  searchChannels / getChannel（本地优先回退）─────────────────────
  group('CH-9 searchChannels 本地优先', () {
    test('本地有命中 → 直接返回本地，不调 API', () async {
      final repo = _FakeChannelRepo();
      repo.localChannels = [_channel(1), _channel(2)]; // name: 'Channel-1/2'

      final api = _FakeChannelApi(
        searchResult: [_channel(99)], // API 有不同数据
      );
      final service = ChannelService.forTest(
        api: api,
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.searchChannels('Channel-1');

      expect(result, hasLength(1));
      expect(result.first.id, 1, reason: '应返回本地命中，不是 API 数据');
      expect(api.searchChannelCalls, isEmpty,
          reason: '本地有结果时不应调 API');
    });

    test('本地无命中 → 回退到 API', () async {
      final repo = _FakeChannelRepo();
      repo.localChannels = [_channel(1)]; // name: 'Channel-1'

      final api = _FakeChannelApi(searchResult: [_channel(99)]);
      final service = ChannelService.forTest(
        api: api,
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      // 搜索 "xyz" 本地无法匹配 'Channel-1'
      final result = await service.searchChannels('xyz');

      expect(result, hasLength(1));
      expect(result.first.id, 99, reason: '本地无结果时应走 API');
      expect(api.searchChannelCalls, equals(['xyz']));
    });

    test('本地空列表 + API 返回空 → 返回空', () async {
      final service = ChannelService.forTest(
        api: _FakeChannelApi(searchResult: []),
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.searchChannels('nothing');

      expect(result, isEmpty);
    });
  });

  group('CH-9 getChannel 本地优先', () {
    test('本地有数据 → 直接返回本地，不调 API', () async {
      final repo = _FakeChannelRepo();
      repo.localChannels = [_channel(42)];

      final api = _FakeChannelApi(channelByIdFromApi: _channel(99));
      final service = ChannelService.forTest(
        api: api,
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.getChannel('42');

      expect(result, isNotNull);
      expect(result!.id, 42, reason: '本地有数据应返回本地，不是 API 数据');
      expect(api.getChannelCalls, isEmpty,
          reason: '本地命中时不应调 API');
    });

    test('本地无数据 → 调 API + 保存到本地', () async {
      final repo = _FakeChannelRepo();
      // localChannels 为空

      final api = _FakeChannelApi(channelByIdFromApi: _channel(55));
      final service = ChannelService.forTest(
        api: api,
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.getChannel('55');

      expect(result, isNotNull);
      expect(result!.id, 55, reason: '本地无数据应返回 API 数据');
      expect(api.getChannelCalls, equals(['55']));
      expect(repo.savedChannels, hasLength(1),
          reason: 'API 命中后应保存到本地');
      expect(repo.savedChannels.first.id, 55);
    });

    test('本地无数据 + API 返回 null → 返回 null，不写本地', () async {
      final repo = _FakeChannelRepo();

      final api = _FakeChannelApi(channelByIdFromApi: null);
      final service = ChannelService.forTest(
        api: api,
        repo: repo,
        messageRepo: _FakeChannelMessageRepo(),
      );

      final result = await service.getChannel('999');

      expect(result, isNull);
      expect(repo.savedChannels, isEmpty,
          reason: 'API 返回 null 时不应写本地');
    });
  });

  // ─── CH-10  cleanupOldData ───────────────────────────────────────────────
  group('CH-10 cleanupOldData', () {
    test('有 2 个订阅 → deleteOldMessages 被调 2 次，携带正确 keepCount', () async {
      final repo = _FakeChannelRepo();
      repo.allSubscriptionsList = [
        ChannelSubscriptionModel(
          channelId: 10,
          subscribedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
        ChannelSubscriptionModel(
          channelId: 20,
          subscribedAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      ];

      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
        messageRepo: msgRepo,
      );

      await service.cleanupOldData(keepCount: 500);

      expect(msgRepo.deleteOldMessagesCalls, hasLength(2));
      expect(
        msgRepo.deleteOldMessagesCalls.map((e) => e.$1).toSet(),
        containsAll(['10', '20']),
        reason: '两个订阅的频道都应清理',
      );
      expect(
        msgRepo.deleteOldMessagesCalls.every((e) => e.$2 == 500),
        isTrue,
        reason: 'keepCount 应透传',
      );
    });

    test('无订阅 → deleteOldMessages 不被调用', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(), // allSubscriptionsList 默认空
        messageRepo: msgRepo,
      );

      await service.cleanupOldData();

      expect(msgRepo.deleteOldMessagesCalls, isEmpty);
    });

    test('repo 抛异常 → 不崩溃', () async {
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _ThrowingChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      // 不应抛出
      await expectLater(service.cleanupOldData(), completes);
    });
  });

  // ─── CH-11  handleChannelMessageRevoked ──────────────────────────────────
  group('CH-11 handleChannelMessageRevoked', () {
    test('有效载荷 → 删本地 + 广播 ChannelMessageDeletedEvent(reason=revoked)',
        () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final events = <ChannelMessageDeletedEvent>[];
      final sub =
          AppEventBus.on<ChannelMessageDeletedEvent>().listen(events.add);

      await service.handleChannelMessageRevoked({
        'channel_id': 'ch-10',
        'message_id': 'msg-10',
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(msgRepo.deletedMessageIds, equals(['msg-10']),
          reason: '撤回必须删本地消息');
      expect(events, hasLength(1));
      expect(events.first.channelId, 'ch-10');
      expect(events.first.messageId, 'msg-10');
      expect(events.first.reason, 'revoked',
          reason: '撤回事件 reason 应为 revoked，与删除区分');
    });

    test('channel_id 为空 → 忽略，不删本地不广播', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final events = <ChannelMessageDeletedEvent>[];
      final sub =
          AppEventBus.on<ChannelMessageDeletedEvent>().listen(events.add);

      await service.handleChannelMessageRevoked({
        'channel_id': '',
        'message_id': 'msg-10',
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(msgRepo.deletedMessageIds, isEmpty);
      expect(events, isEmpty);
    });

    test('message_id 为空 → 忽略，不删本地不广播', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final service = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final events = <ChannelMessageDeletedEvent>[];
      final sub =
          AppEventBus.on<ChannelMessageDeletedEvent>().listen(events.add);

      await service.handleChannelMessageRevoked({
        'channel_id': 'ch-10',
        'message_id': '',
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(msgRepo.deletedMessageIds, isEmpty);
      expect(events, isEmpty);
    });
  });

  // ─── CH-12  addReaction / removeReaction ─────────────────────────────────
  group('CH-12 addReaction', () {
    test('API 成功 → 返回 true', () async {
      final api = _FakeChannelApi();
      api.addReactionResult = true;
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.addReaction(
        channelId: 'ch-1',
        messageId: 'msg-1',
        reactionType: 'like',
      );

      expect(ok, isTrue);
      expect(api.addReactionCalls, equals([('ch-1', 'msg-1', 'like')]));
    });

    test('API 失败 → 返回 false', () async {
      final api = _FakeChannelApi();
      api.addReactionResult = false;
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.addReaction(
        channelId: 'ch-1',
        messageId: 'msg-1',
        reactionType: 'like',
      );

      expect(ok, isFalse);
    });

    test('API 抛异常 → 返回 false，不崩溃', () async {
      final service = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.addReaction(
        channelId: 'ch-1',
        messageId: 'msg-1',
        reactionType: 'like',
      );

      expect(ok, isFalse);
    });
  });

  group('CH-12 removeReaction', () {
    test('API 成功 → 返回 true', () async {
      final api = _FakeChannelApi();
      api.removeReactionResult = true;
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.removeReaction(
        channelId: 'ch-1',
        messageId: 'msg-1',
        reactionType: 'like',
      );

      expect(ok, isTrue);
      expect(api.removeReactionCalls, equals([('ch-1', 'msg-1', 'like')]));
    });

    test('API 失败 → 返回 false', () async {
      final api = _FakeChannelApi();
      api.removeReactionResult = false;
      final service = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.removeReaction(
        channelId: 'ch-1',
        messageId: 'msg-1',
        reactionType: 'like',
      );

      expect(ok, isFalse);
    });

    test('API 抛异常 → 返回 false，不崩溃', () async {
      final service = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: _FakeChannelMessageRepo(),
      );

      final ok = await service.removeReaction(
        channelId: 'ch-1',
        messageId: 'msg-1',
        reactionType: 'like',
      );

      expect(ok, isFalse);
    });
  });

  // ─── CH-13 getUnreadCount / updateUnreadCount / getTotalUnreadCount / getChannelStats
  group('CH-13 未读计数与统计', () {
    test('getUnreadCount — 有订阅时返回 unreadCount', () async {
      final repo = _FakeChannelRepo();
      repo.subscriptions['ch-1'] = ChannelSubscriptionModel(
        channelId: 1,
        subscribedAt: DateTime(2025, 1, 1),
        unreadCount: 5,
      );
      final svc = ChannelService.forTest(api: _FakeChannelApi(), repo: repo);

      final count = await svc.getUnreadCount('ch-1');
      expect(count, 5);
    });

    test('getUnreadCount — 无订阅记录时返回 0', () async {
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
      );
      final count = await svc.getUnreadCount('no-such-channel');
      expect(count, 0);
    });

    test('updateUnreadCount — 正常写入不抛异常', () async {
      final repo = _FakeChannelRepo();
      final svc = ChannelService.forTest(api: _FakeChannelApi(), repo: repo);

      await expectLater(svc.updateUnreadCount('ch-2', 3), completes);
      expect(repo.unreadCountByChannel['ch-2'], 3);
    });

    test('updateUnreadCount — repo 抛异常时吞掉不崩溃', () async {
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _ThrowingChannelRepo(),
      );
      // 不应抛出任何异常
      await expectLater(svc.updateUnreadCount('ch-x', 1), completes);
    });

    test('getTotalUnreadCount — 汇总多频道未读', () async {
      final repo = _FakeChannelRepo();
      repo.unreadCountByChannel['ch-1'] = 2;
      repo.unreadCountByChannel['ch-2'] = 3;
      final svc = ChannelService.forTest(api: _FakeChannelApi(), repo: repo);

      expect(await svc.getTotalUnreadCount(), 5);
    });

    test('getChannelStats — API 返回数据时透传', () async {
      final stats = ChannelStatsModel(
        channelId: 10,
        subscriberCount: 100,
        totalMessages: 500,
        totalViews: 2000,
        totalReactions: 80,
      );
      final api = _FakeChannelApi(channelStatsResult: stats);
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());

      final result = await svc.getChannelStats('10');
      expect(result?.subscriberCount, 100);
      expect(api.getChannelStatsCalls, ['10']);
    });

    test('getChannelStats — API 返回 null 时透传 null', () async {
      final api = _FakeChannelApi(channelStatsResult: null);
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());

      expect(await svc.getChannelStats('99'), isNull);
    });

    test('getChannelStats — API 抛异常时返回 null 不崩溃', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.getChannelStats('ch-1'), isNull);
    });
  });

  // ─── CH-14 S2C handler：subscribed / unsubscribed / updated / deleted / messageDeleted
  group('CH-14 S2C channel handlers', () {
    // ── handleChannelSubscribed ──────────────────────────────────────────────
    test('subscribed — 空 channel_id → 忽略，不写库不广播', () async {
      final repo = _FakeChannelRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
      );
      await svc.handleChannelSubscribed({'channel_id': ''});
      expect(repo.savedChannels, isEmpty);
      expect(repo.savedSubscriptions, isEmpty);
    });

    test('subscribed — 已有订阅（幂等）→ 不重复写库', () async {
      final repo = _FakeChannelRepo();
      repo.subscriptions['ch-42'] = ChannelSubscriptionModel(
        channelId: 42,
        subscribedAt: DateTime(2025, 1, 1),
      );
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
      );
      await svc.handleChannelSubscribed({'channel_id': 'ch-42'});
      expect(repo.savedChannels, isEmpty); // 没有二次写
    });

    test('subscribed — channel.id=0 → 忽略（无效载荷），不写库', () async {
      final repo = _FakeChannelRepo();
      final now = DateTime(2025, 1, 1);
      final invalidChannel = ChannelModel(
        id: 0,
        name: 'bad',
        type: ChannelType.public,
        creatorId: 0,
        createdAt: now,
        updatedAt: now,
      );
      final api = _FakeChannelApi(channelByIdFromApi: invalidChannel);
      final svc = ChannelService.forTest(api: api, repo: repo);

      await svc.handleChannelSubscribed({'channel_id': 'ch-0'});
      expect(repo.savedChannels, isEmpty);
      expect(repo.savedSubscriptions, isEmpty);
    });

    test('subscribed — 合法 channel → saveChannel + saveSubscription + 广播事件', () async {
      final repo = _FakeChannelRepo();
      final now = DateTime(2025, 1, 1);
      final channel = ChannelModel(
        id: 99,
        name: 'valid',
        type: ChannelType.public,
        creatorId: 1,
        createdAt: now,
        updatedAt: now,
      );
      final api = _FakeChannelApi(channelByIdFromApi: channel);
      final svc = ChannelService.forTest(api: api, repo: repo);

      final events = <ChannelStateChangedEvent>[];
      final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelSubscribed({'channel_id': '99'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.savedChannels, hasLength(1));
      expect(repo.savedChannels.first.id, 99);
      expect(repo.savedSubscriptions, hasLength(1));
      expect(events.any((e) => e.action == 'channel_subscribed'), isTrue);
    });

    // ── handleChannelUnsubscribed ────────────────────────────────────────────
    test('unsubscribed — 空 channel_id → 忽略', () async {
      final repo = _FakeChannelRepo();
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
        messageRepo: msgRepo,
      );
      await svc.handleChannelUnsubscribed({'channel_id': ''});
      expect(repo.deletedSubscriptions, isEmpty);
    });

    test('unsubscribed — 合法 id → deleteSubscription + deleteMessagesByChannel + 广播', () async {
      final repo = _FakeChannelRepo();
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
        messageRepo: msgRepo,
      );

      final events = <ChannelStateChangedEvent>[];
      final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelUnsubscribed({'channel_id': 'ch-5'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.deletedSubscriptions, contains('ch-5'));
      expect(msgRepo.deletedByChannelCalls, contains('ch-5'));
      expect(events.any((e) => e.action == 'channel_unsubscribed'), isTrue);
    });

    // ── handleChannelUpdated ─────────────────────────────────────────────────
    test('updated — 缺少 channel 字段 → 忽略', () async {
      final repo = _FakeChannelRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
      );
      await svc.handleChannelUpdated({'other': 'data'});
      expect(repo.savedChannels, isEmpty);
    });

    test('updated — channel.id=0 → 忽略无效载荷', () async {
      final repo = _FakeChannelRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
      );
      await svc.handleChannelUpdated({
        'channel': {'id': 0, 'name': 'bad'},
      });
      expect(repo.savedChannels, isEmpty);
    });

    test('updated — 合法 channel → saveChannel + 广播 channel_updated', () async {
      final repo = _FakeChannelRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
      );

      final events = <ChannelStateChangedEvent>[];
      final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelUpdated({
        'channel': {
          'id': 7,
          'name': 'updated',
          'type': 'public',
          'creator_id': 1,
          'created_at': '2025-01-01T00:00:00Z',
          'updated_at': '2025-06-01T00:00:00Z',
        },
      });
      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.savedChannels, hasLength(1));
      expect(events.any((e) => e.action == 'channel_updated'), isTrue);
    });

    // ── handleChannelDeleted ─────────────────────────────────────────────────
    test('deleted — 空 channel_id → 忽略', () async {
      final repo = _FakeChannelRepo();
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
        messageRepo: msgRepo,
      );
      await svc.handleChannelDeleted({'channel_id': ''});
      expect(repo.deletedChannels, isEmpty);
    });

    test('deleted — 合法 id → deleteChannel + deleteMessagesByChannel + 广播', () async {
      final repo = _FakeChannelRepo();
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
        messageRepo: msgRepo,
      );

      final events = <ChannelStateChangedEvent>[];
      final sub = AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelDeleted({'channel_id': 'ch-3'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.deletedChannels, contains('ch-3'));
      expect(msgRepo.deletedByChannelCalls, contains('ch-3'));
      expect(events.any((e) => e.action == 'channel_deleted'), isTrue);
    });

    // ── handleChannelMessageDeleted ──────────────────────────────────────────
    test('messageDeleted — 空 channel_id → 忽略', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );
      await svc.handleChannelMessageDeleted(
          {'channel_id': '', 'message_id': 'msg-1'});
      expect(msgRepo.deletedMessages, isEmpty);
    });

    test('messageDeleted — 空 message_id → 忽略', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );
      await svc.handleChannelMessageDeleted(
          {'channel_id': 'ch-1', 'message_id': ''});
      expect(msgRepo.deletedMessages, isEmpty);
    });

    test('messageDeleted — 合法 ids → deleteMessage + 广播 reason=deleted', () async {
      final msgRepo = _FakeChannelMessageRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
        messageRepo: msgRepo,
      );

      final events = <ChannelMessageDeletedEvent>[];
      final sub = AppEventBus.on<ChannelMessageDeletedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelMessageDeleted(
          {'channel_id': 'ch-1', 'message_id': 'msg-99'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(msgRepo.deletedMessages, contains('msg-99'));
      expect(events.any((e) => e.reason == 'deleted'), isTrue);
    });
  });

  // ─── CH-15 syncUnreadSummary + invitationCreated / invitationAccepted / orderPaid
  group('CH-15 syncUnreadSummary & invitation/order handlers', () {
    // ── syncUnreadSummary ────────────────────────────────────────────────────
    test('syncUnreadSummary — channels 缺失 → 返回空 map，广播 success=false', () async {
      final api = _FakeChannelApi(unreadSummaryResult: {'total_unread': 0});
      // channels 字段缺失（非 List）
      final svc = ChannelService.forTest(
        api: api,
        repo: _FakeChannelRepo(),
      );

      final syncEvents = <ChannelUnreadSummarySyncEvent>[];
      final sub = AppEventBus.on<ChannelUnreadSummarySyncEvent>()
          .listen(syncEvents.add);
      addTearDown(sub.cancel);

      final result = await svc.syncUnreadSummary(trigger: 'test');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(result, isEmpty);
      expect(syncEvents.any((e) => !e.success), isTrue);
      expect(api.getUnreadSummaryCalls, 1);
    });

    test('syncUnreadSummary — channels=[] 权威空集 → 清零所有订阅未读', () async {
      final repo = _FakeChannelRepo();
      repo.subscriptions['10'] = ChannelSubscriptionModel(
        channelId: 10,
        subscribedAt: DateTime(2025, 1, 1),
        unreadCount: 5,
      );
      final api = _FakeChannelApi(
        unreadSummaryResult: {'channels': [], 'total_unread': 0},
      );
      final svc = ChannelService.forTest(api: api, repo: repo);
      repo.allSubscriptionsList = [repo.subscriptions['10']!];

      await svc.syncUnreadSummary(trigger: 'test');

      expect(repo.unreadCountByChannel['10'], 0);
    });

    test('syncUnreadSummary — channels 带数据 → 只更新有差异的订阅', () async {
      final repo = _FakeChannelRepo();
      repo.subscriptions['20'] = ChannelSubscriptionModel(
        channelId: 20,
        subscribedAt: DateTime(2025, 1, 1),
        unreadCount: 3,
      );
      repo.subscriptions['21'] = ChannelSubscriptionModel(
        channelId: 21,
        subscribedAt: DateTime(2025, 1, 1),
        unreadCount: 7,
      );
      repo.allSubscriptionsList = [
        repo.subscriptions['20']!,
        repo.subscriptions['21']!,
      ];
      final api = _FakeChannelApi(
        unreadSummaryResult: {
          'channels': [
            {'channel_id': '20', 'unread_count': 3}, // 无变化
            {'channel_id': '21', 'unread_count': 0}, // 有变化
          ],
          'total_unread': 3,
        },
      );
      final svc = ChannelService.forTest(api: api, repo: repo);

      await svc.syncUnreadSummary();

      // ch-20 未变化（unreadCount 仍 3，未被写入）
      expect(repo.unreadCountByChannel.containsKey('20'), isFalse);
      // ch-21 被清零
      expect(repo.unreadCountByChannel['21'], 0);
    });

    test('syncUnreadSummary — API 抛异常 → 返回空 map，广播 success=false', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      final syncEvents = <ChannelUnreadSummarySyncEvent>[];
      final sub = AppEventBus.on<ChannelUnreadSummarySyncEvent>()
          .listen(syncEvents.add);
      addTearDown(sub.cancel);

      final result = await svc.syncUnreadSummary();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(result, isEmpty);
      expect(syncEvents.any((e) => !e.success), isTrue);
    });

    // ── handleChannelInvitationCreated ───────────────────────────────────────
    test('invitationCreated — 空 channel_id → 忽略', () async {
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
      );
      final events = <ChannelStateChangedEvent>[];
      final sub =
          AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelInvitationCreated({'channel_id': ''});
      await Future.delayed(const Duration(milliseconds: 10));
      expect(events, isEmpty);
    });

    test('invitationCreated — 合法 id → 广播 channel_invitation_created', () async {
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
      );
      final events = <ChannelStateChangedEvent>[];
      final sub =
          AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelInvitationCreated({'channel_id': 'ch-55'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        events.any((e) => e.action == 'channel_invitation_created'),
        isTrue,
      );
    });

    // ── handleChannelInvitationAccepted ──────────────────────────────────────
    test('invitationAccepted — channel.id=0 → 不写库但仍广播', () async {
      final repo = _FakeChannelRepo();
      final now = DateTime(2025, 1, 1);
      final badChannel = ChannelModel(
        id: 0, name: 'bad', type: ChannelType.public,
        creatorId: 0, createdAt: now, updatedAt: now,
      );
      final api = _FakeChannelApi(channelByIdFromApi: badChannel);
      final svc = ChannelService.forTest(api: api, repo: repo);

      final events = <ChannelStateChangedEvent>[];
      final sub =
          AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelInvitationAccepted({'channel_id': 'ch-0'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.savedChannels, isEmpty); // 不写库
      expect(
        events.any((e) => e.action == 'channel_invitation_accepted'),
        isTrue,
      );
    });

    test('invitationAccepted — 合法 channel → 写库 + 广播', () async {
      final repo = _FakeChannelRepo();
      final now = DateTime(2025, 1, 1);
      final channel = ChannelModel(
        id: 77, name: 'ok', type: ChannelType.public,
        creatorId: 1, createdAt: now, updatedAt: now,
      );
      final api = _FakeChannelApi(channelByIdFromApi: channel);
      final svc = ChannelService.forTest(api: api, repo: repo);

      final events = <ChannelStateChangedEvent>[];
      final sub =
          AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelInvitationAccepted({'channel_id': '77'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.savedChannels.any((c) => c.id == 77), isTrue);
      expect(
        events.any((e) => e.action == 'channel_invitation_accepted'),
        isTrue,
      );
    });

    // ── handleChannelOrderPaid ───────────────────────────────────────────────
    test('orderPaid — 空 channel_id → 忽略', () async {
      final repo = _FakeChannelRepo();
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: repo,
      );
      await svc.handleChannelOrderPaid({'channel_id': ''});
      expect(repo.savedChannels, isEmpty);
    });

    test('orderPaid — 合法 id → 广播 channel_order_paid + channel_subscribed 副作用', () async {
      final repo = _FakeChannelRepo();
      final now = DateTime(2025, 1, 1);
      final channel = ChannelModel(
        id: 88, name: 'paid', type: ChannelType.paid,
        creatorId: 1, createdAt: now, updatedAt: now,
      );
      final api = _FakeChannelApi(channelByIdFromApi: channel);
      final svc = ChannelService.forTest(api: api, repo: repo);

      final events = <ChannelStateChangedEvent>[];
      final sub =
          AppEventBus.on<ChannelStateChangedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await svc.handleChannelOrderPaid({'channel_id': '88'});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        events.any((e) => e.action == 'channel_order_paid'),
        isTrue,
      );
      // handleChannelSubscribed 副作用：channel 写库
      expect(repo.savedChannels.any((c) => c.id == 88), isTrue);
    });
  });

  // ─── CH-16 简单委托方法（错误降级 + 透传）
  group('CH-16 简单委托方法', () {
    // getSubscribedChannels
    test('getSubscribedChannels — API 成功 → 透传列表', () async {
      final now = DateTime(2025, 1, 1);
      final ch = ChannelModel(
        id: 1, name: 'ch', type: ChannelType.public,
        creatorId: 0, createdAt: now, updatedAt: now,
      );
      final api = _FakeChannelApi(subscribedChannels: [ch]);
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      final result = await svc.getSubscribedChannels();
      expect(result, hasLength(1));
    });

    test('getSubscribedChannels — API 抛异常 → 返回空列表', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.getSubscribedChannels(), isEmpty);
    });

    // isSubscribed
    test('isSubscribed — 有订阅 → true', () async {
      final repo = _FakeChannelRepo();
      repo.subscriptions['ch-10'] = ChannelSubscriptionModel(
        channelId: 10,
        subscribedAt: DateTime(2025, 1, 1),
      );
      final svc =
          ChannelService.forTest(api: _FakeChannelApi(), repo: repo);
      expect(await svc.isSubscribed('ch-10'), isTrue);
    });

    test('isSubscribed — 无订阅 → false', () async {
      final svc = ChannelService.forTest(
        api: _FakeChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.isSubscribed('ch-99'), isFalse);
    });

    // getSubscribedChannelsWithInfo
    test('getSubscribedChannelsWithInfo — 透传 repo 结果', () async {
      final repo = _FakeChannelRepo();
      repo.channelsWithSubscription = [
        {'id': '1', 'name': 'ch-a'},
        {'id': '2', 'name': 'ch-b'},
      ];
      final svc = ChannelService.forTest(api: _FakeChannelApi(), repo: repo);
      final result = await svc.getSubscribedChannelsWithInfo();
      expect(result, hasLength(2));
    });

    // getMyOrders
    test('getMyOrders — API 成功 → 透传订单列表', () async {
      final api = _FakeChannelApi(
        myOrdersResult: [_order('ORD-001'), _order('ORD-002')],
      );
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      final result = await svc.getMyOrders();
      expect(result, hasLength(2));
    });

    test('getMyOrders — API 抛异常 → 返回空列表', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.getMyOrders(), isEmpty);
    });

    // getMyInvitations / getSentInvitations
    test('getMyInvitations — API 成功 → 透传邀请列表', () async {
      final api = _FakeChannelApi(
        myInvitationsResult: [
          {'id': 'inv-1'},
          {'id': 'inv-2'},
        ],
      );
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      expect(await svc.getMyInvitations(), hasLength(2));
    });

    test('getMyInvitations — API 抛异常 → 返回空列表', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.getMyInvitations(), isEmpty);
    });

    test('getSentInvitations — API 成功 → 透传', () async {
      final api = _FakeChannelApi(
        sentInvitationsResult: [{'id': 'inv-sent-1'}],
      );
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      expect(await svc.getSentInvitations(), hasLength(1));
    });

    test('getSentInvitations — API 抛异常 → 返回空列表', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.getSentInvitations(), isEmpty);
    });
  });

  // ── CH-17: acceptInvitation / rejectInvitation / discoverChannels ─────────
  group('CH-17 acceptInvitation / rejectInvitation / discoverChannels', () {
    // acceptInvitation
    test('acceptInvitation — API 成功 → true，传入 invitationId', () async {
      final api = _FakeChannelApi();
      api.acceptInvitationResult = true;
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      final result = await svc.acceptInvitation('inv-42');
      expect(result, isTrue);
      expect(api.acceptInvitationCalls, ['inv-42']);
    });

    test('acceptInvitation — API 返回 false → false', () async {
      final api = _FakeChannelApi();
      api.acceptInvitationResult = false;
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      expect(await svc.acceptInvitation('inv-99'), isFalse);
    });

    test('acceptInvitation — API 抛异常 → false（不上抛）', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.acceptInvitation('inv-err'), isFalse);
    });

    // rejectInvitation
    test('rejectInvitation — API 成功 → true，传入 invitationId', () async {
      final api = _FakeChannelApi();
      api.rejectInvitationResult = true;
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      final result = await svc.rejectInvitation('inv-43');
      expect(result, isTrue);
      expect(api.rejectInvitationCalls, ['inv-43']);
    });

    test('rejectInvitation — API 抛异常 → false（不上抛）', () async {
      final svc = ChannelService.forTest(
        api: _ThrowingChannelApi(),
        repo: _FakeChannelRepo(),
      );
      expect(await svc.rejectInvitation('inv-err'), isFalse);
    });

    // discoverChannels
    test('discoverChannels — 透传 API 结果', () async {
      final now = DateTime(2025, 1, 1);
      final ch = ChannelModel(
        id: 7, name: 'discover-ch', type: ChannelType.public,
        creatorId: 0, createdAt: now, updatedAt: now,
      );
      final api = _FakeChannelApi();
      api.discoverChannelsResult = [ch];
      final svc = ChannelService.forTest(api: api, repo: _FakeChannelRepo());
      final result = await svc.discoverChannels();
      expect(result, hasLength(1));
      expect(result.first.name, 'discover-ch');
      expect(api.discoverChannelsCalls, 1);
    });
  });
}

/// API stub：所有方法均抛出异常，用于验证 service 异常降级
class _ThrowingChannelApi extends ChannelApi {
  @override
  Future<List<ChannelModel>> getSubscribedChannels({
    String? cursor,
    int limit = 50,
  }) =>
      Future.error(Exception('network error'));

  @override
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) =>
      Future.error(Exception('network error'));

  @override
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) =>
      Future.error(Exception('network error'));

  @override
  Future<bool> markAsRead(String channelId, String messageId) =>
      Future.error(Exception('network error'));

  @override
  Future<bool> addReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) =>
      Future.error(Exception('network error'));

  @override
  Future<bool> removeReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) =>
      Future.error(Exception('network error'));

  @override
  Future<ChannelStatsModel?> getChannelStats(String channelId) =>
      Future.error(Exception('network error'));

  @override
  Future<Map<String, dynamic>> getUnreadSummary() =>
      Future.error(Exception('network error'));

  @override
  Future<List<ChannelOrderModel>> getMyOrders() =>
      Future.error(Exception('network error'));

  @override
  Future<List<Map<String, dynamic>>> getMyInvitations() =>
      Future.error(Exception('network error'));

  @override
  Future<List<Map<String, dynamic>>> getSentInvitations() =>
      Future.error(Exception('network error'));

  @override
  Future<bool> acceptInvitation({required String invitationId}) =>
      Future.error(Exception('network error'));

  @override
  Future<bool> rejectInvitation({required String invitationId}) =>
      Future.error(Exception('network error'));

  @override
  Future<List<ChannelModel>> discoverChannels({
    String? category,
    int limit = 20,
  }) =>
      Future.error(Exception('network error'));
}

/// ChannelRepo stub：getAllSubscriptions 抛出异常，用于验证 cleanupOldData 异常降级
class _ThrowingChannelRepo extends ChannelRepo {
  @override
  Future<List<ChannelSubscriptionModel>> getAllSubscriptions() =>
      Future.error(Exception('db error'));

  @override
  Future<int> updateUnreadCount(String channelId, int count) =>
      Future.error(Exception('db write error'));
}

// ─────────────────────────────────────────────────────────────────────────────
// CH-13 测试组（位于 main() 外，被 main() 中的 group 引用）
// ─────────────────────────────────────────────────────────────────────────────
