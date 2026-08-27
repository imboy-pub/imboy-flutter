/// T9 (WP5) — Workspace Channel 详情视图（I6：内容，不是聊天）
///
/// 结构 = 讨论引导横幅 + 现有频道内容页（[ChannelDetailPage]：内容流 +
/// 发帖入口 + 评论——本就是 Publish 模型，无聊天式输入框）。
///
/// I6 落点：
/// - 本页**不提供任何聊天式输入框**（不引用 ChatInput 等聊天组件）
/// - 需要讨论的文案引导至 Group：「想在 General 里讨论？」→ 跳转本工作区
///   Groups 导航（General 群）
///
/// [detailEntry] 默认为现有 ChannelDetailPage；测试可注入标记 widget
/// 断言结构契约（引导横幅存在 + 无 ChatInput）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceChannelDetailPage extends ConsumerWidget {
  final String channelId;

  /// 频道内容区（null = 现有 ChannelDetailPage；测试注入标记 widget
  /// 断言结构契约：引导横幅存在 + 无 ChatInput）。
  final Widget? detailEntry;

  const WorkspaceChannelDetailPage({
    super.key,
    required this.channelId,
    this.detailEntry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.workspace.channelDetailTitle),
        actions: [
          IconButton(
            key: const ValueKey('workspace-channel-detail-dm-entry'),
            tooltip: t.workspace.dmEntry,
            icon: const Icon(CupertinoIcons.chat_bubble),
            onPressed: () => context.push('/conversation'),
          ),
        ],
      ),
      body: Column(
        children: [
          const _DiscussInGroupBanner(),
          Expanded(
            child: detailEntry ?? defaultWorkspaceChannelDetailEntry(channelId),
          ),
        ],
      ),
    );
  }
}

/// 讨论引导横幅（I6 文案：文案值走 slang，新值全部加引号）。
class _DiscussInGroupBanner extends ConsumerWidget {
  const _DiscussInGroupBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        key: const ValueKey('workspace-channel-discuss-guide'),
        onTap: () {
          // 讨论去 Group（聊天唯一入口）：切到本工作区 Groups 导航
          ref
              .read(workspaceShellProvider.notifier)
              .selectDestination(WorkspaceShellDestination.groups);
          Navigator.of(context).maybePop();
        },
        child: Padding(
          padding: AppSpacing.allMedium,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.chat_bubble_2,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              AppSpacing.horizontalSmall,
              Expanded(
                child: Text(
                  t.workspace.discussInGroupGuide,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 默认内容区：现有频道内容页（发帖/评论模型，无聊天输入框）。
Widget defaultWorkspaceChannelDetailEntry(String channelId) =>
    ChannelDetailPage(channelId: channelId, autoLoadStats: false);
