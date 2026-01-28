/// 聊天背景装饰组件
///
/// 根据用户选择的背景类型显示相应的装饰效果
library;

import 'package:flutter/material.dart';

import 'package:imboy/page/chat/widget/chat_background_manager.dart'
    show ChatBackgroundState;

/// 聊天背景装饰组件
///
/// 注意：此组件已废弃，请直接使用 `ChatBackgroundManager.getCurrentBackgroundDecoration()`
@Deprecated(
  'Use ChatBackgroundManager.getCurrentBackgroundDecoration() instead',
)
class ChatBackgroundDecoration {
  const ChatBackgroundDecoration({required this.backgroundState});

  final ChatBackgroundState backgroundState;

  /// 构建背景装饰
  ///
  /// 此方法仅用于向后兼容，新代码应使用：
  /// ```dart
  /// ref.read(chatBackgroundManagerProvider.notifier).getCurrentBackgroundDecoration()
  /// ```
  BoxDecoration buildDecoration() {
    // 返回默认装饰，实际实现已迁移到 ChatBackgroundManager
    return const BoxDecoration(color: Colors.white);
  }
}
