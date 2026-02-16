import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';

/// Channel 服务
///
/// 负责协调 API 和本地存储，处理频道业务逻辑
/// 包括：数据同步、消息处理、订阅管理等
class ChannelService {
  static final ChannelService to = ChannelService._privateConstructor();
  ChannelService._privateConstructor();

  final ChannelApi _api = ChannelApi();
  final ChannelRepo _repo = ChannelRepo();
  final ChannelMessageRepo _messageRepo = ChannelMessageRepo();

  // ==================== 频道同步 ====================

  /// 同步订阅的频道列表
  ///
  /// 从服务器获取用户订阅的所有频道，并保存到本地
  Future<List<ChannelModel>> syncSubscribedChannels() async {
    try {
      final channels = await _api.getSubscribedChannels();

      // 保存到本地数据库
      for (final channel in channels) {
        await _repo.saveChannel(channel);

        // 创建订阅关系（如果不存在）
        final existing = await _repo.getSubscription(channel.id);
        if (existing == null) {
          await _repo.saveSubscription(
            ChannelSubscriptionModel(
              channelId: channel.id,
              subscribedAt: DateTime.now(),
            ),
          );
        }
      }

      iPrint('ChannelService: 同步了 ${channels.length} 个频道');
      return channels;
    } catch (e) {
      iPrint('ChannelService: 同步频道失败 - $e');
      return [];
    }
  }

  /// 同步频道消息
  ///
  /// [channelId] 频道 ID
  /// [cursor] 游标（上一页最后一条消息的时间戳）
  Future<List<ChannelMessageModel>> syncMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    try {
      final messages = await _api.getMessages(
        channelId: channelId,
        cursor: cursor,
        limit: limit,
      );

      // 保存到本地数据库
      for (final message in messages) {
        await _messageRepo.saveMessage(message);
      }

      iPrint('ChannelService: 同步了 ${messages.length} 条频道消息');
      return messages;
    } catch (e) {
      iPrint('ChannelService: 同步消息失败 - $e');
      return [];
    }
  }

  // ==================== 订阅管理 ====================

  /// 订阅频道
  ///
  /// 同时更新服务器和本地数据
  Future<bool> subscribeChannel(String channelId) async {
    try {
      final success = await _api.subscribe(channelId);
      if (!success) return false;

      // 获取频道信息
      final channel = await _api.getChannel(channelId);
      if (channel == null) return false;

      // 保存频道和订阅关系
      await _repo.saveChannel(channel);
      await _repo.saveSubscription(
        ChannelSubscriptionModel(
          channelId: channelId,
          subscribedAt: DateTime.now(),
        ),
      );

      iPrint('ChannelService: 订阅频道成功 - $channelId');
      return true;
    } catch (e) {
      iPrint('ChannelService: 订阅频道失败 - $e');
      return false;
    }
  }

  /// 取消订阅频道
  ///
  /// 同时更新服务器和本地数据
  Future<bool> unsubscribeChannel(String channelId) async {
    try {
      final success = await _api.unsubscribe(channelId);
      if (!success) return false;

      // 删除本地订阅关系（保留频道信息和消息）
      await _repo.deleteSubscription(channelId);

      iPrint('ChannelService: 取消订阅成功 - $channelId');
      return true;
    } catch (e) {
      iPrint('ChannelService: 取消订阅失败 - $e');
      return false;
    }
  }

  // ==================== 消息操作 ====================

  /// 发布频道消息
  ///
  /// [channelId] 频道 ID
  /// [content] 消息内容
  /// [msgType] 消息类型
  Future<ChannelMessageModel?> publishMessage({
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final message = await _api.publishMessage(
        channelId: channelId,
        content: content,
        msgType: msgType,
        payload: payload,
      );

      if (message == null) return null;

      // 保存到本地
      await _messageRepo.saveMessage(message);

      iPrint('ChannelService: 发布消息成功 - ${message.id}');
      return message;
    } catch (e) {
      iPrint('ChannelService: 发布消息失败 - $e');
      return null;
    }
  }

  /// 获取频道消息列表（优先本地，失败则从服务器获取）
  Future<List<ChannelMessageModel>> getMessages({
    required String channelId,
    int? cursor,
    int limit = 20,
  }) async {
    // 先从本地获取
    final localMessages = await _messageRepo.getMessages(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );

    // 如果本地有数据，直接返回
    if (localMessages.isNotEmpty) {
      return localMessages;
    }

    // 本地无数据，从服务器同步
    return await syncMessages(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
  }

  // ==================== 未读计数 ====================

  /// 获取频道未读总数
  Future<int> getTotalUnreadCount() async {
    return await _repo.getTotalUnreadCount();
  }

  /// 获取指定频道的未读数
  Future<int> getUnreadCount(String channelId) async {
    final subscription = await _repo.getSubscription(channelId);
    return subscription?.unreadCount ?? 0;
  }

  /// 更新频道未读计数
  ///
  /// 由 S2C 消息处理器调用，更新本地未读计数
  Future<void> updateUnreadCount(String channelId, int count) async {
    try {
      await _repo.updateUnreadCount(channelId, count);
      iPrint('ChannelService: 更新未读计数 - $channelId: $count');
    } catch (e) {
      iPrint('ChannelService: 更新未读计数失败 - $e');
    }
  }

  /// 标记频道消息已读
  Future<bool> markAsRead(String channelId, String messageId) async {
    try {
      // 更新服务器
      await _api.markAsRead(channelId, messageId);

      // 更新本地
      await _repo.markAsRead(channelId, messageId);

      iPrint('ChannelService: 标记已读 - $channelId/$messageId');
      return true;
    } catch (e) {
      iPrint('ChannelService: 标记已读失败 - $e');
      return false;
    }
  }

  // ==================== WebSocket 消息处理 ====================

  /// 处理 WebSocket 推送的频道消息
  ///
  /// 由消息服务调用，处理实时推送的频道消息
  Future<void> handleChannelMessage(Map<String, dynamic> data) async {
    try {
      final message = ChannelMessageModel.fromJson(data);

      // 保存消息
      await _messageRepo.saveMessage(message);

      // 更新未读计数
      await _repo.incrementUnreadCount(message.channelId);

      iPrint('ChannelService: 收到频道消息 - ${message.id}');

      // TODO: 发送事件通知 UI 刷新
      // EventBus.instance.emit(ChannelEvents.newMessage, message);
    } catch (e) {
      iPrint('ChannelService: 处理频道消息失败 - $e');
    }
  }

  /// 处理频道订阅通知
  Future<void> handleChannelSubscribed(Map<String, dynamic> data) async {
    try {
      final channelId = data['channel_id'] as String;

      // 检查本地是否已有订阅
      final existing = await _repo.getSubscription(channelId);
      if (existing != null) return;

      // 获取并保存频道信息
      final channel = await _api.getChannel(channelId);
      if (channel == null) return;

      await _repo.saveChannel(channel);
      await _repo.saveSubscription(
        ChannelSubscriptionModel(
          channelId: channelId,
          subscribedAt: DateTime.now(),
        ),
      );

      iPrint('ChannelService: 收到订阅通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理订阅通知失败 - $e');
    }
  }

  /// 处理频道取消订阅通知
  Future<void> handleChannelUnsubscribed(Map<String, dynamic> data) async {
    try {
      final channelId = data['channel_id'] as String;
      await _repo.deleteSubscription(channelId);

      iPrint('ChannelService: 收到取消订阅通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理取消订阅通知失败 - $e');
    }
  }

  /// 处理频道更新通知
  Future<void> handleChannelUpdated(Map<String, dynamic> data) async {
    try {
      final channel = ChannelModel.fromJson(data);
      await _repo.saveChannel(channel);

      iPrint('ChannelService: 收到频道更新通知 - ${channel.id}');
    } catch (e) {
      iPrint('ChannelService: 处理频道更新通知失败 - $e');
    }
  }

  /// 处理频道删除通知
  Future<void> handleChannelDeleted(Map<String, dynamic> data) async {
    try {
      final channelId = data['channel_id'] as String;
      await _repo.deleteChannel(channelId);

      iPrint('ChannelService: 收到频道删除通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理频道删除通知失败 - $e');
    }
  }

  // ==================== 搜索和发现 ====================

  /// 搜索频道
  Future<List<ChannelModel>> searchChannels(String keyword) async {
    // 先搜索本地
    final localResults = await _repo.searchChannels(keyword);
    if (localResults.isNotEmpty) {
      return localResults;
    }

    // 本地无结果，从服务器搜索
    return await _api.searchChannels(keyword);
  }

  /// 发现频道（推荐）
  Future<List<ChannelModel>> discoverChannels({String? category}) async {
    return await _api.discoverChannels(category: category);
  }

  // ==================== 辅助方法 ====================

  /// 获取频道信息（优先本地）
  Future<ChannelModel?> getChannel(String channelId) async {
    // 先从本地获取
    final local = await _repo.getChannel(channelId);
    if (local != null) return local;

    // 本地无数据，从服务器获取
    final remote = await _api.getChannel(channelId);
    if (remote != null) {
      await _repo.saveChannel(remote);
    }
    return remote;
  }

  /// 检查是否已订阅
  Future<bool> isSubscribed(String channelId) async {
    return await _repo.isSubscribed(channelId);
  }

  /// 获取订阅的频道列表（含订阅信息）
  Future<List<Map<String, dynamic>>> getSubscribedChannelsWithInfo() async {
    return await _repo.getSubscribedChannelsWithSubscription();
  }

  /// 清理过期数据
  ///
  /// [keepCount] 每个频道保留的消息数量
  Future<void> cleanupOldData({int keepCount = 1000}) async {
    try {
      final subscriptions = await _repo.getAllSubscriptions();
      for (final sub in subscriptions) {
        await _messageRepo.deleteOldMessages(sub.channelId, keepCount);
      }
      iPrint('ChannelService: 清理过期数据完成');
    } catch (e) {
      iPrint('ChannelService: 清理过期数据失败 - $e');
    }
  }
}

/// 频道事件常量
///
/// 用于 EventBus 事件通知
abstract class ChannelEvents {
  /// 新消息事件
  static const String newMessage = 'channel_new_message';

  /// 订阅状态变更事件
  static const String subscriptionChanged = 'channel_subscription_changed';

  /// 未读计数变更事件
  static const String unreadCountChanged = 'channel_unread_count_changed';

  /// 频道信息更新事件
  static const String channelUpdated = 'channel_info_updated';
}
