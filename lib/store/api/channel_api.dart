import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class ChannelPageResult<T> {
  final List<T> list;
  final String? nextCursor;
  final bool hasMore;

  const ChannelPageResult({
    required this.list,
    required this.nextCursor,
    required this.hasMore,
  });
}

/// 频道 API 客户端
///
/// 负责与后端 API 通信，处理频道相关的网络请求
class ChannelApi extends HttpClient {
  // ==================== 频道 CRUD ====================

  /// 创建频道
  Future<ChannelModel?> createChannel({
    required String name,
    String? description,
    String? avatar,
    int type = 0,
    String? customId,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{'name': name, 'type': type};

    if (description != null) data['description'] = description;
    if (avatar != null) data['avatar'] = avatar;
    if (customId != null) data['custom_id'] = customId;
    if (tags != null) data['tags'] = tags;

    final resp = await post('/api/v1/channel/create', data: data);

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 获取频道信息
  Future<ChannelModel?> getChannel(String channelId) async {
    final resp = await get('/api/v1/channel/$channelId');

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 通过自定义 ID 获取频道
  Future<ChannelModel?> getChannelByCustomId(String customId) async {
    final resp = await get('/api/v1/channel/by_custom_id/$customId');

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 更新频道信息
  Future<ChannelModel?> updateChannel(
    String channelId, {
    String? name,
    String? description,
    String? avatar,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{};

    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (avatar != null) data['avatar'] = avatar;
    if (tags != null) data['tags'] = tags;

    final resp = await put('/api/v1/channel/$channelId/update', data: data);

    if (!resp.ok) {
      throw Exception(resp.msg);
    }

    if (resp.payload == null) {
      throw Exception(
        resp.msg.isEmpty ? 'update response payload is empty' : resp.msg,
      );
    }

    return ChannelModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 删除频道
  Future<bool> deleteChannel(String channelId) async {
    final resp = await post(
      '/api/v1/channel/$channelId/delete',
      data: <String, dynamic>{},
    );
    return resp.ok;
  }

  // ==================== 订阅管理 ====================

  /// 订阅频道
  Future<bool> subscribe(String channelId) async {
    final resp = await post(
      '/api/v1/channel/$channelId/subscribe',
      data: <String, dynamic>{},
    );
    return resp.ok;
  }

  /// 取消订阅
  Future<bool> unsubscribe(String channelId) async {
    final resp = await post(
      '/api/v1/channel/$channelId/unsubscribe',
      data: <String, dynamic>{},
    );
    return resp.ok;
  }

  /// 获取我订阅的频道列表
  Future<List<ChannelModel>> getSubscribedChannels({
    String? cursor,
    int limit = 50,
  }) async {
    final result = await getSubscribedChannelsPage(
      cursor: cursor,
      limit: limit,
    );
    return result.list;
  }

  /// 获取我订阅的频道列表（带分页信息）
  Future<ChannelPageResult<ChannelModel>> getSubscribedChannelsPage({
    String? cursor,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final resp = await get(
      '/api/v1/channels/subscribed',
      queryParameters: params,
    );

    if (!resp.ok || resp.payload == null) {
      return const ChannelPageResult(
        list: [],
        nextCursor: null,
        hasMore: false,
      );
    }

    final list = resp.payload['list'] as List?;
    if (list == null) {
      return const ChannelPageResult(
        list: [],
        nextCursor: null,
        hasMore: false,
      );
    }

    final channels = list
        .map((json) => ChannelModel.fromJson(json as Map<String, dynamic>))
        .toList();
    final dynamic next =
        resp.payload['next_cursor'] ??
        resp.payload['cursor'] ??
        resp.payload['next'] ??
        resp.payload['nextCursor'];
    final nextCursor = next?.toString();
    final hasMore = nextCursor != null && nextCursor.isNotEmpty;

    return ChannelPageResult(
      list: channels,
      nextCursor: hasMore ? nextCursor : null,
      hasMore: hasMore,
    );
  }

  /// 拉取频道未读汇总（服务端权威）
  ///
  /// 对应 `GET /api/v1/channels/unread/summary`。
  Future<Map<String, dynamic>> getUnreadSummary() async {
    final resp = await get('/api/v1/channels/unread/summary');

    if (!resp.ok ||
        resp.payload == null ||
        resp.payload is! Map<String, dynamic>) {
      return const {
        'total_unread': 0,
        'unread_channels': 0,
        'channels': <Map<String, dynamic>>[],
      };
    }

    final payload = Map<String, dynamic>.from(
      resp.payload as Map<dynamic, dynamic>,
    );
    final rawChannels = payload['channels'];
    final channels = rawChannels is List
        ? rawChannels
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => <String, dynamic>{
                  'channel_id': parseModelString(item['channel_id']),
                  'unread_count': parseModelInt(item['unread_count']),
                },
              )
              .where((item) => parseModelString(item['channel_id']).isNotEmpty)
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return <String, dynamic>{
      'total_unread': parseModelInt(payload['total_unread']),
      'unread_channels': parseModelInt(payload['unread_channels']),
      'channels': channels,
    };
  }

  /// 获取我管理的频道列表
  Future<List<ChannelModel>> getManagedChannels() async {
    final resp = await get('/api/v1/channels/managed');

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list
        .map((json) => ChannelModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 获取频道订阅者列表
  Future<List<Map<String, dynamic>>> getSubscribers({
    required String channelId,
    int? cursor,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final resp = await get(
      '/api/v1/channel/$channelId/subscribers',
      queryParameters: params,
    );

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return List<Map<String, dynamic>>.from(list);
  }

  // ==================== 消息操作 ====================

  /// 发布消息
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) async {
    final data = <String, dynamic>{'content': content, 'msg_type': msgType};

    if (payload != null) data['payload'] = payload;

    final resp = await post('/api/v1/channel/$channelId/message', data: data);

    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    if (resp.payload == null) {
      throw Exception('publish response payload is empty');
    }

    return ChannelMessageModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 获取频道消息列表
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final resp = await get(
      '/api/v1/channel/$channelId/messages',
      queryParameters: params,
    );

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list
        .map(
          (json) => ChannelMessageModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  /// 标记已读
  Future<bool> markAsRead(String channelId, String messageId) async {
    final resp = await post(
      '/api/v1/channel/$channelId/read',
      data: {'message_id': messageId},
    );
    return resp.ok;
  }

  // ==================== 搜索和发现 ====================

  /// 搜索频道
  Future<List<ChannelModel>> searchChannels(
    String keyword, {
    int limit = 20,
  }) async {
    final resp = await get(
      '/api/v1/channels/search',
      queryParameters: {'keyword': keyword, 'limit': limit},
    );

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list
        .map((json) => ChannelModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 发现频道（推荐）
  Future<List<ChannelModel>> discoverChannels({
    String? category,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (category != null) params['category'] = category;

    final resp = await get(
      '/api/v1/channels/discover',
      queryParameters: params,
    );

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list
        .map((json) => ChannelModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ==================== 管理员操作 ====================

  /// 添加管理员
  Future<bool> addAdmin(String channelId, String userId, int role) async {
    final resp = await post(
      '/api/v1/channel/$channelId/admin',
      data: {'user_id': userId, 'role': role},
    );
    return resp.ok;
  }

  /// 移除管理员
  Future<bool> removeAdmin(String channelId, String userId) async {
    final resp = await delete('/api/v1/channel/$channelId/admin/$userId');
    return resp.ok;
  }

  /// 获取管理员列表
  Future<List<Map<String, dynamic>>> getAdmins(String channelId) async {
    final resp = await get('/api/v1/channel/$channelId/admins');

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return List<Map<String, dynamic>>.from(list);
  }

  /// 更新管理员角色
  Future<bool> updateAdminRole(
    String channelId,
    String userId,
    int role,
  ) async {
    final resp = await put(
      '/api/v1/channel/$channelId/admin/$userId/role',
      data: {'role': role},
    );
    return resp.ok;
  }

  /// 移除订阅者
  Future<bool> removeSubscriber(String channelId, String userId) async {
    final resp = await delete('/api/v1/channel/$channelId/subscriber/$userId');
    return resp.ok;
  }

  /// 设置消息置顶
  Future<bool> setMessagePinned(
    String channelId,
    String messageId,
    bool pinned,
  ) async {
    final resp = await post(
      '/api/v1/channel/$channelId/message/$messageId/pin',
      data: {'pinned': pinned},
    );
    return resp.ok;
  }

  /// 删除消息
  Future<bool> deleteMessage(String channelId, String messageId) async {
    final resp = await post(
      '/api/v1/channel/$channelId/message/$messageId/delete',
      data: <String, dynamic>{},
    );
    return resp.ok;
  }

  // ==================== 同步操作 ====================

  /// 同步频道数据（增量同步）
  Future<Map<String, dynamic>?> sync({int? lastSyncTime}) async {
    final params = <String, dynamic>{};
    if (lastSyncTime != null) params['since'] = lastSyncTime;

    final resp = await get('/api/v1/channels/sync', queryParameters: params);

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload as Map<String, dynamic>?;
  }

  // ==================== 统计相关 API ====================

  /// 获取频道统计数据
  Future<ChannelStatsModel?> getChannelStats(String channelId) async {
    final resp = await get('/api/v1/channel/$channelId/stats');

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelStatsModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 获取频道每日统计数据
  Future<List<ChannelDailyStatsModel>> getDailyStats({
    required String channelId,
    int days = 7,
  }) async {
    final resp = await get(
      '/api/v1/channel/$channelId/stats/daily',
      queryParameters: {'days': days},
    );

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list
        .map(
          (json) =>
              ChannelDailyStatsModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  /// 记录消息阅读
  Future<bool> recordMessageView({
    required String channelId,
    required String messageId,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/message/$messageId/view',
      data: <String, dynamic>{},
    );
    return resp.ok;
  }

  /// 添加消息反应
  Future<bool> addReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/message/$messageId/reaction',
      data: {'reaction_type': reactionType},
    );
    return resp.ok;
  }

  /// 移除消息反应
  Future<bool> removeReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    final resp = await delete(
      '/api/v1/channel/$channelId/message/$messageId/reaction/$reactionType',
    );
    return resp.ok;
  }

  // ==================== 邀请相关（私有频道） ====================

  /// 创建频道邀请
  Future<Map<String, dynamic>?> createInvitation({
    required String channelId,
    required String inviteeUid,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/invitation',
      data: {'invitee_uid': inviteeUid},
    );
    if (!resp.ok || resp.payload == null) return null;
    return resp.payload as Map<String, dynamic>;
  }

  /// 接受频道邀请
  Future<bool> acceptInvitation({required String invitationId}) async {
    final resp = await post(
      '/api/v1/channel/invitation/accept',
      data: {'invitation_id': invitationId},
    );
    return resp.ok;
  }

  /// 拒绝频道邀请
  Future<bool> rejectInvitation({required String invitationId}) async {
    final resp = await post(
      '/api/v1/channel/invitation/reject',
      data: {'invitation_id': invitationId},
    );
    return resp.ok;
  }

  /// 获取我收到的邀请列表
  Future<List<Map<String, dynamic>>> getMyInvitations() async {
    final resp = await get('/api/v1/channel/invitations/my');
    if (!resp.ok || resp.payload == null) return [];
    final list = resp.payload['list'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 获取我发出的邀请列表
  Future<List<Map<String, dynamic>>> getSentInvitations() async {
    final resp = await get('/api/v1/channel/invitations/sent');
    if (!resp.ok || resp.payload == null) return [];
    final list = resp.payload['list'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  // ==================== 订单相关（付费频道） ====================

  /// 创建频道订单
  Future<ChannelOrderModel?> createOrder({required String channelId}) async {
    final resp = await post(
      '/api/v1/channel/$channelId/order',
      data: <String, dynamic>{},
    );

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelOrderModel.fromJson(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
    );
  }

  /// 支付订单（模拟支付）
  Future<bool> payOrder({required String orderNo}) async {
    final resp = await post(
      '/api/v1/channel/order/pay',
      data: {'order_no': orderNo},
    );
    return resp.ok;
  }

  /// 获取我的订单列表
  Future<List<ChannelOrderModel>> getMyOrders() async {
    final resp = await get('/api/v1/channel/orders/my');

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ChannelOrderModel.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }

  /// 获取订单详情
  Future<ChannelOrderModel?> getOrder({required String orderNo}) async {
    final resp = await get('/api/v1/channel/order/$orderNo');

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelOrderModel.fromJson(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
    );
  }
}
