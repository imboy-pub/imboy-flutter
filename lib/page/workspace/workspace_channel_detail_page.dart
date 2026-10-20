/// T9 (WP5) — Workspace Channel 详情视图（I6：内容，不是聊天）
///
/// 结构 = 单一外层 AppBar（频道名 + ⋮ 菜单 + 私聊入口）+ 讨论引导横幅 +
/// 现有频道内容页（[ChannelDetailPage] embedded 模式：内容流 +
/// 发帖入口 + 评论——本就是 Publish 模型，无聊天式输入框）。
///
/// 布局裁决（2026-10-17）：砍内层 GlassAppBar，三层头部（「频道」导航 +
/// 内层频道名灰条 + 头部大标题）收敛为一层；标题与 ⋮ 菜单直接 watch
/// [channelDetailProvider]（内层页面负责加载，同一 provider 单一真源）。
///
/// I6 落点：
/// - 本页**不提供任何聊天式输入框**（不引用 ChatInput 等聊天组件）
/// - 需要讨论的文案引导至 Group：「想在 General 里讨论？」→ 跳转本工作区
///   本工作区群列表（General 群）
///
/// [detailEntry] 默认为现有 ChannelDetailPage（embedded）；测试可注入标记
/// widget 断言结构契约（引导横幅存在 + 无 ChatInput）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_overflow_menu.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceChannelDetailPage extends ConsumerWidget {
  final String channelId;

  /// 频道内容区（null = 现有 ChannelDetailPage embedded；测试注入标记
  /// widget 断言结构契约：引导横幅存在 + 无 ChatInput）。
  final Widget? detailEntry;

  const WorkspaceChannelDetailPage({
    super.key,
    required this.channelId,
    this.detailEntry,
    this.workspaceId,
  });

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 频道数据由内嵌 ChannelDetailPage 加载，同一 provider 直接读（单一
    // 真源）；未加载完成时回退到「频道」标题。
    final channel = ref.watch(channelDetailProvider).channel;
    return Scaffold(
      appBar: AppBar(
        title: channel == null
            ? Text(t.workspace.channelDetailTitle)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => showChannelInfoDialog(context, channel),
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
        actions: [
          if (channel != null)
            ChannelOverflowMenu(
              key: const ValueKey('workspace-channel-overflow-menu'),
              channel: channel,
            ),
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
          _DiscussInGroupBanner(workspaceId: workspaceId),
          Expanded(
            child: detailEntry ?? defaultWorkspaceChannelDetailEntry(channelId),
          ),
        ],
      ),
    );
  }
}

/// 讨论引导横幅（I6 文案：文案值走 slang，新值全部加引号）。
class _DiscussInGroupBanner extends StatelessWidget {
  const _DiscussInGroupBanner({this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        key: const ValueKey('workspace-channel-discuss-guide'),
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(t.workspace.navGroups)),
              body: WorkspaceGroupsPage(workspaceId: workspaceId),
            ),
          ),
        ),
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
              // P1-05：全页唯一方向指示。T06 已把 10 locale 文案的箭头
              // 字符移除；此处 chevron 在 RTL 下自动镜像；对读屏为纯
              // 装饰（导航语义由 InkWell 提供），避免「箭头」被朗读。
              ExcludeSemantics(
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 默认内容区：现有频道内容页 embedded 模式（无内层 AppBar；发帖/评论
/// 模型，无聊天输入框）。
Widget defaultWorkspaceChannelDetailEntry(String channelId) =>
    ChannelDetailPage(
      channelId: channelId,
      autoLoadStats: false,
      embedded: true,
    );
