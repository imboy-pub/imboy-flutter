import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';

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
    final data = <String, dynamic>{
      'name': name,
      'type': type,
    };

    if (description != null) data['description'] = description;
    if (avatar != null) data['avatar'] = avatar;
    if (customId != null) data['custom_id'] = customId;
    if (tags != null) data['tags'] = tags;

    final resp = await post('/v1/channel/create', data: data);
    debugPrint("ChannelApi_createChannel resp: ok=${resp.ok}, code=${resp.code}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload);
  }

  /// 获取频道信息
  Future<ChannelModel?> getChannel(String channelId) async {
    final resp = await get('/v1/channel/$channelId');
    debugPrint("ChannelApi_getChannel resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload);
  }

  /// 通过自定义 ID 获取频道
  Future<ChannelModel?> getChannelByCustomId(String customId) async {
    final resp = await get('/v1/channel/by_custom_id/$customId');
    debugPrint("ChannelApi_getChannelByCustomId resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload);
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
    data['channel_id'] = channelId;

    final resp = await put('/v1/channel/$channelId/update', data: data);
    debugPrint("ChannelApi_updateChannel resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelModel.fromJson(resp.payload);
  }

  /// 删除频道
  Future<bool> deleteChannel(String channelId) async {
    final resp = await post('/v1/channel/$channelId/delete', data: {'channel_id': channelId});
    debugPrint("ChannelApi_deleteChannel resp: ok=${resp.ok}");
    return resp.ok;
  }

  // ==================== 订阅管理 ====================

  /// 订阅频道
  Future<bool> subscribe(String channelId) async {
    final resp = await post('/v1/channel/$channelId/subscribe', data: {'channel_id': channelId});
    debugPrint("ChannelApi_subscribe resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 取消订阅
  Future<bool> unsubscribe(String channelId) async {
    final resp = await post('/v1/channel/$channelId/unsubscribe', data: {'channel_id': channelId});
    debugPrint("ChannelApi_unsubscribe resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 获取我订阅的频道列表
  Future<List<ChannelModel>> getSubscribedChannels({
    String? cursor,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final resp = await get('/v1/channels/subscribed', queryParameters: params);
    debugPrint("ChannelApi_getSubscribedChannels resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list.map((json) => ChannelModel.fromJson(json)).toList();
  }

  /// 获取我管理的频道列表
  Future<List<ChannelModel>> getManagedChannels() async {
    final resp = await get('/v1/channels/managed');
    debugPrint("ChannelApi_getManagedChannels resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list.map((json) => ChannelModel.fromJson(json)).toList();
  }

  /// 获取频道订阅者列表
  Future<List<Map<String, dynamic>>> getSubscribers({
    required String channelId,
    int? cursor,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final resp = await get('/v1/channel/$channelId/subscribers', queryParameters: params);
    debugPrint("ChannelApi_getSubscribers resp: ok=${resp.ok}");

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
    final data = <String, dynamic>{
      'channel_id': channelId,
      'content': content,
      'msg_type': msgType,
    };

    if (payload != null) data['payload'] = payload;

    final resp = await post('/v1/channel/$channelId/message', data: data);
    debugPrint("ChannelApi_publishMessage resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelMessageModel.fromJson(resp.payload);
  }

  /// 获取频道消息列表
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final resp = await get('/v1/channel/$channelId/messages', queryParameters: params);
    debugPrint("ChannelApi_getMessages resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list.map((json) => ChannelMessageModel.fromJson(json)).toList();
  }

  /// 标记已读
  Future<bool> markAsRead(String channelId, String messageId) async {
    final resp = await post('/v1/channel/$channelId/read', data: {
      'message_id': messageId,
    });
    debugPrint("ChannelApi_markAsRead resp: ok=${resp.ok}");
    return resp.ok;
  }

  // ==================== 搜索和发现 ====================

  /// 搜索频道
  Future<List<ChannelModel>> searchChannels(
    String keyword, {
    int limit = 20,
  }) async {
    final resp = await get('/v1/channels/search', queryParameters: {
      'keyword': keyword,
      'limit': limit,
    });
    debugPrint("ChannelApi_searchChannels resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list.map((json) => ChannelModel.fromJson(json)).toList();
  }

  /// 发现频道（推荐）
  Future<List<ChannelModel>> discoverChannels({
    String? category,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (category != null) params['category'] = category;

    final resp = await get('/v1/channels/discover', queryParameters: params);
    debugPrint("ChannelApi_discoverChannels resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list.map((json) => ChannelModel.fromJson(json)).toList();
  }

  // ==================== 管理员操作 ====================

  /// 添加管理员
  Future<bool> addAdmin(String channelId, String userId, int role) async {
    final resp = await post('/v1/channel/$channelId/admin', data: {
      'user_id': userId,
      'role': role,
    });
    debugPrint("ChannelApi_addAdmin resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 移除管理员
  Future<bool> removeAdmin(String channelId, String userId) async {
    final resp = await delete('/v1/channel/$channelId/admin/$userId');
    debugPrint("ChannelApi_removeAdmin resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 获取管理员列表
  Future<List<Map<String, dynamic>>> getAdmins(String channelId) async {
    final resp = await get('/v1/channel/$channelId/admins');
    debugPrint("ChannelApi_getAdmins resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return List<Map<String, dynamic>>.from(list);
  }

  /// 更新管理员角色
  Future<bool> updateAdminRole(String channelId, String userId, int role) async {
    final resp = await put('/v1/channel/$channelId/admin/$userId', data: {
      'role': role,
    });
    debugPrint("ChannelApi_updateAdminRole resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 移除订阅者
  Future<bool> removeSubscriber(String channelId, String userId) async {
    final resp = await delete('/v1/channel/$channelId/subscriber/$userId');
    debugPrint("ChannelApi_removeSubscriber resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 设置消息置顶
  Future<bool> setMessagePinned(String channelId, String messageId, bool pinned) async {
    final resp = await post('/v1/channel/$channelId/message/$messageId/pin', data: {
      'pinned': pinned,
    });
    debugPrint("ChannelApi_setMessagePinned resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 删除消息
  Future<bool> deleteMessage(String channelId, String messageId) async {
    final resp = await post('/v1/channel/$channelId/message/$messageId/delete', data: {});
    debugPrint("ChannelApi_deleteMessage resp: ok=${resp.ok}");
    return resp.ok;
  }

  // ==================== 同步操作 ====================

  /// 同步频道数据（增量同步）
  Future<Map<String, dynamic>?> sync({int? lastSyncTime}) async {
    final params = <String, dynamic>{};
    if (lastSyncTime != null) params['since'] = lastSyncTime;

    final resp = await get('/v1/channels/sync', queryParameters: params);
    debugPrint("ChannelApi_sync resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload;
  }

  // ==================== 统计相关 API ====================

  /// 获取频道统计数据
  Future<ChannelStatsModel?> getChannelStats(String channelId) async {
    final resp = await get('/v1/channel/$channelId/stats');
    debugPrint("ChannelApi_getChannelStats resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return ChannelStatsModel.fromJson(resp.payload);
  }

  /// 获取频道每日统计数据
  Future<List<ChannelDailyStatsModel>> getDailyStats({
    required String channelId,
    int days = 7,
  }) async {
    final resp = await get('/v1/channel/$channelId/stats/daily', queryParameters: {
      'channel_id': channelId,
      'days': days,
    });
    debugPrint("ChannelApi_getDailyStats resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final list = resp.payload['list'] as List?;
    if (list == null) return [];

    return list.map((json) => ChannelDailyStatsModel.fromJson(json)).toList();
  }

  /// 记录消息阅读
  Future<bool> recordMessageView({
    required String channelId,
    required String messageId,
  }) async {
    final resp = await post('/v1/channel/$channelId/message/$messageId/view', data: {
      'channel_id': channelId,
      'message_id': messageId,
    });
    debugPrint("ChannelApi_recordMessageView resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 添加消息反应
  Future<bool> addReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    final resp = await post('/v1/channel/$channelId/message/$messageId/reaction', data: {
      'channel_id': channelId,
      'message_id': messageId,
      'reaction_type': reactionType,
    });
    debugPrint("ChannelApi_addReaction resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 移除消息反应
  Future<bool> removeReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    final resp = await delete('/v1/channel/$channelId/message/$messageId/reaction/$reactionType');
    debugPrint("ChannelApi_removeReaction resp: ok=${resp.ok}");
    return resp.ok;
  }
}
