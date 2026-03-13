/// ChatPage 工具函数
///
/// 从 chat_page.dart 中抽取的纯工具函数
/// 这些函数不依赖状态，可以独立测试和复用
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/helper/datetime.dart';

/// ChatPage 工具类
class ChatPageUtils {
  /// 检查消息是否可以编辑
  ///
  /// [message] - 要检查的消息
  /// [currentUserId] - 当前用户ID
  /// 返回 true 如果消息可以编辑（15分钟内的自己的文本消息）
  static bool canEditMessage(Message message, String currentUserId) {
    if (message.authorId != currentUserId) return false;
    if (message is! TextMessage) return false;
    final nowMs = DateTimeHelper.millisecond();
    final messageTimeMs = message.createdAt?.millisecondsSinceEpoch ?? nowMs;
    final timeDiffMs = nowMs - messageTimeMs;
    return timeDiffMs < 15 * 60 * 1000; // 15分钟内可编辑
  }

  /// 检查消息是否为阅后即焚消息
  ///
  /// [message] - 要检查的消息
  /// 返回 true 如果消息设置了阅后即焚
  static bool isBurnMessage(Message message) {
    final m = message.metadata;
    return m?['burn'] == true || m?['is_burn'] == true;
  }

  /// 获取消息的阅后即焚时长（毫秒）
  ///
  /// [message] - 要检查的消息
  /// 返回阅后即焚的时长（毫秒），0 表示未设置
  static int getBurnAfterMs(Message message) {
    final m = message.metadata;
    final raw = m?['burn_after_ms'] ?? m?['expiry_time'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  /// 为消息添加阅后即焚元数据
  ///
  /// [base] - 基础元数据 Map
  /// [burnEnabled] - 是否启用阅后即焚
  /// [burnAfterMs] - 阅后即焚时长（毫秒）
  /// 返回包含阅后即焚元数据的新 Map（如果启用），否则返回原 Map
  static Map<String, dynamic> withBurnMetadata({
    required Map<String, dynamic> base,
    required bool burnEnabled,
    required int burnAfterMs,
  }) {
    if (!burnEnabled) return base;
    return <String, dynamic>{
      ...base,
      'burn': true,
      'burn_after_ms': burnAfterMs,
    };
  }

  /// 验证消息是否为文本消息
  ///
  /// [message] - 要检查的消息
  /// 返回 true 如果消息是文本消息类型
  static bool isTextMessage(Message message) {
    return message is TextMessage;
  }

  /// 验证消息是否为图片消息
  ///
  /// [message] - 要检查的消息
  /// 返回 true 如果消息是图片消息类型
  static bool isImageMessage(Message message) {
    return message is ImageMessage;
  }

  /// 验证消息是否为视频消息
  ///
  /// [message] - 要检查的消息
  /// 返回 true 如果消息是视频消息类型
  static bool isVideoMessage(Message message) {
    final type = message.metadata?['msg_type'] ?? '';
    return type == 'video';
  }

  /// 验证消息是否为音频消息
  ///
  /// [message] - 要检查的消息
  /// 返回 true 如果消息是音频消息类型
  static bool isAudioMessage(Message message) {
    final type = message.metadata?['msg_type'] ?? '';
    return type == 'voice';
  }

  /// 验证消息是否为文件消息
  ///
  /// [message] - 要检查的消息
  /// 返回 true 如果消息是文件消息类型
  static bool isFileMessage(Message message) {
    final type = message.metadata?['msg_type'] ?? '';
    return type == 'file';
  }

  /// 获取消息类型
  ///
  /// [message] - 要检查的消息
  /// 返回消息类型字符串
  static String getMessageType(Message message) {
    return message.metadata?['msg_type'] ?? 'unknown';
  }

  /// 检查消息是否由当前用户发送
  ///
  /// [message] - 要检查的消息
  /// [currentUserId] - 当前用户ID
  /// 返回 true 如果消息是由当前用户发送的
  static bool isFromCurrentUser(Message message, String currentUserId) {
    return message.authorId == currentUserId;
  }
}
