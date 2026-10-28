/// T9 (WP5) — Workspace Channel 详情视图（I6：内容，不是聊天）
///
/// 结构 = 单一外层 AppBar（频道名 + ⋮ 菜单）+ 现有频道内容页
/// （[ChannelDetailPage] embedded 模式：内容流 + 发帖入口 + 评论——
/// 本就是 Publish 模型，无聊天式输入框）。
///
/// 布局裁决（2026-10-17）：砍内层 GlassAppBar，三层头部（「频道」导航 +
/// 内层频道名灰条 + 头部大标题）收敛为一层；标题与 ⋮ 菜单直接 watch
/// [channelDetailProvider]（内层页面负责加载，同一 provider 单一真源）。
///
/// W06/F12 收敛（J12）：移除「去 General 群聊聊」常驻引导横幅与进个人
/// 会话列表的「私聊/全部消息」按钮——讨论的唯一合法目的地是内容区内的
/// 真实绑定讨论入口（[ChannelDiscussionEntry]，经 embedded
/// ChannelDetailPage 提供）；不造 General、不自动加入。
///
/// [detailEntry] 默认为现有 ChannelDetailPage（embedded）；测试可注入标记
/// widget 断言结构契约（无 ChatInput、无讨论引导横幅）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_detail_rules.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_overflow_menu.dart';
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';

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
    final id = workspaceId ?? ref.watch(currentWorkspaceProvider)?.id ?? '';
    final content = ProviderScope(
      overrides: [
        channelDetailProvider.overrideWith(ChannelDetailNotifier.new),
      ],
      child: _AuthorizedWorkspaceChannelPage(
        channelId: channelId,
        target: (workspaceId: id, resource: 'channel:$channelId'),
        detailEntry: detailEntry,
      ),
    );
    return WorkspaceAccessGuard(
      target: (workspaceId: id, resource: 'channel:$channelId'),
      builder: (_, access) => content,
    );
  }
}

class _AuthorizedWorkspaceChannelPage extends ConsumerWidget {
  const _AuthorizedWorkspaceChannelPage({
    required this.channelId,
    required this.target,
    required this.detailEntry,
  });

  final String channelId;
  final WorkspaceAccessTarget target;
  final Widget? detailEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(channelDetailProvider.select((state) => state.error), (
      _,
      error,
    ) {
      if (error != null) {
        ref
            .read(workspaceAccessProvider(target).notifier)
            .markContentUnavailable();
      }
    });
    // 频道数据由内嵌 ChannelDetailPage 加载，同一 provider 直接读（单一
    // 真源）；未加载完成时回退到「频道」标题。叠页/其他目标在途时按归属
    // 过滤回退到本目标快照，避免标题串台（J07）。
    final channel = ownChannelDetailState(
      ref.watch(channelDetailProvider),
      ref.read(channelDetailProvider.notifier).requestedChannelId,
      channelId,
      ref.read(channelDetailProvider.notifier).snapshotFor(channelId),
    ).channel;
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
            IconButton(
              tooltip: context.t.channel.linkTitle,
              icon: const Icon(CupertinoIcons.link),
              onPressed: () => showChannelShareSheet(context, channel),
            ),
          if (channel != null)
            ChannelOverflowMenu(
              key: const ValueKey('workspace-channel-overflow-menu'),
              channel: channel,
            ),
        ],
      ),
      body: detailEntry ?? defaultWorkspaceChannelDetailEntry(channelId),
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
