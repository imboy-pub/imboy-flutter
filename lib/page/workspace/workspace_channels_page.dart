/// T9 (WP5) — Workspace Channels 视图（内容在这里，§4.2 IA）
///
/// workspace channel 列表（GET /workspaces/:id/channels，scope 严格分区）；
/// 点进 Channel 详情视图 = 只有发帖/评论入口，无聊天式输入框（I6）——
/// 需要讨论的文案引导至 Group（General）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class WorkspaceChannelsPage extends ConsumerWidget {
  const WorkspaceChannelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        title: t.workspace.navChannels,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final channels = ref.watch(workspaceChannelsProvider(wsId));
    return channels.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: false,
      loading: () => const WorkspaceLoadingView(),
      error: (e, _) => WorkspaceErrorView(
        message: workspaceErrorMessage(e),
        onRetry: () => ref.invalidate(workspaceChannelsProvider(wsId)),
      ),
      data: (list) => _ChannelList(
        key: ValueKey((ref.watch(currentUserProvider)?.uid ?? '', wsId)),
        wsId: wsId,
        channels: list,
      ),
    );
  }
}

class _ChannelList extends ConsumerStatefulWidget {
  final EntityId wsId;
  final List<ChannelModel> channels;
  const _ChannelList({super.key, required this.wsId, required this.channels});
  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  String _query = '';

  Future<void> _refresh() async {
    try {
      ref.invalidate(workspaceChannelsProvider(widget.wsId));
      await ref.read(workspaceChannelsProvider(widget.wsId).future);
    } catch (_) {
      // The parent renders the provider's error and retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    final refreshing = ref
        .watch(workspaceChannelsProvider(widget.wsId))
        .isRefreshing;
    return Column(
      children: [
        Padding(
          padding: AppSpacing.allRegular,
          child: Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  key: const ValueKey('workspace-channel-search'),
                  placeholder: t.channel.searchHint,
                  onChanged: (text) =>
                      setState(() => _query = text.trim().toLowerCase()),
                ),
              ),
              IconButton(
                key: const ValueKey('workspace-channel-refresh'),
                tooltip: MaterialLocalizations.of(context)
                    .refreshIndicatorSemanticLabel,
                onPressed: refreshing ? null : _refresh,
                icon: refreshing
                    ? const CupertinoActivityIndicator()
                    : const Icon(CupertinoIcons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: _refresh, child: _list(context)),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final channels = widget.channels
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query) ||
              '${c.id}'.contains(_query) ||
              (c.customId ?? '').toLowerCase().contains(_query),
        )
        .toList();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.allRegular,
      itemCount: channels.isEmpty ? 1 : channels.length,
      separatorBuilder: (_, _) => AppSpacing.verticalSmall,
      itemBuilder: (context, index) => channels.isEmpty
          ? WorkspaceEmptyView(
              icon: CupertinoIcons.antenna_radiowaves_left_right,
              title: _query.isEmpty
                  ? t.workspace.channelsEmptyTitle
                  : t.channel.noResults,
              subtitle: _query.isEmpty ? t.workspace.channelsEmptySubtitle : '',
            )
          : _ChannelTile(
              wsId: widget.wsId,
              channel: channels[index],
              theme: Theme.of(context),
            ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final EntityId wsId;
  final ChannelModel channel;
  final ThemeData theme;

  const _ChannelTile({
    required this.wsId,
    required this.channel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('workspace-channel-tile-${channel.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.regular),
      onTap: () => context.push(
        '/workspace/$wsId/channels/${channel.id}',
        extra: {'channel_name': channel.name},
      ),
      child: Container(
        padding: AppSpacing.allRegular,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.regular),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                CupertinoIcons.antenna_radiowaves_left_right,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            AppSpacing.horizontalRegular,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.verticalTiny,
                  Text(
                    t.workspace.channelTileSubtitle(
                      count: channel.subscriberCount.toString(),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // I6：频道 = 内容（Publish），不是聊天；详情只有发帖/评论入口
            const Icon(CupertinoIcons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}
