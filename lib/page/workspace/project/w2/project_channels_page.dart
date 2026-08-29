/// W2 (ZC-04/ZC-06) — 项目关联频道页（Project Channels）
///
/// 关联管理：link（幂等 created|existing，重复关联给明确反馈不报错）、
/// unlink（确认弹层）、列表（分页）。候选频道取自工作区频道集合
/// （GET /workspaces/:id/channels，WP5 既有端点），不预过滤已关联——
/// 重复选择已关联频道走后端幂等返回 existing。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_providers.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class ProjectChannelsPage extends ConsumerStatefulWidget {
  final EntityId projectId;
  final EntityId workspaceId;

  const ProjectChannelsPage({
    super.key,
    required this.projectId,
    this.workspaceId = '',
  });

  @override
  ConsumerState<ProjectChannelsPage> createState() =>
      _ProjectChannelsPageState();
}

class _ProjectChannelsPageState extends ConsumerState<ProjectChannelsPage> {
  int _pages = 1;
  bool _mutating = false;

  Future<void> _runWrite(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
    } on WorkspaceApiException catch (e) {
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _invalidatePages() {
    for (var p = 1; p <= _pages; p++) {
      ref.invalidate(projectChannelPageProvider((widget.projectId, p)));
    }
  }

  /// 关联频道选择器（候选 = 工作区频道全量；重复选择已关联频道走幂等）。
  Future<void> _link(EntityId projectId) async {
    final t = context.t;
    List<ChannelModel>? candidates;
    try {
      candidates = await ref
          .read(workspaceApiProvider)
          .channels(ref.read(currentWorkspaceProvider)?.id ?? '');
    } catch (e) {
      AppLoading.showError(e.toString());
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      AppLoading.showSuccess(t.workspace.projectChannelNoCandidate);
      return;
    }
    final selected = await showCupertinoModalPopup<ChannelModel>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.workspace.projectChannelLinkTitle),
        actions: [
          for (final c in candidates!)
            CupertinoActionSheetAction(
              key: ValueKey('project-channel-candidate-${c.id}'),
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (selected == null) return;
    await _runWrite(() async {
      // ChannelModel.id 为 int；link 契约按 EntityId（String）传参
      final flag = await ref
          .read(projectChannelApiProvider)
          .link(projectId: projectId, channelId: '${selected.id}');
      if (!mounted) return;
      // 幂等反馈：重复 link 不报错、不重复入库
      AppLoading.showSuccess(
        flag == 'existing'
            ? t.workspace.projectChannelLinkExistingToast
            : t.workspace.projectChannelLinkedToast,
      );
      _invalidatePages();
    });
  }

  Future<void> _unlink(EntityId projectId, ProjectChannelModel c) async {
    final t = context.t;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.workspace.projectChannelUnlinkTitle(name: c.name)),
        message: Text(t.workspace.projectChannelUnlinkDesc),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.projectChannelUnlinkSubmit),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    await _runWrite(() async {
      await ref
          .read(projectChannelApiProvider)
          .unlink(projectId: projectId, channelId: c.channelId);
      if (mounted) {
        AppLoading.showSuccess(t.workspace.projectChannelUnlinkedToast);
      }
      _invalidatePages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final myUid = UserRepoLocal.to.currentUid;
    final detailAsync = ref.watch(projectDetailProvider(widget.projectId));
    final project = detailAsync.value;
    final wsId = widget.workspaceId.isNotEmpty
        ? widget.workspaceId
        : (project?.workspaceId ?? '');
    final currentWs = ref.watch(currentWorkspaceProvider);
    final archived =
        currentWs != null && currentWs.id == wsId && currentWs.isArchived;
    final membersAsync = wsId.isEmpty
        ? null
        : ref.watch(assigneeCandidatesProvider(wsId));
    WorkspaceMemberRole? myWsRole;
    for (final m in membersAsync?.value ?? const <WorkspaceMemberModel>[]) {
      if (m.userId == myUid) myWsRole = m.role;
    }
    final isGuest = myWsRole == WorkspaceMemberRole.guest;
    final isProjectOwner =
        project != null && project.ownerId == myUid && myUid.isNotEmpty;
    final canWrite =
        !archived &&
        !isGuest &&
        (isProjectOwner ||
            (myWsRole != null && myWsRole != WorkspaceMemberRole.guest));

    final pageAsyncs = <AsyncValue<WorkspacePageResult<ProjectChannelModel>>>[
      for (var p = 1; p <= _pages; p++)
        ref.watch(projectChannelPageProvider((widget.projectId, p))),
    ];
    final hasLoading = pageAsyncs.any((a) => a.isLoading);
    final firstError = pageAsyncs
        .where((a) => a.hasError)
        .map((a) => a.error)
        .firstOrNull;
    final loadedPages = <WorkspacePageResult<ProjectChannelModel>>[
      for (final a in pageAsyncs) ?a.value,
    ];

    Widget body;
    if (firstError != null && loadedPages.isEmpty) {
      body = isProjectForbiddenError(firstError)
          ? ProjectForbiddenView(
              onRetry: () => ref.invalidate(
                projectChannelPageProvider((widget.projectId, 1)),
              ),
            )
          : WorkspaceErrorView(
              message: projectW2ViewMessage(context, firstError),
              onRetry: () => ref.invalidate(
                projectChannelPageProvider((widget.projectId, 1)),
              ),
            );
    } else if (hasLoading && loadedPages.isEmpty) {
      body = const WorkspaceLoadingView();
    } else {
      final items = [for (final pg in loadedPages) ...pg.list];
      final totalPage = loadedPages.isEmpty ? 1 : loadedPages.last.totalPage;
      body = ListView(
        padding: AppSpacing.allRegular,
        children: [
          if (canWrite)
            FilledButton.icon(
              key: const ValueKey('project-channel-link-entry'),
              onPressed: _mutating ? null : () => _link(widget.projectId),
              icon: const Icon(CupertinoIcons.link, size: 18),
              label: Text(t.workspace.projectChannelLinkTitle),
            ),
          if (canWrite) AppSpacing.verticalRegular,
          if (items.isEmpty)
            WorkspaceEmptyView(
              icon: CupertinoIcons.link,
              title: t.workspace.projectChannelEmptyTitle,
              subtitle: t.workspace.projectChannelEmptySubtitle,
            )
          else ...[
            for (final c in items)
              _ChannelTile(
                channel: c,
                canWrite: canWrite,
                mutating: _mutating,
                onUnlink: () => _unlink(widget.projectId, c),
              ),
          ],
          if (!hasLoading && loadedPages.isNotEmpty && totalPage > _pages) ...[
            AppSpacing.verticalSmall,
            ProjectW2LoadMoreButton(
              onPressed: () => setState(() => _pages += 1),
            ),
          ],
          if (hasLoading && loadedPages.isNotEmpty)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.projectChannelsTitle)),
      body: body,
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final ProjectChannelModel channel;
  final bool canWrite;
  final bool mutating;
  final VoidCallback onUnlink;

  const _ChannelTile({
    required this.channel,
    required this.canWrite,
    required this.mutating,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('project-channel-tile-${channel.channelId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
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
            backgroundImage: channel.avatar.isNotEmpty
                ? NetworkImage(channel.avatar)
                : null,
            child: channel.avatar.isEmpty
                ? Icon(
                    CupertinoIcons.volume_up,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          AppSpacing.horizontalRegular,
          Expanded(
            child: Text(
              channel.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (canWrite)
            IconButton(
              key: ValueKey('project-channel-unlink-${channel.channelId}'),
              tooltip: context.t.workspace.projectChannelUnlinkSubmit,
              icon: const Icon(Icons.link_off, size: 18),
              onPressed: mutating ? null : onUnlink,
            ),
        ],
      ),
    );
  }
}
