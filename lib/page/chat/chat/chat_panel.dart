/// Phase 2.1 — Chat Panel 嵌入式聊天面板（架构接缝）
///
/// 与 mobile 端的 [ChatPage] 平行的 Web 嵌入式版本：
/// - **不带 [Scaffold] / [AppBar]**：作为 [WebMainPanel.chatBuilder] 的右栏内容
///   渲染，由父级 (1.1.h.2 [WebShellPage]) 控制整体布局
/// - **架构接缝（architectural seam）**：本切片仅建立 props 边界 + 顶部 header +
///   占位 body；后续 slice 2.1.b/c/d 逐个接入 [ChatMessageList] / [ChatInput] /
///   [chatProvider] 状态层（避免一次性引入大量依赖让单测复杂度爆炸）
/// - **mobile 端零影响**：[ChatPage] 完全不动，本 widget 与之并行存在
///
/// 设计原则（与 Phase 1.1 一致）：
/// - 无 i18n 依赖：title / closeTooltip 通过 props 注入（slang 解析在调用方）
/// - 无业务依赖：onClose 回调由调用方处理（通常是
///   `ref.read(webShellProvider.notifier).clearSelection()`）
/// - 响应主题：用 ColorScheme / TextTheme 取色
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/chat/widget/chat_message_list.dart';

/// Web 嵌入式聊天面板
///
/// 当前阶段（2.1）仅渲染 header + 占位 body。
/// 实际消息列表 / 输入框接入留给 2.1.b/c/d 切片。
class ChatPanel extends ConsumerWidget {
  /// 对端 ID（C2C uid 或 C2G groupId，TSID 字符串）
  final String peerId;

  /// 'C2C' / 'C2G'
  final String chatType;

  /// header 显示的标题（由调用方传入 i18n 解析后的对端昵称/群名）
  final String title;

  /// 关闭按钮 tooltip（i18n 解析后的字符串）
  final String closeTooltip;

  /// 关闭回调（点击 header 关闭按钮时触发）
  ///
  /// 通常调用方做 `ref.read(webShellProvider.notifier).clearSelection()`，
  /// 本 widget 不直接耦合 webShellProvider（保持模块边界）。
  final VoidCallback? onClose;

  // === 2.1.b 新增：消息列表 props（可选，传入则用 ChatMessageList，否则占位） ===

  /// 消息列表（null = 占位模式 / 空列表 = 显示空消息状态 / 非空 = 渲染列表）
  final List<Message>? messages;

  /// 当前用户 ID（messages 非 null 时必填）
  final String? currentUserId;

  /// 消息长按回调（messages 非 null 时必填）
  final void Function(Message message)? onMessageLongPress;

  /// 消息双击回调（messages 非 null 时必填）
  final void Function(Message message)? onMessageDoubleTap;

  /// 消息单击回调（可选）
  final void Function(Message message)? onMessageTap;

  /// 上拉到底加载更多（可选，分页）
  final Future<void> Function()? onEndReached;

  // === 2.1.c 新增：底部输入区域（解耦设计 — 调用方传任何 widget） ===

  /// 底部输入区域 widget（通常是 ChatInput；null = 不渲染输入区）
  ///
  /// 解耦设计：本 widget 不直接 import ChatInput（避免引入 StatefulWidget 重 state
  /// 与 chat_provider 强依赖），由调用方决定传什么 widget。例如：
  /// - 生产: `inputArea: ChatInput(peerId: peerId, ...)`
  /// - 测试: `inputArea: TextField(...)` 或 `inputArea: SizedBox.shrink()`
  /// - 只读模式: `inputArea: null`
  final Widget? inputArea;

  const ChatPanel({
    super.key,
    required this.peerId,
    required this.chatType,
    required this.title,
    required this.closeTooltip,
    this.onClose,
    this.messages,
    this.currentUserId,
    this.onMessageLongPress,
    this.onMessageDoubleTap,
    this.onMessageTap,
    this.onEndReached,
    this.inputArea,
  }) : assert(
         messages == null ||
             (currentUserId != null &&
                 onMessageLongPress != null &&
                 onMessageDoubleTap != null),
         'messages 提供时 currentUserId/onMessageLongPress/onMessageDoubleTap 必填',
       );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          _ChatPanelHeader(
            title: title,
            chatType: chatType,
            closeTooltip: closeTooltip,
            onClose: onClose,
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: messages == null
                ? _ChatPanelPlaceholder(peerId: peerId, chatType: chatType)
                : ChatMessageList(
                    messages: messages!,
                    currentUserId: currentUserId!,
                    onMessageLongPress: onMessageLongPress!,
                    onMessageDoubleTap: onMessageDoubleTap!,
                    onMessageTap: onMessageTap,
                    onEndReached: onEndReached,
                  ),
          ),
          ?inputArea,
        ],
      ),
    );
  }
}

/// header：avatar 占位 + 标题 + 类型 badge + 关闭按钮
class _ChatPanelHeader extends StatelessWidget {
  final String title;
  final String chatType;
  final String closeTooltip;
  final VoidCallback? onClose;

  const _ChatPanelHeader({
    required this.title,
    required this.chatType,
    required this.closeTooltip,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: colorScheme.surfaceContainer,
      child: Row(
        children: [
          // avatar 占位（2.1.b 接入真实头像）
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withAlpha(31),
            child: Icon(
              chatType == 'C2G' ? Icons.group : Icons.person,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: closeTooltip,
              onPressed: onClose,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

/// 占位 body（2.1.b/c 接入 ChatMessageList + ChatInput）
class _ChatPanelPlaceholder extends StatelessWidget {
  final String peerId;
  final String chatType;

  const _ChatPanelPlaceholder({required this.peerId, required this.chatType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '$chatType chat: $peerId',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TODO Phase 2.1.b/c — ChatMessageList + ChatInput',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
