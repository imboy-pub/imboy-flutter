part of 'message_s2c.dart';

/// 频道相关 S2C handler（自 MessageS2CService 抽出的库级私有函数，行为与调用方零变更）
/// 处理频道消息推送
///
/// Action: channel_message
/// 触发时机：订阅的频道发布新消息
/// 处理逻辑：保存消息到本地，更新未读计数
Future<void> _handleChannelMessage(
  Map<String, dynamic> data,
  Map<String, dynamic> payload,
) async {
  iPrint('[S2C] channel_message: 收到频道消息');

  try {
    await ChannelService.to.handleChannelMessage(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelMessage failed: $e');
  }
}

/// 处理频道订阅通知
///
/// Action: channel_subscribed
/// 触发时机：用户成功订阅频道
/// 处理逻辑：更新本地订阅状态
Future<void> _handleChannelSubscribed(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  iPrint('[S2C] channel_subscribed: channelId=$channelId');

  try {
    await ChannelService.to.handleChannelSubscribed(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelSubscribed failed: $e');
  }
}

/// 处理频道取消订阅通知
///
/// Action: channel_unsubscribed
/// 触发时机：用户取消订阅频道
/// 处理逻辑：更新本地订阅状态
Future<void> _handleChannelUnsubscribed(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  iPrint('[S2C] channel_unsubscribed: channelId=$channelId');

  try {
    await ChannelService.to.handleChannelUnsubscribed(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelUnsubscribed failed: $e');
  }
}

/// 处理频道信息更新通知
///
/// Action: channel_updated
/// 触发时机：频道信息被管理员更新
/// 处理逻辑：更新本地频道信息
Future<void> _handleChannelUpdated(Map<String, dynamic> payload) async {
  iPrint('[S2C] channel_updated: 收到频道更新通知');

  try {
    await ChannelService.to.handleChannelUpdated(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelUpdated failed: $e');
  }
}

Future<void> _handleChannelMessageDeleted(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  final messageId = payload['message_id']?.toString() ?? '';
  iPrint(
    '[S2C] channel_message_deleted: channelId=$channelId, messageId=$messageId',
  );

  try {
    await ChannelService.to.handleChannelMessageDeleted(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelMessageDeleted failed: $e');
  }
}

Future<void> _handleChannelMessageRevoked(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  final messageId = payload['message_id']?.toString() ?? '';
  iPrint(
    '[S2C] channel_message_revoked: channelId=$channelId, messageId=$messageId',
  );

  try {
    await ChannelService.to.handleChannelMessageRevoked(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelMessageRevoked failed: $e');
  }
}

Future<void> _handleChannelMessageEdited(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  final messageId = payload['message_id']?.toString() ?? '';
  iPrint(
    '[S2C] channel_message_edited: channelId=$channelId, messageId=$messageId',
  );

  try {
    await ChannelService.to.handleChannelMessageEdited(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelMessageEdited failed: $e');
  }
}

/// 处理频道删除通知
///
/// Action: channel_deleted
/// 触发时机：频道被创建者删除
/// 处理逻辑：删除本地频道数据
Future<void> _handleChannelDeleted(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  iPrint('[S2C] channel_deleted: channelId=$channelId');

  try {
    await ChannelService.to.handleChannelDeleted(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelDeleted failed: $e');
  }
}

Future<void> _handleChannelInvitationCreated(
  Map<String, dynamic> payload,
) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  iPrint('[S2C] channel_invitation_created: channelId=$channelId');

  try {
    await ChannelService.to.handleChannelInvitationCreated(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelInvitationCreated failed: $e');
  }
}

Future<void> _handleChannelInvitationAccepted(
  Map<String, dynamic> payload,
) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  iPrint('[S2C] channel_invitation_accepted: channelId=$channelId');

  try {
    await ChannelService.to.handleChannelInvitationAccepted(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelInvitationAccepted failed: $e');
  }
}

Future<void> _handleChannelOrderPaid(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  iPrint('[S2C] channel_order_paid: channelId=$channelId');

  try {
    await ChannelService.to.handleChannelOrderPaid(payload);
  } on Object catch (e) {
    iPrint('[S2C] handleChannelOrderPaid failed: $e');
  }
}

/// 处理频道未读计数更新
///
/// Action: channel_unread_count
/// 触发时机：频道未读消息数变化
/// 处理逻辑：更新本地未读计数，发布事件通知 UI 刷新
Future<void> _handleChannelUnreadCount(Map<String, dynamic> payload) async {
  final channelId = payload['channel_id']?.toString() ?? '';
  final unreadCount = parseModelInt(payload['unread_count']);
  iPrint(
    '[S2C] channel_unread_count: channelId=$channelId, count=$unreadCount',
  );

  try {
    // 更新本地未读计数
    await ChannelService.to.updateUnreadCount(channelId, unreadCount);

    // 发布事件通知 UI 刷新
    AppEventBus.fire(
      ChannelUnreadCountUpdatedEvent(
        channelId: channelId,
        unreadCount: unreadCount,
      ),
    );
  } on Object catch (e) {
    iPrint('[S2C] s2c_handler failed: $e');
  }
}
