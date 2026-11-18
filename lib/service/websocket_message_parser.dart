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
    // DEF-SYN04-READSYNC-WEB-1（TSID 契约 / safeParseBigIntJson 语义）：
    // S2C 帧顶层 from/to 为 64-bit uid JSON integer，普通解码在 web 上
    // 经 V8 最短往返舍入丢精度（…856→…860），message_read_sync 的
    // _requireReadOwner 与 owner.uid 不等 → StateError 被 switchS2C 吞
    // → markAsRead 永不执行。与 trust/deviceKey/group socket 同款：解码
    // 前对原始文本保真 top-level from/to（只动这条 S2C 解码路径）。
    if (decoded['type']?.toString().toUpperCase() == 'S2C') {
      return jsonDecode(
        rewriteChannelIds(message, ChannelResponseShape.s2cSocket),
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
