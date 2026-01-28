/// 消息滚动处理器 Mixin
///
/// 处理消息列表滚动相关功能
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 消息滚动处理器 Mixin
///
/// 提供滚动到指定消息、降级滚动等功能
mixin MessageScrollHandler {
  // 获取 Widget 引用
  WidgetRef get ref;

  // 获取要滚动到的消息 ID
  String? get targetMessageId;

  // 获取 chatProvider
  dynamic get chatProvider;

  // 获取 messageScrollManagerProvider
  dynamic get messageScrollManagerProvider;

  // 滚动到目标消息
  Future<void> scrollToTargetMessage() async {
    try {
      // 确保消息列表已加载
      final chatService = (ref.read(chatProvider) as dynamic).chatService;
      if (chatService?.messages.isEmpty ?? true) {
        debugPrint("消息列表为空，无法滚动");
        return;
      }

      // 查找目标消息在列表中的索引
      final messages = chatService!.messages;
      final targetIndex = messages.indexWhere((m) => m.id == targetMessageId);

      if (targetIndex == -1) {
        debugPrint("未找到目标消息: $targetMessageId");
        return;
      }

      debugPrint(
        "找到目标消息: $targetMessageId, 索引: $targetIndex, 总消息数: ${messages.length}",
      );

      // 使用聊天控制器的滚动方法
      await chatService?.scrollToMessage(
        targetMessageId!,
        duration: const Duration(milliseconds: 500),
        offset: 100.0,
      );

      // 高亮消息
      ref
          .read(messageScrollManagerProvider.notifier)
          .highlightMessage(targetMessageId!);
    } catch (e) {
      debugPrint("滚动到目标消息失败: $e");
      // 降级处理：使用简单的索引滚动
      fallbackScrollToMessage();
    }
  }

  /// 降级滚动方法（使用简单的索引滚动）
  void fallbackScrollToMessage() {
    try {
      final chatService = (ref.read(chatProvider) as dynamic).chatService;
      if (chatService?.messages.isEmpty ?? true) {
        return;
      }

      final messages = chatService!.messages;
      final targetIndex = messages.indexWhere((m) => m.id == targetMessageId);

      if (targetIndex == -1 || targetMessageId == null) {
        return;
      }

      // 估算滚动位置
      final estimatedOffset = targetIndex * 80.0; // 假设每条消息平均 80 像素

      // 延迟高亮
      Future.delayed(const Duration(milliseconds: 300), () {
        ref
            .read(messageScrollManagerProvider.notifier)
            .highlightMessage(targetMessageId!);
      });

      debugPrint("使用降级方法滚动到消息: $targetMessageId, 位置: $estimatedOffset");
    } catch (e) {
      debugPrint("降级滚动也失败: $e");
    }
  }
}
