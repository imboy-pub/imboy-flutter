import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';

/// The existing channel-card message shape consumed by the send-to route.
Map<String, dynamic> channelCardShareExtra(ChannelModel channel) => {
  'msg': {
    'msg_type': 'channel_card',
    'content': channel.name,
    'payload': {
      'channel_id': channel.id,
      'channel_name': channel.name,
      'channel_avatar': channel.avatar,
      'subscriber_count': channel.subscriberCount,
    },
  },
};

/// 使用已注册的频道卡片渲染器；接收端凭标识重新鉴权读取文章。
Map<String, dynamic> channelArticleShareExtra(
  String channelId,
  ChannelMessageModel message,
) => {
  'msg': {
    'msg_type': 'channel_card',
    'content': message.contentPreview,
    'payload': {
      'channel_id': channelId,
      'message_id': message.id,
      'channel_name': message.contentPreview,
    },
  },
};
