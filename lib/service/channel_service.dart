import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/common_events.dart'
    show
        ChannelMessageDeletedEvent,
        ChannelNewMessageEvent,
        ChannelStateChangedEvent,
        ChannelUnreadCountUpdatedEvent,
        ChannelUnreadSummarySyncEvent;
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';

/// Channel 服务
///
/// 负责协调 API 和本地存储，处理频道业务逻辑。
/// 这是 channel_content 在 Flutter 侧的稳定模块边界，页面层应优先依赖这里。
/// 包括：数据同步、消息处理、订阅管理等
class ChannelService {
  static final ChannelService to = ChannelService._privateConstructor();

  final ChannelApi _api;
  final ChannelRepo _repo;
  final ChannelMessageRepo _messageRepo;

  ChannelService._privateConstructor()
    : _api = ChannelApi(),
      _repo = ChannelRepo(),
      _messageRepo = ChannelMessageRepo();

  @visibleForTesting
  ChannelService.forTest({
    required ChannelApi api,
    required ChannelRepo repo,
    ChannelMessageRepo? messageRepo,
  }) : _api = api,
       _repo = repo,
       _messageRepo = messageRepo ?? ChannelMessageRepo();

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
        final existing = await _repo.getSubscription(channel.id.toString());
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

  /// 获取订阅频道列表（服务端权威）。
  Future<List<ChannelModel>> getSubscribedChannels({int limit = 50}) async {
    try {
      return await _api.getSubscribedChannels(limit: limit);
    } catch (e) {
      iPrint('ChannelService: 获取订阅频道失败 - $e');
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
          channelId: parseModelInt(channelId),
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

  /// 删除频道。
  Future<bool> deleteChannel(String channelId) async {
    try {
      final success = await _api.deleteChannel(channelId);
      if (!success) return false;
      await _repo.deleteChannel(channelId);
      iPrint('ChannelService: 删除频道成功 - $channelId');
      return true;
    } catch (e) {
      iPrint('ChannelService: 删除频道失败 - $e');
      return false;
    }
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

  /// 拉取服务端未读汇总并对账到本地订阅表
  ///
  /// 用于冷启动或页面刷新时的权威修正，避免仅依赖推送增量。
  Future<Map<String, dynamic>> syncUnreadSummary({
    String trigger = 'manual',
  }) async {
    const source = 'server_unread_summary_pull';
    int changed = 0;
    int totalUnread = 0;
    try {
      final summary = await _api.getUnreadSummary();
      final rawChannels = summary['channels'];

      // 载荷守卫：必须显式为 List（含空 List），才可视为「权威未读集合」。
      // - `channels` 缺失或为 null/非 List 表示上游异常或版本错配：
      //   不得用空白权威集清零本地未读；仅上报 success=false 供观测。
      // - `channels: []` 是合法的权威空集，表示无未读，允许清零。
      if (rawChannels is! List) {
        iPrint(
          'ChannelService: 未读汇总载荷异常 - '
          'channels 字段缺失或类型错误 (type=${rawChannels.runtimeType})',
        );
        AppEventBus.fireTracked(
          ChannelUnreadSummarySyncEvent(
            trigger: trigger,
            source: source,
            totalUnread: totalUnread,
            changedSubscriptions: changed,
            success: false,
          ),
        );
        return const {};
      }

      final authoritativeByChannel = <String, int>{};
      for (final item in rawChannels.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final channelId = parseModelString(row['channel_id']);
        if (channelId.isEmpty) continue;
        authoritativeByChannel[channelId] = parseModelInt(
          row['unread_count'],
        );
      }

      final subscriptions = await _repo.getAllSubscriptions();
      for (final sub in subscriptions) {
        final nextUnread = authoritativeByChannel[sub.channelId.toString()] ?? 0;
        if (sub.unreadCount == nextUnread) continue;
        await _repo.updateUnreadCount(sub.channelId.toString(), nextUnread);
        changed++;
        AppEventBus.fire(
          ChannelUnreadCountUpdatedEvent(
            channelId: sub.channelId.toString(),
            unreadCount: nextUnread,
          ),
        );
      }

      totalUnread = parseModelInt(summary['total_unread']);
      AppEventBus.fire(
        ChannelUnreadCountUpdatedEvent(
          channelId: 'unread_summary',
          unreadCount: totalUnread,
        ),
      );
      AppEventBus.fireTracked(
        ChannelUnreadSummarySyncEvent(
          trigger: trigger,
          source: source,
          totalUnread: totalUnread,
          changedSubscriptions: changed,
          success: true,
        ),
      );

      iPrint('ChannelService: 未读汇总同步完成 - changed=$changed, total=$totalUnread');
      return summary;
    } catch (e) {
      iPrint('ChannelService: 同步未读汇总失败 - $e');
      AppEventBus.fireTracked(
        ChannelUnreadSummarySyncEvent(
          trigger: trigger,
          source: source,
          totalUnread: totalUnread,
          changedSubscriptions: changed,
          success: false,
        ),
      );
      return const {};
    }
  }

  /// 标记频道消息已读
  ///
  /// 三步同步：API 通知服务端 → 本地 DB 清零 → 广播
  /// [ChannelUnreadCountUpdatedEvent]，驱动 UI 徽标与总未读缓存刷新。
  /// 缺任一步都会导致服务端/本地/UI 状态不一致。
  Future<bool> markAsRead(String channelId, String messageId) async {
    try {
      // 更新服务器
      await _api.markAsRead(channelId, messageId);

      // 更新本地
      await _repo.markAsRead(channelId, messageId);

      // 广播 0 未读，驱动 UI 徽标与 _ChannelUnreadCountCache 刷新。
      AppEventBus.fire(
        ChannelUnreadCountUpdatedEvent(
          channelId: channelId,
          unreadCount: 0,
        ),
      );

      iPrint('ChannelService: 标记已读 - $channelId/$messageId');
      return true;
    } catch (e) {
      iPrint('ChannelService: 标记已读失败 - $e');
      return false;
    }
  }

  /// 设置消息置顶状态。
  Future<bool> setMessagePinned(
    String channelId,
    String messageId,
    bool pinned,
  ) async {
    try {
      final success = await _api.setMessagePinned(channelId, messageId, pinned);
      if (success) {
        await _messageRepo.setMessagePinned(messageId, pinned);
      }
      iPrint(
        'ChannelService: 设置消息置顶${success ? "成功" : "失败"} - '
        '$channelId/$messageId/$pinned',
      );
      return success;
    } catch (e) {
      iPrint('ChannelService: 设置消息置顶失败 - $e');
      return false;
    }
  }

  /// 删除频道消息。
  Future<bool> deleteMessage(String channelId, String messageId) async {
    try {
      final success = await _api.deleteMessage(channelId, messageId);
      if (success) {
        await _messageRepo.deleteMessage(messageId);
        AppEventBus.fire(
          ChannelMessageDeletedEvent(
            channelId: channelId,
            messageId: messageId,
            reason: 'deleted',
          ),
        );
      }
      iPrint(
        'ChannelService: 删除频道消息${success ? "成功" : "失败"} - '
        '$channelId/$messageId',
      );
      return success;
    } catch (e) {
      iPrint('ChannelService: 删除频道消息失败 - $e');
      return false;
    }
  }

  // ==================== 订单相关（付费频道） ====================

  /// 创建订单
  Future<ChannelOrderModel?> createOrder(String channelId) async {
    try {
      final order = await _api.createOrder(channelId: channelId);
      if (order == null) return null;
      iPrint('ChannelService: 创建订单成功 - ${order.orderNo}');
      return order;
    } catch (e) {
      iPrint('ChannelService: 创建订单失败 - $e');
      return null;
    }
  }

  /// 支付订单
  Future<bool> payOrder(String orderNo) async {
    try {
      final success = await _api.payOrder(orderNo: orderNo);
      iPrint('ChannelService: 支付订单${success ? "成功" : "失败"} - $orderNo');
      return success;
    } catch (e) {
      iPrint('ChannelService: 支付订单失败 - $e');
      return false;
    }
  }

  /// 创建并支付订单（最小闭环）
  Future<ChannelOrderModel?> createAndPayOrder(String channelId) async {
    final order = await createOrder(channelId);
    if (order == null) return null;

    final paid = await payOrder(order.orderNo);
    if (!paid) return null;

    return await getOrder(order.orderNo);
  }

  /// 获取我的订单列表
  Future<List<ChannelOrderModel>> getMyOrders() async {
    try {
      return await _api.getMyOrders();
    } catch (e) {
      iPrint('ChannelService: 获取我的订单失败 - $e');
      return [];
    }
  }

  /// 获取订单详情
  Future<ChannelOrderModel?> getOrder(String orderNo) async {
    try {
      return await _api.getOrder(orderNo: orderNo);
    } catch (e) {
      iPrint('ChannelService: 获取订单详情失败 - $e');
      return null;
    }
  }

  // ==================== 邀请相关（私有频道） ====================

  /// 获取我收到的邀请
  Future<List<Map<String, dynamic>>> getMyInvitations() async {
    try {
      return await _api.getMyInvitations();
    } catch (e) {
      iPrint('ChannelService: 获取我的邀请失败 - $e');
      return [];
    }
  }

  /// 获取我发出的邀请
  Future<List<Map<String, dynamic>>> getSentInvitations() async {
    try {
      return await _api.getSentInvitations();
    } catch (e) {
      iPrint('ChannelService: 获取已发邀请失败 - $e');
      return [];
    }
  }

  /// 接受邀请
  Future<bool> acceptInvitation(String invitationId) async {
    try {
      final success = await _api.acceptInvitation(invitationId: invitationId);
      iPrint('ChannelService: 接受邀请${success ? "成功" : "失败"} - $invitationId');
      return success;
    } catch (e) {
      iPrint('ChannelService: 接受邀请失败 - $e');
      return false;
    }
  }

  /// 拒绝邀请
  Future<bool> rejectInvitation(String invitationId) async {
    try {
      final success = await _api.rejectInvitation(invitationId: invitationId);
      iPrint('ChannelService: 拒绝邀请${success ? "成功" : "失败"} - $invitationId');
      return success;
    } catch (e) {
      iPrint('ChannelService: 拒绝邀请失败 - $e');
      return false;
    }
  }

  // ==================== 统计和互动 ====================

  /// 获取频道统计。
  Future<ChannelStatsModel?> getChannelStats(String channelId) async {
    try {
      return await _api.getChannelStats(channelId);
    } catch (e) {
      iPrint('ChannelService: 获取频道统计失败 - $e');
      return null;
    }
  }

  /// 添加消息反应。
  Future<bool> addReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    try {
      final success = await _api.addReaction(
        channelId: channelId,
        messageId: messageId,
        reactionType: reactionType,
      );
      iPrint('ChannelService: 添加消息反应${success ? "成功" : "失败"} - $messageId');
      return success;
    } catch (e) {
      iPrint('ChannelService: 添加消息反应失败 - $e');
      return false;
    }
  }

  /// 移除消息反应。
  Future<bool> removeReaction({
    required String channelId,
    required String messageId,
    required String reactionType,
  }) async {
    try {
      final success = await _api.removeReaction(
        channelId: channelId,
        messageId: messageId,
        reactionType: reactionType,
      );
      iPrint('ChannelService: 移除消息反应${success ? "成功" : "失败"} - $messageId');
      return success;
    } catch (e) {
      iPrint('ChannelService: 移除消息反应失败 - $e');
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
      if (message.channelId == 0 || message.id == 0) {
        iPrint(
          'ChannelService: 忽略无效频道消息 - '
          'channelId=${message.channelId}, messageId=${message.id}',
        );
        return;
      }

      // 保存消息
      await _messageRepo.saveMessage(message);

      // 更新未读计数
      await _repo.incrementUnreadCount(message.channelId.toString());

      iPrint('ChannelService: 收到频道消息 - ${message.id}');

      // 发送事件通知 UI 刷新
      AppEventBus.fire(
        ChannelNewMessageEvent(
          channelId: message.channelId.toString(),
          message: message.toMap(),
        ),
      );
    } catch (e) {
      iPrint('ChannelService: 处理频道消息失败 - $e');
    }
  }

  /// 处理频道订阅通知
  ///
  /// 多端同步：用户在设备 A 订阅后，设备 B 通过 S2C 收到此通知，
  /// 需写本地 + 广播 [ChannelStateChangedEvent]，让订阅列表等 UI
  /// 立即刷新；否则本端频道列表停留旧快照。
  Future<void> handleChannelSubscribed(Map<String, dynamic> data) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      if (channelId.isEmpty) return;

      // 检查本地是否已有订阅；幂等：重复 S2C 不触发二次事件。
      final existing = await _repo.getSubscription(channelId);
      if (existing != null) return;

      // 获取并保存频道信息
      final channel = await _api.getChannel(channelId);
      if (channel == null) return;

      await _repo.saveChannel(channel);
      await _repo.saveSubscription(
        ChannelSubscriptionModel(
          channelId: parseModelInt(channelId),
          subscribedAt: DateTime.now(),
        ),
      );

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channelId,
          action: 'channel_subscribed',
          payload: data,
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
      final channelId = parseModelString(data['channel_id']);
      if (channelId.isEmpty) return;
      await _repo.deleteSubscription(channelId);
      // 级联清理本地消息：取消订阅后该频道不再可访问，保留消息仅徒增占用。
      await _messageRepo.deleteMessagesByChannel(channelId);

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channelId,
          action: 'channel_unsubscribed',
          payload: data,
        ),
      );

      iPrint('ChannelService: 收到取消订阅通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理取消订阅通知失败 - $e');
    }
  }

  /// 处理频道更新通知
  Future<void> handleChannelUpdated(Map<String, dynamic> data) async {
    try {
      final channelData = parseModelJsonMap(data['channel']);
      if (channelData == null || channelData.isEmpty) {
        iPrint('ChannelService: 忽略缺少 channel 的更新通知');
        return;
      }
      final channel = ChannelModel.fromJson(channelData);
      if (channel.id == 0) {
        iPrint('ChannelService: 忽略缺少 channel.id 的更新通知');
        return;
      }
      await _repo.saveChannel(channel);
      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channel.id.toString(),
          action: 'channel_updated',
          payload: data,
        ),
      );

      iPrint('ChannelService: 收到频道更新通知 - ${channel.id}');
    } catch (e) {
      iPrint('ChannelService: 处理频道更新通知失败 - $e');
    }
  }

  /// 处理频道删除通知
  Future<void> handleChannelDeleted(Map<String, dynamic> data) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      if (channelId.isEmpty) return;
      await _repo.deleteChannel(channelId);
      // 级联清理本地消息：频道被删除后消息已无归属，避免孤儿行长期占用空间
      // 并污染全局消息计数。
      await _messageRepo.deleteMessagesByChannel(channelId);
      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channelId,
          action: 'channel_deleted',
          payload: data,
        ),
      );

      iPrint('ChannelService: 收到频道删除通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理频道删除通知失败 - $e');
    }
  }

  Future<void> handleChannelMessageDeleted(Map<String, dynamic> data) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      final messageId = parseModelString(data['message_id']);
      if (channelId.isEmpty || messageId.isEmpty) {
        return;
      }
      await _messageRepo.deleteMessage(messageId);
      AppEventBus.fire(
        ChannelMessageDeletedEvent(
          channelId: channelId,
          messageId: messageId,
          reason: 'deleted',
        ),
      );
      iPrint('ChannelService: 收到频道删消息通知 - $channelId/$messageId');
    } catch (e) {
      iPrint('ChannelService: 处理频道删消息通知失败 - $e');
    }
  }

  Future<void> handleChannelMessageRevoked(Map<String, dynamic> data) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      final messageId = parseModelString(data['message_id']);
      if (channelId.isEmpty || messageId.isEmpty) {
        return;
      }
      await _messageRepo.deleteMessage(messageId);
      AppEventBus.fire(
        ChannelMessageDeletedEvent(
          channelId: channelId,
          messageId: messageId,
          reason: 'revoked',
        ),
      );
      iPrint('ChannelService: 收到频道撤回通知 - $channelId/$messageId');
    } catch (e) {
      iPrint('ChannelService: 处理频道撤回通知失败 - $e');
    }
  }

  Future<void> handleChannelInvitationCreated(Map<String, dynamic> data) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      if (channelId.isEmpty) return;
      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channelId,
          action: 'channel_invitation_created',
          payload: data,
        ),
      );
      iPrint('ChannelService: 收到频道邀请创建通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理频道邀请创建通知失败 - $e');
    }
  }

  Future<void> handleChannelInvitationAccepted(
    Map<String, dynamic> data,
  ) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      if (channelId.isEmpty) return;
      final channel = await _api.getChannel(channelId);
      if (channel != null) {
        await _repo.saveChannel(channel);
      }
      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channelId,
          action: 'channel_invitation_accepted',
          payload: data,
        ),
      );
      iPrint('ChannelService: 收到频道邀请接受通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理频道邀请接受通知失败 - $e');
    }
  }

  Future<void> handleChannelOrderPaid(Map<String, dynamic> data) async {
    try {
      final channelId = parseModelString(data['channel_id']);
      if (channelId.isEmpty) return;
      await handleChannelSubscribed(data);
      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: channelId,
          action: 'channel_order_paid',
          payload: data,
        ),
      );
      iPrint('ChannelService: 收到频道订单支付通知 - $channelId');
    } catch (e) {
      iPrint('ChannelService: 处理频道订单支付通知失败 - $e');
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
  Future<List<ChannelModel>> discoverChannels({
    String? category,
    int limit = 20,
  }) async {
    return await _api.discoverChannels(category: category, limit: limit);
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
        await _messageRepo.deleteOldMessages(sub.channelId.toString(), keepCount);
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
