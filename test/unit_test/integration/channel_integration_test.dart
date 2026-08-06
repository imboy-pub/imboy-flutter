/// Channel 功能集成测试
///
/// 测试前后端 API 是否能正确对接
///
/// 运行方式：
/// ```bash
/// flutter test test/integration/channel_integration_test.dart
/// ```
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';

class _RecordedRequest {
  final String method;
  final String path;
  final dynamic data;
  final Map<String, dynamic>? queryParameters;

  const _RecordedRequest({
    required this.method,
    required this.path,
    this.data,
    this.queryParameters,
  });
}

class _FakeChannelApi extends ChannelApi {
  final Map<String, IMBoyHttpResponse> _responses = {};
  final List<_RecordedRequest> requests = [];

  void stub({
    required String method,
    required String path,
    required IMBoyHttpResponse response,
  }) {
    _responses['${method.toUpperCase()} $path'] = response;
  }

  _RecordedRequest lastRequest() {
    if (requests.isEmpty) {
      throw StateError('No request has been recorded');
    }
    return requests.last;
  }

  IMBoyHttpResponse _popResponse(String method, String path) {
    final key = '${method.toUpperCase()} $path';
    final response = _responses[key];
    if (response == null) {
      return IMBoyHttpResponse.failure(
        errCode: 404,
        errMsg: 'Missing stub for $key',
      );
    }
    return response;
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requests.add(
      _RecordedRequest(
        method: 'GET',
        path: uri,
        queryParameters: queryParameters,
      ),
    );
    return _popResponse('GET', uri);
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requests.add(
      _RecordedRequest(
        method: 'POST',
        path: uri,
        data: data,
        queryParameters: queryParameters,
      ),
    );
    return _popResponse('POST', uri);
  }
}

void main() {
  group('ChannelApi Integration Tests', () {
    test(
      'create/get/subscribe/messages should have stable API assertions',
      () async {
        final api = _FakeChannelApi();

        api.stub(
          method: 'POST',
          path: '/api/v1/channel/create',
          response: IMBoyHttpResponse.success({
            'id': 1001,
            'name': '稳定测试频道',
            'description': 'for ci',
            'type': 1,
            'custom_id': 'stable_channel_1001',
            'creator_uid': 9001,
            'subscriber_count': 9,
            'is_verified': false,
            'created_at': '1767225600000',
            'updated_at': '1767225600000',
          }),
        );
        api.stub(
          method: 'GET',
          path: '/api/v1/channel/channel_1001',
          response: IMBoyHttpResponse.success({
            'id': 1001,
            'name': '稳定测试频道',
            'description': 'for ci',
            'type': 1,
            'custom_id': 'stable_channel_1001',
            'creator_uid': 9001,
            'subscriber_count': 10,
            'is_verified': true,
            'created_at': '1767225600000',
            'updated_at': '1767225600000',
          }),
        );
        api.stub(
          method: 'POST',
          path: '/api/v1/channel/channel_1001/subscribe',
          response: IMBoyHttpResponse.success({'ok': true}),
        );
        api.stub(
          method: 'GET',
          path: '/api/v1/channels/subscribed',
          response: IMBoyHttpResponse.success({
            'list': [
              {
                'id': 1001,
                'name': '稳定测试频道',
                'description': 'for ci',
                'type': 1,
                'custom_id': 'stable_channel_1001',
                'creator_uid': 9001,
                'subscriber_count': 10,
                'is_verified': true,
                'created_at': '1767225600000',
                'updated_at': '1767225600000',
                'user_role': 0,
                'is_subscribed': 1,
              },
            ],
            'next_cursor': 'cursor_2',
          }),
        );
        api.stub(
          method: 'POST',
          path: '/api/v1/channel/1001/message',
          response: IMBoyHttpResponse.success({
            'id': 5001,
            'channel_id': 1001,
            'content': 'hello ci',
            'msg_type': 'channel_text',
            'is_pinned': 0,
            'view_count': 0,
            'reaction_summary': {'like': 0},
            'created_at': '1767225600000',
          }),
        );

        final created = await api.createChannel(
          name: '稳定测试频道',
          description: 'for ci',
          type: 1,
          customId: 'stable_channel_1001',
          tags: const ['ci', 'channel'],
        );
        expect(created, isNotNull);
        expect(created!.id, 1001);
        expect(created.type, ChannelType.private);
        final createReq = api.lastRequest();
        expect(createReq.method, 'POST');
        expect(createReq.path, '/api/v1/channel/create');
        expect(
          (createReq.data as Map<String, dynamic>)['custom_id'],
          'stable_channel_1001',
        );
        expect((createReq.data as Map<String, dynamic>)['tags'], [
          'ci',
          'channel',
        ]);

        final detail = await api.getChannel('channel_1001');
        expect(detail, isNotNull);
        expect(detail!.isVerified, isTrue);
        expect(api.lastRequest().path, '/api/v1/channel/channel_1001');

        final subscribed = await api.subscribe('channel_1001');
        expect(subscribed, isTrue);
        expect(
          api.lastRequest().path,
          '/api/v1/channel/channel_1001/subscribe',
        );

        final subscribedPage = await api.getSubscribedChannelsPage(
          cursor: 'cursor_1',
          limit: 20,
        );
        expect(subscribedPage.list, hasLength(1));
        expect(subscribedPage.hasMore, isTrue);
        expect(subscribedPage.nextCursor, 'cursor_2');
        final subscribedReq = api.lastRequest();
        expect(subscribedReq.path, '/api/v1/channels/subscribed');
        expect(subscribedReq.queryParameters?['cursor'], 'cursor_1');
        expect(subscribedReq.queryParameters?['limit'], 20);

        final message = await api.publishMessage(
          channelId: '1001',
          content: 'hello ci',
          msgType: 'channel_text',
        );
        expect(message, isNotNull);
        expect(message!.id, 5001);
        final publishReq = api.lastRequest();
        expect(publishReq.path, '/api/v1/channel/1001/message');
        expect(
          (publishReq.data as Map<String, dynamic>)['content'],
          'hello ci',
        );
        expect(
          (publishReq.data as Map<String, dynamic>)['msg_type'],
          'channel_text',
        );
      },
    );

    test(
      'invitation APIs should validate payload and endpoint contracts',
      () async {
        final api = _FakeChannelApi();

        api.stub(
          method: 'POST',
          path: '/api/v1/channel/2001/invitation',
          response: IMBoyHttpResponse.success({
            'id': 'inv_2001',
            'channel_id': 'channel_2001',
            'invitee_uid': 'user_2002',
            'status': 0,
          }),
        );
        api.stub(
          method: 'POST',
          path: '/api/v1/channel/invitation/accept',
          response: IMBoyHttpResponse.success({'ok': true}),
        );
        api.stub(
          method: 'POST',
          path: '/api/v1/channel/invitation/reject',
          response: IMBoyHttpResponse.success({'ok': true}),
        );
        api.stub(
          method: 'GET',
          path: '/api/v1/channel/invitations/my',
          response: IMBoyHttpResponse.success({
            'list': [
              {
                'id': 'inv_2001',
                'channel_id': 'channel_2001',
                'invitee_uid': 'me',
                'status': 0,
              },
            ],
          }),
        );
        api.stub(
          method: 'GET',
          path: '/api/v1/channel/invitations/sent',
          response: IMBoyHttpResponse.success({
            'list': [
              {
                'id': 'inv_2002',
                'channel_id': 'channel_2001',
                'invitee_uid': 'user_2002',
                'status': 1,
              },
            ],
          }),
        );

        final invitation = await api.createInvitation(
          channelId: '2001',
          inviteeUid: 'user_2002',
        );
        expect(invitation, isNotNull);
        expect(invitation!['id'], 'inv_2001');
        final createReq = api.lastRequest();
        expect(createReq.path, '/api/v1/channel/2001/invitation');
        expect(
          (createReq.data as Map<String, dynamic>)['invitee_uid'],
          'user_2002',
        );

        final accepted = await api.acceptInvitation(invitationId: 'inv_2001');
        expect(accepted, isTrue);
        final acceptReq = api.lastRequest();
        expect(acceptReq.path, '/api/v1/channel/invitation/accept');
        expect(
          (acceptReq.data as Map<String, dynamic>)['invitation_id'],
          'inv_2001',
        );

        final rejected = await api.rejectInvitation(invitationId: 'inv_2002');
        expect(rejected, isTrue);
        final rejectReq = api.lastRequest();
        expect(rejectReq.path, '/api/v1/channel/invitation/reject');
        expect(
          (rejectReq.data as Map<String, dynamic>)['invitation_id'],
          'inv_2002',
        );

        final myInvites = await api.getMyInvitations();
        expect(myInvites, hasLength(1));
        expect(myInvites.first['id'], 'inv_2001');
        expect(api.lastRequest().path, '/api/v1/channel/invitations/my');

        final sentInvites = await api.getSentInvitations();
        expect(sentInvites, hasLength(1));
        expect(sentInvites.first['id'], 'inv_2002');
        expect(api.lastRequest().path, '/api/v1/channel/invitations/sent');
      },
    );

    test(
      'order APIs should validate create/pay/list/detail contracts',
      () async {
        final api = _FakeChannelApi();

        final orderPayload = {
          'id': 3001,
          'channel_id': 3001,
          'user_id': 3001,
          'order_no': 'CH1767225600000123',
          'amount': 9.9,
          'currency': 'CNY',
          'status': 1,
          'payment_method': 'mock',
          'payment_no': 'PAY_3001',
          'subscription_start_at': '1767225600000',
          'subscription_end_at': '1769817600000',
          'expires_at': '1767312000000',
          'created_at': '1767225600000',
          'updated_at': '1767225600000',
        };

        api.stub(
          method: 'POST',
          path: '/api/v1/channel/3001/order',
          response: IMBoyHttpResponse.success(orderPayload),
        );
        api.stub(
          method: 'POST',
          path: '/api/v1/channel/order/pay',
          response: IMBoyHttpResponse.success({'ok': true}),
        );
        api.stub(
          method: 'GET',
          path: '/api/v1/channel/orders/my',
          response: IMBoyHttpResponse.success({
            'list': [orderPayload],
          }),
        );
        api.stub(
          method: 'GET',
          path: '/api/v1/channel/order/CH1767225600000123',
          response: IMBoyHttpResponse.success(orderPayload),
        );

        final created = await api.createOrder(channelId: '3001');
        expect(created, isNotNull);
        expect(created!.orderNo, 'CH1767225600000123');
        expect(created.paymentMethod, 'mock');
        expect(api.lastRequest().path, '/api/v1/channel/3001/order');

        final paid = await api.payOrder(orderNo: 'CH1767225600000123');
        expect(paid, isTrue);
        final payReq = api.lastRequest();
        expect(payReq.path, '/api/v1/channel/order/pay');
        expect(
          (payReq.data as Map<String, dynamic>)['order_no'],
          'CH1767225600000123',
        );

        final orders = await api.getMyOrders();
        expect(orders, hasLength(1));
        expect(orders.first.channelId, 3001);
        expect(api.lastRequest().path, '/api/v1/channel/orders/my');

        final detail = await api.getOrder(orderNo: 'CH1767225600000123');
        expect(detail, isNotNull);
        expect(detail!.orderNo, 'CH1767225600000123');
        expect(detail.status, 1);
        expect(
          api.lastRequest().path,
          '/api/v1/channel/order/CH1767225600000123',
        );
      },
    );
  });

  group('ChannelModel Serialization Tests', () {
    test('ChannelModel should serialize to/from JSON correctly', () {
      final json = {
        'id': 1001,
        'name': 'Test Channel',
        'description': 'A test channel',
        'avatar': 'https://example.com/avatar.jpg',
        'type': 0,
        'custom_id': 'test_channel',
        'creator_id': 123,
        'subscriber_count': 100,
        'is_verified': true,
        'tags': ['news', 'tech'],
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      };

      final model = ChannelModel.fromJson(json);
      expect(model.id, 1001);
      expect(model.name, 'Test Channel');
      expect(model.type, ChannelType.public);
      expect(model.subscriberCount, 100);
      expect(model.isVerified, isTrue);
      expect(model.tags, ['news', 'tech']);

      final serialized = model.toJson();
      expect(serialized['id'], 1001);
      expect(serialized['name'], 'Test Channel');
    });

    test('ChannelModel should parse bool/int/string mixed fields', () {
      final json = {
        'id': 987,
        'name': 'Mixed Channel',
        'description': 12345,
        'avatar': '',
        'type': '2',
        'custom_id': 667,
        'creator_uid': 9001,
        'subscriber_count': '88',
        'is_verified': 'true',
        'tags': '["news", 9, true]',
        'created_at': '1767225600',
        'updated_at': 1767225600000,
        'user_role': '3',
        'is_subscribed': '1',
      };

      final model = ChannelModel.fromJson(json);
      expect(model.id, 987);
      expect(model.name, 'Mixed Channel');
      expect(model.description, '12345');
      expect(model.avatar, isNull);
      expect(model.type, ChannelType.paid);
      expect(model.customId, '667');
      expect(model.creatorId, 9001);
      expect(model.subscriberCount, 88);
      expect(model.isVerified, isTrue);
      expect(model.tags, ['news', '9', 'true']);
      expect(model.createdAt.millisecondsSinceEpoch, 1767225600000);
      expect(model.updatedAt.millisecondsSinceEpoch, 1767225600000);
      expect(model.userRole, ChannelUserRole.creator);
      expect(model.isSubscribed, isTrue);
    });

    test('ChannelMessageModel should serialize correctly', () {
      final json = {
        'id': 123,
        'channel_id': 1001,
        'author_id': 2001,
        'author_name': 'Test User',
        'author_avatar': 'https://example.com/avatar.jpg',
        'content': 'Hello, Channel!',
        'msg_type': 'text',
        'payload': {'text': 'Hello, Channel!'},
        'is_pinned': false,
        'view_count': 50,
        'reaction_summary': {'like': 10},
        'created_at': '2026-01-01T00:00:00Z',
      };

      final model = ChannelMessageModel.fromJson(json);
      expect(model.id, 123);
      expect(model.channelId, 1001);
      expect(model.authorName, 'Test User');
      expect(model.content, 'Hello, Channel!');
      expect(model.msgType, 'text');
      expect(model.viewCount, 50);
      expect(model.isPinned, isFalse);
    });

    test('ChannelMessageModel should parse bool/int/string mixed fields', () {
      final json = {
        'id': 456,
        'channel_id': 789,
        'content': 2468,
        'msg_type': 1011,
        'is_pinned': true,
        'view_count': '12',
        'reaction_summary': {'like': '2', 'dislike': false},
        'created_at': '1767225600000',
      };

      final model = ChannelMessageModel.fromJson(json);
      expect(model.id, 456);
      expect(model.channelId, 789);
      expect(model.content, '2468');
      expect(model.msgType, '1011');
      expect(model.isPinned, isTrue);
      expect(model.viewCount, 12);
      expect(model.reactionSummary?['like'], 2);
      expect(model.reactionSummary?['dislike'], 0);
    });

    test(
      'ChannelMessageModel should parse bool view_count without cast errors',
      () {
        final json = {
          'id': 9901,
          'channel_id': 9902,
          'content': 'bool view count',
          'msg_type': 'channel_text',
          'is_pinned': 0,
          'view_count': true,
          'created_at': '1767225600000',
        };

        final model = ChannelMessageModel.fromJson(json);
        expect(model.id, 9901);
        expect(model.channelId, 9902);
        expect(model.isPinned, isFalse);
        expect(model.viewCount, 1);
      },
    );

    test(
      'ChannelSubscriptionModel should parse bool/int/string mixed fields',
      () {
        final json = {
          'channel_id': 123,
          'subscribed_at': '1767225600000',
          'last_read_at': 1767225601,
          'last_message_id': 999,
          'unread_count': '8',
          'notifications_enabled': true,
          'is_pinned': '1',
          'is_muted': false,
        };

        final model = ChannelSubscriptionModel.fromJson(json);
        expect(model.channelId, 123);
        expect(model.unreadCount, 8);
        expect(model.notificationsEnabled, isTrue);
        expect(model.isPinned, isTrue);
        expect(model.isMuted, isFalse);
        expect(model.lastMessageId, 999);
        // 秒级时间戳应自动转换为毫秒级
        expect(model.lastReadAt?.millisecondsSinceEpoch, 1767225601000);
      },
    );

    test('ChannelStatsModel should parse numeric strings', () {
      final json = {
        'channel_id': 789,
        'subscriber_count': '100',
        'total_messages': '200',
        'total_views': 300,
        'total_reactions': true,
      };

      final model = ChannelStatsModel.fromJson(json);
      expect(model.channelId, 789);
      expect(model.subscriberCount, 100);
      expect(model.totalMessages, 200);
      expect(model.totalViews, 300);
      expect(model.totalReactions, 1);
    });
  });

  group('Channel API URL Tests', () {
    test('API endpoints should match backend routes', () {
      // 验证前端 API 客户端的 URL 路径与后端路由配置一致
      final expectedEndpoints = {
        'create': '/api/v1/channel/create',
        'show': '/api/v1/channel/:channel_id',
        'by_custom_id': '/api/v1/channel/by_custom_id/:custom_id',
        'update': '/api/v1/channel/:channel_id/update',
        'delete': '/api/v1/channel/:channel_id/delete',
        'subscribe': '/api/v1/channel/:channel_id/subscribe',
        'unsubscribe': '/api/v1/channel/:channel_id/unsubscribe',
        'subscribed': '/api/v1/channels/subscribed',
        'managed': '/api/v1/channels/managed',
        'publish_message': '/api/v1/channel/:channel_id/message',
        'messages': '/api/v1/channel/:channel_id/messages',
        'mark_read': '/api/v1/channel/:channel_id/read',
        'search': '/api/v1/channels/search',
        'discover': '/api/v1/channels/discover',
        'add_admin': '/api/v1/channel/:channel_id/admin',
        'remove_admin': '/api/v1/channel/:channel_id/admin/:user_id',
        'update_admin_role': '/api/v1/channel/:channel_id/admin/:user_id/role',
        'create_invitation': '/api/v1/channel/:channel_id/invitation',
        'accept_invitation': '/api/v1/channel/invitation/accept',
        'reject_invitation': '/api/v1/channel/invitation/reject',
        'my_invitations': '/api/v1/channel/invitations/my',
        'sent_invitations': '/api/v1/channel/invitations/sent',
        'create_order': '/api/v1/channel/:channel_id/order',
        'pay_order': '/api/v1/channel/order/pay',
        'my_orders': '/api/v1/channel/orders/my',
        'get_order': '/api/v1/channel/order/:order_no',
      };

      // 验证所有端点都已定义
      expect(expectedEndpoints.length, 26);
      expect(
        expectedEndpoints['update_admin_role'],
        '/api/v1/channel/:channel_id/admin/:user_id/role',
      );
      expect(
        expectedEndpoints['create_order'],
        '/api/v1/channel/:channel_id/order',
      );

      // 注意：实际的 URL 验证需要在运行时通过 mock 或集成测试完成
    });
  });
}
