/// 消息事件处理器 Mixin
///
/// 处理所有消息相关的用户交互事件
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

// 导入 UserCollectHelper 用于判断消息是否可收藏
import 'package:imboy/modules/social_graph/public.dart' show UserCollectHelper;

/// 消息事件处理器 Mixin
///
/// 提供消息点击、双击、长按等事件处理方法
mixin MessageEventHandler {
  // 获取当前用户 ID
  String get currentUserId;

  // 获取 MessageActionHandler 实例
  dynamic get messageActionHandler;

  // 获取 BuildContext
  BuildContext get context;

  // 更新引用消息的回调
  Future<void> updateQuoteMessage(Message? msg);

  // 消息重试回调
  Future<void> onMessageRetry(String messageId);

  /// 检查消息是否可以保存
  bool canSaveMessage(Message message) {
    if (message is ImageMessage) {
      return true;
    } else if (message is FileMessage) {
      return true;
    } else if (message is CustomMessage) {
      final msgType = message.metadata?['msg_type'] ?? '';
      return msgType == 'video' || msgType == 'voice';
    }
    return false;
  }

  /// 检查消息是否可以收藏
  bool canCollectMessage(Message message) {
    // 使用 UserCollectHelper 判断消息是否支持收藏
    // 支持：文本、图片、语音、视频、文件、位置、名片
    int kind = UserCollectHelper.getCollectKind(message);
    debugPrint("canCollectMessage: type=${message.runtimeType}, kind=$kind");
    return kind > 0;
  }

  /// 检查消息是否可以重试
  bool canRetryMessage(Message message) {
    return message.status == MessageStatus.error;
  }

  /// 编辑消息
  Future<void> editMessage(Message message) async {
    await messageActionHandler.editMessage(message);
  }

  /// 添加消息反应
  Future<void> addReaction(Message message, String emoji) async {
    await messageActionHandler.addReaction(context, message, emoji);
  }

  /// 删除消息(仅自己)
  Future<void> deleteMessageForMe(
    BuildContext context,
    Message msg, {
    bool pop = true,
  }) async {
    await messageActionHandler.deleteMessageForMe(context, msg, pop: pop);
  }

  /// 删除消息(所有人)
  Future<void> deleteMessageForEveryone(
    BuildContext context,
    Message msg,
  ) async {
    await messageActionHandler.deleteMessageForEveryone(context, msg);
  }

  /// 复制消息文本
  void copyMessageText(TextMessage msg) {
    messageActionHandler.copyMessageText(msg);
  }

  /// 保存消息内容
  Future<void> saveMessageContent(Message msg) async {
    await messageActionHandler.saveMessageContent(msg);
  }

  /// 收藏消息
  Future<void> collectMessage(Message msg) async {
    await messageActionHandler.collectMessage(msg);
  }

  /// 撤回消息
  Future<void> revokeMessage(Message msg) async {
    await messageActionHandler.revokeMessage(msg);
  }

  /// 转发消息
  void forwardMessage(Message msg) {
    messageActionHandler.forwardMessage(context, msg);
  }
}
