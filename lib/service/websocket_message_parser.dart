import 'dart:convert';

import 'package:imboy/component/http/channel_id_response_decoder.dart';

/// 统一消息解析方法
Map<String, dynamic> parseWebSocketMessage(dynamic message) {
  if (message is String) {
    final decoded = jsonDecode(message) as Map<String, dynamic>;
    if (decoded['action'] == 'e2ee_trust_changed' ||
        decoded['action'] == 'e2ee_device_key_changed') {
      return jsonDecode(
        rewriteChannelIds(
          message,
          decoded['action'] == 'e2ee_trust_changed'
              ? ChannelResponseShape.trustSocket
              : ChannelResponseShape.deviceKeySocket,
        ),
      ) as Map<String, dynamic>;
    }
    if ((decoded['action']?.toString().toLowerCase() ?? '').startsWith(
          'group_',
        ) ||
        decoded['action'] == 'apply_friend' ||
        decoded['action'] == 'apply_friend_confirm' ||
        decoded['type']?.toString().toUpperCase() == 'C2G' ||
        decoded['type']?.toString().toUpperCase() == 'C2C') {
      return jsonDecode(
        rewriteChannelIds(message, ChannelResponseShape.groupSocket),
      ) as Map<String, dynamic>;
    }
    if ((decoded['action']?.toString().toLowerCase() ?? '').startsWith(
          'channel_',
        ) ||
        (decoded['type']?.toString().toUpperCase() == 'C2CH_SERVER_ACK')) {
      return jsonDecode(rewriteChannelIds(message, ChannelResponseShape.socket))
          as Map<String, dynamic>;
    }
    return decoded;
  } else if (message is Map<String, dynamic>) {
    return message;
  } else if (message is Map) {
    return Map<String, dynamic>.from(message);
  }
  throw FormatException('不支持的消息格式: ${message.runtimeType}');
}
