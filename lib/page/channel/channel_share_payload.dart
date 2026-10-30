import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';

/// 「频道 → 聊天」分享消息的 payload 形状：**扁平**业务字段。
///
/// 所有消息 builder 都从 `metadata` 顶层读业务字段（红包含 `greeting`、
/// 名片含 `uid`…），频道卡片渲染器同样读 `metadata['channel_id']`。
/// 曾把业务字段再包一层 `payload`，卡片拿不到频道标识 —— 点卡片没有任何
/// 反应（2026-10-30 真机排查）。新发送一律写扁平；历史嵌套行由
/// `ChannelCardMessageBuilder` 的嵌套兜底读取兼容，见该文件 `_flatten`。
Map<String, dynamic> channelCardShareExtra(ChannelModel channel) => {
  'msg': {
    'msg_type': MessageType.channelCard,
    'content': channel.name,
    'channel_id': channel.id,
    'channel_name': channel.name,
    'channel_avatar': channel.avatar,
    'subscriber_count': channel.subscriberCount,
  },
};

/// 频道内**单条内容**（文章/图文/图片/视频…）分享到聊天。
///
/// 复用已注册的频道卡片渲染器；`message_id` 让接收端直接落到该条内容页
/// （见 `ChannelCardMessageBuilder` 的跳转：数字 id 才走 article 路由）。
///
/// ⚠️ 这里曾写私有 msg_type `channel_message`：全站没有任何 builder 注册它，
/// 收发双方都只看到「不支持的消息类型 (channel_message)」——正是 2026-10-30
/// 截图的缺陷。历史行的识别与归一在 `MessageTypeNormalizer` 的别名表。
Map<String, dynamic> channelPostShareExtra(
  String channelId,
  ChannelMessageModel message,
) => {
  'msg': {
    'msg_type': MessageType.channelCard,
    'content': message.contentPreview,
    'channel_id': channelId,
    'message_id': message.id,
    'channel_name': message.contentPreview,
  },
};
