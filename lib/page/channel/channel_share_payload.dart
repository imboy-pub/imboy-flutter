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
