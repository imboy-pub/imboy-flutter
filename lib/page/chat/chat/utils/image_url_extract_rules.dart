/// 消息列表图片 URL 提取 —— 纯函数（仅依赖 flutter_chat_core + 消息类型常量）
///
/// slice-C-6: `_getAllImageUrlsInConversation`（L2415-2462）中的 URL 提取
/// 循环内联在 Widget 方法体，三个分支（ImageMessage / CustomMessage单图 /
/// CustomMessage多图），零测试覆盖。
/// 提取后注入 `List<Message>`，可独立单测钉死所有分支与边界契约。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 从消息列表中提取所有图片 URL，保持原始顺序。
///
/// 处理三种情况：
/// 1. [ImageMessage]           — 直接取 `source` 字段
/// 2. [CustomMessage] `image`  — 取 `metadata['source']`，不存在时取 `['uri']`
/// 3. [CustomMessage] `image_multi` — 遍历 `metadata['images']`，取各元素 `['uri']`
///
/// `effective_msg_type` 优先于 `msg_type`（外层业务覆写语义）。
/// 空串 URL 一律跳过，不进入结果列表。
List<String> extractImageUrlsFromMessages(List<Message> messages) {
  final urls = <String>[];
  for (final msg in messages) {
    if (msg is ImageMessage) {
      if (msg.source.isNotEmpty) urls.add(msg.source);
    } else if (msg is CustomMessage) {
      final meta = msg.metadata ?? {};
      final msgType =
          (meta['effective_msg_type'] ?? meta['msg_type'] ?? '') as String;

      if (msgType == MessageType.image) {
        final uri =
            ((meta['source'] ?? meta['uri'] ?? '') as String);
        if (uri.isNotEmpty) urls.add(uri);
      } else if (msgType == MessageType.imageMulti) {
        final images = meta['images'] as List<dynamic>?;
        if (images != null) {
          for (final img in images) {
            final uri = (img['uri'] ?? '') as String;
            if (uri.isNotEmpty) urls.add(uri);
          }
        }
      }
    }
  }
  return urls;
}
