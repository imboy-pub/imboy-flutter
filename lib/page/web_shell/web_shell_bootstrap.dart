/// Phase 1.1.h.1 — WebShellPage i18n + 业务接线层
///
/// 解析 slang i18n 文案 + 注入业务 page widget，得到完整可消费的 Web Shell。
/// 是 Phase 1.1.i 路由集成时的目标 widget。
///
/// 设计要点：
/// - **复用现有 i18n key**：`t.titleMessage` / `t.titleContact` / `t.channel.title`
///   / `t.titleMine` 全部是 BottomNavigationPage 已用的 key；welcomeTitle 用
///   运行时全局 `appName`（packageInfo），无需新增 yaml entry，避免与并行
///   i18n 工作撞车
/// - **业务 page 直接复用**：4 个 Tab 中栏内容用现有 [ConversationPage] / [ContactPage]
///   / [ChannelListPage] / [MinePage]，与 BottomNavigationPage 实例化方式一致
/// - **mobile fallback 复用 BottomNavigationPage**：< 900px 时无缝降级到移动端入口
/// - **Selection builder 用占位 widget**：真实 chat panel / contact detail panel
///   等业务 widget 是 Phase 2/3 的工作，本切片用 [_PlaceholderPanel] 占位，
///   后续切片逐个替换
/// - **无单元测试**：本 widget 是简单接线层，关键逻辑全在 [WebShellPage]（已 15
///   widget 测覆盖），集成正确性由 1.1.i 后浏览器烟雾测试 + E2E 验证（避免对
///   ConversationPage 等 ProviderScope 重链路做无价值 mock）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/config/init.dart' show appName;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';

import 'web_shell.dart';

/// Web Shell 业务接线层（i18n + 业务 page 注入）
class WebShellBootstrap extends ConsumerWidget {
  const WebShellBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);

    return WebShellPage(
      // i18n labels — 复用 BottomNavigationPage 已用 key（零新增）
      tabMessageLabel: t.titleMessage,
      tabContactLabel: t.titleContact,
      tabChannelLabel: t.channel.title,
      tabMineLabel: t.titleMine,
      welcomeTitle: appName.isEmpty ? 'ImBoy' : appName,
      // welcomeSubtitle 暂不传：避免新增 i18n key（Phase 4 桌面增强时再补）

      // Tab 中栏内容 — 与 BottomNavigationPage._buildPageList() 顺序对齐
      messageTab: const ConversationPage(),
      contactTab: ContactPage(),
      channelTab: const ChannelListPage(),
      mineTab: MinePage(),

      // 2.6 Chat selection → 真实 ChatPanel（2.1 骨架 + 2.1.b ChatMessageList 接入点）
      // messages/currentUserId 暂不传 → ChatPanel 走占位分支（2.1 行为兼容）
      // 后续 2.1.b.* 切片接入 chat_provider 后传入真实 messages
      chatBuilder: (sel) => ChatPanel(
        peerId: sel.peerId,
        chatType: sel.chatType,
        title: sel.peerId, // TODO 接入 contact_repo 解析昵称（2.1.d）
        closeTooltip: t.cancel,
        onClose: () =>
            ref.read(webShellProvider.notifier).clearSelection(),
        // 2.1.c 续: 过渡占位输入框（真实 ChatInput 接入需 composerHeightNotifier/
        // _handleSendPressed mixin/ExtraItems 链路 — 留作 Phase 2 后续切片）
        inputArea: const _SimpleWebInput(),
      ),
      contactBuilder: (sel) => _PlaceholderPanel('Contact: ${sel.uid}'),
      channelBuilder: (sel) =>
          _PlaceholderPanel('Channel: ${sel.channelId}'),
      mineBuilder: (sel) =>
          _PlaceholderPanel('Mine: ${sel.section ?? "overview"}'),

      // mobile fallback — < 900px 时无缝复用移动端入口
      mobileFallback: const BottomNavigationPage(),

      // Badge counts — 暂不接入 provider（Phase 1.1.h.1.b 时再 ref.watch
      // unreadMessageCountProvider 等真实数据源）
    );
  }
}

/// 2.1.c 续 — 真实 ChatInput 接入前的过渡输入框
///
/// 提供视觉完整性（TextField + 禁用 send button + 提示），让用户在 alpha
/// 测试时知道发送功能尚未启用。真实 ChatInput 接入需要 chat_provider mixin
/// + composerHeightNotifier + ExtraItems 等链路（Phase 2 后续切片）。
class _SimpleWebInput extends StatelessWidget {
  const _SimpleWebInput();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Send message (TODO Phase 2.1.c real ChatInput)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: 'Disabled (Phase 2.1.c TODO)',
            onPressed: null,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Phase 2/3 实施真实 panel 前的占位 widget
class _PlaceholderPanel extends StatelessWidget {
  final String label;

  const _PlaceholderPanel(this.label);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      alignment: Alignment.center,
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
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'TODO Phase 2/3',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
